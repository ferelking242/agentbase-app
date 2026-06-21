import 'package:flutter/material.dart';
import '../models/prompt.dart';
import '../theme.dart';

class PromptTile extends StatelessWidget {
  final AgentPrompt prompt;

  const PromptTile({super.key, required this.prompt});

  Color _statusColor() {
    switch (prompt.status) {
      case 'done':
        return kGreen;
      case 'executing':
        return kYellow;
      case 'read':
        return kAccent2;
      default:
        return kMuted;
    }
  }

  String _statusLabel() {
    switch (prompt.status) {
      case 'done':
        return 'Terminé';
      case 'executing':
        return 'En cours';
      case 'read':
        return 'Lu';
      default:
        return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '#${prompt.number}',
                    style: const TextStyle(
                      color: kAccent2,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  prompt.text.length > 80
                      ? '${prompt.text.substring(0, 80)}...'
                      : prompt.text,
                  style: const TextStyle(
                    color: kText2,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _statusLabel(),
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (prompt.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: prompt.attachments.map((a) {
                IconData icon;
                switch (a.type) {
                  case 'image':
                    icon = Icons.image_outlined;
                    break;
                  case 'audio':
                    icon = Icons.mic_outlined;
                    break;
                  default:
                    icon = Icons.attach_file;
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: kSurface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 11, color: kMuted2),
                      const SizedBox(width: 4),
                      Text(
                        a.name,
                        style: const TextStyle(fontSize: 10.5, color: kMuted2),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
