import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import '../../../core/sync/sync_providers.dart';
import '../../drive_backup/data/drive_backup_service.dart';
import '../../drive_backup/presentation/drive_backup_screen.dart';
import '../application/files_providers.dart';
import '../data/file_storage.dart';
import '../data/files_repository.dart';
import 'download_file_card.dart';
import 'file_viewer_screen.dart';

class MyFilesScreen extends ConsumerStatefulWidget {
  const MyFilesScreen({super.key});
  @override
  ConsumerState<MyFilesScreen> createState() => _MyFilesScreenState();
}

class _MyFilesScreenState extends ConsumerState<MyFilesScreen> {
  String? _folder;
  String _query = '', _sort = 'Name';
  bool _busy = false;
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _backupMenu() async {
    final service = await ref.read(driveBackupProvider.future);
    if (!mounted || service == null) {
      return;
    }
    await showFiloBottomSheet<void>(
      title: 'Drive backup',
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListenableBuilder(
          listenable: service,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Filo needs permission to create and manage its backup files in your Google Drive. This does not give Filo access to all your Drive files.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Turn on Drive backup'),
                  value: service.enabled,
                  onChanged: service.busy && !service.enabled
                      ? null
                      : (value) async {
                          if (value) {
                            await service.enable();
                          } else {
                            await service.disable();
                          }
                        },
                ),
                SwitchListTile(
                  title: const Text('Back up on Wi-Fi only'),
                  value: service.wifiOnly,
                  onChanged: service.busy ? null : service.setWifiOnly,
                ),
                FilledButton(
                  onPressed: !service.enabled || service.busy
                      ? null
                      : () async {
                          await service.queueLibrary();
                          await (await ref.read(syncCoordinatorProvider.future))
                              ?.run(retryFailed: true);
                        },
                  child: const Text('Back up now'),
                ),
                if (service.busy) const LinearProgressIndicator(),
                Text(service.message),
                Text(
                  service.lastSuccess == null
                      ? 'No backups yet.'
                      : 'Last backup: ${DateTime.parse(service.lastSuccess!).toLocal()}',
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(this.context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DriveBackupScreen(),
                      ),
                    );
                  },
                  child: const Text('Backup details'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _work(Future<void> Function() action) async {
    if (!mounted || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } on FileProblem catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Could not complete this file action. Try again.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<String?> _name(String title, [String value = '']) =>
      showDialog<String>(
        context: context,
        builder: (_) => _NameDialog(title: title, value: value),
      );

  Future<bool> _confirm(String title, String text, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  Future<String?> _pickFolder(
    List<LocalFolderRecord> folders, {
    String? exclude,
  }) {
    final visible = folders.where((folder) => folder.id != exclude).toList();
    return showFiloBottomSheet<String>(
      title: 'Move to folder',
      context: context,
      scrollBody: false,
      builder: (context) => ListView.builder(
        // Small pickers fit their content; larger collections remain virtualized.
        shrinkWrap: visible.length < 8,
        primary: false,
        itemCount: visible.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return ListTile(
              title: const Text('My Files (root)'),
              onTap: () => Navigator.pop(context, '__root__'),
            );
          }
          final folder = visible[index - 1];
          return ListTile(
            leading: const FiloIcon(FiloIcons.folder),
            title: Text(folder.name),
            subtitle: folder.classId == null
                ? null
                : const Text('Class folder'),
            onTap: () => Navigator.pop(context, folder.id),
          );
        },
      ),
    );
  }

  Future<void> _add(FilesRepository repository) async {
    final action = await showFiloBottomSheet<String>(
      title: 'Add to Files',
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FiloSheetAction(
              label: 'Upload files',
              description: 'Choose files from your device.',
              icon: FiloIcons.upload,
              onTap: () => Navigator.pop(context, 'files'),
            ),
            const SizedBox(height: 12),
            FiloSheetAction(
              label: 'New folder',
              description: 'Organize files on this device.',
              icon: FiloIcons.newFolder,
              onTap: () => Navigator.pop(context, 'folder'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'folder') {
      final name = await _name('New folder');
      if (name != null) {
        await _work(() async {
          await repository.newFolder(name, _folder);
        });
      }
    } else {
      final picked = await FilePicker.pickFiles();
      await _work(() async {
        for (final file in picked) {
          if (file.path == null) {
            _message('Could not read ${file.name}.');
            continue;
          }
          try {
            await repository.importFile(File(file.path!), file.name, _folder);
          } on FileProblem catch (error) {
            _message('${file.name}: ${error.message}');
          }
        }
      });
    }
  }

  Future<void> _fileActions(
    FilesRepository repository,
    LocalFileRecord file,
    List<LocalFolderRecord> folders,
  ) async {
    final action = await showFiloBottomSheet<String>(
      title: 'File actions',
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(file.name)),
            for (final label in [
              'Open',
              'Open in another app',
              'Rename',
              'Move',
              'Delete',
              'Export a copy',
            ])
              ListTile(
                title: Text(label),
                onTap: () => Navigator.pop(context, label),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'Open') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FileViewerScreen(file: file, repository: repository),
        ),
      );
    } else if (action == 'Open in another app') {
      await _work(() => openExternal(context, repository, file));
    } else if (action == 'Export a copy') {
      await _work(() => exportFile(context, repository, file));
    } else if (action == 'Rename') {
      final name = await _name('Rename file', file.name);
      if (name != null) {
        await _work(() => repository.renameFile(file, name));
      }
    } else if (action == 'Move') {
      final folder = await _pickFolder(folders);
      if (folder != null) {
        await _work(
          () => repository.moveFile(file, folder == '__root__' ? null : folder),
        );
      }
    } else if (action == 'Delete') {
      final backup = ref.read(driveBackupProvider).asData?.value;
      final yes = await _confirm(
        'Delete file?',
        "${file.name}\n\nDelete this file from your device? This can't be undone."
            '${backup?.enabled == true ? '\nThe Drive copy is not removed.' : ''}',
        'Delete file',
      );
      if (yes) {
        await _work(() => repository.deleteFile(file));
      }
    }
  }

  Set<String> _descendants(String id, List<LocalFolderRecord> all) {
    final result = <String>{id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final folder in all) {
        if (result.contains(folder.parentId) && result.add(folder.id)) {
          changed = true;
        }
      }
    }
    return result;
  }

