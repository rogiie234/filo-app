import 'dart:async';

import 'package:flutter/material.dart';

// Reveal the whole field/error, then let EditableText keep it above the keyboard.
Future<void> revealFiloField(BuildContext target) async {
  await WidgetsBinding.instance.endOfFrame;
  if (!target.mounted) return;
  EditableText? input;
  void findInput(Element element) {
    if (element.widget is EditableText) {
      input ??= element.widget as EditableText;
    }
    element.visitChildren(findInput);
  }

  target.visitChildElements(findInput);
  FocusNode? control = input?.focusNode;
  if (control == null) {
    for (final node in FocusScope.of(target).traversalDescendants) {
      final context = node.context;
      if (!node.canRequestFocus || context == null) continue;
      var inside = identical(context, target);
      context.visitAncestorElements((element) {
        inside = inside || identical(element, target);
        return !inside;
      });
      if (inside) {
        control = node;
        break;
      }
    }
  }
  control?.requestFocus();
  await Scrollable.ensureVisible(target, alignment: .15);
}

/// Flutter announces only the first form error; reveal and focus that same field.
bool validateFiloForm(GlobalKey<FormState> key) {
  final form = key.currentState;
  if (form == null) return false;
  final invalid = form.validateGranularly();
  if (invalid.isEmpty) return true;
  unawaited(revealFiloField(invalid.first.context));
  return false;
}
