import 'dart:convert';
  import 'package:http/http.dart' as http;
  import '../models/room.dart';
  import '../models/prompt.dart';
  import '../models/message.dart';
  import '../services/prefs_service.dart';

  class GitHubService {
    final String owner, repo;
    String _pat = '';
    final http.Client _client;
    GitHubService({this.owner='ferelking242', this.repo='agentbase', http.Client? client}) : _client = client ?? http.Client();

    bool get hasPat => _pat.isNotEmpty;
    void setPat(String p) => _pat = p;
    Future<bool> init() async { final p = await PrefsService.getPat(); if (p!=null&&p.isNotEmpty){_pat=p;return true;} return false; }

    Map<String,String> get _h => {'Authorization':'token $_pat','Accept':'application/vnd.github.v3+json','Content-Type':'application/json'};
    Future<bool> validatePat() async { try { final r=await _client.get(Uri.parse('https://api.github.com/repos/$owner/$repo'),headers:_h); return r.statusCode==200; } catch(_){return false;} }

    Future<List<Room>> fetchRooms() async {
      try {
        final r=await _client.get(Uri.parse('https://raw.githubusercontent.com/$owner/$repo/main/api/v1/rooms.json'));
        if(r.statusCode!=200) return [];
        final d=jsonDecode(r.body) as Map<String,dynamic>;
        return (d['rooms'] as List<dynamic>? ?? []).map((j)=>Room.fromJson(j as Map<String,dynamic>)).toList();
      } catch(_){ return []; }
    }

    Future<String?> _raw(String path) async {
      try { final r=await _client.get(Uri.parse('https://raw.githubusercontent.com/$owner/$repo/main/$path')); return r.statusCode==200?r.body:null; } catch(_){return null;}
    }

    Future<String?> fetchContext(String roomId) => _raw('rooms/$roomId/context.md');
    Future<String?> fetchRules(String roomId) => _raw('rooms/$roomId/rules.md');

    Future<List<String>> listFiles(String roomId) async {
      try {
        final r=await _client.get(Uri.parse('https://api.github.com/repos/$owner/$repo/contents/rooms/$roomId'),headers:_pat.isNotEmpty?_h:{});
        if(r.statusCode!=200) return [];
        return (jsonDecode(r.body) as List<dynamic>).map((f)=>f['name'] as String).toList();
      } catch(_){return [];}
    }

    Future<String?> _fileSha(String path) async {
      try {
        final r=await _client.get(Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$path'),headers:_h);
        if(r.statusCode!=200) return null;
        return (jsonDecode(r.body) as Map<String,dynamic>)['sha'] as String?;
      } catch(_){return null;}
    }

    Future<void> pushRules(String roomId, String content) async {
      if(_pat.isEmpty) throw Exception('No PAT');
      final path='rooms/$roomId/rules.md';
      final sha=await _fileSha(path);
      final body = <String,dynamic>{'message':'Update rules.md — $roomId','content':base64Encode(utf8.encode(content))};
      if(sha!=null) body['sha']=sha;
      final r=await _client.put(Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$path'),headers:_h,body:jsonEncode(body));
      if(r.statusCode!=200&&r.statusCode!=201) throw Exception('Push rules failed: ${r.statusCode}');
    }

    Future<List<ChatMessage>> fetchMessages(String roomId) async {
      final files=await listFiles(roomId);
      final results=<ChatMessage>[];
      await Future.wait(files.where((fn)=>fn.startsWith('chat-')||fn.contains('agent')).map((fn) async {
        final c=await _raw('rooms/$roomId/$fn');
        if(c==null) return;
        results.add(ChatMessage.fromMarkdown(c,fn));
      }));
      results.sort((a,b){ final ta=a.createdAt,tb=b.createdAt; if(ta==null&&tb==null)return 0; if(ta==null)return 1; if(tb==null)return -1; return ta.compareTo(tb); });
      return results;
    }

    Future<void> pushMessage(String roomId, String text) async {
      if(_pat.isEmpty) throw Exception('No PAT');
      final ts=DateTime.now().millisecondsSinceEpoch;
      final c=ChatMessage(id:'chat-$ts.md',sender:'Moi',content:text,isUser:true,createdAt:DateTime.fromMillisecondsSinceEpoch(ts));
      final md=['## Message utilisateur','**Sender:** Moi','**Created:** ${DateTime.now().toIso8601String()}','',text].join('\n');
      final r=await _client.put(Uri.parse('https://api.github.com/repos/$owner/$repo/contents/rooms/$roomId/chat-$ts.md'),
        headers:_h,body:jsonEncode({'message':'Chat — $roomId','content':base64Encode(utf8.encode(md))}));
      if(r.statusCode!=201) throw Exception('Push msg failed: ${r.statusCode}');
    }

    Future<List<AgentPrompt>> fetchPrompts(String roomId) async {
      final files=await listFiles(roomId);
      final results=<AgentPrompt>[];
      await Future.wait(files.where((fn)=>fn.startsWith('prompt-')).map((fn) async {
        final c=await _raw('rooms/$roomId/$fn');
        if(c==null) return;
        results.add(AgentPrompt.fromMarkdown(c,fn));
      }));
      results.sort((a,b){ final ta=a.createdAt,tb=b.createdAt; if(ta==null&&tb==null)return 0; if(ta==null)return 1; if(tb==null)return -1; return tb.compareTo(ta); });
      return results;
    }

    Future<void> pushPrompt(String roomId, AgentPrompt prompt) async {
      if(_pat.isEmpty) throw Exception('No PAT');
      final r=await _client.put(Uri.parse('https://api.github.com/repos/$owner/$repo/contents/rooms/$roomId/prompt-${prompt.id}.md'),
        headers:_h,body:jsonEncode({'message':'Prompt ${prompt.name.isNotEmpty?prompt.name:"#${prompt.number}"} — $roomId','content':base64Encode(utf8.encode(prompt.toMarkdown()))}));
      if(r.statusCode!=201) throw Exception('Push prompt failed: ${r.statusCode}');
    }
  }