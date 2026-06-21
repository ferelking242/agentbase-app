import 'package:flutter/material.dart';
import '../models/room.dart';
import '../services/github_service.dart';
import '../theme.dart';
import '../widgets/room_card.dart';
import 'room_detail_screen.dart';

class RoomsScreen extends StatefulWidget {
  final GitHubService github;
  const RoomsScreen({super.key, required this.github});
  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List<Room> _rooms = [];
  List<Room> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rooms = await widget.github.fetchRooms();
      if (mounted) setState(() { _rooms = rooms; _filtered = rooms; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _rooms
          : _rooms.where((r) =>
              r.name.toLowerCase().contains(q) ||
              r.description.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg2,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: kBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 14, color: kText2),
          ),
        ),
        title: const Text('Rooms'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kBorder),
        ),
        actions: [
          GestureDetector(
            onTap: _load,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kBorder),
              ),
              child: const Icon(Icons.refresh, size: 16, color: kMuted2),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kAccent))
                : _error != null
                    ? _buildError()
                    : _buildGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: kBg2,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: kText, fontSize: 13.5),
          decoration: const InputDecoration(
            hintText: 'Rechercher une room…',
            hintStyle: TextStyle(color: kMuted, fontSize: 13.5),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, size: 16, color: kMuted),
            contentPadding: EdgeInsets.symmetric(vertical: 11),
            isDense: true,
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: kMuted),
            const SizedBox(height: 12),
            const Text('Impossible de charger les rooms', style: TextStyle(
              color: kText2, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(color: kMuted, fontSize: 11.5),
              textAlign: TextAlign.center),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: kAccent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text('Réessayer', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔍', style: TextStyle(fontSize: 32)),
            SizedBox(height: 12),
            Text('Aucune room trouvée', style: TextStyle(color: kMuted2, fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: kAccent,
      backgroundColor: kSurface,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${_filtered.length} room${_filtered.length > 1 ? "s" : ""}',
            style: const TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...List.generate(_filtered.length, (i) {
            final room = _filtered[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RoomCard(
                room: room,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => RoomDetailScreen(room: room, github: widget.github),
                )),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
