import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';

const driveFileScope = 'https://www.googleapis.com/auth/drive.file';

class DriveFailure implements Exception {
  const DriveFailure(this.message);
  final String message;
}

class BackupPaused implements Exception {
  const BackupPaused();
}

class DrivePermissionRequired extends DriveFailure {
  const DrivePermissionRequired(super.message);
}

class DriveResponse {
  DriveResponse(this.status, this.headers, this.body);
  final int status;
  final HttpHeaders headers;
  final String body;
  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;
}

/// Only Google Drive endpoints are accepted; Google tokens never reach Supabase.
class DriveApi {
  DriveApi(this.account, this.beforeRequest);
  final GoogleSignInAccount account;
  final Future<void> Function() beforeRequest;
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);
  String? _token;
  bool _closed = false;

  void close() {
    _closed = true;
    _http.close(force: true);
  }

  static Uri endpoint(String path, [Map<String, String>? query]) =>
      Uri.https('www.googleapis.com', path, query);

  Future<void> authorize({required bool interactive}) async {
    // Reuse an existing grant; consent UI is only a fallback on enable.
    var authorization = await account.authorizationClient
        .authorizationForScopes([driveFileScope]);
    if (authorization == null && interactive && !_closed) {
      authorization = await account.authorizationClient.authorizeScopes([
        driveFileScope,
      ]);
    }
    if (authorization == null) {
      throw const DrivePermissionRequired(
        'Drive permission is needed. Turn Drive backup on again.',
      );
    }
    _token = authorization.accessToken;
  }

  Future<DriveResponse> request(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? body,
    bool retried = false,
  }) async {
    if (_closed) {
      throw const BackupPaused();
    }
    if (uri.scheme != 'https' || uri.host != 'www.googleapis.com') {
      throw const DriveFailure('Unexpected Drive upload address. Try again.');
    }
    await beforeRequest();
    if (_token == null) {
      await authorize(interactive: false);
    }
    if (_closed) {
      throw const BackupPaused();
    }
    final req = await _http.openUrl(method, uri);
    req.followRedirects = false; // 308 is an upload status, not a redirect.
    req.headers.set('Authorization', 'Bearer $_token');
    headers.forEach((key, value) => req.headers.set(key, value));
    req.contentLength = body?.length ?? 0;
    if (body != null) {
      req.add(body);
    }
    try {
      final response = await req.close().timeout(const Duration(seconds: 60));
      final text = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 60));
      final result = DriveResponse(response.statusCode, response.headers, text);
      if (result.status == 401 && !retried) {
        await account.authorizationClient.clearAuthorizationToken(
          accessToken: _token!,
        );
        _token = null;
        return await request(
          method,
          uri,
          headers: headers,
          body: body,
          retried: true,
        );
      }
      return result;
    } on TimeoutException {
      req.abort();
      rethrow;
    }
  }

  void requireSuccess(DriveResponse response) {
    if (response.status >= 200 && response.status < 300) {
      return;
    }
    // Do not expose provider response bodies, tokens or session URLs in UI/logs.
    if (response.status == 401) {
      throw const DrivePermissionRequired(
        'Drive permission expired. Turn Drive backup on again.',
      );
    }
    throw DriveFailure(
      response.status == 403
          ? 'Drive access was refused. Check Drive permission, API setup and storage quota.'
          : 'Drive could not complete the request (${response.status}). Try again.',
    );
  }

  Future<String> generateId() async {
    final response = await request(
      'GET',
      endpoint('/drive/v3/files/generateIds', {'count': '1', 'space': 'drive'}),
    );
    requireSuccess(response);
    return (response.json['ids'] as List).single as String;
  }

  Future<DriveResponse> metadata(String id) => request(
    'GET',
    endpoint('/drive/v3/files/$id', {
      'fields':
          'id,name,mimeType,trashed,size,md5Checksum,parents,appProperties',
    }),
  );

  Future<void> createFolder(String id) async {
    final response = await request(
      'POST',
      endpoint('/drive/v3/files'),
      headers: {'Content-Type': 'application/json'},
      body: utf8.encode(
        jsonEncode({
          'id': id,
          'name': 'Filo Backup',
          'mimeType': 'application/vnd.google-apps.folder',
          'appProperties': {'filoBackup': 'v1'},
        }),
      ),
    );
    // A lost successful create response can be reconciled by the stable ID.
    if (response.status != 409) requireSuccess(response);
  }

  Future<Uri> startUpload({
    required String fileId,
    required String folderId,
    required String name,
    required String digest,
    required int size,
    bool update = false,
  }) async {
    final response = await request(
      update ? 'PATCH' : 'POST',
      endpoint('/upload/drive/v3/files${update ? '/$fileId' : ''}', {
        'uploadType': 'resumable',
        'fields': 'id,size,md5Checksum',
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-Upload-Content-Type': 'application/octet-stream',
        'X-Upload-Content-Length': '$size',
      },
      body: utf8.encode(
        jsonEncode({
          if (!update) 'id': fileId,
          'name': name,
          if (!update) 'parents': [folderId],
          'appProperties': {'filoBackup': 'v1', 'digest': digest},
        }),
      ),
    );
    requireSuccess(response);
    final location = response.headers.value('location');
    if (location == null) {
      throw const DriveFailure('Drive did not start the upload. Try again.');
    }
    final uri = Uri.parse(location);
    if (uri.scheme != 'https' || uri.host != 'www.googleapis.com') {
      throw const DriveFailure('Unexpected Drive upload address.');
    }
    return uri;
  }

  Future<void> createEmptyFile(
    String id,
    String folder,
    String name,
    String digest,
  ) async {
    final response = await request(
      'POST',
      endpoint('/drive/v3/files'),
      headers: {'Content-Type': 'application/json'},
      body: utf8.encode(
        jsonEncode({
          'id': id,
          'name': name,
          'parents': [folder],
          'mimeType': 'application/octet-stream',
          'appProperties': {'filoBackup': 'v1', 'digest': digest},
        }),
      ),
    );
    if (response.status != 409) requireSuccess(response);
  }

  Future<DriveResponse> uploadStatus(Uri uri, int size) =>
      request('PUT', uri, headers: {'Content-Range': 'bytes */$size'});

  Future<DriveResponse> uploadChunk(
    Uri uri,
    List<int> bytes,
    int start,
    int total,
  ) => request(
    'PUT',
    uri,
    headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Range': 'bytes $start-${start + bytes.length - 1}/$total',
    },
    body: bytes,
  );

  static int receivedBytes(DriveResponse response) {
    final range = response.headers.value('range');
    if (range == null) {
      return 0;
    }
    final match = RegExp(r'^bytes=0-(\d+)$').firstMatch(range);
    if (match == null) {
      throw const DriveFailure('Drive returned an invalid upload offset.');
    }
    return int.parse(match[1]!) + 1;
  }
}
