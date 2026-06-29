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

  String get _api => 'https://api.github.com/repos/$owner/$repo';
  String get _raw => 'https://raw.githubusercontent.com/$owner/$repo/main';

  Future<bool> validatePat() async {
    try {
      final r = await _client.get(Uri.parse('$_api'), headers: _h);
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Rooms ─────────────────────────────────────────────────────────────────

  Future<List<Room>> fetchRooms() async {
    for (final url in ['$_raw/api/v1/rooms.json', '$_raw/rooms.json', '$_raw/data/rooms.json']) {
      try {
        final r = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        if (r.statusCode == 200) {
          final data = jsonDecode(r.body);
          final list = data is List ? data : (data['rooms'] as List? ?? []);
          return list.map((e) => Room.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  Future<Map<String, dynamic>?> _roomsFileMeta() async {
    for (final p in ['api/v1/rooms.json', 'rooms.json', 'data/rooms.json']) {
      final r = await _client.get(Uri.parse('$_api/contents/$p'), headers: _h);
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        final content = utf8.decode(base64Decode((body['content'] as String).replaceAll('\n', '')));
        return {'sha': body['sha'], 'path': p, 'content': content};
      }
    }
    return null;
  }

  Future<Room> createRoom(String name, {String description = '', String color = '#6366f1'}) async {
    if (_pat.isEmpty) throw Exception('Token GitHub manquant');
    final id = 'room_${DateTime.now().millisecondsSinceEpoch}';
    final newRoom = Room(id: id, name: name, description: description, color: color);
    final meta = await _roomsFileMeta();
    List<dynamic> rooms = [];
    String? sha;
    String path = 'api/v1/rooms.json';
    if (meta != null) {
      sha = meta['sha'] as String;
      path = meta['path'] as String;
      final data = jsonDecode(meta['content'] as String);
      rooms = data is List ? data : (data['rooms'] as List? ?? []);
    }
    rooms.add(newRoom.toJson());
    final body = jsonEncode({
      'message': 'rooms: add $name',
      'content': base64Encode(utf8.encode(jsonEncode({'rooms': rooms}))),
      if (sha != null) 'sha': sha,
    });
    final r = await _client.put(Uri.parse('$_api/contents/$path'), headers: _h, body: body);
    if (r.statusCode != 200 && r.statusCode != 201) throw Exception('Création room échouée: ${r.statusCode}');
    return newRoom;
  }

  // ── Room detail ───────────────────────────────────────────────────────────

  Future<String?> _raw_(String path) async {
    try {
      final r = await _client.get(Uri.parse('$_raw/$path'));
      return r.statusCode == 200 ? r.body : null;
    } catch (_) { return null; }
  }

  Future<String?> fetchContext(String roomId) => _raw_('rooms/$roomId/context.md');
  Future<String?> fetchRules(String roomId) => _raw_('rooms/$roomId/rules.md');

  Future<List<String>> listFiles(String roomId) async {
    try {
      final r = await _client.get(
        Uri.parse('$_api/contents/rooms/$roomId'),
        headers: _pat.isNotEmpty ? _h : {});
      if (r.statusCode != 200) return [];
      return (jsonDecode(r.body) as List<dynamic>).map((f) => f['name'] as String).toList();
    } catch (_) { return []; }
  }

  Future<String?> _fileSha(String path) async {
    try {
      final r = await _client.get(Uri.parse('$_api/contents/$path'), headers: _h);
      if (r.statusCode != 200) return null;
      return (jsonDecode(r.body) as Map<String, dynamic>)['sha'] as String?;
    } catch (_) { return null; }
  }

  Future<void> pushRules(String roomId, String content) async {
    if (_pat.isEmpty) throw Exception('No PAT');
    final path = 'rooms/$roomId/rules.md';
    final sha = await _fileSha(path);
    final body = <String, dynamic>{
      'message': 'Update rules.md — $roomId',
      'content': base64Encode(utf8.encode(content)),
    };
    if (sha != null) body['sha'] = sha;
    final r = await _client.put(Uri.parse('$_api/contents/$path'), headers: _h, body: jsonEncode(body));
    if (r.statusCode != 200 && r.statusCode != 201) throw Exception('Push rules failed: ${r.statusCode}');
  }

  Future<List<ChatMessage>> fetchMessages(String roomId) async {
    final files = await listFiles(roomId);
    final results = <ChatMessage>[];
    await Future.wait(files.where((fn) => fn.startsWith('chat-') || fn.contains('agent')).map((fn) async {
      final c = await _raw_('rooms/$roomId/$fn');
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
    final md = ['## Message utilisateur', '**Sender:** Moi',
      '**Created:** ${DateTime.now().toIso8601String()}', '', text].join('\n');
    final r = await _client.put(
      Uri.parse('$_api/contents/rooms/$roomId/chat-$ts.md'),
      headers: _h,
      body: jsonEncode({'message': 'Chat — $roomId', 'content': base64Encode(utf8.encode(md))}));
    if (r.statusCode != 201) throw Exception('Push msg failed: ${r.statusCode}');
  }

  Future<List<AgentPrompt>> fetchPrompts(String roomId) async {
    final files = await listFiles(roomId);
    final results = <AgentPrompt>[];
    await Future.wait(files.where((fn) => fn.startsWith('prompt-')).map((fn) async {
      final c = await _raw_('rooms/$roomId/$fn');
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
      Uri.parse('$_api/contents/rooms/$roomId/prompt-${prompt.id}.md'),
      headers: _h,
      body: jsonEncode({
        'message': 'Prompt ${prompt.name.isNotEmpty ? prompt.name : "#${prompt.number}"} — $roomId',
        'content': base64Encode(utf8.encode(prompt.toMarkdown())),
      }));
    if (r.statusCode != 201) throw Exception('Push prompt failed: ${r.statusCode}');
  }

  // ── Direct prompts ────────────────────────────────────────────────────────

  Future<String?> fetchPromptContent(String id) => _raw_('prompts/$id.md');

  Future<List<SavedPrompt>> fetchRemotePrompts() async {
    if (_pat.isEmpty) return [];
    try {
      final r = await _client.get(
        Uri.parse('$_api/contents/prompts'), headers: _h);
      if (r.statusCode != 200) return [];
      final files = (jsonDecode(r.body) as List<dynamic>)
          .where((f) => (f['name'] as String).endsWith('.md'))
          .toList();
      final results = <SavedPrompt>[];
      await Future.wait(files.map((f) async {
        final fileName = f['name'] as String;
        final id = fileName.replaceAll('.md', '');
        final rawUrl = '$_raw/prompts/$fileName';
        final content = await _raw_('prompts/$fileName');
        String promptName = id;
        DateTime? created;
        if (content != null) {
          for (final line in content.split('\n')) {
            if (line.startsWith('**Created:**')) {
              try { created = DateTime.parse(line.replaceFirst('**Created:**', '').trim()); } catch (_) {}
            }
          }
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

  // ── Upload asset helper ───────────────────────────────────────────────────

  Future<String> _uploadAsset(String path, Uint8List bytes, {String? message}) async {
    String? sha;
    final check = await _client.get(Uri.parse('$_api/contents/$path'), headers: _h);
    if (check.statusCode == 200) sha = (jsonDecode(check.body) as Map<String, dynamic>)['sha'] as String?;
    final body = jsonEncode({
      'message': message ?? 'upload $path',
      'content': base64Encode(bytes),
      if (sha != null) 'sha': sha,
    });
    final res = await _client.put(Uri.parse('$_api/contents/$path'), headers: _h, body: body);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Upload failed: ${res.statusCode}');
    return '$_raw/$path';
  }

  // ── Push direct prompt with @mention inline images ────────────────────────

  Future<String> pushDirectPrompt(
    String id,
    String text,
    List<AttachedFile> files, {
    Room? room,
    String? roomContext,
  }) async {
    if (_pat.isEmpty) throw Exception('PAT non configuré — va dans Paramètres');

    // 1. Upload each attachment & build name→url map
    final urlMap = <String, String>{};
    for (final f in files) {
      final safeName = f.name.replaceAll(' ', '_');
      try {
        final url = await _uploadAsset('assets/prompts/$id/$safeName', f.bytes);
        urlMap[f.name] = url;
      } catch (_) {}
    }

    // 2. Parse @mentions and build inline MD
    final mentionPattern = RegExp(r'@(\w+)');
    final usedFiles = <String>{};

    String resolveUrl(String mention) {
      final needle = mention.toLowerCase();
      for (final entry in urlMap.entries) {
        final norm = entry.key.replaceAll(' ', '_').replaceAll('.', '_').toLowerCase();
        if (norm == needle || entry.key.toLowerCase() == needle) return entry.value;
        if (norm.startsWith(needle) || needle.startsWith(norm.split('_').first)) return entry.value;
      }
      return '';
    }

    String resolveFileName(String mention) {
      final needle = mention.toLowerCase();
      for (final key in urlMap.keys) {
        final norm = key.replaceAll(' ', '_').replaceAll('.', '_').toLowerCase();
        if (norm == needle || key.toLowerCase() == needle) return key;
        if (norm.startsWith(needle) || needle.startsWith(norm.split('_').first)) return key;
      }
      return mention;
    }

    final contentBuf = StringBuffer();
    int lastEnd = 0;
    for (final match in mentionPattern.allMatches(text)) {
      final beforeText = text.substring(lastEnd, match.start);
      if (beforeText.isNotEmpty) contentBuf.write(beforeText);
      final mentionKey = match.group(1)!;
      final url = resolveUrl(mentionKey);
      final fileName = resolveFileName(mentionKey);
      if (url.isNotEmpty) {
        if (usedFiles.contains(fileName)) {
          contentBuf.write('\n*[@$mentionKey — voir image ci-dessus]*\n');
        } else {
          usedFiles.add(fileName);
          contentBuf.write('\n\n![$fileName]($url)\n\n');
        }
      } else {
        contentBuf.write(match.group(0)!);
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) contentBuf.write(text.substring(lastEnd));
    final inlineContent = contentBuf.toString().trim();

    final nonMentioned = urlMap.entries.where((e) => !usedFiles.contains(e.key)).toList();

    // 3. Build MD with hidden metadata comment + visible content
    final now = DateTime.now();
    final sb = StringBuffer();
    sb.writeln('<!-- AGENTBASE_META');
    sb.writeln('ID: $id');
    sb.writeln('Created: ${now.toIso8601String()}');
    if (room != null) sb.writeln('Room: ${room.name} (${room.id})');
    sb.writeln('-->');
    sb.writeln();
    sb.writeln('## Contenu');
    sb.writeln();
    sb.writeln(inlineContent.isNotEmpty ? inlineContent : '_(aucun texte)_');
    if (nonMentioned.isNotEmpty) {
      sb.writeln();
      sb.writeln('## Pièces jointes');
      sb.writeln();
      for (final e in nonMentioned) {
        final isImg = ['png','jpg','jpeg','gif','webp']
            .contains(e.key.split('.').last.toLowerCase());
        sb.writeln(isImg ? '![${e.key}](${e.value})' : '[${e.key}](${e.value})');
      }
    }
    if (roomContext != null && roomContext.trim().isNotEmpty) {
      sb.writeln();
      sb.writeln('---');
      sb.writeln();
      sb.writeln('## Contexte — ${room?.name ?? "Global"}');
      sb.writeln();
      sb.writeln(roomContext.trim());
    }

    // 4. Push MD file
    final promptPath = 'prompts/$id.md';
    final body = jsonEncode({
      'message': 'Prompt $id',
      'content': base64Encode(utf8.encode(sb.toString())),
    });
    final r = await _client.put(Uri.parse('$_api/contents/$promptPath'), headers: _h, body: body);
    if (r.statusCode != 201 && r.statusCode != 200) {
      throw Exception('Sauvegarde échouée: ${r.statusCode}');
    }
    return '$_raw/$promptPath';
  }

  // ── OpenSpace ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> fetchOpenspaceImages() async {
    try {
      final r = await _client.get(
        Uri.parse('$_api/contents/openspace'),
        headers: _pat.isNotEmpty ? _h : {},
      );
      if (r.statusCode == 404) return [];
      if (r.statusCode != 200) throw Exception('Erreur ${r.statusCode}');
      final files = (jsonDecode(r.body) as List<dynamic>)
          .where((f) {
            final name = (f['name'] as String).toLowerCase();
            return name.endsWith('.png') || name.endsWith('.jpg') ||
                   name.endsWith('.jpeg') || name.endsWith('.gif') || name.endsWith('.webp');
          })
          .toList();
      return files.map((f) {
        final name = f['name'] as String;
        final slug = name.replaceAll(' ', '_').replaceAll(RegExp(r'\.[^.]+$'), '');
        return {
          'name': name,
          'mention': '@$slug',
          'rawUrl': '$_raw/openspace/$name',
          'sha': f['sha'] as String? ?? '',
        };
      }).toList();
    } catch (e) {
      throw Exception('Chargement OpenSpace : $e');
    }
  }

  Future<Map<String, dynamic>> uploadOpenspaceImage(
    String originalName,
    Uint8List bytes,
    List<dynamic> existingImages,
  ) async {
    if (_pat.isEmpty) throw Exception('Token GitHub manquant');

    final ext = originalName.contains('.')
        ? originalName.substring(originalName.lastIndexOf('.')).toLowerCase()
        : '.jpg';
    final baseName = originalName.contains('.')
        ? originalName.substring(0, originalName.lastIndexOf('.'))
        : originalName;
    final safeBase = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

    final existingNames = existingImages
        .map((f) => (f is Map ? f['name'] : '') as String)
        .toSet();

    String finalName = '$safeBase$ext';
    if (existingNames.contains(finalName)) {
      int counter = 1;
      while (existingNames.contains('${safeBase}_$counter$ext')) {
        counter++;
      }
      finalName = '${safeBase}_$counter$ext';
    }

    final path = 'openspace/$finalName';
    final body = jsonEncode({
      'message': 'OpenSpace: add $finalName',
      'content': base64Encode(bytes),
    });
    final r = await _client.put(Uri.parse('$_api/contents/$path'), headers: _h, body: body);
    if (r.statusCode != 201 && r.statusCode != 200) {
      throw Exception('Upload échoué : ${r.statusCode}');
    }
    final resp = jsonDecode(r.body) as Map<String, dynamic>;
    final sha = (resp['content'] as Map<String, dynamic>)['sha'] as String? ?? '';
    final slug = finalName.replaceAll(RegExp(r'\.[^.]+$'), '');
    return {
      'name': finalName,
      'mention': '@$slug',
      'rawUrl': '$_raw/$path',
      'sha': sha,
    };
  }

  Future<void> deleteOpenspaceImage(String name, String sha) async {
    if (_pat.isEmpty) throw Exception('Token GitHub manquant');
    final r = await _client.delete(
      Uri.parse('$_api/contents/openspace/$name'),
      headers: _h,
      body: jsonEncode({'message': 'OpenSpace: remove $name', 'sha': sha}),
    );
    if (r.statusCode != 200) throw Exception('Suppression échouée : ${r.statusCode}');
  }
}
