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
          TextSpan(text: match[1], style: FiloTypography.strongLabel(context)),
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
      TextSpan(
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
        children: spans,
      ),
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
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: ai ? Alignment.centerLeft : Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: FiloSpacing.screen),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (constraints.maxWidth * (ai ? .96 : .88))
                  .clamp(0, 640)
                  .toDouble(),
            ),
            child: Column(
              crossAxisAlignment: ai
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: FiloSpacing.s8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ai) ...[
                        const ExcludeSemantics(
                          child: Mascot(pose: 'reading', size: 28),
                        ),
                        const SizedBox(width: FiloSpacing.s8),
                      ],
                      Semantics(
                        label: ai ? 'Filo, AI study assistant' : 'You',
                        excludeSemantics: true,
                        child: Text(
                          ai ? 'Filo' : 'You',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: ai ? colors.surface : colors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(
                        ai ? FiloRadii.small : FiloRadii.large,
                      ),
                      topRight: Radius.circular(
                        ai ? FiloRadii.large : FiloRadii.small,
                      ),
                      bottomLeft: const Radius.circular(FiloRadii.large),
                      bottomRight: const Radius.circular(FiloRadii.large),
                    ),
                    border: ai
                        ? Border.all(color: colors.outlineVariant)
                        : null,
                  ),
                  padding: const EdgeInsets.all(FiloSpacing.s16),
                  child: ai
                      ? StudyAnswerText(content)
                      : SelectableText(
                          content,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colors.onPrimary, height: 1.5),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: FiloSpacing.s4),
                  child: Wrap(
                    spacing: FiloSpacing.s12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: ai ? WrapAlignment.start : WrapAlignment.end,
                    children: [
                      if (ai)
                        Text(
                          mode == 'files'
                              ? 'Answers use your files'
                              : 'General knowledge',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      if (unsaved)
                        Text(
                          'Not confirmed saved',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.error),
                        ),
                      if (time != null)
                        Text(
                          MaterialLocalizations.of(context).formatTimeOfDay(
                            TimeOfDay.fromDateTime(time!.toLocal()),
                          ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      if (ai)
                        IconButton(
                          tooltip: 'Copy answer',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          iconSize: 18,
                          onPressed: () async {
                            try {
                              await Clipboard.setData(
                                ClipboardData(text: content),
                              );
                              if (context.mounted) {
                                showMessage(context, 'Answer copied.');
                              }
                            } catch (_) {
                              if (context.mounted) {
                                showMessage(
                                  context,
                                  'Could not copy this answer. Try again.',
                                );
                              }
                            }
                          },
                          icon: const FiloIcon(FiloIcons.copy),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StudyChatMarker extends StatelessWidget {
  const StudyChatMarker({
    super.key,
    required this.label,
    this.leading,
    this.action,
    this.thinking = false,
  });
  final String label;
  final bool thinking;
  final Widget? leading, action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: FiloSpacing.s12),
    child: Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: FiloSpacing.s8),
        ],
        Expanded(
          child: thinking
              ? const StudyThinkingLabel()
              : Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        ?action,
      ],
    ),
  );
}

class StudyThinkingLabel extends StatefulWidget {
  const StudyThinkingLabel({super.key});

  @override
  State<StudyThinkingLabel> createState() => _StudyThinkingLabelState();
}

class _StudyThinkingLabelState extends State<StudyThinkingLabel>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Thinking',
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final dots = MediaQuery.disableAnimationsOf(context)
              ? 3
              : 1 + (_animation.value * 3).floor();
          return Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Thinking '),
                TextSpan(text: '.' * dots),
                TextSpan(
                  text: '.' * (3 - dots),
                  style: const TextStyle(color: Colors.transparent),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        },
      ),
    ),
  );
}
