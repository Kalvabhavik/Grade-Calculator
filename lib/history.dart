import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'history_service.dart';

// Reuse grade color from final.dart context
Color _hGradeColor(String g) {
  if (g.startsWith('A')) return const Color(0xFF00C896);
  if (g.startsWith('B')) return const Color(0xFF4A90D9);
  if (g.startsWith('C')) return const Color(0xFFF5A623);
  if (g.startsWith('D')) return const Color(0xFFE8703A);
  return const Color(0xFFE84848);
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistorySession> _sessions = [];
  bool _loading = true;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await HistoryService.loadSessions();
    if (mounted) setState(() { _sessions = sessions; _loading = false; });
  }

  Future<void> _delete(String id) async {
    await HistoryService.deleteSession(id);
    setState(() => _sessions.removeWhere((s) => s.id == id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session deleted"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Clear History?", style: TextStyle(color: Colors.white)),
        content: const Text("This will delete all saved sessions.", style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Clear All", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await HistoryService.clearAll();
      setState(() => _sessions = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white),
        title: Text("Grading History",
            style: GoogleFonts.inconsolata(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [
          if (_sessions.isNotEmpty)
            IconButton(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              tooltip: "Clear All",
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
              colors: [Color(0xFF0D1B3E), Color(0xFF0A0E1A)], radius: 1.2, center: Alignment.topLeft),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _sessions.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (_, i) => _sessionCard(_sessions[i]),
                    ),
                  ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.history, size: 80, color: Colors.white12),
      const SizedBox(height: 20),
      Text("No Sessions Yet", style: GoogleFonts.inconsolata(color: Colors.white38, fontSize: 22)),
      const SizedBox(height: 8),
      const Text("Grade a class to see results here.", style: TextStyle(color: Colors.white24, fontSize: 14)),
    ]));
  }

  Widget _sessionCard(HistorySession s) {
    final isExpanded = _expandedId == s.id;
    final dateStr = DateFormat('dd MMM yyyy  HH:mm').format(s.timestamp);
    final total = s.totalStudents;
    final passCount = s.chartData.where((e) {
      final g = (e['grade'] as String).toUpperCase();
      return !g.startsWith('D') && !g.startsWith('F');
    }).fold(0, (sum, e) => sum + (e['count'] as num).toInt());
    final failCount = total - passCount;

    return Dismissible(
      key: Key(s.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(20)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B3E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Delete?", style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes", style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
      onDismissed: (_) => _delete(s.id),
      child: GestureDetector(
        onTap: () => setState(() => _expandedId = isExpanded ? null : s.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900.withOpacity(0.4), Colors.black.withOpacity(0.6)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isExpanded ? Colors.blue.shade400 : Colors.white12,
              width: isExpanded ? 1.5 : 1,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                // Pass rate ring
                SizedBox(width: 52, height: 52, child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: total == 0 ? 0 : passCount / total,
                    backgroundColor: Colors.red.shade900.withOpacity(0.5),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF00C896)),
                    strokeWidth: 5,
                  ),
                  Text('${s.passRate.toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ])),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(
                    s.templateId == 'manual' ? 'Custom Template' : 'Template: ${s.templateId}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text("$total students", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(width: 10),
                    if (s.maxMarks != null)
                      Text("/ ${s.maxMarks} max", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                ])),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white38),
              ]),
            ),

            // ── Mini grade bar ──
            if (s.chartData.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 10,
                    child: Row(children: s.chartData.map((e) {
                      final cnt = (e['count'] as num).toInt();
                      final col = _hGradeColor(e['grade'] as String);
                      return Flexible(
                        flex: cnt == 0 ? 0 : cnt,
                        child: Container(color: col),
                      );
                    }).toList()),
                  ),
                ),
              ),

            // ── Division chips ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(spacing: 6, runSpacing: 4, children: s.divisions.entries.map((e) =>
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade800),
                  ),
                  child: Text("${e.key} ${e.value}%",
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                )
              ).toList()),
            ),

            // ── Expanded grade breakdown ──
            if (isExpanded) ...[
              const Divider(color: Colors.white12, height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Grade Breakdown",
                      style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...s.chartData.map((e) {
                    final cnt = (e['count'] as num).toInt();
                    final pct = total == 0 ? 0.0 : cnt / total * 100;
                    final col = _hGradeColor(e['grade'] as String);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        SizedBox(width: 60,
                            child: Text(
                              (e['grade'] as String).replaceAll(' Grade', ''),
                              style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 12),
                            )),
                        Expanded(child: Stack(children: [
                          Container(height: 20, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6))),
                          FractionallySizedBox(
                            widthFactor: (pct / 100).clamp(0.02, 1.0),
                            child: Container(height: 20, decoration: BoxDecoration(color: col.withOpacity(0.7), borderRadius: BorderRadius.circular(6))),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Align(alignment: Alignment.centerLeft,
                              child: Text("$cnt  (${pct.toStringAsFixed(1)}%)",
                                  style: const TextStyle(color: Colors.white, fontSize: 11))),
                          ),
                        ])),
                      ]),
                    );
                  }),
                  const SizedBox(height: 8),
                  Row(children: [
                    _summaryChip("Pass", passCount, const Color(0xFF00C896)),
                    const SizedBox(width: 8),
                    _summaryChip("Fail", failCount, const Color(0xFFE84848)),
                    if (s.stats['mean'] != null) ...[
                      const SizedBox(width: 8),
                      _summaryChip("μ", s.stats['mean'], Colors.cyan),
                    ],
                    if (s.stats['sigma'] != null) ...[
                      const SizedBox(width: 8),
                      _summaryChip("σ", s.stats['sigma'], Colors.purple),
                    ],
                  ]),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _summaryChip(String label, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text("$label: $value",
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
