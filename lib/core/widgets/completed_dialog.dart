import 'package:flutter/material.dart';

/// Returns after both the result and the closing animation, so callers can
/// safely dispose controllers used by the dialog's text fields.
Future<T?> showCompletedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    barrierDismissible: false,
    builder: builder,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    barrierColor: DialogTheme.of(context).barrierColor ?? Colors.black54,
  );
  final result = await navigator.push(route);
  await route.completed;
  return result;
}
