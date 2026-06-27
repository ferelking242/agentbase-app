import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_prompt.dart';

class PrefsService {
  static const _kPat         = 'gh_pat';
  static const _kPrompts     = 'saved_prompts';
  static const _kNextNumber  = 'prompt_next_number';

  // ── PAT ──────────────────────────────────────────────────────────────────
  static Future<String?> getPat() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kPat);
  }

  static Future<void> savePat(String pat) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPat, pat);
  }

  static Future<void> clearPat() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kPat);
  }

  // ── Next sequential number ───────────────────────────────────────────────
  static Future<int> _nextNumber() async {
    final p = await SharedPreferences.getInstance();
    final n = p.getInt(_kNextNumber) ?? 1;
    await p.setInt(_kNextNumber, n + 1);
    return n;
  }

  // ── Prompts ──────────────────────────────────────────────────────────────
  static Future<List<SavedPrompt>> getPrompts() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPrompts);
    if (raw == null) return [];
    return SavedPrompt.listFromJson(raw);
  }

  static Future<SavedPrompt> addPrompt(SavedPrompt prompt) async {
    final p = await SharedPreferences.getInstance();
    int num = prompt.number;
    if (num == 0) num = await _nextNumber();
    final numbered = SavedPrompt(
      id: prompt.id, name: prompt.name, link: prompt.link,
      created: prompt.created, number: num,
    );
    final existing = await getPrompts();
    existing.insert(0, numbered);
    await p.setString(_kPrompts, SavedPrompt.listToJson(existing));
    return numbered;
  }

  static Future<void> deletePrompt(String id) async {
    final p = await SharedPreferences.getInstance();
    final existing = await getPrompts();
    existing.removeWhere((pr) => pr.id == id);
    await p.setString(_kPrompts, SavedPrompt.listToJson(existing));
  }

  static Future<void> updatePromptName(String id, String newName) async {
    final p = await SharedPreferences.getInstance();
    final prompts = await getPrompts();
    final idx = prompts.indexWhere((pr) => pr.id == id);
    if (idx == -1) return;
    prompts[idx] = prompts[idx].copyWith(name: newName);
    await p.setString(_kPrompts, SavedPrompt.listToJson(prompts));
  }

  static Future<void> replaceAll(List<SavedPrompt> prompts) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPrompts, SavedPrompt.listToJson(prompts));
  }
}
