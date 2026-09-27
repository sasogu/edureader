import 'package:flutter/material.dart';

// Reutilizamos los mismos colores que para el highlight
const underlineColors = <String, Color>{
  'Amarillo': Color(0xFFFFF176),
  'Verde': Color(0xFFA5D6A7),
  'Azul': Color(0xFF90CAF9),
  'Rosa': Color(0xFFF48FB1),
  'Naranja': Color(0xFFFFCC80),
};

class UnderlineColorDialog extends StatefulWidget {
  const UnderlineColorDialog({required this.initialColor, super.key});

  final Color initialColor;

  @override
  State<UnderlineColorDialog> createState() => _UnderlineColorDialogState();
}

class _UnderlineColorDialogState extends State<UnderlineColorDialog> {
  late Color _selected = widget.initialColor;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Color del subrayado'),
    content: SizedBox(
      width: 340,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in underlineColors.entries)
            ChoiceChip(
              label: Text(entry.key),
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
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_selected),
        child: const Text('Subrayar'),
      ),
    ],
  );
}
