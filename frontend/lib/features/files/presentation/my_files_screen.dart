import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../../../core/widgets/entry_background.dart';
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
            padding: const EdgeInsets.symmetric(horizontal: FiloSpacing.screen),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Filo needs permission to create and manage its backup files in your Google Drive. This does not give Filo access to all your Drive files.',
                ),
                FiloSwitchListTile(
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
                FiloSwitchListTile(
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
                if (service.busy) const FiloLinearProgressIndicator(),
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
      showFiloDialog<String>(
        context: context,
        builder: (_) => _NameDialog(title: title, value: value),
      );

  Future<bool> _confirm(String title, String text, String action) async =>
      await showFiloDialog<bool>(
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
        padding: const EdgeInsets.symmetric(horizontal: FiloSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FiloSheetAction(
              label: 'Upload files',
              description: 'Choose files from your device.',
              icon: FiloIcons.upload,
              onTap: () => Navigator.pop(context, 'files'),
            ),
            const SizedBox(height: FiloSpacing.s12),
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
                leading: Icon(
                  switch (label) {
                    'Open' => Icons.description_outlined,
                    'Open in another app' => Icons.open_in_new_rounded,
                    'Rename' => Icons.edit_outlined,
                    'Move' => Icons.drive_file_move_outlined,
                    'Delete' => Icons.delete_outline_rounded,
                    _ => Icons.ios_share_rounded,
                  },
                  color: label == 'Delete'
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                title: Text(
                  label,
                  style: label == 'Delete'
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
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
          builder: (_) => FileViewerScreen(
            showMascot: true,
            file: file,
            repository: repository,
          ),
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
                leading: Icon(
                  switch (label) {
                    'Rename' => Icons.edit_outlined,
                    'Move' => Icons.drive_file_move_outlined,
                    _ => Icons.delete_outline_rounded,
                  },
                  color: label == 'Delete'
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                title: Text(
                  label,
                  style: label == 'Delete'
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
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
    return FiloFirstListLoad(
      id: 'files',
      hasItems: visibleFolders.isNotEmpty || visibleFiles.isNotEmpty,
      ready:
          repository.hasValue &&
          fileData.hasValue &&
          folderData.hasValue &&
          !repository.isLoading &&
          !fileData.isLoading &&
          !folderData.isLoading &&
          !repository.hasError &&
          !fileData.hasError &&
          !folderData.hasError,
      child: PopScope(
        canPop: _folder == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            setState(() => _folder = path.isEmpty ? null : path.last.parentId);
          }
        },
        child: Scaffold(
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButtonAnimator:
              FloatingActionButtonAnimator.noAnimation,
          floatingActionButton: Padding(
            padding: const EdgeInsets.symmetric(horizontal: FiloSpacing.screen),
            child: FiloButton(
              label: _busy ? 'Please wait\u2026' : 'Add files',
              icon: _busy ? null : FiloIcons.add,
              busy: _busy,
              minHeight: 64,
              onPressed: repo == null || _busy ? null : () => _add(repo),
            ),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(
                child: EntryBackground(verification: true, breeze: true),
              ),
              SafeArea(
                top: false,
                child:
                    repository.isLoading ||
                        fileData.isLoading ||
                        folderData.isLoading
                    ? const Center(
                        child: FiloCircularProgressIndicator(
                          semanticsLabel: 'Loading files',
                        ),
                      )
                    : repo == null || fileData.hasError || folderData.hasError
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            FiloSpacing.screen,
                            FiloSpacing.screen,
                            FiloSpacing.screen,
                            112,
                          ),
                          child: EmptyState(
                            title: "Couldn't load files. Try again.",
                            pose: 'confused',
                            bob: false,
                            action: TextButton(
                              onPressed: () {
                                ref.invalidate(filesRepositoryProvider);
                                ref.invalidate(localFilesProvider);
                                ref.invalidate(localFoldersProvider);
                              },
                              child: const Text('Retry'),
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          FiloSpacing.screen,
                          FiloSpacing.s16,
                          FiloSpacing.screen,
                          112,
                        ),
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              _folder == null
                                  ? 'Your library'
                                  : path.lastOrNull?.name ?? 'Folder',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(height: FiloSpacing.s8),
                          Text(
                            'Your files, organized on this device.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: FiloSpacing.s20),
                          TextField(
                            controller: _search,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              hintText: 'Search files and folders',
                              prefixIcon: const FiloIcon(FiloIcons.search),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => setState(() {
                                        _query = '';
                                        _search.clear();
                                      }),
                                    ),
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                          const SizedBox(height: FiloSpacing.s8),
                          Wrap(
                            spacing: FiloSpacing.s8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (_folder != null)
                                IconButton(
                                  tooltip: 'Up to parent folder',
                                  onPressed: () => setState(
                                    () => _folder = path.isEmpty
                                        ? null
                                        : path.last.parentId,
                                  ),
                                  icon: const FiloIcon(FiloIcons.back),
                                ),
                              TextButton.icon(
                                onPressed: _backupMenu,
                                icon: const FiloIcon(
                                  FiloIcons.cloudUpload,
                                  size: 20,
                                ),
                                label: const Text('Drive backup'),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Sort files',
                                initialValue: _sort,
                                onSelected: (value) =>
                                    setState(() => _sort = value),
                                itemBuilder: (_) => [
                                  for (final value in ['Name', 'Date', 'Size'])
                                    PopupMenuItem(
                                      value: value,
                                      child: Text('Sort by $value'),
                                    ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: FiloSpacing.s12,
                                    vertical: FiloSpacing.s12,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sort_rounded, size: 20),
                                      const SizedBox(width: FiloSpacing.s8),
                                      Text('Sort: $_sort'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (path.isNotEmpty)
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _folder = null),
                                  child: const Text('Your library'),
                                ),
                                for (final folder in path)
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _folder = folder.id),
                                    child: Text('› ${folder.name}'),
                                  ),
                              ],
                            ),
                          if (_busy) const FiloLinearProgressIndicator(),
                          if (visibleFolders.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: FiloSpacing.s12,
                              ),
                              child: Text(
                                'Folders',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          if (visibleFolders.isEmpty &&
                              visibleFiles.isEmpty &&
                              query.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: FiloSpacing.screen,
                              ),
                              child: Column(
                                children: [
                                  ExcludeSemantics(
                                    child: AspectRatio(
                                      aspectRatio: 1.5,
                                      child: ColorFiltered(
                                        // Suppress the generated low-opacity halo around the illustration.
                                        colorFilter: const ColorFilter.matrix([
                                          1,
                                          0,
                                          0,
                                          0,
                                          0,
                                          0,
                                          1,
                                          0,
                                          0,
                                          0,
                                          0,
                                          0,
                                          1,
                                          0,
                                          0,
                                          0,
                                          0,
                                          0,
                                          12,
                                          -2700,
                                        ]),
                                        child: Image.asset(
                                          'assets/illustrations/library-empty-folder.png',
                                          fit: BoxFit.contain,
                                          cacheWidth:
                                              (360 *
                                                      MediaQuery.devicePixelRatioOf(
                                                        context,
                                                      ))
                                                  .ceil(),
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.folder_open_rounded,
                                            size: 104,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: FiloSpacing.s16),
                                  Text(
                                    'No files yet.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: FiloSpacing.s8),
                                  Text(
                                    'Download class materials or add your own.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          if (visibleFolders.isEmpty &&
                              visibleFiles.isEmpty &&
                              query.isNotEmpty)
                            const EmptyState(
                              pose: 'curious',
                              bob: false,
                              title: 'No matching files.',
                              message: 'Try another file or folder name.',
                            ),
                          for (final folder in visibleFolders)
                            FiloListItem(
                              index: visibleFolders.indexOf(folder),
                              child: Card(
                                margin: const EdgeInsets.only(
                                  bottom: FiloSpacing.s12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    FiloRadii.large,
                                  ),
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(
                                    FiloSpacing.s12,
                                  ),
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      borderRadius: BorderRadius.circular(
                                        FiloRadii.small,
                                      ),
                                    ),
                                    child: FiloIcon(
                                      FiloIcons.folder,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
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
                                        : () => _folderActions(
                                            repo,
                                            folder,
                                            folders,
                                            files,
                                          ),
                                    icon: const FiloIcon(
                                      FiloIcons.moreVertical,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (visibleFiles.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: FiloSpacing.s12,
                              ),
                              child: Text(
                                'Files on this device',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          for (final file in visibleFiles)
                            FiloListItem(
                              index:
                                  visibleFolders.length +
                                  visibleFiles.indexOf(file),
                              child: Card(
                                margin: const EdgeInsets.only(
                                  bottom: FiloSpacing.s12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    FiloRadii.large,
                                  ),
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(
                                    FiloSpacing.s12,
                                  ),
                                  titleTextStyle: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                  isThreeLine: true,
                                  leading: FiloFileTypeTile(
                                    details: FiloFileDetails.fromName(
                                      file.name,
                                      mimeType: file.mimeType,
                                    ),
                                  ),
                                  title: Text(file.name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      FiloFileTypeLabel(
                                        details: FiloFileDetails.fromName(
                                          file.name,
                                          mimeType: file.mimeType,
                                        ),
                                      ),
                                      Text(
                                        '${fileSize(file.size)} · ${MaterialLocalizations.of(context).formatMediumDate(file.updatedAt.toLocal())}',
                                      ),
                                    ],
                                  ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => FileViewerScreen(
                                        showMascot: true,
                                        file: file,
                                        repository: repo,
                                      ),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'File actions',
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                              _fileActions(repo, file, folders),
                                    icon: const FiloIcon(
                                      FiloIcons.moreVertical,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
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
