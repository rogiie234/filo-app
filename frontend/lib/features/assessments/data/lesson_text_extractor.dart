import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';

import '../domain/ai_sources.dart';
import 'file_text_cache.dart';

class LessonReadException implements Exception {
  const LessonReadException(this.code, this.message);
  final String code, message;
  @override
  String toString() => message;
}

const noLessonText = LessonReadException(
  'NO_TEXT',
  'No readable text found in this file.',
);
const lessonTooLarge = LessonReadException(
  'TOO_LARGE',
  'This file is too large. The limit is 10 MB.',
);
const lessonReadFailed = LessonReadException(
  'READ_FAILED',
  'This file could not be read. Choose an unencrypted, undamaged document.',
);
const lessonTimedOut = LessonReadException(
  'TIMEOUT',
  'Reading this file took too long. Choose a smaller file or section.',
);

class LessonTextExtractor {
  LessonTextExtractor({
    this.cache,
    this.timeout = const Duration(seconds: 45),
    this.openPdf,
  });
  final FileTextCache? cache;
  final Duration timeout;
  final Future<PdfDocument> Function(String)? openPdf;
  static Future<void> _tail = Future.value();
  static Future<void> waitUntilIdle() => _tail;
  static const maxFileBytes = 10 * 1024 * 1024;
  static const maxCharacters = 40000;
  static const supported = [
    'txt',
    'pdf',
    'docx',
    'pptx',
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  Future<LessonText> extract(
    String path,
    String fileType, {
    String? attachmentId,
    String? draftQuizId,
    AiCancelToken? cancel,
    void Function(ExtractionProgress)? onProgress,
  }) async {
    final owner = cancel ?? AiCancelToken();
    final token = AiCancelToken();
    unawaited(owner.cancelled.then((_) => token.cancel()));
    final type = fileType.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    if (!supported.contains(type))
      throw const LessonReadException(
        'UNSUPPORTED',
        'This file type is not supported.',
      );
    owner.check();
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      token.cancel();
    });
    final work = _tail.then((_) async {
      token.check();
      try {
        final file = File(path);
        final length = await file.length();
        if (length > maxFileBytes) throw lessonTooLarge;
        final stamp = await file.lastModified();
        onProgress?.call(const ExtractionProgress('Checking text cache...'));
        final key = attachmentId == null
            ? 'sha:${(await _worker(path, 'sha', token, onProgress))['text']}'
            : 'att:$attachmentId';
        token.check();
        final hit = await cache?.find(key);
        if (hit != null) {
          if (draftQuizId != null) await cache!.associate(draftQuizId, key);
          return hit;
        }
        final raw = type == 'pdf'
            ? await _pdf(path, token, onProgress)
            : ['jpg', 'jpeg', 'png', 'webp'].contains(type)
            ? await _image(path, token, onProgress)
            : await _worker(path, type, token, onProgress);
        token.check();
        if (length != await file.length() || stamp != await file.lastModified())
          throw lessonReadFailed;
        final result = LessonText(
          text: raw['text'] as String,
          sourceKey: key,
          knownCharacterCount: raw['character_count'] as int?,
          warnings: (raw['warnings'] as List).cast<String>(),
        );
        if (result.text.trim().isEmpty) throw noLessonText;
        if (cache != null && draftQuizId != null)
          await cache!.save(result, draftQuizId);
        token.check();
        return result;
      } on LessonReadException {
        rethrow;
      } on AiCancelled {
        rethrow;
      } catch (_) {
        throw lessonReadFailed;
      }
    });
    // Native calls drain before another extraction is admitted, even after cancellation.
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    try {
      return await token.wait(work);
    } on AiCancelled {
      if (timedOut) throw lessonTimedOut;
      rethrow;
    } finally {
      timer.cancel();
    }
  }

  Future<Map<String, dynamic>> _worker(
    String path,
    String type,
    AiCancelToken token,
    void Function(ExtractionProgress)? progress,
  ) async {
    final port = ReceivePort();
    final result = Completer<Map<String, dynamic>>();
    final sub = port.listen((dynamic value) {
      final map = Map<String, dynamic>.from(value as Map);
      if (map.containsKey('stage')) {
        if (!token.isCancelled)
          progress?.call(
            ExtractionProgress(
              map['stage'] as String,
              completed: map['completed'] as int?,
              total: map['total'] as int?,
            ),
          );
      } else if (map.containsKey('error')) {
        if (!result.isCompleted)
          result.completeError(
            LessonReadException(
              map['error'] as String,
              map['message'] as String,
            ),
          );
      } else if (!result.isCompleted) {
        result.complete(map);
      }
    });
    final exit = ReceivePort();
    final exited = exit.first;
    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(_extractWorker, (
        path,
        type,
        port.sendPort,
      ), onExit: exit.sendPort);
      return await token.wait(result.future);
    } finally {
      isolate?.kill(priority: Isolate.immediate);
      if (isolate != null) {
        try {
          await exited.timeout(const Duration(seconds: 2));
        } catch (_) {}
      }
      await sub.cancel();
      port.close();
      exit.close();
    }
  }

  Future<Map<String, dynamic>> _pdf(
    String path,
    AiCancelToken token,
    void Function(ExtractionProgress)? progress,
  ) async {
    if (openPdf == null) await pdfrxFlutterInitialize();
    // PDFium parsing/text reading already uses pdfrx's background worker isolate.
    final doc = openPdf != null
        ? await openPdf!(path)
        : await PdfDocument.openFile(path, passwordProvider: () async => null);
    final pages = <String>[];
    var bytes = 0, skipped = 0, processed = 0;
    var capped = false;
    try {
      for (final page in doc.pages) {
        token.check();
        progress?.call(
          ExtractionProgress(
            'Reading PDF pages...',
            completed: processed,
            total: doc.pages.length,
          ),
        );
        final text = (await page.loadText())?.fullText ?? '';
        token.check();
        processed++;
        if (text.trim().isEmpty) {
          skipped++;
          continue;
        }
        final remaining = (lessonCacheByteCap - bytes - 2)
            .clamp(0, lessonCacheByteCap)
            .toInt();
        final limited = await _boundInBackground(text, remaining);
        pages.add(limited.$1);
        bytes += limited.$3 + 2;
        if (limited.$2 || bytes >= lessonCacheByteCap) {
          capped = true;
          break;
        }
      }
      final cleaned = await _cleanInBackground(pages);
      token.check();
      progress?.call(
        ExtractionProgress(
          'PDF text read',
          completed: processed,
          total: doc.pages.length,
        ),
      );
      return {
        'text': cleaned.$1,
        'character_count': cleaned.$2,
        'warnings': [
          ...cleaned.$3,
          if (skipped > 0)
            '$skipped PDF pages had no readable text and were skipped. Scanned pages are unsupported.',
          if (capped) 'Only the first 2 MB of extracted text was kept. Choose a smaller section for the rest.',
        ],
      };
    } finally {
      await doc.dispose();
    }
  }

  Future<Map<String, dynamic>> _image(
    String path,
    AiCancelToken token,
    void Function(ExtractionProgress)? progress,
  ) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      progress?.call(const ExtractionProgress('Preparing image...'));
      final prepared = await const MethodChannel('com.filo.filo/lesson_image')
          .invokeMapMethod<String, dynamic>('prepare', {'path': path});
      final pixels = prepared?['bytes'] as Uint8List?;
      final width = prepared?['width'] as int?,
          height = prepared?['height'] as int?;
      if (pixels == null ||
          width == null ||
          height == null ||
          width < 2 ||
          height < 2 ||
          width > 2048 ||
          height > 2048 ||
          width * height > 4000000 ||
          pixels.length != width * height * 3 ~/ 2)
        throw lessonReadFailed;
      token.check();
      progress?.call(const ExtractionProgress('Reading image...'));
      final recognized = await recognizer.processImage(
        InputImage.fromBytes(
          bytes: pixels,
          metadata: InputImageMetadata(
            size: Size(width.toDouble(), height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: width,
          ),
        ),
      );
      token.check();
      final recognizedText = recognized.text;
      final limited = await _cleanImageInBackground(recognizedText);
      return {
        'text': limited.$1,
        'character_count': limited.$3,
        'warnings': [
          ...limited.$4,
          if (prepared?['resized'] == true)
            'The image was resized before reading to reduce memory use.',
          if (prepared?['cropped'] == true)
            'A one-pixel image edge was removed for text recognition.',
          if (limited.$2) 'Only the first 2 MB of extracted text was kept.',
        ],
      };
    } on PlatformException catch (e) {
      if (e.code == 'NO_TEXT') throw noLessonText;
      throw lessonReadFailed;
    } finally {
      await recognizer.close();
    }
  }

  static void validateSources(List<Map<String, String>> sources) {
    if (sources.isEmpty ||
        sources.length > 3 ||
        sources.any((s) => (s['text'] ?? '').trim().isEmpty))
      throw noLessonText;
    if (sources.fold<int>(0, (n, s) => n + s['text']!.runes.length) >
        maxCharacters) {
      throw const LessonReadException(
        'TOO_LARGE',
        'The selected text exceeds 40,000 characters.',
      );
    }
  }
}

