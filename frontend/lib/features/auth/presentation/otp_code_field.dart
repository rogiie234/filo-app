import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/filo_theme_tokens.dart';
import '../../../core/widgets/filo_widgets.dart';

/// One native editor preserves paste, autofill, selection and accessible editing.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSubmitted,
    this.onChanged,
    this.hasError = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool hasError;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  double _tapX = 0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 6.0;
      final side = ((constraints.maxWidth - gap * 5) / 6)
          .clamp(0.0, 52.0)
          .toDouble();
      final start = (constraints.maxWidth - side * 6 - gap * 5) / 2;
      final colors = Theme.of(context).colorScheme;
      return AnimatedBuilder(
        animation: Listenable.merge([widget.controller, widget.focusNode]),
        builder: (context, _) {
          final text = widget.controller.text;
          final selected = widget.controller.selection.start.clamp(0, 5);
          return Listener(
            onPointerDown: (event) => _tapX = event.localPosition.dx,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  enableInlinePrediction: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  showCursor: false,
                  style: const TextStyle(color: Colors.transparent),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    labelStyle: TextStyle(color: Colors.transparent),
                    counterText: '',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    constraints: BoxConstraints(minHeight: 64),
                  ),
                  onTap: () {
                    final index = ((_tapX - start) / (side + gap))
                        .floor()
                        .clamp(0, 5)
                        .toInt();
                    widget.controller.selection = index < text.length
                        ? TextSelection(
                            baseOffset: index,
                            extentOffset: index + 1,
                          )
                        : TextSelection.collapsed(offset: text.length);
                  },
                  onSubmitted: widget.onSubmitted,
                  onChanged: widget.onChanged,
                ),
                IgnorePointer(
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      textDirection: TextDirection.ltr,
                      children: List.generate(
                        6,
                        (index) => Padding(
                          padding: EdgeInsets.only(right: index < 5 ? gap : 0),
                          child: Container(
                            width: side,
                            height: side,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              boxShadow: widget.hasError
                                  ? [
                                      BoxShadow(
                                        color: colors.error.withValues(
                                          alpha: .18,
                                        ),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : const [],
                              color: widget.enabled
                                  ? colors.surface
                                  : FiloThemeTokens.of(context).disabledFill,
                              borderRadius: BorderRadius.circular(
                                FiloRadii.small,
                              ),
                              border: Border.all(
                                color: widget.hasError
                                    ? colors.error
                                    : widget.enabled &&
                                          widget.focusNode.hasFocus &&
                                          selected == index
                                    ? colors.primary
                                    : FiloThemeTokens.of(context).controlBorder,
                                width:
                                    widget.hasError ||
                                        widget.enabled &&
                                            widget.focusNode.hasFocus &&
                                            selected == index
                                    ? 2
                                    : 1,
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                index < text.length ? text[index] : '',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: widget.enabled
                                          ? colors.onSurface
                                          : FiloThemeTokens.of(context)
                                                .disabledInk,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
