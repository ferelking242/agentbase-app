import 'dart:convert';
  import 'package:http/http.dart' as http;
  import '../models/room.dart';
  import '../models/prompt.dart';
  import '../services/prefs_service.dart';

  class GitHubService {
    final String owner, repo;
    String _pat = '';
    final http.Client _client;

    GitHubService({this.owner = 'ferelking242', this.repo = 'agentbase', http.Client? client})
      : _client = client ?? http.Client();

    bool get hasPat => _pat.isNotEmpty;
    void setPat(String p) => _pat = p;

    Future<bool> init() async {
      final p = await PrefsService.getPat();
      if (p != null && p.isNotEmpty) { _pat = p; return true; }
      return false;
    }

    Map<String, String> get _auth => {'Authorization': 'token $_pat', 'Accept': 'application/vnd.github.v3+json', 'Content-Type': 'application/json'};

    Future<bool> validatePat() async {
      if (_pat.isEmpty) return false;
      try { final r = await _client.get(Uri.parse('https://api.github.com/repos/$owner/$repo'), headers: _auth); return r.statusCode == 200; }
      catch (_) { return false; }
    }

    Future<List<Room>> fetchRooms() async {
      try {
        final r = await _client.get(Uri.parse('https://raw.githubusercontent.com/$owner/$repo/main/api/v1/rooms.json'));
        if (r.statusCode != 200) return [];
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return (data['rooms'] as List<dynamic>? ?? []).map((j) => Room.fromJson(j as Map<String, dynamic>)).toList();
      } catch (_) { return []; }
    }

    Future<String?> _raw(String roomId, String filename) async {
      try {
        final r = await _client.get(Uri.parse('https://raw.githubusercontent.com/$owner/$repo/main/rooms/$roomId/$filename'));
        return r.statusCode == 200 ? r.body : null;
      } catch (_) { return null; }
    }

    Future<String?> fetchContext(String roomId) => _raw(roomId, 'context.md');
    Future<String?> fetchRules(String roomId) => _raw(roomId, 'rules.md');

    Future<List<String>> listFiles(String roomId) async {
      try {
        final headers = _pat.isNotEmpty ? _auth : <String, String>{};
        final r = await _client.get(Uri.parse('https://api.github.com/repos/$owner/$repo/contents/rooms/$roomId'), headers: headers);
        if (r.statusCode != 200) return [];
        return (jsonDecode(r.body) as List<dynamic>).map((f) => f['name'] as String).toList();
      } catch (_) { return []; }
    }

    Future<List<TimelineEntry>> fetchTimeline(String roomId) async {
      final files = await listFiles(roomId);
      final results = <TimelineEntry>[];
      await Future.wait(files.map((fn) async {
        final c = await _raw(roomId, fn);
        if (c == null) return;
        if (fn.startsWith('prompt-')) results.add(PromptEntry(AgentPrompt.fromMarkdown(c, fn)));
        else if (fn.contains('agent') || fn.contains('status')) results.add(AgentEntryItem(AgentEntry.fromMarkdown(c, fn)));
      }));
      results.sort((a, b) {
        final ta = a.timestamp, tb = b.timestamp;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      return results;
    }

    Future<void> pushPrompt(String roomId, AgentPrompt prompt) async {
      if (_pat.isEmpty) throw Exception('No PAT');
      final content = base64Encode(utf8.encode(prompt.toMarkdown()));
      final r = await _client.put(
        Uri.parse('https://api.github.com/repos/$owner/$repo/contents/rooms/$roomId/prompt-${prompt.id}.md'),
        headers: _auth,
        body: jsonEncode({'message': 'Prompt #${prompt.number} — room/$roomId', 'content': content}),
      );
      if (r.statusCode != 201) throw Exception('Push failed: ${r.statusCode}');
    }
  }