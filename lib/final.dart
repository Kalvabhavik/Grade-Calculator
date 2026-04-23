import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:math';
import 'jk.dart';
import 'history_service.dart';
import "package:lottie/lottie.dart";

class ProcessGradesPage extends StatefulWidget {
  final Map<String, int> divisions;
  final String templateId;
  final Map<String, String>? manualBoundaries;
  final bool startInAiMode;
  final String? scope;
  const ProcessGradesPage({
    super.key,
    required this.divisions,
    required this.templateId,
    this.manualBoundaries,
    this.startInAiMode = false,
    this.scope,
  });
  @override
  State<ProcessGradesPage> createState() => _ProcessGradesPageState();
}

// ── Grade color helper ──
Color gradeColor(String g) {
  if (g.startsWith('A')) return const Color(0xFF00C896);
  if (g.startsWith('B')) return const Color(0xFF4A90D9);
  if (g.startsWith('C')) return const Color(0xFFF5A623);
  if (g.startsWith('D')) return const Color(0xFFE8703A);
  return const Color(0xFFE84848);
}

class _ProcessGradesPageState extends State<ProcessGradesPage> with TickerProviderStateMixin {
  String _status = "Upload the completed Excel template.";
  bool _isProcessing = false;
  String? _downloadUrl;
  String? _lastError;
  List<dynamic> _chartData = [];
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _divisionBreakdown = {};
  late TabController _tabCtrl;

  // AI mode toggle
  bool _aiMode = false;
  // Uploaded file id — reused if the user wants a mapping preview before
  // triggering /calculate-grades.
  String? _lastFileId;
  List<dynamic>? _detectedSheets;
  // Overrides keyed by sheet name → division → header.
  final Map<String, Map<String, String>> _mappingOverride = {};

