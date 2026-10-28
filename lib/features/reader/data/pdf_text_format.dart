/// Removes the physical line breaks imposed by a PDF page while keeping
/// paragraph breaks. This is a reading aid, not a reconstruction of layout.
String reflowPdfText(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final paragraphs = <String>[];
  var current = '';
  for (final value in lines) {
    final line = value.trim().replaceAll(RegExp(r'[ \t]+'), ' ');
    if (line.isEmpty) {
      if (current.isNotEmpty) paragraphs.add(current);
      current = '';
      continue;
    }
    if (current.isEmpty) {
      current = line;
    } else if (current.endsWith('-') &&
        RegExp(r'^[a-záéíóúüñçàèò]').hasMatch(line)) {
      current = '${current.substring(0, current.length - 1)}$line';
    } else {
      current = '$current $line';
    }
  }
  if (current.isNotEmpty) paragraphs.add(current);
  return paragraphs.join('\n\n');
}
