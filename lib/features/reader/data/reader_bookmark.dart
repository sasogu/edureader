import 'package:flutter_readium/flutter_readium.dart';

class ReaderBookmark {
  const ReaderBookmark({
    required this.id,
    required this.locator,
    required this.label,
    required this.createdAt,
  });

  factory ReaderBookmark.create({
    required Locator locator,
    required String label,
  }) {
    final now = DateTime.now();
    return ReaderBookmark(
      id: 'bookmark_${now.microsecondsSinceEpoch}',
      locator: locator,
      label: label.trim(),
      createdAt: now,
    );
  }

  factory ReaderBookmark.fromJson(Map<String, dynamic> json) {
    return ReaderBookmark(
      id: json['id'] as String,
      locator: Locator.fromJson(json['locator'] as Map<String, dynamic>)!,
      label: json['label'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final Locator locator;
  final String label;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'locator': locator.toJson(),
    'label': label,
    'createdAt': createdAt.toIso8601String(),
  };
}