  void _reset() {
    setState(() {
      _downloadUrl = null;
      _chartData = [];
      _lastError = null;
      _stats = {};
      _divisionBreakdown = {};
      _status = _aiMode
          ? 'AI mode: upload any Excel and we will auto-grade it.'
          : 'Upload the completed Excel template.';
    });
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    _aiMode = widget.startInAiMode;
    if (widget.startInAiMode) {
      _status = 'AI mode: upload any Excel and we will auto-grade it.';
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Derived stats ──
  int get _total => _chartData.fold(0, (s, e) => s + (e['count'] as num).toInt());
  int get _passCount => _chartData.where((e) {
    final g = (e['grade'] as String).toUpperCase();
    return !g.startsWith('D') && !g.startsWith('F');
  }).fold(0, (s, e) => s + (e['count'] as num).toInt());
  int get _failCount => _total - _passCount;
  double get _passRate => _total == 0 ? 0 : _passCount / _total * 100;
  int get _topCount => _chartData.isEmpty ? 0 : _chartData.firstWhere(
    (e) => (e['grade'] as String).toUpperCase().startsWith('A'),
    orElse: () => {'count': 0},
  )['count'] as int;

  Future<void> _pickAi() => _pickFiles(autoDetect: true);

  Future<void> _pick() => _pickFiles(autoDetect: false);

  Future<void> _pickFiles({required bool autoDetect}) async {
    final files = await openFiles(acceptedTypeGroups: [
      const XTypeGroup(label: 'Excel', extensions: ['xlsx', 'xls', 'csv'])
    ]);
    if (files.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _status = autoDetect
          ? 'AI is reading your Excel file(s)...'
          : 'Uploading and calculating grades...';
      _downloadUrl = null;
      _lastError = null;
      _chartData = [];
    });

    try {
      final req = http.MultipartRequest('POST', Uri.parse('$url/upload'));
      for (final file in files) {
        req.files.add(http.MultipartFile.fromBytes(
          'files',
          await file.readAsBytes(),
          filename: file.name,
        ));
      }
      final up = await req.send();
      final uploadText = await up.stream.bytesToString();
      if (up.statusCode != 200) {
        throw Exception('Upload failed (HTTP ${up.statusCode}): $uploadText');
      }
      final upData = json.decode(uploadText);
      _lastFileId = upData['file_id'] as String?;

      // Fetch AI-detected column mapping so the UI can preview it before
      // calculating grades. We do this even in template mode — if any
      // division didn't match an Excel column, warn the user.
      try {
        final det = await http.post(
          Uri.parse('$url/detect'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'file_id': _lastFileId,
            'divisions': widget.divisions,
          }),
        );
        if (det.statusCode == 200) {
          final j = json.decode(det.body);
          _detectedSheets = j['sheets'] as List<dynamic>?;
        }
      } catch (_) {
        // detect endpoint may not exist on older backends — ignore
      }

      final body = {
        'file_id': _lastFileId,
        'divisions': widget.divisions,
        'distribution_type': widget.templateId == 'manual' ? 'manual' : 'template',
        'template_id': widget.templateId,
        'auto_detect': autoDetect,
        if (_mappingOverride.isNotEmpty) 'mapping_override': _mappingOverride,
        if (widget.templateId == 'manual' && widget.manualBoundaries != null)
          'manual_boundaries': widget.manualBoundaries,
      };
      final calc = await http.post(
        Uri.parse('$url/calculate-grades'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (calc.statusCode != 200) {
        throw Exception('Calculation failed (HTTP ${calc.statusCode}): ${calc.body}');
      }

      final d = json.decode(calc.body);
      final chartData = d['chart_data'] ?? [];
      final stats = Map<String, dynamic>.from(d['stats'] ?? {});
      final total = (chartData as List).fold(0, (s, e) => s + (e['count'] as num).toInt());
      final passCount = chartData.where((e) {
        final g = (e['grade'] as String).toUpperCase();
        return !g.startsWith('D') && !g.startsWith('F');
      }).fold(0, (s, e) => s + (e['count'] as num).toInt());
      final passRate = total == 0 ? 0.0 : passCount / total * 100;

      await HistoryService.saveSession(HistorySession(
        id: HistoryService.generateId(),
        timestamp: DateTime.now(),
        divisions: widget.divisions,
        templateId: widget.templateId,
        maxMarks: null,
        chartData: chartData,
        stats: stats,
        passRate: passRate,
        totalStudents: total,
      ));

      setState(() {
        _isProcessing = false;
        _status = autoDetect ? 'AI grading complete!' : 'Grades calculated!';
        _downloadUrl = '${url.replaceAll('/api', '')}${d['download_url']}';
        _chartData = chartData;
        _stats = stats;
        _divisionBreakdown = d['division_breakdown'] ?? {};
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _lastError = e.toString().replaceFirst('Exception: ', '');
        _status = 'Error occurred.';
      });
    }
  }

  Future<void> _download() async {
    if (_downloadUrl == null) return;
    if (!await launchUrl(Uri.parse(_downloadUrl!), mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file')));
    }
  }

  // ═══════════════════════════════════════════════════════
  //  CHART WIDGETS
  // ═══════════════════════════════════════════════════════

  Widget _barChart() {
    if (_chartData.isEmpty) return const SizedBox.shrink();
    final maxY = (_chartData.map((e) => (e['count'] as num).toDouble()).reduce(max) + 2);
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
            "${_chartData[g.x.toInt()]['grade']}\n${rod.toY.toInt()} students",
            const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
          getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 10)))),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
          final g = _chartData[v.toInt()]['grade'] as String;
          return Padding(padding: const EdgeInsets.only(top: 6),
              child: Text(g.replaceAll(' Grade', '').replaceAll(' ', ''), style: const TextStyle(color: Colors.white70, fontSize: 10)));
        })),
      ),
      gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white12, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(_chartData.length, (i) => BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: (_chartData[i]['count'] as num).toDouble(),
          gradient: LinearGradient(colors: [gradeColor(_chartData[i]['grade']).withOpacity(0.6), gradeColor(_chartData[i]['grade'])], begin: Alignment.bottomCenter, end: Alignment.topCenter),
          width: 28, borderRadius: BorderRadius.circular(6),
        ),
      ])),
    ));
  }

  Widget _pieChart() {
    if (_chartData.isEmpty) return const SizedBox.shrink();
    return PieChart(PieChartData(
      sectionsSpace: 3,
      centerSpaceRadius: 50,
      sections: List.generate(_chartData.length, (i) {
        final c = (_chartData[i]['count'] as num).toDouble();
        final pct = _total == 0 ? 0.0 : c / _total * 100;
        return PieChartSectionData(
          value: c,
          title: pct < 5 ? '' : '${pct.toStringAsFixed(1)}%',
          titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          color: gradeColor(_chartData[i]['grade']),
          radius: 80,
        );
      }),
    ));
  }

  Widget _passFail() {
    if (_total == 0) return const SizedBox.shrink();
    return PieChart(PieChartData(
      sectionsSpace: 4,
      centerSpaceRadius: 60,
      sections: [
        PieChartSectionData(value: _passCount.toDouble(), title: 'Pass\n${_passRate.toStringAsFixed(1)}%',
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            color: const Color(0xFF00C896), radius: 70),
        PieChartSectionData(value: _failCount.toDouble(),
            title: _failCount == 0 ? '' : 'Fail\n${(100 - _passRate).toStringAsFixed(1)}%',
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            color: const Color(0xFFE84848), radius: 70),
      ],
    ));
  }

  Widget _gradeTable() {
    return SingleChildScrollView(child: Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Expanded(child: Text("Grade", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          SizedBox(width: 60, child: Center(child: Text("Count", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          SizedBox(width: 70, child: Center(child: Text("Share", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          SizedBox(width: 80, child: Center(child: Text("Bar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        ]),
      ),
      const SizedBox(height: 6),
      ..._chartData.map((e) {
        final cnt = (e['count'] as num).toInt();
        final pct = _total == 0 ? 0.0 : cnt / _total * 100;
        final col = gradeColor(e['grade']);
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: col.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: col.withOpacity(0.3)),
          ),
          child: Row(children: [
            Expanded(child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(e['grade'], style: TextStyle(color: col, fontWeight: FontWeight.w600)),
            ])),
            SizedBox(width: 60, child: Center(child: Text("$cnt", style: const TextStyle(color: Colors.white, fontSize: 15)))),
            SizedBox(width: 70, child: Center(child: Text("${pct.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white70)))),
            SizedBox(width: 80, child: ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: pct / 100, minHeight: 10,
                backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(col)))),
          ]),
        );
      }),
    ]));
  }

  // ═══════════════════════════════════════════════════════
  //  STAT CARDS
  // ═══════════════════════════════════════════════════════
  Widget _statsRow() {
    final mu = _stats['mean'];
    final sigma = _stats['sigma'];
    final median = _stats['median'];
    final maxS = _stats['max_score'];
    final minS = _stats['min_score'];
    return Wrap(spacing: 12, runSpacing: 12, children: [
      _statCard("Total Students", "$_total", Icons.people, Colors.blue),
      _statCard("Pass Rate", "${_passRate.toStringAsFixed(1)}%", Icons.check_circle, const Color(0xFF00C896)),
      _statCard("Fail Rate", "${(100 - _passRate).toStringAsFixed(1)}%", Icons.cancel, const Color(0xFFE84848)),
      _statCard("Top Grade (A)", "$_topCount", Icons.star, Colors.amber),
      if (mu != null) _statCard("Mean (μ)", "${(mu as num).toStringAsFixed(1)}%", Icons.functions, Colors.cyan),
      if (sigma != null) _statCard("Std Dev (σ)", "${(sigma as num).toStringAsFixed(1)}", Icons.show_chart, Colors.purple),
      if (median != null) _statCard("Median", "${(median as num).toStringAsFixed(1)}", Icons.linear_scale, Colors.orange),
      if (maxS != null) _statCard("Highest", "${(maxS as num).toStringAsFixed(1)}", Icons.arrow_upward, Colors.green),
      if (minS != null) _statCard("Lowest", "${(minS as num).toStringAsFixed(1)}", Icons.arrow_downward, Colors.red),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  //  HEATMAP  — grade × metric intensity grid
  // ══════════════════════════════════════════════════
  Widget _heatmap() {
    if (_chartData.isEmpty) return const Center(child: Text("No data", style: TextStyle(color: Colors.white38)));

    // Build cumulative list for each grade
    int running = 0;
    final rows = _chartData.map((e) {
      final cnt = (e['count'] as num).toInt();
      final pct = _total == 0 ? 0.0 : cnt / _total * 100;
      running += cnt;
      final cumulPct = _total == 0 ? 0.0 : running / _total * 100;
      final col = gradeColor(e['grade'] as String);
      return {'grade': e['grade'], 'count': cnt, 'pct': pct, 'cumul': cumulPct, 'color': col};
    }).toList();

    final metrics = ['Count', 'Share %', 'Cum. %', 'Intensity'];
    final maxCount = _chartData.map((e) => (e['count'] as num).toInt()).reduce(max).toDouble();

    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Column headers
      Row(children: [
        const SizedBox(width: 72),
        ...metrics.map((m) => Expanded(child: Center(
          child: Text(m, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        ))),
      ]),
      const SizedBox(height: 6),
      // Rows per grade
      ...rows.map((r) {
        final cnt = r['count'] as int;
        final pct = r['pct'] as double;
        final cumul = r['cumul'] as double;
        final col = r['color'] as Color;
        final intensity = maxCount == 0 ? 0.0 : cnt / maxCount;

        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(children: [
            // Grade label
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(color: col.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(
                (r['grade'] as String).replaceAll(' Grade', ''),
                textAlign: TextAlign.center,
                style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            const SizedBox(width: 4),
            // Count cell
            Expanded(child: _heatCell(cnt.toString(), intensity, col)),
            // Pct cell
            Expanded(child: _heatCell('${pct.toStringAsFixed(1)}%', pct / 100, col)),
            // Cumulative cell
            Expanded(child: _heatCell('${cumul.toStringAsFixed(1)}%', cumul / 100, Colors.cyan)),
            // Solid intensity bar cell
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Stack(children: [
                Container(height: 34, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8))),
                FractionallySizedBox(
                  widthFactor: intensity.clamp(0.03, 1.0),
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [col.withOpacity(0.4), col]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Center(child: Text('${(intensity * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ]),
            )),
          ]),
        );
      }),
      const SizedBox(height: 8),
      // Legend
      Row(children: [
        const SizedBox(width: 72),
        Expanded(child: _heatLegend()),
      ]),
    ]));
  }

  Widget _heatCell(String label, double intensity, Color col) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: col.withOpacity((intensity * 0.7).clamp(0.07, 0.7)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: col.withOpacity(0.3)),
        ),
        child: Center(child: Text(label, style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _heatLegend() {
    return Row(children: [
      const Text("Low", style: TextStyle(color: Colors.white38, fontSize: 9)),
      const SizedBox(width: 4),
      Expanded(child: Container(
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: const LinearGradient(colors: [Color(0xFF0D1B3E), Color(0xFF00C896)]),
        ),
      )),
      const SizedBox(width: 4),
      const Text("High", style: TextStyle(color: Colors.white38, fontSize: 9)),
    ]);
  }

  // ══════════════════════════════════════════════════
  //  CDF — Cumulative Distribution Function line chart
  // ══════════════════════════════════════════════════
  Widget _cdfChart() {
    if (_chartData.isEmpty) return const Center(child: Text("No data", style: TextStyle(color: Colors.white38)));

    // Build CDF points — x = grade index, y = cumulative %
    double running = 0;
    final spots = <FlSpot>[];
    for (int i = 0; i < _chartData.length; i++) {
      running += (_chartData[i]['count'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), _total == 0 ? 0 : running / _total * 100));
    }

    // Also build individual % spots for reference
    final pctSpots = <FlSpot>[];
    for (int i = 0; i < _chartData.length; i++) {
      final p = _total == 0 ? 0.0 : (_chartData[i]['count'] as num) / _total * 100;
      pctSpots.add(FlSpot(i.toDouble(), p.toDouble()));
    }

    return LineChart(LineChartData(
      minY: 0, maxY: 110,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
            '${_chartData[s.x.toInt()]['grade']}\n${s.y.toStringAsFixed(1)}%',
            const TextStyle(color: Colors.white, fontSize: 11),
          )).toList(),
        ),
      ),
      gridData: FlGridData(
        show: true,
        getDrawingHorizontalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1),
        getDrawingVerticalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
          getTitlesWidget: (v, m) => Text('${v.toInt()}%', style: const TextStyle(color: Colors.white38, fontSize: 9)))),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
          final i = v.toInt();
          if (i < 0 || i >= _chartData.length) return const SizedBox.shrink();
          final g = (_chartData[i]['grade'] as String).replaceAll(' Grade', '').replaceAll(' ', '');
          return Padding(padding: const EdgeInsets.only(top: 4),
              child: Text(g, style: const TextStyle(color: Colors.white54, fontSize: 9)));
        })),
      ),
      lineBarsData: [
        // CDF line — cyan
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.cyanAccent,
          barWidth: 2.5,
          dotData: FlDotData(show: true, getDotPainter: (s, d, bar, i) =>
              FlDotCirclePainter(radius: 4, color: Colors.cyanAccent, strokeColor: Colors.white, strokeWidth: 1)),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [Colors.cyanAccent.withOpacity(0.25), Colors.cyanAccent.withOpacity(0.0)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Per-grade % line — amber
        LineChartBarData(
          spots: pctSpots,
          isCurved: false,
          color: Colors.amber,
          barWidth: 1.5,
          dashArray: [6, 4],
          dotData: FlDotData(show: true, getDotPainter: (s, d, bar, i) =>
              FlDotCirclePainter(radius: 3, color: Colors.amber, strokeColor: Colors.white, strokeWidth: 1)),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      // 50% and 100% reference lines
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(y: 50, color: Colors.white24, strokeWidth: 1, dashArray: [4, 4],
            label: HorizontalLineLabel(show: true, alignment: Alignment.topRight,
                labelResolver: (_) => '50%', style: const TextStyle(color: Colors.white38, fontSize: 9))),
        HorizontalLine(y: 100, color: Colors.white12, strokeWidth: 1,
            label: HorizontalLineLabel(show: true, alignment: Alignment.topRight,
                labelResolver: (_) => '100%', style: const TextStyle(color: Colors.white24, fontSize: 9))),
      ]),
    ));
  }

  // ── File format help dialog ──
  void _showFormatHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Expected File Formats", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _formatSection("Individual Sheet", "Reg No | Student Name | Mids | Final",
            "Row 2 must contain max marks under each marks column. Student marks start from row 3.",
            Colors.blue.shade800),
          const SizedBox(height: 16),
          _formatSection("Team Sheet", "Team ID | Team Name | Members Reg Nos | Project",
            "Row 2 contains max marks. Put team members in one cell separated by comma, space, or new line.",
            Colors.purple.shade800),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade700)),
            child: const Text(
              "Header matching is flexible: Mids, Mid Term, mid_term, and similar names are treated as the selected category when possible.",
              style: TextStyle(color: Colors.orange, fontSize: 11),
            ),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text("Got it", style: TextStyle(color: Colors.blue.shade300))),
        ],
      ),
    );
  }

  Widget _formatSection(String title, String format, String note, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.3), borderRadius: BorderRadius.circular(10), border: Border.all(color: color)),
        child: Text(format, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12)),
      ),
      const SizedBox(height: 4),
      Text(note, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bool hasData = _chartData.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: BackButton(color: Colors.white),
        title: Text(
          widget.scope == null ? "Grade Analytics" : "Grade Analytics — ${widget.scope}",
          style: GoogleFonts.inconsolata(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isProcessing && _detectedSheets != null)
            TextButton.icon(
              onPressed: _showMappingPreview,
              icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 16),
              label: const Text("AI Mapping", style: TextStyle(color: Colors.amberAccent, fontSize: 13)),
            ),
          if (!_isProcessing && hasData)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
              label: const Text("New", style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(colors: [Color(0xFF0D1B3E), Color(0xFF0A0E1A)], radius: 1.2, center: Alignment.topLeft),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── AI / Template Mode Toggle ──
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _aiMode = false;
                      _status = 'Upload the completed Excel template.';
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_aiMode ? Colors.blue.shade700 : Colors.transparent,
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.table_chart, size: 16, color: !_aiMode ? Colors.white : Colors.white38),
                        const SizedBox(width: 6),
                        Text('Use Template', style: TextStyle(
                          color: !_aiMode ? Colors.white : Colors.white38,
                          fontWeight: !_aiMode ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        )),
                      ]),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _aiMode = true;
                      _status = 'AI mode: upload any Excel and we will auto-grade it.';
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _aiMode ? Colors.purple.shade700 : Colors.transparent,
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.auto_awesome, size: 16, color: _aiMode ? Colors.white : Colors.white38),
                        const SizedBox(width: 6),
                        Text('AI Direct Upload', style: TextStyle(
                          color: _aiMode ? Colors.white : Colors.white38,
                          fontWeight: _aiMode ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        )),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),

            // ── AI mode info banner ──
            if (_aiMode && !hasData && !_isProcessing)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.purple.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple.shade600),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 18),
                    const SizedBox(width: 8),
                    Text('AI-Powered Auto-Grading', style: TextStyle(color: Colors.purple.shade200, fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                    'Upload one workbook with multiple sheets, or select the individual and team files together. '
                    'The system reads max marks from the sheet and matches similar headers like Mids, Mid Term, and mid_term.\n\n'
                    'Supported formats: .xlsx  .xls  .csv',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ]),
              ),

            // ── Status ──
            Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),

            // ── Processing ──
            if (_isProcessing)
              Center(child: SizedBox(height: 220, width: 220, child: Lottie.asset("assets/final.json"))),

            // ── Error ──
            if (!_isProcessing && _lastError != null) ...[
              Container(
                padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade800)),
                child: Column(children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
                  const SizedBox(height: 8),
                  Text(_lastError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
              Center(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text("Try Again", style: TextStyle(color: Colors.white)),
                onPressed: _aiMode ? _pickAi : _pick,
              )),
            ],

            if (!hasData && !_isProcessing)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade800),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.grid_on, color: Colors.blue.shade300, size: 20),
                    const SizedBox(width: 8),
                    Text("Excel-Driven Marks",
                        style: TextStyle(color: Colors.blue.shade200, fontSize: 14, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton(
                      onPressed: _showFormatHelp,
                      child: Text("File Format Help", style: TextStyle(color: Colors.blue.shade300, fontSize: 11)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  const Text(
                    "Max marks are read from the second row of the sheet. Select both individual and team files when your template download created two files.",
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ]),
              ),

            // ── Upload button (template mode) ──
            if (!_isProcessing && !hasData && _lastError == null && !_aiMode)
              Center(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                icon: const Icon(Icons.upload_file, color: Colors.white),
                label: const Text('Select Template File(s)', style: TextStyle(color: Colors.white, fontSize: 16)),
                onPressed: _pick,
              )),

            // ── Upload button (AI mode) ──
            if (!_isProcessing && !hasData && _aiMode)
              Center(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                icon: const Icon(Icons.auto_awesome, color: Colors.white),
                label: const Text('Upload Excel File(s)', style: TextStyle(color: Colors.white, fontSize: 16)),
                onPressed: _pickAi,
              )),

            // ════════════════════════════════════════════
            //  ANALYTICS DASHBOARD
            // ════════════════════════════════════════════
            if (hasData) ...[

              // Stat cards
              _statsRow(),
              const SizedBox(height: 24),

              // Tab bar
              Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(14)),
                child: TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicator: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.blue.shade800),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(icon: Icon(Icons.bar_chart, size: 16), text: "Bar"),
                    Tab(icon: Icon(Icons.pie_chart, size: 16), text: "Pie"),
                    Tab(icon: Icon(Icons.donut_large, size: 16), text: "Pass/Fail"),
                    Tab(icon: Icon(Icons.table_rows, size: 16), text: "Table"),
                    Tab(icon: Icon(Icons.grid_on, size: 16), text: "Heatmap"),
                    Tab(icon: Icon(Icons.show_chart, size: 16), text: "CDF"),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Chart panels
              SizedBox(
                height: 320,
                child: TabBarView(controller: _tabCtrl, children: [
                  // Bar
                  _chartPanel("Grade Distribution", _barChart()),
                  // Pie
                  _chartPanel("Grade Proportions", Row(children: [
                    Expanded(child: _pieChart()),
                    const SizedBox(width: 12),
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: _chartData.map((e) {
                      final col = gradeColor(e['grade']);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(e['grade'].toString().replaceAll(' Grade', ''), style: TextStyle(color: col, fontSize: 11)),
                        ]),
                      );
                    }).toList()),
                  ])),
                  // Pass/Fail
                  _chartPanel("Pass vs Fail", Column(children: [
                    Expanded(child: _passFail()),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _legend("Pass ($_passCount)", const Color(0xFF00C896)),
                      const SizedBox(width: 20),
                      _legend("Fail ($_failCount)", const Color(0xFFE84848)),
                    ]),
                    const SizedBox(height: 8),
                  ])),
                  // Table
                  SingleChildScrollView(child: _gradeTable()),
                  // Heatmap
                  _chartPanel("Grade Intensity Heatmap", _heatmap()),
                  // CDF
                  _chartPanel("Cumulative Distribution (CDF)", _cdfChart()),
                ]),
              ),

              const SizedBox(height: 24),

              // Download + reset
              Center(child: Column(children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  icon: const Icon(Icons.download, color: Colors.black),
                  label: const Text("Download Graded Excel", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _download,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text("Process Another File"),
                  onPressed: _reset,
                ),
              ])),
              const SizedBox(height: 30),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _chartPanel(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Expanded(child: chart),
      ]),
    );
  }

  Widget _legend(String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(color: color, fontSize: 12)),
  ]);

  // ── AI column-mapping preview dialog ──────────────────────────────
  // Lets the user see exactly how the backend matched the division names
  // they entered to the columns in the uploaded Excel, and lets them
  // override the mapping if the AI guessed wrong.
  void _showMappingPreview() {
    final sheets = _detectedSheets;
    if (sheets == null || sheets.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(builder: (dialogCtx, setDialogState) {
        return Dialog(
          backgroundColor: const Color(0xFF0D1B3E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(child: Text("AI Column Mapping",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ]),
                const Text(
                  "This is how the AI matched your division names to the columns in your Excel. "
                  "Tap any row to override the match if it guessed wrong.",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(children: [
                    for (final sheet in sheets) _mappingSheetCard(sheet, setDialogState),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text("Close", style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
                    icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                    label: const Text("Re-grade with overrides", style: TextStyle(color: Colors.white)),
                    onPressed: _mappingOverride.isEmpty
                        ? null
                        : () {
                            Navigator.pop(dialogCtx);
                            _recalculateWithOverrides();
                          },
                  ),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _mappingSheetCard(Map<String, dynamic> sheet, StateSetter setDialogState) {
    final name = sheet['sheet_name'] as String? ?? '';
    final isTeam = sheet['is_team_sheet'] == true;
    final available = List<String>.from(
        (sheet['division_columns'] as List<dynamic>? ?? []).map((e) => e.toString()));
    final mapping = Map<String, dynamic>.from(sheet['mapping'] as Map? ?? {});
    final confidence = Map<String, dynamic>.from(sheet['confidence'] as Map? ?? {});
    final current = _mappingOverride[name] ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isTeam ? Icons.groups : Icons.person, color: Colors.blue.shade200, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (isTeam ? Colors.purple : Colors.blue).shade800,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(isTeam ? 'TEAM' : 'INDIVIDUAL',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 10),
        ...mapping.entries.map((e) {
          final division = e.key;
          final guessed = e.value as String?;
          final overridden = current[division];
          final effective = overridden ?? guessed;
          final score = (confidence[division] as num?)?.toDouble() ?? 0.0;
          final scoreColor = score >= 90
              ? Colors.green.shade300
              : score >= 70
                  ? Colors.amber.shade300
                  : Colors.red.shade300;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(
                flex: 2,
                child: Text(division,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white30, size: 14),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: DropdownButton<String?>(
                  value: available.contains(effective) ? effective : null,
                  hint: const Text('(no match)', style: TextStyle(color: Colors.red, fontSize: 12)),
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0D1B3E),
                  iconSize: 16,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('(ignore)', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ),
                    ...available.map((h) => DropdownMenuItem<String?>(
                          value: h,
                          child: Text(h, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (newVal) => setDialogState(() {
                    final sheetOverrides = _mappingOverride.putIfAbsent(name, () => {});
                    if (newVal == null) {
                      sheetOverrides.remove(division);
                    } else {
                      sheetOverrides[division] = newVal;
                    }
                    if (sheetOverrides.isEmpty) _mappingOverride.remove(name);
                  }),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text('${score.toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: scoreColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  Future<void> _recalculateWithOverrides() async {
    final fileId = _lastFileId;
    if (fileId == null) return;
    setState(() {
      _isProcessing = true;
      _status = 'Recalculating with your overrides…';
      _lastError = null;
      _chartData = [];
    });
    try {
      final body = {
        'file_id': fileId,
        'divisions': widget.divisions,
        'template_id': widget.templateId,
        'auto_detect': _aiMode,
        'mapping_override': _mappingOverride,
        if (widget.templateId == 'manual' && widget.manualBoundaries != null)
          'manual_boundaries': widget.manualBoundaries,
      };
      final calc = await http.post(
        Uri.parse('$url/calculate-grades'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (calc.statusCode != 200) {
        throw Exception('Recalc failed (HTTP ${calc.statusCode}): ${calc.body}');
      }
      final d = json.decode(calc.body);
      setState(() {
        _isProcessing = false;
        _status = 'Grades recalculated with your overrides.';
        _downloadUrl = '${url.replaceAll('/api', '')}${d['download_url']}';
        _chartData = d['chart_data'] ?? [];
        _stats = Map<String, dynamic>.from(d['stats'] ?? {});
        _divisionBreakdown = d['division_breakdown'] ?? {};
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _lastError = e.toString().replaceFirst('Exception: ', '');
        _status = 'Error occurred.';
      });
    }
  }
}
