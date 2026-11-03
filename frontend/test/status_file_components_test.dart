import 'dart:async';
import 'dart:math' as math;

import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/files/application/files_providers.dart';
import 'package:filo/features/files/data/download_manager.dart';
import 'package:filo/features/files/data/file_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/files/presentation/class_files_preview.dart';
import 'package:filo/features/files/presentation/download_file_card.dart';
import 'package:filo/features/grading/presentation/submissions_screen.dart';
import 'package:filo/features/study/presentation/study_chat_message.dart';
import 'package:filo/features/study/presentation/study_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _Downloads extends ChangeNotifier implements DownloadManager {
  @override
  final states = <String, DownloadState>{};
  var cancels = 0;
  @override
  void cancel(String id) {
    cancels++;
    states.remove(id);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected download operation: ${invocation.memberName}',
  );
}

double contrast(Color a, Color b) =>
    (math.max(a.computeLuminance(), b.computeLuminance()) + .05) /
    (math.min(a.computeLuminance(), b.computeLuminance()) + .05);

void main() {
  Widget app(Widget child, ThemeData theme) => MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: const MediaQueryData(
        textScaler: TextScaler.linear(1.3),
        disableAnimations: true,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    ),
  );

  test(
    'classification keeps real extensions and uses MIME only without one',
    () {
      for (final (name, type, label) in [
        ('handout.PDF', FiloFileType.pdf, 'PDF'),
        ('photo.png', FiloFileType.image, 'PNG'),
        ('photo.JPEG', FiloFileType.image, 'JPEG'),
        ('notes.doc', FiloFileType.doc, 'DOC'),
        ('notes.docx', FiloFileType.doc, 'DOCX'),
        ('slides.ppt', FiloFileType.ppt, 'PPT'),
        ('slides.pptx', FiloFileType.ppt, 'PPTX'),
        ('sheet.xls', FiloFileType.xls, 'XLS'),
        ('sheet.xlsx', FiloFileType.xls, 'XLSX'),
        ('data.csv', FiloFileType.xls, 'CSV'),
        ('notes.txt', FiloFileType.text, 'TXT'),
        ('notes.md', FiloFileType.text, 'MD'),
        ('archive.zip', FiloFileType.other, 'ZIP'),
        ('readme', FiloFileType.other, 'No extension'),
        ('.hidden', FiloFileType.other, 'No extension'),
        ('filename.', FiloFileType.other, 'No extension'),
      ]) {
        final details = FiloFileDetails.fromName(name);
        expect(details.type, type, reason: name);
        expect(details.label, label, reason: name);
        expect(fileIcon(name), type.icon);
        expect(studyFileIcon(name), type.icon);
      }
      expect(
        FiloFileDetails.fromName(r'C:\folder.name\photo.PNG').label,
        'PNG',
      );
      expect(
        FiloFileDetails.fromName('/folder.name/readme').label,
        'No extension',
      );
      expect(
        FiloFileDetails.fromName('renamed.pdf', mimeType: 'image/png').type,
        FiloFileType.pdf,
      );
      expect(
        FiloFileDetails.fromName('archive.zip', mimeType: 'image/png').type,
        FiloFileType.other,
      );
      for (final (mime, type) in [
        ('APPLICATION/PDF; charset=utf-8', FiloFileType.pdf),
        ('image/jpeg', FiloFileType.image),
        ('application/msword', FiloFileType.doc),
        (
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          FiloFileType.ppt,
        ),
        (
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          FiloFileType.xls,
        ),
        ('text/plain', FiloFileType.text),
        ('application/octet-stream', FiloFileType.other),
      ]) {
        final details = FiloFileDetails.fromName('readme', mimeType: mime);
        expect(details.type, type);
        expect(details.label, contains('No extension'));
      }
      expect(
        FiloFileDetails.fromName('website.pdf', kind: 'link').label,
        'Link',
      );
      expect(
        FiloFileDetails.fromName('pasted.txt', kind: 'text').label,
        'Text',
      );
    },
  );

  testWidgets(
    'presets retain icons, words, weight and measured contrast in both themes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      expect(FiloStatusPreset.draft.icon, FiloIcons.edit);
      expect(FiloStatusPreset.waitingForApproval.icon, FiloIcons.pending);
      expect(FiloStatusPreset.cloudOnly.icon, FiloIcons.cloud);
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        for (final preset in FiloStatusPreset.values) {
          await tester.pumpWidget(app(FiloStatusChip.preset(preset), theme));
          await tester.pumpAndSettle();
          final chip = tester.widget<Chip>(find.byType(Chip));
          expect(find.text(preset.label), findsOneWidget);
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(preset.label))
                .maxLines,
            isNull,
          );
          expect(find.bySemanticsLabel(preset.label), findsOneWidget);
          expect(chip.labelStyle!.color, isNotNull);
          expect(
            contrast(chip.labelStyle!.color!, chip.backgroundColor!),
            greaterThanOrEqualTo(4.5),
          );
          final icon = tester.widget<FiloIcon>(find.byType(FiloIcon));
          expect(icon.icon, preset.icon);
          expect(
            contrast(icon.color!, chip.backgroundColor!),
            greaterThanOrEqualTo(3),
          );
          expect(
            find.ancestor(
              of: find.byType(FiloIcon),
              matching: find.byType(ExcludeSemantics),
            ),
            findsWidgets,
          );
          if (preset == FiloStatusPreset.graded)
            expect(chip.labelStyle!.fontWeight, FontWeight.w800);
          if (preset == FiloStatusPreset.missing)
            expect(chip.side!.color, theme.colorScheme.error);
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(app(const FiloAiBadge(), theme));
        final chip = tester.widget<Chip>(find.byType(Chip));
        final tokens = theme.extension<FiloThemeTokens>()!;
        expect(chip.backgroundColor, tokens.lime);
        expect(chip.side!.color, tokens.limeDeep);
        expect(chip.labelStyle!.color, tokens.onLime);
      }
    },
  );

  testWidgets(
    '44 dp tiles and separate labels fit narrow 130 percent layouts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        for (final type in FiloFileType.values) {
          final details = FiloFileDetails(type, extension: 'EXTENSION');
          await tester.pumpWidget(
            app(
              Row(
                children: [
                  FiloFileTypeTile(details: details),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'A long filename which may truncate independently',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        FiloFileTypeLabel(details: details),
                      ],
                    ),
                  ),
                ],
              ),
              theme,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.getSize(find.byType(FiloFileTypeTile)),
            const Size(44, 44),
          );
          expect(find.text('EXTENSION'), findsOneWidget);
          expect(
            tester
                .renderObject<RenderParagraph>(find.text('EXTENSION'))
                .maxLines,
            isNull,
          );
          expect(find.bySemanticsLabel('EXTENSION'), findsOneWidget);
          final (ink, fill) = type.colors(theme);
          expect(contrast(ink, fill), greaterThanOrEqualTo(3));
          expect(
            contrast(theme.colorScheme.onSurface, theme.colorScheme.surface),
            greaterThanOrEqualTo(4.5),
          );
          final container = tester.widget<Container>(
            find.descendant(
              of: find.byType(FiloFileTypeTile),
              matching: find.byType(Container),
            ),
          );
          expect(
            (container.decoration as BoxDecoration).borderRadius,
            BorderRadius.circular(12),
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'shared adapters preserve grade wording, file types and AI accessibility copy',
    (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          app(
            const Column(
              children: [
                GradeStatusChip('Graded (not returned)'),
                GradeStatusChip('Not due yet'),
                FileCard(
                  file: PreviewFile(
                    'A very long course document.docx',
                    'Documents',
                    '1 MB',
                    'Preview',
                  ),
                ),
                StudyChatBubble(
                  content: 'Saved answer',
                  role: 'assistant',
                  mode: 'general',
                ),
                FiloAiBadge(
                  semanticLabel: 'AI-generated. Check it before publishing.',
                ),
              ],
            ),
            theme,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Graded (not returned)'), findsOneWidget);
        expect(find.text('Not due yet'), findsOneWidget);
        expect(find.text('DOCX'), findsOneWidget);
        expect(find.byType(FiloFileTypeTile), findsOneWidget);
        expect(find.text('Saved answer'), findsOneWidget);
        expect(
          find.bySemanticsLabel('AI-generated. Check it before publishing.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'long status and source labels override Material single-line defaults',
    (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          app(
            Column(
              children: [
                const SizedBox(
                  width: 160,
                  child: GradeStatusChip(
                    'Graded (not returned to the student yet)',
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: ActionChip(
                    onPressed: () {},
                    label: const FiloFileTypeLabel(
                      details: FiloFileDetails(
                        FiloFileType.doc,
                        extension: 'UNUSUALLYLONGEXTENSION',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            theme,
          ),
        );
        await tester.pumpAndSettle();
        for (final label in [
          'Graded (not returned to the student yet)',
          'UNUSUALLYLONGEXTENSION',
        ]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(paragraph.maxLines, isNull);
          expect(paragraph.softWrap, isTrue);
          expect(paragraph.overflow, TextOverflow.visible);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'cloud-only waits for cache lookup and yields to progress and failure',
    (tester) async {
      final files = StreamController<List<LocalFileRecord>>.broadcast();
      final downloads = _Downloads();
      final date = DateTime.utc(2026);
      TextButton button(String label) => tester.widget<TextButton>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate(
                (widget) => widget is TextButton,
              ),
            )
            .first,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localFilesProvider.overrideWith((ref) => files.stream),
            downloadManagerProvider.overrideWith((ref) async => downloads),
            connectivityProvider.overrideWith((ref) => Stream.value(false)),
          ],
          child: app(
            DownloadFileCard(
              classId: 'class',
              postId: 'post',
              attachment: CachePostAttachment(
                id: 'file',
                postId: 'post',
                kind: 'file',
                name: 'Notes.pdf',
                sortOrder: 0,
                createdAt: date,
                updatedAt: date,
              ),
            ),
            AppTheme.light,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Cloud only'), findsNothing);
      expect(find.text('Available offline'), findsNothing);
      files.addError(StateError('Read failed'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Cloud only'), findsNothing);
      files.add([]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Cloud only'), findsOneWidget);
      expect(button('Download').onPressed, isNull);
      downloads.states['file'] = const DownloadState(
        running: true,
        received: 1,
        total: 2,
      );
      downloads.notifyListeners();
      await tester.pump();
      expect(find.text('Cloud only'), findsNothing);
      expect(find.text('Available offline'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(downloads.cancels, 1);
      expect(find.text('Cloud only'), findsOneWidget);
      downloads.states['file'] = const DownloadState(
        error: FileProblem('Download failed.'),
      );
      downloads.notifyListeners();
      await tester.pump();
      expect(find.text('Cloud only'), findsNothing);
      expect(find.text('Available offline'), findsNothing);
      expect(find.text('Download failed.'), findsOneWidget);
      expect(button('Retry').onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(files.close);
      downloads.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
