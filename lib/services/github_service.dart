import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/room.dart';
import '../models/prompt.dart';
import '../models/message.dart';
import '../models/saved_prompt.dart';
import '../services/prefs_service.dart';

class AttachedFile {
  final String name;
  final Uint8List bytes;
  final bool isImage;
  AttachedFile({required this.name, required this.bytes, required this.isImage});
}

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

  Map<String, String> get _h => {
    'Authorization': 'token $_pat',
    'Accept': 'application/vnd.github.v3+json',
    'Content-Type': 'application/json',
  };

  Future<bool> validatePat() async {
    try {
      final r = await _client.get(Uri.parse('https://api.github.com/repos/$owner/$repo'), headers: _h);
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<List<Room>> fetchRooms() async {
    try {
      final r = await _client.get(Uri.parse('https://raw.githubusercontent.com/$owner/$repo/main/api/v1/rooms.json'));
      if (r.statusCode != 200) return [];
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      return (d['rooms'] as List<dynamic>? ?? []).map((j) => Room.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<String?> _raw(String path) async {
    try {
      final r = await _client.get(Uri.parse('https://raw.githubusercontent.com/$owner/$repo/main/$path'));
      return r.statusCode == 200 ? r.body : null;
    } catch (_) { return null; }
  }

  Future<String?> fetchContext(String roomId) => _raw('rooms/$roomId/context.md');
  Future<String?> fetchRules(String roomId) => _raw('rooms/$roomId/rules.md');

  Future<List<String>> listFiles(String roomId) async {
    try {
      final r = await _client.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo/contents/rooms/$roomId'),
        headers: _pat.isNotEmpty ? _h : {});
      if (r.statusCode != 200) return [];
      return (jsonDecode(r.body) as List<dynamic>).map((f) => f['name'] as String).toList();
    } catch (_) { return []; }
  }

  Future<String?> _fileSha(String path) async {
    try {
      final r = await _client.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$path'), headers: _h);
      if (r.statusCode != 200) return null;
      return (jsonDecode(r.body) as Map<String, dynamic>)['sha'] as String?;
    } catch (_) { return null; }
  }

  Future<void> pushRules(String roomId, String content) async {
    if (_pat.isEmpty) throw Exception('No PAT');
    final path = 'rooms/$roomId/rules.md';
    final sha = await _fileSha(path);
    final body = <String, dynamic>{'message': 'Update rules.md — $roomId', 'content': base64Encode(utf8.encode(content))};
    if (sha != null) body['sha'] = sha;
    final r = await _client.put(
      Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$path'),
      headers: _h, body: jsonEncode(body));
    if (r.statusCode != 200 && r.statusCode != 201) throw Exception('Push rules failed: ${r.statusCode}');
  }

  Future<List<ChatMessage>> fetchMessages(String roomId) async {
    final files = await listFiles(roomId);
    final results = <ChatMessage>[];
    await Future.wait(files.where((fn) => fn.startsWith('chat-') || fn.contains('agent')).map((fn) async {
      final c = await _raw('rooms/$roomId/$fn');
      if (c == null) return;
      results.add(ChatMessage.fromMarkdown(c, fn));
    }));
    results.sort((a, b) {
      final ta = a.createdAt, tb = b.createdAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.compareTo(tb);
    });
    return results;
  }

  Future<void> pushMessage(String roomId, String text) async {
    if (_pat.isEmpty) throw Exception('No PAT');
    final ts = DateTime.now().millisecondsSinceEpoch;
    final md = ['## Message utilisateur', '**Sender:** Moi', '**Created:** ${DateTime.now().toIso8601String()}', '', text].join('\n');
    final r = await _client.put(
      Uri.parse('https://api.github.com/repos/$owner/$repo/contents/rooms/$roomId/chat-$ts.md'),
      headers: _h, body: jsonEncode({'message': 'Chat — $roomId', 'content': base64Encode(utf8.encode(md))}));
    if (r.statusCode != 201) throw Exception('Push msg failed: ${r.statusCode}');
  }

  Future<List<AgentPrompt>> fetchPrompts(String roomId) async {
    final files = await listFiles(roomId);
    final results = <AgentPrompt>[];
    await Future.wait(files.where((fn) => fn.startsWith('prompt-')).map((fn) async {
      final c = await _raw('rooms/$roomId/$fn');
      if (c == null) return;
      results.add(AgentPrompt.fromMarkdown(c, fn));
    }));
    results.sort((a, b) {
      final ta = a.createdAt, tb = b.createdAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return results;
  }

  Future<void> pushPrompt(String roomId, AgentPrompt prompt) async {
    if (_pat.isEmpty) throw Exception('No PAT');
    final r = await _client.put(
      Uri.parse('https://api.github.com/repos/$owner/$repo/contents/rooms/$roomId/prompt-${prompt.id}.md'),
      headers: _h,
      body: jsonEncode({'message': 'Prompt ${prompt.name.isNotEmpty ? prompt.name : "#${prompt.number}"} — $roomId', 'content': base64Encode(utf8.encode(prompt.toMarkdown()))}));
    if (r.statusCode != 201) throw Exception('Push prompt failed: ${r.statusCode}');
  }

  /// Fetches the raw markdown content of a direct prompt by ID.
  Future<String?> fetchPromptContent(String id) => _raw('prompts/$id.md');

  /// Lists all direct prompts from the repo — used for cross-device sync.
  Future<List<SavedPrompt>> fetchRemotePrompts() async {
    if (_pat.isEmpty) return [];
    try {
      final r = await _client.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo/contents/prompts'),
        headers: _h);
      if (r.statusCode != 200) return [];

      final files = (jsonDecode(r.body) as List<dynamic>)
          .where((f) => (f['name'] as String).endsWith('.md'))
          .toList();

      final results = <SavedPrompt>[];
      await Future.wait(files.map((f) async {
        final fileName = f['name'] as String;
        final id = fileName.replaceAll('.md', '');
        final rawUrl = 'https://raw.githubusercontent.com/$owner/$repo/main/prompts/$fileName';
        final content = await _raw('prompts/$fileName');
        String promptName = id;
        DateTime? created;
        if (content != null) {
          for (final line in content.split('\n')) {
            if (line.startsWith('**Created:**')) {
              try { created = DateTime.parse(line.replaceFirst('**Created:**', '').trim()); } catch (_) {}
            }
          }
          // Extract first line of "## Contenu" as name
          final lines = content.split('\n');
          final idx = lines.indexWhere((l) => l.trim() == '## Contenu');
          if (idx != -1) {
            for (int i = idx + 1; i < lines.length && i < idx + 5; i++) {
              final l = lines[i].trim();
              if (l.isNotEmpty && !l.startsWith('#') && !l.startsWith('**') && l != '_(aucun texte)_') {
                promptName = l.split(' ').take(7).join(' ');
                if (promptName.length > 55) promptName = '${promptName.substring(0, 52)}...';
                break;
              }
            }
          }
        }
        results.add(SavedPrompt(
          id: id,
          name: promptName.isNotEmpty ? promptName : id,
          link: rawUrl,
          created: created ?? DateTime.fromMillisecondsSinceEpoch(
              int.tryParse(id) ?? DateTime.now().millisecondsSinceEpoch),
        ));
      }));

      results.sort((a, b) => b.created.compareTo(a.created));
      return results;
    } catch (_) { return []; }
  }

  /// Saves a direct prompt (text + attachments) to prompts/{id}.md
  Future<String> pushDirectPrompt(
    String id,
    String text,
    List<AttachedFile> files, {
    Room? room,
    String? roomContext,
  }) async {
    if (_pat.isEmpty) throw Exception('PAT non configure — va dans Parametres');

    // 1. Upload each attachment
    final attachLines = <String>[];
    for (final f in files) {
      final assetPath = 'prompts/assets/$id/${f.name}';
      final res = await _client.put(
        Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$assetPath'),
        headers: _h,
        body: jsonEncode({'message': 'Prompt $id — asset ${f.name}', 'content': base64Encode(f.bytes)}),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        final rawUrl = 'https://raw.githubusercontent.com/$owner/$repo/main/$assetPath';
        attachLines.add(f.isImage ? '![${f.name}]($rawUrl)' : '[${f.name}]($rawUrl)');
      }
    }

    // 2. Build clean markdown — no footer
    final now = DateTime.now().toIso8601String();
    final sb = StringBuffer();
    sb.writeln('# Prompt $id');
    sb.writeln();
    sb.writeln('**ID:** $id');
    sb.writeln('**Created:** $now');
    if (room != null) sb.writeln('**Room:** ${room.name} (`${room.id}`)');

    if (room != null && roomContext != null && roomContext.trim().isNotEmpty) {
      sb.writeln();
      sb.writeln('## Contexte — ${room.name}');
      sb.writeln();
      sb.writeln(roomContext.trim());
    }

    sb.writeln();
    sb.writeln('## Contenu');
    sb.writeln();
    sb.writeln(text.isNotEmpty ? text : '_(aucun texte)_');

    if (attachLines.isNotEmpty) {
      sb.writeln();
      sb.writeln('## Pieces jointes');
      sb.writeln();
      for (final l in attachLines) sb.writeln(l);
    }

    // 3. Push the prompt file
    final promptPath = 'prompts/$id.md';
    final r = await _client.put(
      Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$promptPath'),
      headers: _h,
      body: jsonEncode({'message': 'Prompt $id', 'content': base64Encode(utf8.encode(sb.toString()))}),
    );
    if (r.statusCode != 201 && r.statusCode != 200) {
      throw Exception('Sauvegarde echouee: ${r.statusCode}');
    }
    return 'https://raw.githubusercontent.com/$owner/$repo/main/$promptPath';
  }
}
