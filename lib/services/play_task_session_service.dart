import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PlayTaskSessionService {
  static const _prefix = 'play_task_session_v2_';

  Future<Map<String, dynamic>> load(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      // A damaged local game state should never prevent opening the game.
    }
    return <String, dynamic>{};
  }

  Future<void> save(String key, Map<String, dynamic> value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('$_prefix$key', jsonEncode(value));
  }

  Future<void> clear(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$_prefix$key');
  }

  Future<void> clearPracticeSessions() async {
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences
        .getKeys()
        .where((key) => key.startsWith('${_prefix}practice_'))
        .toList(growable: false);
    await Future.wait(keys.map(preferences.remove));
  }
}
