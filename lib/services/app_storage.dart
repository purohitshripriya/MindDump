import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class AppStorage {
  static const _tasksKey = 'mind_dump_tasks_v1';
  static const _historyKey = 'mind_dump_history_v1';

  Future<List<ThoughtTask>> loadTasks() async {
    final preferences = await SharedPreferences.getInstance();
    return _decodeList(preferences.getString(_tasksKey))
        .map(ThoughtTask.fromJson)
        .toList();
  }

  Future<List<ThoughtDump>> loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    return _decodeList(preferences.getString(_historyKey))
        .map(ThoughtDump.fromJson)
        .toList();
  }

  Future<void> saveTasks(List<ThoughtTask> tasks) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _tasksKey,
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
  }

  Future<void> saveHistory(List<ThoughtDump> history) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _historyKey,
      jsonEncode(history.map((dump) => dump.toJson()).toList()),
    );
  }

  List<Map<String, dynamic>> _decodeList(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Saved MindDump data is not a list.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }
}
