import 'dart:convert';
  import 'package:flutter/material.dart';
  import '../models/prompt.dart';
  import '../theme.dart';

  class PromptTile extends StatelessWidget {
    final AgentPrompt prompt;
    const PromptTile({super.key, required this.prompt});

    Color _sc() {
      switch (prompt.status.toLowerCase()) {
        case 'done': case 'executed': return kGreen;
        case 'executing': case 'running': return kYellow;
        case 'read': return kAccent2;
        default: return kMuted;
      }
    }
    String _sl() {
      switch (prompt.status.toLowerCase()) {
        case 'done': case 'executed': return 'Exécuté';
        case 'executing': case 'running': return 'En cours';
        case 'read': return 'Lu';
        default: return 'En attente';
      }
    }
    IconData _si() {
      switch (prompt.status.toLowerCase()) {
        case 'done': case 'executed': return Icons.check_circle_outline;
        case 'executing': case 'running': return Icons.sync;
        case 'read': return Icons.visibility_outlined;
        default: return Icons.radio_button_unchecked;
      }
    }

    @override
    Widget build(BuildContext context) {
      final color = _sc();
      final ts = prompt.createdAt;
      final timeStr = ts != null
        ? '${ts.day.toString().padLeft(2,"0")}/${ts.month.toString().padLeft(2,"0")} ${ts.hour.toString().padLeft(2,"0")}:${ts.minute.toString().padLeft(2,"0")}'
        : '';
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _detail(context),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text('#${prompt.number}',
                        style: const TextStyle(color: kAccent2, fontSize: 10.5, fontWeight: FontWeight.w700, fontFamily: 'Courier')),
                    ),
                    const SizedBox(width: 8),
                    if (timeStr.isNotEmpty) Text(timeStr, style: const TextStyle(color: kMuted, fontSize: 10.5)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_si(), size: 11, color: color),
                        const SizedBox(width: 4),
                        Text(_sl(), style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                  if (prompt.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(prompt.text.length > 160 ? '${prompt.text.substring(0,160)}…' : prompt.text,
                      style: const TextStyle(color: kText2, fontSize: 13, height: 1.5)),
                  ],
                  if (prompt.attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, children: prompt.attachments.map((a) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(a.type == 'image' ? Icons.image_outlined : a.type == 'audio' ? Icons.audiotrack_outlined : Icons.attach_file,
                          size: 11, color: kMuted2),
                        const SizedBox(width: 4),
                        Text(a.name.length > 18 ? '${a.name.substring(0,18)}…' : a.name,
                          style: const TextStyle(color: kMuted2, fontSize: 10.5)),
                      ]),
                    )).toList()),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    void _detail(BuildContext context) {
      showModalBottomSheet(
        context: context,
        backgroundColor: kBg2, isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => DraggableScrollableSheet(
          expand: false, initialChildSize: 0.6, maxChildSize: 0.92, minChildSize: 0.3,
          builder: (_, ctrl) => _Sheet(prompt: prompt, ctrl: ctrl),
        ),
      );
    }
  }

  class _Sheet extends StatelessWidget {
    final AgentPrompt prompt;
    final ScrollController ctrl;
    const _Sheet({required this.prompt, required this.ctrl});

    Color _sc() {
      switch (prompt.status.toLowerCase()) {
        case 'done': case 'executed': return kGreen;
        case 'executing': case 'running': return kYellow;
        default: return kMuted;
      }
    }

    @override
    Widget build(BuildContext context) {
      final color = _sc();
      return Column(children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: kBorder2, borderRadius: BorderRadius.circular(2))),
        Expanded(child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: kAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
                child: Text('Prompt #${prompt.number}',
                  style: const TextStyle(color: kAccent2, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Courier')),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
                child: Text(prompt.status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 16),
            if (prompt.text.isNotEmpty) ...[
              const Text('Instructions', style: TextStyle(color: kMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.08)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
                child: Text(prompt.text, style: const TextStyle(color: kText2, fontSize: 13.5, height: 1.6)),
              ),
              const SizedBox(height: 16),
            ],
            ...prompt.attachments.map((a) {
              if (a.type == 'image' && a.base64Data != null) {
                try {
                  final bytes = base64Decode(a.base64Data!);
                  return Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: ClipRRect(borderRadius: BorderRadius.circular(10),
                      child: Image.memory(bytes, fit: BoxFit.cover)));
                } catch (_) {}
              }
              return Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(9), border: Border.all(color: kBorder)),
                  child: Row(children: [
                    Icon(a.type == 'audio' ? Icons.audiotrack_outlined : Icons.attach_file, size: 16, color: kMuted2),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.name, style: const TextStyle(color: kText2, fontSize: 13))),
                  ]),
                ));
            }),
          ],
        )),
      ]);
    }
  }