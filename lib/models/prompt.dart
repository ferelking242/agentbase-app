class PromptAttachment {
  final String type; // 'image' | 'audio' | 'file'
  final String name;
  final String path;
  final String? base64Data;
  final int? sizeBytes;

  PromptAttachment({
    required this.type,
    required this.name,
    required this.path,
    this.base64Data,
    this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'path': path,
    'size_bytes': sizeBytes,
  };
}

class AgentPrompt {
  final String id;
  final int number;
  final String roomId;
  final String text;
  final List<PromptAttachment> attachments;
  final DateTime createdAt;
  final String status; // 'pending' | 'read' | 'executing' | 'done'

  AgentPrompt({
    required this.id,
    required this.number,
    required this.roomId,
    required this.text,
    required this.attachments,
    required this.createdAt,
    this.status = 'pending',
  });

  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('## Prompt #$number — Room: $roomId');
    buf.writeln();
    buf.writeln('**ID:** $id');
    buf.writeln('**Created:** ${createdAt.toIso8601String()}');
    buf.writeln('**Status:** $status');
    buf.writeln();
    buf.writeln('### Instructions');
    buf.writeln();
    buf.writeln(text);
    buf.writeln();
    if (attachments.isNotEmpty) {
      buf.writeln('### Attachments');
      buf.writeln();
      for (final att in attachments) {
        buf.writeln('- **${att.type.toUpperCase()}** `${att.name}`');
        if (att.base64Data != null) {
          buf.writeln();
          buf.writeln('```base64');
          buf.writeln(att.base64Data);
          buf.writeln('```');
          buf.writeln();
        }
      }
    }
    buf.writeln();
    buf.writeln('---');
    buf.writeln('*Généré par AgentBase Mobile*');
    return buf.toString();
  }

  factory AgentPrompt.fromMarkdown(String id, String content) {
    final lines = content.split('\n');
    String text = '';
    String status = 'pending';
    int number = 0;
    
    bool inInstructions = false;
    final textLines = <String>[];
    
    for (final line in lines) {
      if (line.startsWith('## Prompt #')) {
        final match = RegExp(r'#(\d+)').firstMatch(line);
        if (match != null) number = int.tryParse(match.group(1) ?? '0') ?? 0;
      } else if (line.startsWith('**Status:**')) {
        status = line.replaceAll('**Status:**', '').trim();
      } else if (line.startsWith('### Instructions')) {
        inInstructions = true;
      } else if (line.startsWith('### Attachments') || line.startsWith('---')) {
        inInstructions = false;
      } else if (inInstructions) {
        textLines.add(line);
      }
    }
    text = textLines.join('\n').trim();

    return AgentPrompt(
      id: id,
      number: number,
      roomId: '',
      text: text,
      attachments: [],
      createdAt: DateTime.now(),
      status: status,
    );
  }
}
