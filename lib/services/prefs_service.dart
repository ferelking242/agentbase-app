import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const _keyPat = 'github_pat';
  static const _keyOwner = 'github_owner';

  static Future<String?> getPat() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyPat);
  }

  static Future<void> savePat(String pat) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyPat, pat);
  }

  static Future<void> clearPat() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyPat);
  }

  static Future<String?> getOwner() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyOwner);
  }

  static Future<void> saveOwner(String owner) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyOwner, owner);
  }
}
