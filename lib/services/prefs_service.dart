import 'package:shared_preferences/shared_preferences.dart';

  class PrefsService {
    static const _patKey = 'gh_pat';
    static Future<String?> getPat() async {
      final p = await SharedPreferences.getInstance();
      return p.getString(_patKey);
    }
    static Future<void> savePat(String pat) async {
      final p = await SharedPreferences.getInstance();
      await p.setString(_patKey, pat);
    }
    static Future<void> clearPat() async {
      final p = await SharedPreferences.getInstance();
      await p.remove(_patKey);
    }
  }