// Top-level scopes keep database/native handles out of isolate closure captures.
Future<(String, bool, int)> _boundInBackground(String value, int cap) =>
    Isolate.run(() {
      final part = boundedLessonText(value, cap);
      return (part.$1, part.$2, utf8.encode(part.$1).length);
    });
Future<(String, int, List<String>)> _cleanInBackground(List<String> pages) =>
    Isolate.run(() {
      final warnings = <String>[];
      final text = cleanLessonPages(pages, onSkipped: warnings.add);
      return (text, text.runes.length, warnings);
    });
Future<(String, bool, int, List<String>)> _cleanImageInBackground(
  String value,
) => Isolate.run(() {
  final warnings = <String>[];
  final part = boundedLessonText(
    cleanLessonPages([value], onSkipped: warnings.add),
    lessonCacheByteCap,
  );
  return (part.$1, part.$2, part.$1.runes.length, warnings);
});

(String, bool) boundedLessonText(String value, int byteCap) {
  final output = StringBuffer();
  var bytes = 0;
  for (final rune in value.runes) {
    final size = rune <= 127
        ? 1
        : rune <= 2047
        ? 2
        : rune <= 65535
        ? 3
        : 4;
    if (bytes + size > byteCap) return (output.toString(), true);
    bytes += size;
    output.writeCharCode(rune);
  }
  return (output.toString(), false);
}

