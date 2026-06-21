import 'package:flutter/material.dart';
import '../models/room.dart';
import '../theme.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;

  const RoomCard({super.key, required this.room, required this.onTap});

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return kAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _parseColor(room.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 3, color: accent),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: accent.withOpacity(0.25)),
                          ),
                          child: Center(
                            child: Text(
                              room.icon,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.name,
                                style: const TextStyle(
                                  color: kText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (room.passwordProtected)
                                Row(
                                  children: [
                                    Icon(Icons.lock_outline,
                                        size: 11, color: kMuted),
                                    const SizedBox(width: 3),
                                    Text('Protégé',
                                        style: TextStyle(
                                            fontSize: 11, color: kMuted)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            size: 13, color: kMuted),
                      ],
                    ),
                    if (room.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        room.description,
                        style: const TextStyle(
                            fontSize: 12.5, color: kMuted2, height: 1.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _chip(accent, '${room.transcriptCount} fichiers'),
                        const SizedBox(width: 6),
                        _chip(kPurple, room.created),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
