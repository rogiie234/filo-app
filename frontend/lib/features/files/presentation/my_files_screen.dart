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
  const MyFilesScreen({super.key, this.embedded = false, this.onBusyChanged});
  final bool embedded;
  final ValueChanged<bool>? onBusyChanged;
  @override
  ConsumerState<MyFilesScreen> createState() => MyFilesScreenState();
}

class MyFilesScreenState extends ConsumerState<MyFilesScreen> {
  String? _folder;
  String _query = '', _sort = 'Name';
  bool _ascending = true;
  bool _grid = false;
  String _typeFilter = 'all';
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
    widget.onBusyChanged?.call(true);
    try {
      await action();
    } on FileProblem catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Could not complete this file action. Try again.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(false);
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

  Future<void> addFiles() async {
    final repository = ref.read(filesRepositoryProvider).asData?.value;
    if (repository != null) await _add(repository);
  }

  Future<void> _add(FilesRepository repository) => _work(() async {
    final folder = _folder;
    final picked = await FilePicker.pickFiles();
    if (!mounted) return;
    var added = 0;
    for (final file in picked) {
      if (file.path == null) {
        _message('Could not read ${file.name}.');
        continue;
      }
      try {
        await repository.importFile(File(file.path!), file.name, folder);
        added++;
      } on FileProblem catch (error) {
        _message('${file.name}: ${error.message}');
      }
    }
    if (mounted && added > 0 && added == picked.length) {
      showFiloToast(
        context,
        added == 1 ? 'File added.' : '$added files added.',
        kind: FiloToastKind.success,
      );
    }
  });

