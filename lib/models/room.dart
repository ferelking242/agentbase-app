import 'package:flutter/material.dart';

class Room {
  final String id, name, description, color;
  final int transcriptCount, chatCount;

  const Room({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    this.transcriptCount = 0,
    this.chatCount = 0,
  });

  /// Combined prompt count shown in the UI
  int get promptCount => transcriptCount + chatCount;

  factory Room.fromJson(Map<String, dynamic> j) => Room(
    id:              j['id']               as String? ?? '',
    name:            j['name']             as String? ?? 'Room',
    description:     j['description']      as String? ?? '',
    color:           j['color']            as String? ?? '#6366f1',
    transcriptCount: j['transcript_count'] as int? ?? 0,
    chatCount:       j['chat_count']       as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'color': color,
    'transcript_count': transcriptCount,
    'chat_count': chatCount,
  };

  Color get accentColor {
    try { return Color(int.parse('FF${color.replaceAll("#", "")}', radix: 16)); }
    catch (_) { return const Color(0xFF6366F1); }
  }

  IconData get iconData {
    switch (id.toLowerCase()) {
      case 'watchtower': return Icons.radar_outlined;
      case 'scorais':    return Icons.bar_chart_outlined;
      case 'room-3':     return Icons.memory_outlined;
      case 'room-4':     return Icons.code_outlined;
      case 'room-5':     return Icons.auto_awesome_outlined;
      default:
        final l = name.toLowerCase();
        if (l.contains('code') || l.contains('dev'))      return Icons.code_outlined;
        if (l.contains('design') || l.contains('ui'))     return Icons.palette_outlined;
        if (l.contains('data')  || l.contains('score'))   return Icons.bar_chart_outlined;
        if (l.contains('watch') || l.contains('monitor')) return Icons.radar_outlined;
        if (l.contains('server') || l.contains('back'))   return Icons.dns_outlined;
        return Icons.layers_outlined;
    }
  }
}
