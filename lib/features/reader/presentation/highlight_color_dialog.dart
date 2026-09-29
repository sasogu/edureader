import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

const highlightColors = <String, Color>{
  'Amarillo': Color(0xFFFFF176),
  'Verde': Color(0xFFA5D6A7),
  'Azul': Color(0xFF90CAF9),
  'Rosa': Color(0xFFF48FB1),
  'Naranja': Color(0xFFFFCC80),
};

class HighlightColorDialog extends StatefulWidget {
  const HighlightColorDialog({required this.initialColor, super.key});

  final Color initialColor;

  @override
  State<HighlightColorDialog> createState() => _HighlightColorDialogState();
}

class _HighlightColorDialogState extends State<HighlightColorDialog> {
  late Color _selected = widget.initialColor;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(AppLocalizations.of(context).highlightColorTitle),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in highlightColors.entries)
            ChoiceChip(
              label: Text(switch (entry.key) {
                'Amarillo' => AppLocalizations.of(context).colorYellow,
                'Verde' => AppLocalizations.of(context).colorGreen,
                'Azul' => AppLocalizations.of(context).colorBlue,
                'Rosa' => AppLocalizations.of(context).colorPink,
                'Naranja' => AppLocalizations.of(context).colorOrange,
                _ => entry.key,
              }),
              selected: _selected == entry.value,
              backgroundColor: entry.value,
              selectedColor: entry.value,
              labelStyle: const TextStyle(color: Colors.black),
              checkmarkColor: Colors.black,
              showCheckmark: true,
              onSelected: (_) => setState(() => _selected = entry.value),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(AppLocalizations.of(context).cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_selected),
        child: Text(AppLocalizations.of(context).underlineAction),
      ),
    ],
  );
}
