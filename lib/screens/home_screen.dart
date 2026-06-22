import 'package:flutter/material.dart';
  import '../models/room.dart';
  import '../services/github_service.dart';
  import '../screens/settings_screen.dart';
  import '../screens/room_detail_screen.dart';
  import '../theme.dart';

  class HomeScreen extends StatefulWidget {
    final GitHubService github;
    const HomeScreen({super.key, required this.github});
    @override
    State<HomeScreen> createState() => _HomeScreenState();
  }

  class _HomeScreenState extends State<HomeScreen> {
    List<Room> _rooms = [];
    Room? _selected;
    bool _loading = true;
    bool _patMissing = false;
    final _scaffoldKey = GlobalKey<ScaffoldState>();

    @override
    void initState() { super.initState(); _init(); }

    Future<void> _init() async {
      await widget.github.init();
      if (mounted) setState(() => _patMissing = !widget.github.hasPat);
      await _load();
    }

    Future<void> _load() async {
      setState(() => _loading = true);
      try {
        final rooms = await widget.github.fetchRooms();
        if (mounted) setState(() { _rooms = rooms; _loading = false; });
      } catch (_) { if (mounted) setState(() => _loading = false); }
    }

    void _onRoom(Room room, bool wide) {
      if (wide) {
        setState(() => _selected = room);
      } else {
        _scaffoldKey.currentState?.closeDrawer();
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => RoomDetailScreen(room: room, github: widget.github)));
      }
    }

    @override
    Widget build(BuildContext context) {
      final wide = MediaQuery.of(context).size.width >= 720;
      final sidebar = _Sidebar(
        rooms: _rooms, selected: _selected, loading: _loading, patMissing: _patMissing,
        onSelect: (r) => _onRoom(r, wide),
        onSettings: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => SettingsScreen(github: widget.github))).then((_) => setState(() {})),
        onRefresh: _load,
        onMenuTap: wide ? null : () => _scaffoldKey.currentState?.openDrawer(),
      );
      if (wide) {
        return Scaffold(
          backgroundColor: kBg,
          body: Row(children: [
            SizedBox(width: 240, child: sidebar),
            Container(width: 0.5, color: kBorder),
            Expanded(child: _selected != null
              ? RoomDetailView(room: _selected!, github: widget.github)
              : _EmptyState()),
          ]),
        );
      }
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: kBg,
        drawer: Drawer(
          backgroundColor: kSidebar,
          width: 260,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: sidebar,
        ),
        body: _EmptyState(onMenu: () => _scaffoldKey.currentState?.openDrawer()),
      );
    }
  }

  // ─── Sidebar ─────────────────────────────────────────────────
  class _Sidebar extends StatelessWidget {
    final List<Room> rooms;
    final Room? selected;
    final bool loading, patMissing;
    final ValueChanged<Room> onSelect;
    final VoidCallback onSettings, onRefresh;
    final VoidCallback? onMenuTap;
    const _Sidebar({required this.rooms, this.selected, required this.loading, required this.patMissing,
      required this.onSelect, required this.onSettings, required this.onRefresh, this.onMenuTap});

    @override
    Widget build(BuildContext context) {
      return Container(
        color: kSidebar,
        child: Column(children: [
          // Header
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
            child: Row(children: [
              Container(width: 22, height: 22,
                decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.bolt, size: 13, color: Colors.white)),
              const SizedBox(width: 9),
              const Expanded(child: Text('AgentBase',
                style: TextStyle(color: kText, fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: -0.3))),
              GestureDetector(onTap: onRefresh,
                child: const Icon(Icons.refresh, size: 15, color: kMuted)),
            ]),
          ),
          if (patMissing)
            Container(
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: kYellow.withOpacity(0.08), borderRadius: BorderRadius.circular(7),
                border: Border.all(color: kYellow.withOpacity(0.2))),
              child: Row(children: [
                const Icon(Icons.key_outlined, size: 13, color: kYellow),
                const SizedBox(width: 7),
                const Expanded(child: Text('Token requis', style: TextStyle(color: kYellow, fontSize: 11, fontWeight: FontWeight.w500))),
                GestureDetector(onTap: onSettings,
                  child: const Text('Config.', style: TextStyle(color: kAccentL, fontSize: 11, fontWeight: FontWeight.w600))),
              ]),
            ),
          // Section label
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 6),
            child: Row(children: [
              const Text('ESPACES', style: TextStyle(color: kMuted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const Spacer(),
              if (loading) const SizedBox(width: 10, height: 10,
                child: CircularProgressIndicator(color: kMuted, strokeWidth: 1)),
            ]),
          ),
          // Room list
          Expanded(
            child: loading && rooms.isEmpty
              ? const Center(child: CircularProgressIndicator(color: kAccent))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemCount: rooms.length,
                  itemBuilder: (_, i) => _RoomItem(room: rooms[i], selected: selected?.id == rooms[i].id, onTap: () => onSelect(rooms[i])),
                ),
          ),
          // Settings footer
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorder, width: 0.5))),
            child: _SidebarBtn(icon: Icons.settings_outlined, label: "Parametres", onTap: onSettings),
          ),
        ]),
      );
    }
  }

  class _RoomItem extends StatefulWidget {
    final Room room;
    final bool selected;
    final VoidCallback onTap;
    const _RoomItem({required this.room, required this.selected, required this.onTap});
    @override
    State<_RoomItem> createState() => _RoomItemState();
  }
  class _RoomItemState extends State<_RoomItem> {
    bool _hover = false;
    @override
    Widget build(BuildContext context) {
      final accent = widget.room.accentColor;
      Color bg = Colors.transparent;
      if (widget.selected) bg = kSurface2;
      else if (_hover) bg = kSurface;
      return MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit:  (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
            child: Row(children: [
              Container(width: 3, height: 3, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 9),
              Icon(widget.room.iconData, size: 15, color: widget.selected ? accent : kMuted2),
              const SizedBox(width: 9),
              Expanded(child: Text(widget.room.name,
                style: TextStyle(color: widget.selected ? kText : kText2, fontSize: 13, fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400),
                overflow: TextOverflow.ellipsis)),
              if ((widget.room.transcriptCount + widget.room.chatCount) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: kSurface3, borderRadius: BorderRadius.circular(4)),
                  child: Text('${widget.room.transcriptCount + widget.room.chatCount}',
                    style: const TextStyle(color: kMuted2, fontSize: 10)),
                ),
            ]),
          ),
        ),
      );
    }
  }

  class _SidebarBtn extends StatelessWidget {
    final IconData icon;
    final String label;
    final VoidCallback onTap;
    const _SidebarBtn({required this.icon, required this.label, required this.onTap});
    @override
    Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(children: [
          const SizedBox(width: 8),
          Icon(icon, size: 15, color: kMuted),
          const SizedBox(width: 9),
          Text(label, style: const TextStyle(color: kMuted2, fontSize: 13)),
        ]),
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────
  class _EmptyState extends StatelessWidget {
    final VoidCallback? onMenu;
    const _EmptyState({this.onMenu});
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: kBg,
        appBar: onMenu != null ? AppBar(
          backgroundColor: kBg,
          leading: IconButton(icon: const Icon(Icons.menu, size: 18, color: kMuted2), onPressed: onMenu),
          title: const Text('AgentBase'),
        ) : null,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 48, height: 48,
              decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
              child: const Icon(Icons.layers_outlined, size: 22, color: kMuted2)),
            const SizedBox(height: 14),
            const Text('Selectionne un espace', style: TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Choisis un espace dans le menu lateral', style: TextStyle(color: kMuted, fontSize: 13)),
          ]),
        ),
      );
    }
  }