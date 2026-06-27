import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/room.dart';
import '../models/saved_prompt.dart';
import '../screens/home_screen.dart';

class GitHubService {
  final String token;
  final String owner;
  final String repo;
  final String branch;

  GitHubService({
    required this.token,
    required this.owner,
    required this.repo,
    this.branch = 'main',
  });

  Map<String, String> get _headers => {
    'Authorization': 'token $token',
    'Accept': 'application/vnd.github.v3+json',
    'Content-Type': 'application/json',
  };

  String get _apiBase => 'https://api.github.com/repos/$owner/$repo';
  String get _rawBase => 'https://raw.githubusercontent.com/$owner/$repo/$branch';

  // ── Upload a single asset ─────────────────────────────────────────────────
  Future<String> uploadAsset(String path, Uint8List bytes, {String? message}) async {
    final b64 = base64Encode(bytes);
    String? sha;
    final check = await http.get(Uri.parse('$_apiBase/contents/$path'), headers: _headers);
    if (check.statusCode == 200) sha = jsonDecode(check.body)['sha'];

    final body = jsonEncode({'message': message ?? 'upload $path', 'content': b64, 'branch': branch, if (sha != null) 'sha': sha});
    final res = await http.put(Uri.parse('$_apiBase/contents/$path'), headers: _headers, body: body);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Upload failed: ${res.statusCode}');
    return '$_rawBase/$path';
  }

