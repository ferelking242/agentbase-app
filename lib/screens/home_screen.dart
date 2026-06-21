import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import '../models/room.dart';
  import '../services/github_service.dart';
  import '../services/prefs_service.dart';
  import '../theme.dart';
  import '../widgets/room_card.dart';
  import 'room_detail_screen.dart';
  import 'settings_screen.dart';

  class HomeScreen extends StatefulWidget {
    const HomeScreen({super.key});
    @override
    State<HomeScreen> createState() => _HomeScreenState();
  }

  class _HomeScreenState extends State<HomeScreen> {
    final _github = GitHubService();
    final _scaffoldKey = GlobalKey<ScaffoldState>();
    List<Room> _rooms = [];
    bool _loading = true;
    String? _error;
    bool _patOk = false;
    String? _activeRoomId;

    @override
    void initState() {
      super.initState();
      _init();
    }

    Future<void> _init() async {
      final pat = await PrefsService.getPat();
      if (pat != null && pat.isNotEmpty) {
        _github.setPat(pat);
        _github.validatePat().then((ok) {
          if (mounted) setState(() => _patOk = ok);
        });
      }
      _loadRooms();
    }

    Future<void> _loadRooms() async {
      setState(() { _loading = true; _error = null; });
      try {
        final rooms = await _github.fetchRooms();
        if (mounted) setState(() { _rooms = rooms; _loading = false; });
      } catch (e) {
        if (mounted) setState(() { _error = e.toString(); _loading = false; });
      }
    }

    void _openRoom(Room room) {
      setState(() => _activeRoomId = room.id);
      Navigator.push(context,
        MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room, github: _github)),
      ).then((_) => setState(() => _activeRoomId = null));
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: kBg,
        drawer: _buildDrawer(),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      );
    }

    Widget _buildTopBar() {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: kBg,
          border: Border(bottom: BorderSide(color: kBorder, width: 0.5)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: kBorder),
                ),
                child: const Icon(Icons.menu, size: 17, color: kMuted2),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kAccent, kPurple]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text('A', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('AgentBase', style: TextStyle(
                  color: kText, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              ],
            ),
            const Spacer(),
            // Connection dot
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: (_patOk ? kGreen : kMuted).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (_patOk ? kGreen : kMuted).withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(
                      color: _patOk ? kGreen : kMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(_patOk ? 'Connecté' : 'Non connecté',
                    style: TextStyle(
                      color: _patOk ? kGreen : kMuted,
                      fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildDrawer() {
      return Drawer(
        backgroundColor: kBg2,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [kAccent, kPurple]),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Center(
                        child: Text('AB', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AgentBase', style: TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('v2.0', style: TextStyle(color: kMuted, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(height: 0.5, color: kBorder),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Text('Rooms', style: const TextStyle(
                      color: kMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.08)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () { Navigator.pop(context); _loadRooms(); },
                      child: const Icon(Icons.refresh, size: 14, color: kMuted),
                    ),
                  ],
                ),
              ),
              // Room list in drawer
              Expanded(
                child: _loading
                  ? const Center(child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: kAccent, strokeWidth: 1.5)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: _rooms.map((room) {
                        Color accent;
                        try {
                          final h = room.color.replaceAll('#', '');
                          accent = Color(int.parse('FF$h', radix: 16));
                        } catch (_) { accent = kAccent; }
                        final isActive = _activeRoomId == room.id;
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _openRoom(room);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: isActive ? accent.withOpacity(0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(room.name, style: TextStyle(
                                    color: isActive ? accent : kText2,
                                    fontSize: 13,
                                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                  )),
                                ),
                                Text(room.icon, style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
              ),
              const Divider(color: kBorder, height: 1),
              // Settings
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => SettingsScreen(github: _github)));
                },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 16, color: kMuted2),
                      SizedBox(width: 10),
                      Text('Paramètres', style: TextStyle(color: kText2, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildBody() {
      if (_loading) {
        return const Center(child: CircularProgressIndicator(color: kAccent));
      }
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 36, color: kMuted),
                const SizedBox(height: 12),
                const Text('Impossible de charger', style: TextStyle(color: kText2, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(_error!, style: const TextStyle(color: kMuted, fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _loadRooms,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(9)),
                    child: const Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return RefreshIndicator(
        color: kAccent,
        backgroundColor: kSurface,
        onRefresh: _loadRooms,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${_rooms.length} room${_rooms.length > 1 ? "s" : ""}',
              style: const TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.05)),
            const SizedBox(height: 12),
            ..._rooms.map((room) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RoomCard(room: room, onTap: () => _openRoom(room)),
            )),
            const SizedBox(height: 20),
          ],
        ),
      );
    }
  }