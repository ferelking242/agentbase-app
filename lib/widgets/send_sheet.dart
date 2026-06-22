import 'package:flutter/material.dart';
import '../models/room.dart';
import '../services/github_service.dart';

typedef SendResult = ({String name, Room? room});

class SendSheet extends StatefulWidget {
  final String defaultName;
  final List<Room> preloadedRooms;
  final GitHubService github;
  const SendSheet({
    super.key,
    required this.defaultName,
    required this.preloadedRooms,
    required this.github,
  });
  @override
  State<SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<SendSheet> {
  late final TextEditingController _ctrl;
  Room? _room;
  List<Room> _rooms = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.defaultName);
    _rooms = List.from(widget.preloadedRooms);
    if (_rooms.isEmpty) _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    setState(() => _loading = true);
    try {
      final r = await widget.github.fetchRooms();
      if (mounted) setState(() { _rooms = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _submit() {
    Navigator.pop(context, (name: _ctrl.text.trim(), room: _room));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(2)),
              )),

              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('NOM DU PROMPT',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: const TextStyle(color: Color(0xFFECECEC), fontSize: 15),
                  cursorColor: const Color(0xFF6366F1),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Ex: Analyse de données',
                    hintStyle: const TextStyle(color: Color(0xFF444444)),
                    filled: true,
                    fillColor: const Color(0xFF0D0D0D),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF222222))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF222222))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: Color(0xFF444444)),
                      onPressed: () => _ctrl.clear(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text('ROOM',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              ),
              SizedBox(
                height: 40,
                child: _loading
                  ? const Center(child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1))))
                  : ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        RoomChip(
                          label: 'Aucune',
                          selected: _room == null,
                          onTap: () => setState(() => _room = null)),
                        ..._rooms.map((r) => RoomChip(
                          label: r.name,
                          icon: r.iconData,
                          color: r.accentColor,
                          selected: _room?.id == r.id,
                          onTap: () => setState(() => _room = r),
                        )),
                      ],
                    ),
              ),

              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF666666),
                        side: const BorderSide(color: Color(0xFF2A2A2A)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _room != null ? 'Envoyer → ${_room!.name}' : 'Envoyer',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoomChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  const RoomChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF6366F1);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.18) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : const Color(0xFF2A2A2A), width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: selected ? c : const Color(0xFF666666)),
            const SizedBox(width: 5),
          ],
          Text(label, style: TextStyle(
            color: selected ? c : const Color(0xFF777777),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          )),
        ]),
      ),
    );
  }
}