  // ── Push a direct prompt MD to GitHub ────────────────────────────────────
  Future<String> pushDirectPrompt(
    String id,
    String text,
    List<AttachedFile> files, {
    Room? room,
    String? roomContext,
  }) async {
    if (token.isEmpty) throw Exception('Token GitHub manquant');

    final now = DateTime.now();
    final dateStr = '${now.year}-${_p(now.month)}-${_p(now.day)}';
    final timeStr = '${_p(now.hour)}:${_p(now.minute)}:${_p(now.second)}';
    final roomName = room?.name ?? 'Global';
    final roomId = room?.id ?? 'global';

    // Upload all assets first and build name → rawUrl map
    final urlMap = <String, String>{}; // originalName → url
    for (final f in files) {
      final safeName = f.name.replaceAll(' ', '_');
      final assetPath = 'assets/prompts/$id/$safeName';
      try {
        final url = await uploadAsset(assetPath, f.bytes);
        urlMap[f.name] = url;
      } catch (_) {}
    }

    // Parse @mentions in text and build inline MD content
    final mentionPattern = RegExp(r'@(\w+)');
    final usedFiles = <String>{};

    String _resolveUrl(String mention) {
      final needle = mention.toLowerCase();
      for (final entry in urlMap.entries) {
        final normalized = entry.key.replaceAll(' ', '_').replaceAll('.', '_').toLowerCase();
        if (normalized == needle || entry.key.toLowerCase() == needle) return entry.value;
        if (normalized.startsWith(needle) || needle.startsWith(normalized.split('_').first)) return entry.value;
      }
      return '';
    }

    String _resolveFileName(String mention) {
      final needle = mention.toLowerCase();
      for (final key in urlMap.keys) {
        final normalized = key.replaceAll(' ', '_').replaceAll('.', '_').toLowerCase();
        if (normalized == needle || key.toLowerCase() == needle) return key;
        if (normalized.startsWith(needle) || needle.startsWith(normalized.split('_').first)) return key;
      }
      return mention;
    }

    // Build content with inline images at @mention positions
    final contentBuf = StringBuffer();
    int lastEnd = 0;
    for (final match in mentionPattern.allMatches(text)) {
      final beforeText = text.substring(lastEnd, match.start);
      if (beforeText.isNotEmpty) contentBuf.write(beforeText);

      final mentionKey = match.group(1)!;
      final url = _resolveUrl(mentionKey);
      final fileName = _resolveFileName(mentionKey);

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

    // Non-mentioned files → attachments section
    final nonMentioned = urlMap.entries.where((e) => !usedFiles.contains(e.key)).toList();

    // Build final MD (metadata in hidden comment, invisible in rendered view)
    final sb = StringBuffer();
    sb.writeln('<!-- AGENTBASE_META');
    sb.writeln('ID: $id');
    sb.writeln('Created: $dateStr $timeStr');
    sb.writeln('Room: $roomName ($roomId)');
    sb.writeln('-->');
    sb.writeln();
    sb.writeln('# Prompt');
    sb.writeln();
    if (inlineContent.isNotEmpty) {
      sb.writeln(inlineContent);
      sb.writeln();
    }
    if (nonMentioned.isNotEmpty) {
      sb.writeln('## Pièces jointes');
      sb.writeln();
      for (final e in nonMentioned) {
        final isImage = e.key.toLowerCase().endsWith('.png') ||
            e.key.toLowerCase().endsWith('.jpg') ||
            e.key.toLowerCase().endsWith('.jpeg') ||
            e.key.toLowerCase().endsWith('.gif') ||
            e.key.toLowerCase().endsWith('.webp');
        if (isImage) {
          sb.writeln('![${e.key}](${e.value})');
        } else {
          sb.writeln('[${e.key}](${e.value})');
        }
        sb.writeln();
      }
    }
    if (roomContext != null && roomContext.isNotEmpty) {
      sb.writeln('---');
      sb.writeln();
      sb.writeln('## Contexte Room: $roomName');
      sb.writeln();
      sb.writeln(roomContext);
    }

    final mdContent = sb.toString();
    final mdPath = 'prompts/$id.md';
    final mdUrl = await uploadAsset(mdPath, Uint8List.fromList(utf8.encode(mdContent)), message: 'prompt: $id');
    return 'https://github.com/$owner/$repo/blob/$branch/$mdPath';
  }

  // ── Fetch rooms ───────────────────────────────────────────────────────────
  Future<List<Room>> fetchRooms() async {
    // Try primary URL first, then fallback
    final urls = [
      '$_rawBase/api/v1/rooms.json',
      '$_rawBase/rooms.json',
      '$_rawBase/data/rooms.json',
    ];
    for (final url in urls) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final list = data is List ? data : (data['rooms'] as List? ?? []);
          return list.map((e) => Room.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  // ── Fetch raw rooms JSON with SHA (for updates) ───────────────────────────
  Future<Map<String, dynamic>?> _fetchRoomsRaw() async {
    final paths = ['api/v1/rooms.json', 'rooms.json', 'data/rooms.json'];
    for (final p in paths) {
      final res = await http.get(Uri.parse('$_apiBase/contents/$p'), headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return {'sha': body['sha'], 'path': p, 'content': utf8.decode(base64Decode((body['content'] as String).replaceAll('\n', '')))};
      }
    }
    return null;
  }

  // ── Create a new room ─────────────────────────────────────────────────────
  Future<Room> createRoom(String name, {String description = '', String color = '#6366f1'}) async {
    if (token.isEmpty) throw Exception('Token GitHub manquant');
    final id = 'room_${DateTime.now().millisecondsSinceEpoch}';
    final newRoom = Room(id: id, name: name, description: description, color: color);

    final existing = await _fetchRoomsRaw();
    List<dynamic> rooms = [];
    String? sha;
    String path = 'api/v1/rooms.json';

    if (existing != null) {
      sha = existing['sha'] as String;
      path = existing['path'] as String;
      final data = jsonDecode(existing['content'] as String);
      rooms = data is List ? data : (data['rooms'] as List? ?? []);
    }
    rooms.add(newRoom.toJson());

    final newContent = jsonEncode({'rooms': rooms});
    final b64 = base64Encode(utf8.encode(newContent));
    final body = jsonEncode({'message': 'rooms: add $name', 'content': b64, 'branch': branch, if (sha != null) 'sha': sha});
    final res = await http.put(Uri.parse('$_apiBase/contents/$path'), headers: _headers, body: body);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Création room échouée: ${res.statusCode}');
    return newRoom;
  }

  // ── Fetch room context file ───────────────────────────────────────────────
  Future<String?> fetchContext(String roomId) async {
    final paths = [
      'rooms/$roomId/context.md',
      'api/v1/rooms/$roomId/context.md',
      'rooms/$roomId.md',
    ];
    for (final p in paths) {
      try {
        final res = await http.get(Uri.parse('$_rawBase/$p')).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) return res.body;
      } catch (_) {}
    }
    return null;
  }

  // ── Fetch prompt content from GitHub ─────────────────────────────────────
  Future<String?> fetchPromptContent(String id) async {
    final urls = [
      '$_rawBase/prompts/$id.md',
      '$_rawBase/prompts/$id/index.md',
    ];
    for (final url in urls) {
      try {
        final res = await http.get(Uri.parse(url), headers: {'Authorization': 'token $token'}).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) return res.body;
      } catch (_) {}
    }
    return null;
  }

  // ── Sync prompts list ─────────────────────────────────────────────────────
  Future<List<SavedPrompt>> syncPrompts() async {
    if (token.isEmpty) throw Exception('Token GitHub manquant');
    final res = await http.get(Uri.parse('$_apiBase/contents/prompts'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 404) return [];
    if (res.statusCode != 200) throw Exception('Sync failed: ${res.statusCode}');
    final files = jsonDecode(res.body) as List;
    final prompts = <SavedPrompt>[];
    int number = files.length;
    for (final f in files.reversed) {
      if (f['name'].toString().endsWith('.md')) {
        final id = f['name'].toString().replaceAll('.md', '');
        final link = 'https://github.com/$owner/$repo/blob/$branch/prompts/${f['name']}';
        prompts.add(SavedPrompt(id: id, name: id, link: link, created: DateTime.now(), number: number--));
      }
    }
    return prompts;
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}
