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
      } catch (_) { return kAccent; }
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
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top accent line
              Container(height: 2, color: accent),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text(room.icon, style: const TextStyle(fontSize: 20))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(room.name, style: const TextStyle(
                                  color: kText, fontSize: 14,
                                  fontWeight: FontWeight.w700, letterSpacing: -0.2),
                                  overflow: TextOverflow.ellipsis),
                              ),
                              if (room.passwordProtected)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.lock_outline, size: 12, color: kMuted),
                                ),
                            ],
                          ),
                          if (room.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(room.description,
                                style: const TextStyle(color: kMuted2, fontSize: 12, height: 1.4),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: kMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }