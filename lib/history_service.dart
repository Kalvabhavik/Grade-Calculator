import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HistorySession {
  final String id;
  final DateTime timestamp;
  final Map<String, int> divisions;
  final String templateId;
  final int? maxMarks;
  final List<dynamic> chartData;
  final Map<String, dynamic> stats;
  final double passRate;
  final int totalStudents;

  const HistorySession({
    required this.id,
    required this.timestamp,
    required this.divisions,
    required this.templateId,
    this.maxMarks,
    required this.chartData,
    required this.stats,
    required this.passRate,
    required this.totalStudents,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'divisions': divisions,
    'templateId': templateId,
    'maxMarks': maxMarks,
    'chartData': chartData,
    'stats': stats,
    'passRate': passRate,
    'totalStudents': totalStudents,
  };

  factory HistorySession.fromJson(Map<String, dynamic> j) => HistorySession(
    id: j['id'] as String,
    timestamp: DateTime.parse(j['timestamp'] as String),
    divisions: Map<String, int>.from(j['divisions'] as Map),
    templateId: j['templateId'] as String,
    maxMarks: j['maxMarks'] as int?,
    chartData: j['chartData'] as List<dynamic>,
    stats: Map<String, dynamic>.from(j['stats'] as Map? ?? {}),
    passRate: (j['passRate'] as num).toDouble(),
    totalStudents: (j['totalStudents'] as num).toInt(),
  );
}

class HistoryService {
  static const _key = 'grade_history_sessions';

  static Future<List<HistorySession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) {
      try {
        return HistorySession.fromJson(json.decode(s));
      } catch (_) {
        return null;
      }
    }).whereType<HistorySession>().toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Future<void> saveSession(HistorySession session) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(json.encode(session.toJson()));
    // Keep only the last 50 sessions
    if (raw.length > 50) raw.removeAt(0);
    await prefs.setStringList(_key, raw);
  }

  static Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((s) {
      try {
        return (json.decode(s) as Map)['id'] == id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_key, raw);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static String generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
}