String cleanLessonPages(
  List<String> pages, {
  void Function(String)? onSkipped,
}) {
  List<String> lines(String text) => text
      .replaceAll('\uFEFF', '')
      .split(RegExp(r'\r\n|\n|\r'))
      .map((l) => l.replaceAll(RegExp(r'[^\S\r\n]+'), ' ').trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final all = pages.map(lines).toList(), repeated = <String, int>{};
  for (final page in all) {
    if (page.length < 3) continue;
    for (final line in {page.first, page.last}) {
      if (line.length > 3 &&
          line.length < 100 &&
          RegExp(r'[A-Za-z]').hasMatch(line))
        repeated[line] = (repeated[line] ?? 0) + 1;
    }
  }
  final edges = repeated.entries
      .where(
        (e) => all.length >= 3 && e.value >= 3 && e.value * 2 >= all.length,
      )
      .map((e) => e.key)
      .toSet();
  final pageNumber = RegExp(
    r'^(?:page\s+\d+(?:\s+(?:of|/)\s*\d+)?|[-–—]\s*\d+\s*[-–—])$',
    caseSensitive: false,
  );
  final output = <String>[];
  var removed = 0;
  for (var p = 0; p < all.length; p++) {
    final kept = <String>[];
    for (var i = 0; i < all[p].length; i++) {
      final line = all[p][i];
      final edge = i == 0 || i == all[p].length - 1;
      final sequentialNumber =
          all.length > 1 &&
          all[p].length > 1 &&
          RegExp(r'^\d+$').hasMatch(line) &&
          int.tryParse(line) == p + 1;
      if (edge &&
          (pageNumber.hasMatch(line) ||
              edges.contains(line) ||
              sequentialNumber)) {
        removed++;
      } else {
        kept.add(line);
      }
    }
    if (kept.isNotEmpty) output.add(kept.join('\n'));
  }
  if (removed > 0)
    onSkipped?.call(
      '$removed repeated page-edge headers or page markers were removed during cleanup.',
    );
  return output.join('\n\n');
}

(String, List<String>) decodeLessonTxt(Uint8List bytes) {
  if (bytes.length >= 2 &&
      ((bytes[0] == 255 && bytes[1] == 254) ||
          (bytes[0] == 254 && bytes[1] == 255))) {
    if (bytes.length.isOdd) throw lessonReadFailed;
    return (
      String.fromCharCodes([
        for (var i = 2; i < bytes.length; i += 2)
          bytes[0] == 255
              ? bytes[i] | (bytes[i + 1] << 8)
              : (bytes[i] << 8) | bytes[i + 1],
      ]),
      [],
    );
  }
  try {
    return (utf8.decode(bytes), []);
  } on FormatException {
    const cp = [
      0x20ac,
      0x81,
      0x201a,
      0x192,
      0x201e,
      0x2026,
      0x2020,
      0x2021,
      0x2c6,
      0x2030,
      0x160,
      0x2039,
      0x152,
      0x8d,
      0x17d,
      0x8f,
      0x90,
      0x2018,
      0x2019,
      0x201c,
      0x201d,
      0x2022,
      0x2013,
      0x2014,
      0x2dc,
      0x2122,
      0x161,
      0x203a,
      0x153,
      0x9d,
      0x17e,
      0x178,
    ];
    return (
      String.fromCharCodes(
        bytes.map((b) => b >= 128 && b <= 159 ? cp[b - 128] : b),
      ),
      ['The TXT file was read using Windows-1252 fallback encoding.'],
    );
  }
}

Future<void> _extractWorker((String, String, SendPort) input) async {
  final (path, type, port) = input;
  try {
    final file = File(path);
    if (await file.length() > LessonTextExtractor.maxFileBytes)
      throw lessonTooLarge;
    if (type == 'sha') {
      var read = 0;
      port.send({
        'text':
            (await sha256
                    .bind(
                      file.openRead().map((chunk) {
                        read += chunk.length;
                        if (read > LessonTextExtractor.maxFileBytes)
                          throw lessonTooLarge;
                        return chunk;
                      }),
                    )
                    .first)
                .toString(),
        'warnings': <String>[],
      });
      return;
    }
    final builder = BytesBuilder(copy: false);
    port.send({'stage': 'Reading file...'});
    await for (final chunk in file.openRead()) {
      if (builder.length + chunk.length > LessonTextExtractor.maxFileBytes)
        throw lessonTooLarge;
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    final warnings = <String>[];
    String text;
    if (type == 'txt') {
      final decoded = decodeLessonTxt(bytes);
      if (decoded.$1.contains('\u0000')) throw lessonReadFailed;
      warnings.addAll(decoded.$2);
      text = cleanLessonPages([decoded.$1], onSkipped: warnings.add);
    } else {
      final parsed = extractOfficeLesson(
        type,
        bytes,
        (done, total) => port.send({
          'stage': 'Reading document...',
          'completed': done,
          'total': total,
        }),
      );
      text = parsed.$1;
      warnings.addAll(parsed.$2);
    }
    final bounded = boundedLessonText(text, lessonCacheByteCap);
    if (bounded.$2)
      warnings.add(
        'Only the first 2 MB of extracted text was kept. Choose a smaller section for the rest.',
      );
    port.send({
      'text': bounded.$1,
      'character_count': bounded.$1.runes.length,
      'warnings': warnings,
    });
  } on LessonReadException catch (e) {
    port.send({'error': e.code, 'message': e.message});
  } catch (_) {
    port.send({
      'error': lessonReadFailed.code,
      'message': lessonReadFailed.message,
    });
  }
}

(String, List<String>) extractOfficeLesson(
  String type,
  Uint8List bytes,
  void Function(int, int)? progress,
) {
  final cleanupWarnings = <String>[];
  final decoder = ZipDecoder();
  final archive = decoder.decodeBytes(bytes);
  if (decoder.directory.fileHeaders.any(
        (h) => (h.generalPurposeBitFlag & 1) != 0,
      ) ||
      archive.length > 5000 ||
      archive.fold<int>(0, (n, f) => n + f.size) > 50 * 1024 * 1024) {
    throw const LessonReadException(
      'RESOURCE_LIMIT',
      'This document is encrypted or too complex. Choose an unencrypted, smaller section.',
    );
  }
  XmlDocument xml(String path) {
    final file = archive.find(path);
    if (file == null || file.size > 4 * 1024 * 1024) throw lessonReadFailed;
    final data = file.content;
    if (data.length > 4 * 1024 * 1024) throw lessonReadFailed;
    final text = utf8.decode(data);
    if (text.contains('<!DOCTYPE') || text.contains('<!ENTITY'))
      throw lessonReadFailed;
    return XmlDocument.parse(text);
  }

  String paragraphs(XmlDocument doc, String ns) {
    final output = StringBuffer();
    for (final p in doc.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'p' && e.namespaceUri == ns,
    )) {
      for (final e in p.descendants.whereType<XmlElement>()) {
        if (e.namespaceUri != ns ||
            !identical(
              e.ancestors
                  .whereType<XmlElement>()
                  .where((a) => a.name.local == 'p' && a.namespaceUri == ns)
                  .firstOrNull,
              p,
            ))
          continue;
        if (e.name.local == 't') output.write(e.innerText);
        if (e.name.local == 'tab') output.write('\t');
        if (e.name.local == 'br') output.write('\n');
      }
      output.writeln();
      if (output.length > 4 * 1024 * 1024) break;
    }
    return output.toString();
  }

  if (type == 'docx') {
    progress?.call(0, 1);
    final text = cleanLessonPages([
      paragraphs(
        xml('word/document.xml'),
        'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
      ),
    ], onSkipped: cleanupWarnings.add);
    progress?.call(1, 1);
    return (
      text,
      [
        ...cleanupWarnings,
        'Only document body text was read. Images, headers and footnotes were not read; table layout may be simplified.',
      ],
    );
  }
  const ns =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  final rels = {
    for (final e in xml(
      'ppt/_rels/presentation.xml.rels',
    ).rootElement.childElements)
      if (e.getAttribute('TargetMode') != 'External')
        e.getAttribute('Id')!: e.getAttribute('Target')!,
  };
  final ids = xml('ppt/presentation.xml').descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == 'sldId')
      .toList();
  final pages = <String>[];
  var skipped = 0, retained = 0;
  for (var i = 0; i < ids.length; i++) {
    progress?.call(i, ids.length);
    final target = rels[ids[i].getAttribute('id', namespace: ns)];
    if (target == null) throw lessonReadFailed;
    final path = target.startsWith('/') ? target.substring(1) : 'ppt/$target';
    if (!RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(path))
      throw lessonReadFailed;
    final text = paragraphs(
      xml(path),
      'http://schemas.openxmlformats.org/drawingml/2006/main',
    );
    if (text.trim().isEmpty) skipped++;
    pages.add(text);
    retained += text.length;
    if (retained > 4 * 1024 * 1024) break;
  }
  progress?.call(pages.length, ids.length);
  return (
    cleanLessonPages(pages, onSkipped: cleanupWarnings.add),
    [
      ...cleanupWarnings,
      'Only slide text was read. Images, charts and speaker notes were not read.',
      if (skipped > 0) '$skipped slides had no readable text and were skipped.',
      if (pages.length < ids.length)
        'Some slides were skipped after the text cache limit was reached.',
    ],
  );
}
