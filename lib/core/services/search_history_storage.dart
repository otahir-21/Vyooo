import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local recent search queries (per signed-in user, or guest).
class SearchHistoryStorage {
  SearchHistoryStorage();

  static const int maxItems = 20;
  static const String _keyPrefix = 'search_recent_v1_';

  String _prefsKey([String? uid]) {
    final id = (uid ?? FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    return id.isEmpty ? '${_keyPrefix}guest' : '$_keyPrefix$id';
  }

  Future<List<String>> load({String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey(uid));
    if (raw == null || raw.isEmpty) return <String>[];
    return raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<List<String>> add(
    String raw, {
    String? uid,
    List<String>? current,
  }) async {
    final query = raw.trim();
    if (query.isEmpty) {
      return current ?? await load(uid: uid);
    }

    var list = List<String>.from(current ?? await load(uid: uid));
    final key = query.toLowerCase();
    list.removeWhere((e) => e.trim().toLowerCase() == key);
    list.insert(0, query);
    if (list.length > maxItems) {
      list = list.sublist(0, maxItems);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey(uid), list);
    return list;
  }

  Future<List<String>> removeAt(
    int index, {
    String? uid,
    List<String>? current,
  }) async {
    final list = List<String>.from(current ?? await load(uid: uid));
    if (index < 0 || index >= list.length) return list;
    list.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey(uid), list);
    return list;
  }
}
