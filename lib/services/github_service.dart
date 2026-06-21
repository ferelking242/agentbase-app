import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/room.dart';
import '../models/prompt.dart';

class GitHubService {
  static const String _baseApi = 'https://api.github.com';
  static const String _rawBase = 'https://raw.githubusercontent.com';
  static const String _owner = 'ferelking242';
  static const String _repo = 'agentbase';
  static const String _branch = 'main';

  String? _pat;

  void setPat(String pat) => _pat = pat.trim();
  String? get pat => _pat;
  bool get hasPat => _pat != null && _pat!.isNotEmpty;

  Map<String, String> get _headers => {
    'Accept': 'application/vnd.github.v3+json',
    'Content-Type': 'application/json',
    if (hasPat) 'Authorization': 'Bearer $_pat',
  };

  Future<List<Room>> fetchRooms() async {
    final url = '$_rawBase/$_owner/$_repo/$_branch/api/v1/rooms.json';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = jsonDecode(res.body);
    final list = data['rooms'] as List;
    return list.map((e) => Room.fromJson(e)).toList();
  }

  Future<List<AgentPrompt>> fetchRoomPrompts(String roomId) async {
    final url = '$_baseApi/repos/$_owner/$_repo/contents/rooms/$roomId';
    final res = await http.get(Uri.parse(url), headers: _headers);
    if (res.statusCode == 404) return [];
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final files = jsonDecode(res.body) as List;
    final prompts = <AgentPrompt>[];
    for (final file in files) {
      final name = file['name'] as String;
      if (name.endsWith('.md')) {
        try {
          final raw = await http.get(Uri.parse(file['download_url']));
          if (raw.statusCode == 200) {
            final prompt = AgentPrompt.fromMarkdown(name, raw.body);
            prompts.add(prompt);
          }
        } catch (_) {}
      }
    }
    prompts.sort((a, b) => b.number.compareTo(a.number));
    return prompts;
  }

  Future<void> pushPrompt(String roomId, AgentPrompt prompt) async {
    if (!hasPat) throw Exception('PAT requis pour écrire');
    final filename = 'prompt-${prompt.id}.md';
    final path = 'rooms/$roomId/$filename';
    final url = '$_baseApi/repos/$_owner/$_repo/contents/$path';
    final content = base64Encode(utf8.encode(prompt.toMarkdown()));

    String? sha;
    final check = await http.get(Uri.parse(url), headers: _headers);
    if (check.statusCode == 200) {
      sha = (jsonDecode(check.body))['sha'];
    }

    final body = jsonEncode({
      'message': '📱 Prompt #${prompt.number} — room/$roomId',
      'content': content,
      'branch': _branch,
      if (sha != null) 'sha': sha,
    });

    final res = await http.put(Uri.parse(url), headers: _headers, body: body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Push failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<bool> validatePat() async {
    if (!hasPat) return false;
    try {
      final res = await http.get(
        Uri.parse('$_baseApi/repos/$_owner/$_repo'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchRepoStats() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseApi/repos/$_owner/$_repo'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {};
  }
}
