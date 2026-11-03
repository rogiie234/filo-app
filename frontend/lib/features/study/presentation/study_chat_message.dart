import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';

/// Only line structure and paired bold markers are interpreted. No HTML/URL widgets.
class StudyAnswerText extends StatelessWidget {
  const StudyAnswerText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].replaceFirst(RegExp(r'^\s*[-*] '), '• ');
      var cursor = 0;
      for (final match in RegExp(r'\*\*([^*]+)\*\*').allMatches(line)) {
        spans.add(TextSpan(text: line.substring(cursor, match.start)));
        spans.add(
          TextSpan(
            text: match[1],
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        );
        cursor = match.end;
      }
      spans.add(
        TextSpan(
          text: '${line.substring(cursor)}${i < lines.length - 1 ? '\n' : ''}',
        ),
      );
    }
    return SelectableText.rich(
      TextSpan(style: Theme.of(context).textTheme.bodyLarge, children: spans),
    );
  }
}

class StudyChatBubble extends StatelessWidget {
  const StudyChatBubble({
    super.key,
    required this.content,
    required this.role,
    required this.mode,
    this.time,
    this.unsaved = false,
  });
  final String content, role, mode;
  final DateTime? time;
  final bool unsaved;
  @override
  Widget build(BuildContext context) {
    final ai = role == 'assistant';
    return Align(
      alignment: ai ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (MediaQuery.sizeOf(context).width - 72)
                .clamp(120, 640)
                .toDouble(),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                color: ai ? FiloColors.surface : FiloColors.selected,
                border: ai
                    ? const Border(
                        left: BorderSide(color: FiloColors.limeDeep, width: 4),
                      )
                    : null,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ai
                              ? const FiloAiBadge()
                              : Text(
                                  'You',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                        ),
                      ),
                      if (ai)
                        IconButton(
                          tooltip: 'Copy answer',
                          onPressed: () async {
                            try {
                              await Clipboard.setData(
                                ClipboardData(text: content),
                              );
                              if (context.mounted)
                                showMessage(context, 'Answer copied.');
                            } catch (_) {
                              if (context.mounted)
                                showMessage(
                                  context,
                                  'Could not copy this answer. Try again.',
                                );
                            }
                          },
                          icon: const Icon(Icons.copy_outlined),
                        ),
                    ],
                  ),
                  if (ai) StudyAnswerText(content) else SelectableText(content),
                  const SizedBox(height: 8),
                  Text(
                    mode == 'files'
                        ? 'Answers use your files'
                        : 'General knowledge',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  if (unsaved) const Text('Not confirmed saved'),
                  if (time != null)
                    Text(
                      MaterialLocalizations.of(context).formatTimeOfDay(
                        TimeOfDay.fromDateTime(time!.toLocal()),
                      ),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
