import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:filo/features/assessments/data/lesson_text_extractor.dart';
import 'package:filo/features/assessments/data/file_text_cache.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

Uint8List office(Map<String, String> files) {
  final archive = Archive();
  for (final e in files.entries) {
    archive.add(ArchiveFile.string(e.key, e.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Future<LessonText> readBytes(
  String name,
  List<int> bytes, {
  LessonTextExtractor? extractor,
  AiCancelToken? cancel,
  void Function(ExtractionProgress)? onProgress,
}) async {
  final dir = await Directory.systemTemp.createTemp('filo-extraction-test');
  try {
    final file = await File('${dir.path}/$name').writeAsBytes(bytes);
    return await (extractor ?? LessonTextExtractor()).extract(
      file.path,
      name.split('.').last,
      cancel: cancel,
      onProgress: onProgress,
    );
  } finally {
    await LessonTextExtractor.waitUntilIdle();
    await dir.delete(recursive: true);
  }
}

class FakePage implements PdfPage {
  FakePage(this.read);
  final Future<String> Function() read;
  @override
  Future<PdfPageRawText?> loadText() async => PdfPageRawText(await read(), []);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePdf implements PdfDocument {
  FakePdf(List<Future<String> Function()> reads)
    : pages = reads.map(FakePage.new).toList();
  @override
  final List<PdfPage> pages;
  bool disposed = false;
  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'cleanup preserves facts/paragraphs while removing repeated page edges',
    () {
      final warnings = <String>[];
      expect(
        cleanLessonPages([
          'A rule\n1',
          'Another rule\n2',
        ], onSkipped: warnings.add),
        'A rule\n\nAnother rule',
      );
      expect(warnings.single, contains('2 '));
      expect(
        cleanLessonPages([
          'Course header\n\n Rule  1:  values  must be unique.\nPage 1',
          'Course header\n2NF removes partial dependencies.\nPage 2',
          'Course header\nA value of 42 is data.\nPage 3',
        ]),
        'Rule 1: values must be unique.\n\n2NF removes partial dependencies.\n\nA value of 42 is data.',
      );
      expect(
        cleanLessonPages(['Definition\nKeep this definition\nDefinition']),
        contains('Definition'),
      );
    },
  );
  test('UTF-8 BOM, UTF-16 LE/BE and Windows-1252 are decoded', () async {
    expect(
      (await readBytes(
        'a.txt',
        utf8.encode('\uFEFFFirst\r\nFilipino 😀'),
      )).text,
      'First\nFilipino 😀',
    );
    for (final bytes in [
      [255, 254, 65, 0, 10, 0, 66, 0],
      [254, 255, 0, 65, 0, 10, 0, 66],
    ]) {
      expect((await readBytes('a.txt', bytes)).text, 'A\nB');
    }
    final fallback = await readBytes('a.txt', [147, 72, 105, 148]);
    expect(fallback.text, '“Hi”');
    expect(fallback.warnings.single, contains('Windows-1252'));
  });
  test('DOCX run spacing and table-cell lines are preserved', () async {
    final result = await readBytes(
      'a.docx',
      office({
        'word/document.xml': '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
<w:p><w:r><w:t>First </w:t></w:r><w:r><w:t>rule</w:t></w:r></w:p>
<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Cell one</w:t></w:r></w:p></w:tc>
<w:tc><w:p><w:r><w:t>Cell two</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>''',
      }),
    );
    expect(result.text, 'First rule\nCell one\nCell two');
    expect(result.characterCount, result.text.runes.length);
    expect(result.warnings, isNotEmpty);
  });
  test('PPTX uses relationships and keeps blank lines between slides', () async {
    final bytes = office({
      'ppt/presentation.xml': '<p:presentation xmlns:p="p" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><p:sldIdLst><p:sldId r:id="r2"/><p:sldId r:id="r1"/></p:sldIdLst></p:presentation>',
      'ppt/_rels/presentation.xml.rels': '<Relationships><Relationship Id="r1" Target="slides/slide1.xml"/><Relationship Id="r2" Target="slides/slide2.xml"/></Relationships>',
      for (final n in [1, 2])
        'ppt/slides/slide$n.xml':
            '<p:sld xmlns:p="p" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:p><a:r><a:t>Slide $n</a:t></a:r></a:p></p:sld>',
    });
    final progress = <ExtractionProgress>[];
    expect(
      (await readBytes('a.pptx', bytes, onProgress: progress.add)).text,
      'Slide 2\n\nSlide 1',
    );
    expect(progress.any((p) => p.completed == 2 && p.total == 2), true);
  });
  test('empty and corrupt documents have typed failures', () async {
    await expectLater(
      readBytes('a.txt', []),
      throwsA(
        isA<LessonReadException>().having((e) => e.code, 'code', 'NO_TEXT'),
      ),
    );
    await expectLater(
      readBytes('a.doc', [1]),
      throwsA(
        isA<LessonReadException>().having((e) => e.code, 'code', 'UNSUPPORTED'),
      ),
    );
    await expectLater(
      readBytes('a.pptx', [1, 2]),
      throwsA(isA<LessonReadException>()),
    );
    await expectLater(
      readBytes('a.txt', [255, 254, 65]),
      throwsA(isA<LessonReadException>()),
    );
  });
  test(
    '10 MiB input rejected; file cache and request caps are independent',
    () async {
      await expectLater(
        readBytes('a.txt', Uint8List(LessonTextExtractor.maxFileBytes + 1)),
        throwsA(
          isA<LessonReadException>().having((e) => e.code, 'code', 'TOO_LARGE'),
        ),
      );
      final result = await readBytes(
        'a.txt',
        utf8.encode('a' * (lessonCacheByteCap + 1)),
      );
      expect(result.characterCount, lessonCacheByteCap);
      expect(result.warnings.join(), contains('2 MB'));
      expect(boundedLessonText('😀a', 4), ('😀', true));
    },
  );
  test('XML declarations are refused', () async {
    await expectLater(
      readBytes(
        'a.docx',
        office({'word/document.xml': '<!DOCTYPE x [<!ENTITY e "v">]><x/>'}),
      ),
      throwsA(isA<LessonReadException>()),
    );
  });
  test(
    'scanned PDF NO_TEXT; mixed PDF retains text and disposes document',
    () async {
      final scan = FakePdf([() async => '', () async => ' ']);
      await expectLater(
        readBytes('a.pdf', [
          1,
        ], extractor: LessonTextExtractor(openPdf: (_) async => scan)),
        throwsA(
          isA<LessonReadException>().having((e) => e.code, 'code', 'NO_TEXT'),
        ),
      );
      expect(scan.disposed, true);
      final mixed = FakePdf([() async => '', () async => 'A readable rule.']);
      final result = await readBytes('a.pdf', [
        1,
      ], extractor: LessonTextExtractor(openPdf: (_) async => mixed));
      expect(result.text, 'A readable rule.');
      expect(result.warnings.join(), contains('1 PDF pages'));
      expect(mixed.disposed, true);
    },
  );
  test(
    'cancel stops waiting but native reader disposes after draining',
    () async {
      final entered = Completer<void>(), release = Completer<String>();
      final document = FakePdf([
        () {
          entered.complete();
          return release.future;
        },
      ]);
      final cancel = AiCancelToken();
      final dir = await Directory.systemTemp.createTemp('filo-cancel');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}/a.pdf').writeAsBytes([1]);
      final operation = LessonTextExtractor(openPdf: (_) async => document)
          .extract(file.path, 'pdf', cancel: cancel);
      final expectation = expectLater(operation, throwsA(isA<AiCancelled>()));
      await entered.future;
      cancel.cancel();
      await expectation;
      expect(document.disposed, false);
      release.complete('Text');
      await LessonTextExtractor.waitUntilIdle();
      expect(document.disposed, true);
    },
  );
  test('timeout has its own code and leaves the queue usable', () async {
    final document = FakePdf([
      () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return 'Text';
      },
    ]);
    await expectLater(
      readBytes(
        'a.pdf',
        [1],
        extractor: LessonTextExtractor(
          timeout: const Duration(milliseconds: 10),
          openPdf: (_) async => document,
        ),
      ),
      throwsA(
        isA<LessonReadException>().having((e) => e.code, 'code', 'TIMEOUT'),
      ),
    );
    expect((await readBytes('next.txt', utf8.encode('Next'))).text, 'Next');
  });
}
