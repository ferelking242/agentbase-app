class Room {
  final String id;
  final String name;
  final String description;
  final String color;
  final String icon;
  final String created;
  final bool passwordProtected;
  final int transcriptCount;
  final int chatCount;

  Room({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
    required this.created,
    required this.passwordProtected,
    required this.transcriptCount,
    required this.chatCount,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      color: json['color'] ?? '#6366F1',
      icon: json['icon'] ?? '📁',
      created: json['created'] ?? '',
      passwordProtected: json['password_protected'] ?? false,
      transcriptCount: json['transcript_count'] ?? 0,
      chatCount: json['chat_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'color': color,
    'icon': icon,
    'created': created,
    'password_protected': passwordProtected,
    'transcript_count': transcriptCount,
    'chat_count': chatCount,
  };
}
