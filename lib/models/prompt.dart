import 'dart:convert';

  class AgentPrompt {
    final String id, roomId, text, status;
    final int number;
    final DateTime? createdAt;
    final List<PromptAttachment> attachments;

    const AgentPrompt({
      required this.id, required this.number, required this.roomId,
      required this.text, required this.status,
      this.createdAt, this.attachments = const [],
    });

    factory AgentPrompt.fromMarkdown(String content, String filename) {
      int number = 0;
      String text = '', status = 'pending', id = '';
      DateTime? createdAt;
      final attachments = <PromptAttachment>[];
      final lines = content.split('\n');
      if (lines.isNotEmpty && lines[0].startsWith('## ')) {
        final m = RegExp(r'#(\d+)').firstMatch(lines[0]);
        if (m != null) number = int.tryParse(m.group(1)!) ?? 0;
      }
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i];
        if (line.startsWith('**ID:**')) {
          id = line.replaceFirst('**ID:**', '').trim();
        } else if (line.startsWith('**Created:**')) {
          try { createdAt = DateTime.parse(line.replaceFirst('**Created:**', '').trim()); } catch (_) {}
        } else if (line.startsWith('**Status:**')) {
          status = line.replaceFirst('**Status:**', '').trim();
        } else if (line.trim() == '### Instructions') {
          final buf = StringBuffer();
          i++;
          while (i < lines.length && !lines[i].startsWith('###')) {
            buf.writeln(lines[i]);
            i++;
          }
          text = buf.toString().trim();
          i--;
        } else if (line.trim() == '### Attachments') {
          i++;
          while (i < lines.length) {
            final l = lines[i];
            if (l.startsWith('- **')) {
              final typeM = RegExp(r'\*\*(\w+)\*\*').firstMatch(l);
              final nameM = RegExp(r'`([^`]+)`').firstMatch(l);
              final t = typeM?.group(1)?.toLowerCase() ?? 'file';
              final n = nameM?.group(1) ?? 'file';
              final b64 = StringBuffer();
              i++;
              if (i < lines.length && lines[i].startsWith('```')) {
                i++;
                while (i < lines.length && !lines[i].startsWith('```')) {
                  b64.write(lines[i].trim());
                  i++;
                }
              }
              final b64str = b64.toString();
              attachments.add(PromptAttachment(
                type: t, name: n, path: '',
                base64Data: b64str.isNotEmpty ? b64str : null,
                sizeBytes: b64str.isNotEmpty ? (b64str.length * 3 ~/ 4) : 0,
              ));
            }
            i++;
          }
        }
      }
      if (id.isEmpty) {
        final tsM = RegExp(r'\d{13}').firstMatch(filename);
        id = tsM?.group(0) ?? filename;
        if (createdAt == null && tsM != null) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(int.parse(tsM.group(0)!));
        }
      }
      return AgentPrompt(id: id, number: number, roomId: '', text: text, status: status, createdAt: createdAt, attachments: attachments);
    }

    String toMarkdown() {
      final buf = StringBuffer();
      buf.writeln('## Prompt #$number — Room: $roomId');
      buf.writeln();
      buf.writeln('**ID:** $id');
      buf.writeln('**Created:** ${createdAt?.toIso8601String() ?? DateTime.now().toIso8601String()}');
      buf.writeln('**Status:** $status');
      buf.writeln();
      buf.writeln('### Instructions');
      buf.writeln();
      buf.writeln(text);
      if (attachments.isNotEmpty) {
        buf.writeln();
        buf.writeln('### Attachments');
        for (final a in attachments) {
          buf.writeln();
          buf.writeln('- **${a.type.toUpperCase()}** `${a.name}`');
          if (a.base64Data != null && a.base64Data!.isNotEmpty) {
            buf.writeln();
            buf.writeln('```base64');
            buf.writeln(a.base64Data);
            buf.writeln('```');
          }
        }
      }
      return buf.toString();
    }
  }

  class PromptAttachment {
    final String type, name, path;
    final String? base64Data;
    final int sizeBytes;
    const PromptAttachment({required this.type, required this.name, required this.path, this.base64Data, required this.sizeBytes});
  }

  class AgentEntry {
    final String id, agentName, content, filename;
    final DateTime? createdAt;
    const AgentEntry({required this.id, required this.agentName, required this.content, required this.createdAt, required this.filename});

    factory AgentEntry.fromMarkdown(String content, String filename) {
      String agentName = 'Agent';
      for (final line in content.split('\n')) {
        if (line.startsWith('## ')) { agentName = line.substring(3).trim(); break; }
      }
      DateTime? ts;
      final tsM = RegExp(r'\d{13}').firstMatch(filename);
      if (tsM != null) ts = DateTime.fromMillisecondsSinceEpoch(int.parse(tsM.group(0)!));
      return AgentEntry(id: filename, agentName: agentName, content: content, createdAt: ts, filename: filename);
    }
  }

  abstract class TimelineEntry { DateTime? get timestamp; }
  class PromptEntry extends TimelineEntry { final AgentPrompt p; PromptEntry(this.p); @override DateTime? get timestamp => p.createdAt; }
  class AgentEntryItem extends TimelineEntry { final AgentEntry e; AgentEntryItem(this.e); @override DateTime? get timestamp => e.createdAt; }