import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_prompt.dart';

class PrefsService {
  static const _kPat = 'gh_pat';
  static const _kPrompts = 'saved_prompts';

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

  static Future<List<SavedPrompt>> getPrompts() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPrompts);
    if (raw == null) return [];
    return SavedPrompt.listFromJson(raw);
  }

  static Future<void> addPrompt(SavedPrompt prompt) async {
    final p = await SharedPreferences.getInstance();
    final existing = await getPrompts();
    existing.insert(0, prompt);
    await p.setString(_kPrompts, SavedPrompt.listToJson(existing));
  }

  static Future<void> deletePrompt(String id) async {
    final p = await SharedPreferences.getInstance();
    final existing = await getPrompts();
    existing.removeWhere((pr) => pr.id == id);
    await p.setString(_kPrompts, SavedPrompt.listToJson(existing));
  }
}