  Future<void> _folderActions(
    FilesRepository repository,
    LocalFolderRecord folder,
    List<LocalFolderRecord> folders,
    List<LocalFileRecord> files,
  ) async {
    final action = await showFiloBottomSheet<String>(
      title: 'Folder actions',
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(folder.name)),
            for (final label in ['Rename', 'Move', 'Delete'])
              ListTile(
                title: Text(label),
                onTap: () => Navigator.pop(context, label),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'Rename') {
      final name = await _name('Rename folder', folder.name);
      if (name != null) {
        await _work(() => repository.changeFolder(folder, name: name));
      }
    } else if (action == 'Move') {
      final blocked = _descendants(folder.id, folders);
      final parent = await _pickFolder(
        folders.where((f) => !blocked.contains(f.id)).toList(),
      );
      if (parent != null) {
        await _work(
          () => repository.changeFolder(
            folder,
            parent: parent == '__root__' ? null : parent,
            move: true,
          ),
        );
      }
    } else {
      final subtree = _descendants(folder.id, folders);
      final count = files.where((f) => subtree.contains(f.folderId)).length;
      final yes = await _confirm(
        'Delete folder?',
        count > 0 || subtree.length > 1
            ? 'Delete ${folder.name}, $count files and all nested folders from this device? This can’t be undone. Drive copies are not removed.'
            : 'Delete ${folder.name} and its nested folders? This can’t be undone.',
        'Delete folder',
      );
      if (yes) {
        await _work(() => repository.deleteFolder(folder));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(filesRepositoryProvider);
    final fileData = ref.watch(localFilesProvider),
        folderData = ref.watch(localFoldersProvider);
    final files = fileData.asData?.value ?? [],
        folders = folderData.asData?.value ?? [];
    final repo = repository.asData?.value;
    final path = <LocalFolderRecord>[];
    var current = _folder;
    while (current != null && !path.any((f) => f.id == current)) {
      final folder = folders.where((f) => f.id == current).firstOrNull;
      if (folder == null) break;
      path.insert(0, folder);
      current = folder.parentId;
    }
    final query = _query.trim().toLowerCase();
    final visibleFolders = folders
        .where(
          (f) => query.isNotEmpty
              ? f.name.toLowerCase().contains(query)
              : f.parentId == _folder,
        )
        .toList();
    final visibleFiles = files
        .where(
          (f) => query.isNotEmpty
              ? f.name.toLowerCase().contains(query)
              : f.folderId == _folder,
        )
        .toList();
    int folderSize(LocalFolderRecord f) {
      final ids = _descendants(f.id, folders);
      return files
          .where((file) => ids.contains(file.folderId))
          .fold(0, (sum, file) => sum + file.size);
    }

    visibleFolders.sort(
      (a, b) => _sort == 'Date'
          ? b.updatedAt.compareTo(a.updatedAt)
          : _sort == 'Size'
          ? folderSize(b).compareTo(folderSize(a))
          : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    visibleFiles.sort(
      (a, b) => _sort == 'Date'
          ? b.updatedAt.compareTo(a.updatedAt)
          : _sort == 'Size'
          ? b.size.compareTo(a.size)
          : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return PopScope(
      canPop: _folder == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _folder = path.isEmpty ? null : path.last.parentId);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Files'),
          leading: _folder == null
              ? null
              : IconButton(
                  onPressed: () => setState(
                    () => _folder = path.isEmpty ? null : path.last.parentId,
                  ),
                  icon: const FiloIcon(FiloIcons.back),
                ),
          actions: [
            IconButton(
              tooltip: 'Drive backup',
              onPressed: _backupMenu,
              icon: const FiloIcon(FiloIcons.cloudUpload),
            ),
            PopupMenuButton<String>(
              initialValue: _sort,
              onSelected: (value) => setState(() => _sort = value),
              itemBuilder: (_) => [
                for (final value in ['Name', 'Date', 'Size'])
                  PopupMenuItem(value: value, child: Text('Sort by $value')),
              ],
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        floatingActionButton: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FiloButton(
            label: _busy ? 'Please wait\u2026' : 'Add files',
            icon: _busy ? null : FiloIcons.add,
            busy: _busy,
            onPressed: repo == null || _busy ? null : () => _add(repo),
          ),
        ),
        body: repository.isLoading || fileData.isLoading || folderData.isLoading
            ? const Center(child: CircularProgressIndicator())
            : repo == null || fileData.hasError || folderData.hasError
            ? Center(
                child: TextButton(
                  onPressed: () {
                    ref.invalidate(filesRepositoryProvider);
                    ref.invalidate(localFilesProvider);
                    ref.invalidate(localFoldersProvider);
                  },
                  child: const Text("Couldn't load files. Try again."),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                children: [
                  TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search files and folders',
                      prefixIcon: FiloIcon(FiloIcons.search),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _folder = null),
                        child: const Text('My Files'),
                      ),
                      for (final folder in path)
                        TextButton(
                          onPressed: () => setState(() => _folder = folder.id),
                          child: Text('› ${folder.name}'),
                        ),
                    ],
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (visibleFolders.isEmpty && visibleFiles.isEmpty)
                    FiloPanel(
                      color: FiloColors.tint,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: Column(
                        children: [
                          const Mascot(pose: 'confused_notepad', size: 144),
                          const SizedBox(height: 24),
                          Semantics(
                            header: true,
                            child: Text(
                              query.isNotEmpty
                                  ? 'No matching files.'
                                  : 'No files yet.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                color: FiloColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            query.isNotEmpty
                                ? 'Try another file or folder name.'
                                : 'Download class materials or add your own.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                              color: FiloColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final folder in visibleFolders)
                    ListTile(
                      leading: const FiloIcon(FiloIcons.folder),
                      title: Text(folder.name),
                      subtitle: Text(
                        '${folder.classId == null ? '' : 'Class folder · '}${fileSize(folderSize(folder))}',
                      ),
                      onTap: () => setState(() {
                        _folder = folder.id;
                        _query = '';
                        _search.clear();
                      }),
                      trailing: IconButton(
                        tooltip: 'Folder actions',
                        onPressed: _busy
                            ? null
                            : () =>
                                  _folderActions(repo, folder, folders, files),
                        icon: const FiloIcon(FiloIcons.moreVertical),
                      ),
                    ),
                  for (final file in visibleFiles)
                    ListTile(
                      leading: FiloIcon(fileIcon(file.name, file.mimeType)),
                      title: Text(file.name),
                      subtitle: Text(
                        '${fileSize(file.size)} · ${MaterialLocalizations.of(context).formatMediumDate(file.updatedAt.toLocal())}',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              FileViewerScreen(file: file, repository: repo),
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'File actions',
                        onPressed: _busy
                            ? null
                            : () => _fileActions(repo, file, folders),
                        icon: const FiloIcon(FiloIcons.moreVertical),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.value});
  final String title, value;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.value);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 255,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}
