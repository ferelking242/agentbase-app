import 'package:shared_preferences/shared_preferences.dart';
  class PrefsService {
    static const _k = 'gh_pat';
    static Future<String?> getPat() async { final p=await SharedPreferences.getInstance(); return p.getString(_k); }
    static Future<void> savePat(String pat) async { final p=await SharedPreferences.getInstance(); await p.setString(_k,pat); }
    static Future<void> clearPat() async { final p=await SharedPreferences.getInstance(); await p.remove(_k); }
  }