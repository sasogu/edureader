import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PdfHighlightRect {
  const PdfHighlightRect(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, double> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory PdfHighlightRect.fromJson(Map<String, dynamic> json) =>
      PdfHighlightRect(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
        (json['width'] as num).toDouble(),
        (json['height'] as num).toDouble(),
      );
}

/// A PDF annotation is anchored to a page, with PDF point coordinates.
/// Deletions remain as tombstones so a second device cannot recreate them.
class PdfAnnotation {
  const PdfAnnotation({
    required this.id,
    required this.pageIndex,
    required this.text,
    required this.rects,
    required this.color,
    this.underline = false,
    required this.note,
    required this.modifiedAt,
    this.deleted = false,
  });

  final String id;
  final int pageIndex;
  final String text;
  final List<PdfHighlightRect> rects;
  final int color;
  final bool underline;
  final String? note;
  final DateTime modifiedAt;
  final bool deleted;

  PdfAnnotation copyWith({String? note, DateTime? modifiedAt, bool? deleted}) =>
      PdfAnnotation(
        id: id,
        pageIndex: pageIndex,
        text: text,
        rects: rects,
        color: color,
        underline: underline,
        note: note ?? this.note,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        deleted: deleted ?? this.deleted,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'pageIndex': pageIndex,
    'text': text,
    'rects': rects.map((rect) => rect.toJson()).toList(),
    'color': color,
    'underline': underline,
    'note': note,
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    'deleted': deleted,
  };

  factory PdfAnnotation.fromJson(Map<String, dynamic> json) => PdfAnnotation(
    id: json['id'] as String,
    pageIndex: json['pageIndex'] as int,
    text: json['text'] as String,
    rects: (json['rects'] as List<dynamic>)
        .map(
          (item) =>
              PdfHighlightRect.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    color: json['color'] as int,
    underline: json['underline'] as bool? ?? false,
    note: json['note'] as String?,
    modifiedAt: DateTime.parse(json['modifiedAt'] as String).toUtc(),
    deleted: json['deleted'] as bool? ?? false,
  );
}

class PdfAnnotationStorage {
  static Future<void> _queue = Future<void>.value();

  String _key(String documentId) => 'pdf_annotations_$documentId';

  Future<List<PdfAnnotation>> load(String documentId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key(documentId));
    if (value == null) return [];
    return (jsonDecode(value) as List<dynamic>)
        .map(
          (item) =>
              PdfAnnotation.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> merge(String documentId, Iterable<PdfAnnotation> incoming) {
    final operation = _queue.then((_) async {
      final existing = {
        for (final item in await load(documentId)) item.id: item,
      };
      for (final item in incoming) {
        final current = existing[item.id];
        if (current == null || item.modifiedAt.isAfter(current.modifiedAt)) {
          existing[item.id] = item;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(documentId),
        jsonEncode(existing.values.map((item) => item.toJson()).toList()),
      );
    });
    _queue = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> delete(String documentId, PdfAnnotation item) => merge(
    documentId,
    [item.copyWith(deleted: true, modifiedAt: DateTime.now().toUtc())],
  );
}