  Future<void> _newFolder(FilesRepository repository) async {
    if (_busy) return;
    final name = await _name('New folder');
    if (name != null) {
      await _work(() async {
        await repository.newFolder(name, _folder);
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
    final snapshot = ref.watch(librarySnapshotProvider);
    final savedFiles = fileData.asData?.value ?? snapshot.files;
    final savedFolders = folderData.asData?.value ?? snapshot.folders;
    final files = savedFiles ?? <LocalFileRecord>[];
    final folders = savedFolders ?? <LocalFolderRecord>[];
    final repo = repository.value;
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
    final matchingFiles = files
        .where(
          (f) => query.isNotEmpty
              ? f.name.toLowerCase().contains(query)
              : f.folderId == _folder,
        )
        .toList();
    final visibleFiles = matchingFiles
        .where(
          (file) =>
              _typeFilter == 'all' ||
              FiloFileDetails.fromName(
                    file.name,
                    mimeType: file.mimeType,
                  ).type.name ==
                  _typeFilter,
        )
        .toList();
    const filters = {
      'all': 'All files',
      'pdf': 'PDFs',
      'image': 'Images',
      'doc': 'Documents',
      'ppt': 'Presentations',
      'xls': 'Spreadsheets',
      'text': 'Text files',
      'other': 'Other files',
    };
    final noMatchingFiles =
        visibleFiles.isEmpty &&
        (query.isNotEmpty || _typeFilter != 'all') &&
        (_typeFilter != 'all' || visibleFolders.isEmpty);
    final folderContents = <String, List<LocalFileRecord>>{};
    List<LocalFileRecord> filesInFolder(LocalFolderRecord folder) =>
        folderContents.putIfAbsent(folder.id, () {
          final ids = _descendants(folder.id, folders);
          return files.where((file) => ids.contains(file.folderId)).toList();
        });
    int folderSize(LocalFolderRecord folder) =>
        filesInFolder(folder).fold(0, (sum, file) => sum + file.size);
    final selectedFolder = path.lastOrNull;
    final summaryFiles = selectedFolder == null
        ? files
        : filesInFolder(selectedFolder);
    final summaryBytes = summaryFiles.fold<int>(
      0,
      (sum, file) => sum + file.size,
    );

    int compareNames(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());
    visibleFolders.sort((a, b) {
      final primary = switch (_sort) {
        'Date' => a.updatedAt.compareTo(b.updatedAt),
        'Size' => folderSize(a).compareTo(folderSize(b)),
        _ => compareNames(a.name, b.name),
      };
      final named = primary != 0 ? primary : compareNames(a.name, b.name);
      final result = named != 0 ? named : a.id.compareTo(b.id);
      return _ascending ? result : -result;
    });
    visibleFiles.sort((a, b) {
      final primary = switch (_sort) {
        'Date' => a.updatedAt.compareTo(b.updatedAt),
        'Size' => a.size.compareTo(b.size),
        'Type' =>
          FiloFileDetails.fromName(
            a.name,
            mimeType: a.mimeType,
          ).type.label.compareTo(
            FiloFileDetails.fromName(b.name, mimeType: b.mimeType).type.label,
          ),
        _ => compareNames(a.name, b.name),
      };
      final named = primary != 0 ? primary : compareNames(a.name, b.name);
      final result = named != 0 ? named : a.id.compareTo(b.id);
      return _ascending ? result : -result;
    });
    final orderLabel = switch (_sort) {
      'Date' => _ascending ? 'Oldest first' : 'Newest first',
      'Size' => _ascending ? 'Smallest first' : 'Largest first',
      _ => _ascending ? 'A to Z' : 'Z to A',
    };
    List<Widget> layoutItems(List<Widget> items, double width) {
      final columns =
          _grid &&
              width >= 280 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.2
          ? 2
          : 1;
      return [
        for (var index = 0; index < items.length; index += columns)
          Padding(
            padding: const EdgeInsets.only(bottom: FiloSpacing.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: FiloSpacing.s12,
              children: [
                for (var column = 0; column < columns; column++)
                  Expanded(
                    child: index + column < items.length
                        ? items[index + column]
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
      ];
    }

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
        child: EntryBackground(
          variation: 8,
          verification: true,
          breeze: true,
          enabled: !widget.embedded,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            bottomNavigationBar: widget.embedded
                ? null
                : SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 72,
                            child: FiloButton(
                              label: 'Add files',
                              icon: FiloIcons.add,
                              iconOnly: true,
                              minHeight: 72,
                              busy: _busy,
                              onPressed: repo == null || _busy
                                  ? null
                                  : () => _add(repo),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            body: SafeArea(
              top: false,
              child:
                  (repository.isLoading && !repository.hasValue) ||
                      (fileData.isLoading && savedFiles == null) ||
                      (folderData.isLoading && savedFolders == null)
                  ? const FiloDelayedLoading(
                      child: Center(
                        child: FiloCircularProgressIndicator(
                          semanticsLabel: 'Loading files',
                        ),
                      ),
                    )
                  : repo == null ||
                        repository.hasError ||
                        fileData.hasError ||
                        folderData.hasError
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          FiloSpacing.screen,
                          FiloSpacing.screen,
                          FiloSpacing.screen,
                          24,
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
                  : LayoutBuilder(
                      builder: (context, constraints) => ListView(
                        padding: const EdgeInsets.fromLTRB(
                          FiloSpacing.screen,
                          FiloSpacing.s16,
                          FiloSpacing.screen,
                          24,
                        ),
                        children: [
                          if (path.isNotEmpty) ...[
                            Wrap(
                              spacing: FiloSpacing.s4,
                              runSpacing: FiloSpacing.s4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Up to parent folder',
                                  onPressed: () => setState(
                                    () => _folder = path.last.parentId,
                                  ),
                                  icon: const FiloIcon(FiloIcons.back),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _folder = null),
                                  child: const Text('Your library'),
                                ),
                                for (final ancestor in path.take(
                                  path.length - 1,
                                ))
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _folder = ancestor.id),
                                    icon: const FiloIcon(
                                      FiloIcons.chevronRight,
                                      size: 16,
                                    ),
                                    label: Text(ancestor.name),
                                  ),
                              ],
                            ),
                            const SizedBox(height: FiloSpacing.s12),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_folder != null) ...[
                                ExcludeSemantics(
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      borderRadius: BorderRadius.circular(
                                        FiloRadii.medium,
                                      ),
                                    ),
                                    child: FiloIcon(
                                      FiloIcons.folder,
                                      size: 28,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: FiloSpacing.s12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Semantics(
                                      header: true,
                                      child: Text(
                                        _folder == null
                                            ? 'Your library'
                                            : selectedFolder?.name ?? 'Folder',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium,
                                      ),
                                    ),
                                    const SizedBox(height: FiloSpacing.s8),
                                    Text(
                                      _folder == null
                                          ? 'Your files, organized on this device.'
                                          : selectedFolder?.classId != null
                                          ? 'Class folder'
                                          : 'Folder',
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
                              IconButton.outlined(
                                tooltip: 'Drive backup',
                                onPressed: _backupMenu,
                                icon: const FiloIcon(FiloIcons.cloudUpload),
                              ),
                            ],
                          ),
                          const SizedBox(height: FiloSpacing.s12),
                          Wrap(
                            spacing: FiloSpacing.s8,
                            runSpacing: FiloSpacing.s8,
                            children: [
                              FiloStatusChip(
                                label:
                                    '${summaryFiles.length} ${summaryFiles.length == 1 ? 'file' : 'files'}',
                                icon: FiloIcons.document,
                              ),
                              FiloStatusChip(
                                label: fileSize(summaryBytes),
                                icon: Icons.storage_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: FiloSpacing.s20),
                          TextField(
                            controller: _search,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              hintText: 'Search files and folders',
                              prefixIcon: const FiloIcon(FiloIcons.search),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_query.isNotEmpty)
                                    IconButton(
                                      tooltip: 'Clear search',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => setState(() {
                                        _query = '';
                                        _search.clear();
                                      }),
                                    ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Filter files',
                                    initialValue: _typeFilter,
                                    icon: Badge(
                                      isLabelVisible: _typeFilter != 'all',
                                      child: const Icon(
                                        Icons.filter_list_rounded,
                                      ),
                                    ),
                                    onSelected: (value) =>
                                        setState(() => _typeFilter = value),
                                    itemBuilder: (_) => [
                                      for (final filter in filters.entries)
                                        CheckedPopupMenuItem(
                                          value: filter.key,
                                          checked: _typeFilter == filter.key,
                                          child: Text(filter.value),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                          const SizedBox(height: FiloSpacing.s8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: FiloSpacing.s8,
                                  runSpacing: FiloSpacing.s8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    PopupMenuButton<String>(
                                      tooltip: 'Sort files',
                                      initialValue: _sort,
                                      onSelected: (value) => setState(() {
                                        _sort = value;
                                        _ascending =
                                            value == 'Name' || value == 'Type';
                                      }),
                                      itemBuilder: (_) => [
                                        for (final value in [
                                          'Name',
                                          'Date',
                                          'Size',
                                          'Type',
                                        ])
                                          CheckedPopupMenuItem(
                                            value: value,
                                            checked: _sort == value,
                                            child: Text(value),
                                          ),
                                      ],
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minHeight: 48,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: FiloSpacing.s12,
                                          vertical: FiloSpacing.s12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            FiloRadii.pill,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.sort_rounded,
                                              size: 20,
                                            ),
                                            const SizedBox(
                                              width: FiloSpacing.s8,
                                            ),
                                            Flexible(
                                              child: Text(
                                                '$_sort: $orderLabel',
                                              ),
                                            ),
                                            const SizedBox(
                                              width: FiloSpacing.s8,
                                            ),
                                            const Icon(
                                              Icons.expand_more_rounded,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton.outlined(
                                      tooltip: _ascending
                                          ? 'Sort descending'
                                          : 'Sort ascending',
                                      onPressed: () => setState(
                                        () => _ascending = !_ascending,
                                      ),
                                      icon: Icon(
                                        _ascending
                                            ? Icons.arrow_upward_rounded
                                            : Icons.arrow_downward_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: FiloSpacing.s8),
                              IconButton.outlined(
                                tooltip: _grid
                                    ? 'Switch to list view'
                                    : 'Switch to grid view',
                                onPressed: () => setState(() => _grid = !_grid),
                                icon: Icon(
                                  _grid
                                      ? Icons.view_list_outlined
                                      : Icons.grid_view_rounded,
                                ),
                              ),
                            ],
                          ),
                          if (_typeFilter != 'all')
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: InputChip(
                                label: Text(filters[_typeFilter]!),
                                onDeleted: () =>
                                    setState(() => _typeFilter = 'all'),
                                deleteButtonTooltipMessage:
                                    'Clear file type filter',
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: FiloSpacing.s12,
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: FiloSpacing.s12,
                              runSpacing: FiloSpacing.s4,
                              children: [
                                Text(
                                  'Folders',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _newFolder(repo),
                                  icon: const FiloIcon(
                                    FiloIcons.newFolder,
                                    size: 20,
                                  ),
                                  label: const Text('New folder'),
                                ),
                              ],
                            ),
                          ),
                          if (visibleFolders.isEmpty &&
                              visibleFiles.isEmpty &&
                              query.isEmpty &&
                              _typeFilter == 'all')
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
                          ...layoutItems([
                            for (final folder in visibleFolders)
                              FiloListItem(
                                index: visibleFolders.indexOf(folder),
                                child: Card(
                                  color: Theme.of(context).colorScheme.surface,
                                  elevation: 1,
                                  shadowColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: .10),
                                  clipBehavior: Clip.antiAlias,
                                  margin: EdgeInsets.zero,
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
                                  child: _LibraryTile(
                                    folder: true,
                                    grid: _grid,
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
                                    title: Text(
                                      folder.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    subtitle: Text(
                                      '${folder.classId == null ? '' : 'Class folder · '}${filesInFolder(folder).length} ${filesInFolder(folder).length == 1 ? 'file' : 'files'} \u00b7 ${fileSize(folderSize(folder))}',
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
                          ], constraints.maxWidth - 2 * FiloSpacing.screen),
                          if (visibleFiles.isNotEmpty || noMatchingFiles)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: FiloSpacing.s12,
                              ),
                              child: Text(
                                'Files',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          if (noMatchingFiles)
                            Column(
                              children: [
                                FiloIllustratedEmptyState(
                                  asset: 'assets/illustrations/library-empty-folder.png',
                                  title: 'No matching files.',
                                  message: _typeFilter == 'all'
                                      ? 'Try another file or folder name.'
                                      : 'Try another file type or clear the filter.',
                                ),
                                if (_typeFilter != 'all')
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _typeFilter = 'all'),
                                    child: const Text('Show all file types'),
                                  ),
                              ],
                            ),
                          ...layoutItems([
                            for (final file in visibleFiles)
                              FiloListItem(
                                index:
                                    visibleFolders.length +
                                    visibleFiles.indexOf(file),
                                child: Card(
                                  color: Theme.of(context).colorScheme.surface,
                                  elevation: 1,
                                  shadowColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: .10),
                                  clipBehavior: Clip.antiAlias,
                                  margin: EdgeInsets.zero,
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
                                  child: _LibraryTile(
                                    grid: _grid,
                                    leading: FiloFileTypeTile(
                                      details: FiloFileDetails.fromName(
                                        file.name,
                                        mimeType: file.mimeType,
                                      ),
                                    ),
                                    title: Text(
                                      file.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    subtitle: Wrap(
                                      spacing: FiloSpacing.s8,
                                      runSpacing: FiloSpacing.s4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
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
                                          : () => _fileActions(
                                              repo,
                                              file,
                                              folders,
                                            ),
                                      icon: const FiloIcon(
                                        FiloIcons.moreVertical,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ], constraints.maxWidth - 2 * FiloSpacing.screen),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.grid,
    this.folder = false,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });
  final bool grid, folder;
  final Widget leading, title, subtitle, trailing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    if (!grid) {
      return FiloCardTap(
        enabled: true,
        child: ListTile(
          contentPadding: const EdgeInsets.all(FiloSpacing.s12),
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          onTap: onTap,
        ),
      );
    }
    final theme = Theme.of(context);
    return FiloCardTap(
      enabled: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 88),
              padding: const EdgeInsets.all(FiloSpacing.s12),
              color: folder
                  ? theme.colorScheme.primaryContainer.withValues(alpha: .5)
                  : theme.colorScheme.surfaceContainerLow,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: leading,
                    ),
                  ),
                  trailing,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(FiloSpacing.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  title,
                  const SizedBox(height: FiloSpacing.s8),
                  DefaultTextStyle(
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    child: subtitle,
                  ),
                ],
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

  String? _error;
  bool _submitted = false;

  void _submit() {
    if (_submitted) return;
    try {
      final name = FilesRepository.validName(_controller.text);
      _submitted = true;
      Navigator.pop(context, name);
    } on FileProblem catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.title == 'New folder';
    final theme = Theme.of(context);
    final cancel = FiloButton(
      label: 'Cancel',
      outlined: true,
      minHeight: 48,
      onPressed: () => Navigator.pop(context),
    );
    final confirm = FiloButton(
      label: creating ? 'Create folder' : 'Save',
      minHeight: 48,
      onPressed: _controller.text.trim().isEmpty ? null : _submit,
    );
    final inlineActions =
        MediaQuery.sizeOf(context).width -
                MediaQuery.viewPaddingOf(context).horizontal >=
            400 &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.1;

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: FiloSpacing.screen,
        vertical: FiloSpacing.screen,
      ),
      icon: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(FiloSpacing.s16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(FiloRadii.medium),
          ),
          child: FiloIcon(
            creating ? FiloIcons.newFolder : FiloIcons.edit,
            color: theme.colorScheme.onPrimaryContainer,
            size: creating ? 48 : 28,
          ),
        ),
      ),
      title: Text(widget.title, textAlign: TextAlign.center),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (creating) ...[
              Text(
                'Choose a name for your folder.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: FiloSpacing.s20),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 255,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: creating ? 'Folder name' : 'Name',
                errorText: _error,
                prefixIcon: creating ? const FiloIcon(FiloIcons.folder) : null,
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear name',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _controller.clear();
                          _error = null;
                        }),
                      ),
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: FiloSpacing.s20),
            if (inlineActions)
              Row(
                children: [
                  Expanded(flex: 2, child: cancel),
                  const SizedBox(width: FiloSpacing.s12),
                  Expanded(flex: 3, child: confirm),
                ],
              )
            else ...[
              confirm,
              const SizedBox(height: FiloSpacing.s8),
              cancel,
            ],
          ],
        ),
      ),
    );
  }
}
