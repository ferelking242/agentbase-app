import 'dart:convert';

class SavedPrompt {
  final String id, name, link;
  final DateTime created;
  final int number;

  const SavedPrompt({
    required this.id,
    required this.name,
    required this.link,
    required this.created,
    this.number = 0,
  });

  SavedPrompt copyWith({String? name}) => SavedPrompt(
    id: id, link: link, created: created, number: number,
    name: name ?? this.name,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'link': link,
    'created': created.toIso8601String(),
    'number': number,
  };

  factory SavedPrompt.fromJson(Map<String, dynamic> j) => SavedPrompt(
    id: j['id'] as String,
    name: j['name'] as String,
    link: j['link'] as String,
    created: DateTime.parse(j['created'] as String),
    number: j['number'] as int? ?? 0,
  );

  static List<SavedPrompt> listFromJson(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => SavedPrompt.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  static String listToJson(List<SavedPrompt> prompts) =>
      jsonEncode(prompts.map((p) => p.toJson()).toList());
}
