import 'package:flutter/material.dart';
  import '../models/room.dart';
  import '../services/github_service.dart';
  import '../theme.dart';
  import 'room_detail_screen.dart';

  class RoomsScreen extends StatefulWidget {
    final GitHubService github;
    const RoomsScreen({super.key, required this.github});
    @override State<RoomsScreen> createState() => _RoomsScreenState();
  }
  class _RoomsScreenState extends State<RoomsScreen> {
    List<Room> _rooms = []; bool _loading = true;
    @override void initState() { super.initState(); _load(); }
    Future<void> _load() async {
      setState(() => _loading = true);
      final r = await widget.github.fetchRooms();
      if (mounted) setState(() { _rooms = r; _loading = false; });
    }
    @override
    Widget build(BuildContext context) {
      if (_loading) return const Center(child: CircularProgressIndicator(color: kAccent));
      return ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Text('Rooms', style: TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          const Spacer(),
          GestureDetector(onTap: _load, child: const Icon(Icons.refresh, size: 16, color: kMuted)),
        ]),
        const SizedBox(height: 4),
        Text('${_rooms.length} espace${_rooms.length>1?"s":""}', style: const TextStyle(color: kMuted, fontSize: 12)),
        const SizedBox(height: 16),
        ..._rooms.map((r) => _RoomCard(room: r, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoomDetailScreen(room: r, github: widget.github))))),
      ]);
    }
  }

  class _RoomCard extends StatelessWidget {
    final Room room; final VoidCallback onTap;
    const _RoomCard({required this.room, required this.onTap});
    @override
    Widget build(BuildContext context) {
      final accent = room.accentColor;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
          child: Column(children: [
            Container(height: 4, decoration: BoxDecoration(color: accent, borderRadius: const BorderRadius.vertical(top: Radius.circular(12)))),
            Padding(padding: const EdgeInsets.all(14), child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(room.iconData, size: 22, color: accent)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(room.name, style: const TextStyle(color: kText, fontSize: 14.5, fontWeight: FontWeight.w700)),
                if (room.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(room.description, style: const TextStyle(color: kMuted2, fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  _stat(Icons.description_outlined, '${room.transcriptCount} prompts'),
                  const SizedBox(width: 12),
                  _stat(Icons.chat_bubble_outline, '${room.chatCount} msgs'),
                ]),
              ])),
              const Icon(Icons.chevron_right, size: 18, color: kMuted),
            ])),
          ]),
        ),
      );
    }
    Widget _stat(IconData icon, String t) => Row(children: [Icon(icon, size: 12, color: kMuted), const SizedBox(width: 4), Text(t, style: const TextStyle(color: kMuted, fontSize: 11))]);
  }