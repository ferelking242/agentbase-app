import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/room.dart';
import '../services/github_service.dart';
import '../theme.dart';
import '../widgets/app_components.dart';
import 'room_detail_screen.dart';

class RoomsScreen extends StatefulWidget {
  final GitHubService github;
  const RoomsScreen({super.key, required this.github});
  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List<Room> _rooms = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.github.fetchRooms();
      if (mounted) setState(() { _rooms = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: SafeArea(
      bottom: false,
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
                child: const Icon(Icons.arrow_back_ios_new, size: 13, color: kMuted),
              ),
            ),
            const SizedBox(width: 12),
            Text('Rooms', style: GoogleFonts.inter(color: kText, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            if (!_loading && _rooms.isNotEmpty) ...[
              const SizedBox(width: 8),
              AppBadge('${_rooms.length}'),
            ],
            const Spacer(),
            GestureDetector(
              onTap: _load,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
                child: const Icon(Icons.refresh_rounded, size: 17, color: kMuted),
              ),
            ),
          ]),
        ),

        // Content
        Expanded(
          child: _loading
              ? const AppLoadingIndicator()
              : _rooms.isEmpty
                  ? const AppEmptyState(icon: Icons.workspaces_outlined, title: 'Aucune room', subtitle: 'Configure ton token GitHub dans Paramètres')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _rooms.length,
                      itemBuilder: (_, i) => _RoomCard(
                        room: _rooms[i],
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => RoomDetailScreen(room: _rooms[i], github: widget.github),
                        )),
                      ),
                    ),
        ),
      ]),
    ),
  );
}

// ── Room Card ─────────────────────────────────────────────────────────────────
class _RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = room.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Hero header
          Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.04)],
              ),
              border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.12), width: 0.5)),
            ),
            child: Stack(children: [
              // Grid pattern
              Positioned.fill(child: Opacity(
                opacity: 0.06,
                child: CustomPaint(painter: _GridPainter(accent)),
              )),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
                    ),
                    child: Icon(room.iconData, size: 24, color: accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(room.name, style: GoogleFonts.inter(color: kText, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                      if (room.description.isNotEmpty) Text(room.description,
                        style: GoogleFonts.inter(color: kMuted2, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kGreenSub.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kGreen.withValues(alpha: 0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text('Actif', style: GoogleFonts.inter(color: kGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(children: [
              Expanded(child: _StatBox(
                icon: Icons.article_outlined,
                value: '${room.transcriptCount}',
                label: 'Prompts',
                color: kAccentMid,
              )),
              Container(width: 0.5, height: 36, color: kBorder, margin: const EdgeInsets.symmetric(horizontal: 12)),
              Expanded(child: _StatBox(
                icon: Icons.chat_bubble_outline,
                value: '${room.chatCount}',
                label: 'Messages',
                color: kAccentMid,
              )),
              Container(width: 0.5, height: 36, color: kBorder, margin: const EdgeInsets.symmetric(horizontal: 12)),
              Expanded(child: _StatBox(
                icon: Icons.rule_outlined,
                value: '—',
                label: 'Règles',
                color: kYellow,
              )),
            ]),
          ),

          // Open button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.08)]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.25), width: 0.5),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.open_in_new_rounded, size: 15, color: accent),
                const SizedBox(width: 8),
                Text('Ouvrir la room', style: GoogleFonts.inter(color: accent, fontSize: 13.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _StatBox({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 13, color: color.withValues(alpha: 0.7)),
      const SizedBox(width: 5),
      Text(value, style: GoogleFonts.inter(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
    ]),
    const SizedBox(height: 2),
    Text(label, style: GoogleFonts.inter(color: kMuted2, fontSize: 11)),
  ]);
}

// ── Grid Painter ──────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    const step = 20.0;
    for (double x = 0; x < size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}
