import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:pie_chart/pie_chart.dart';

import 'download_helper.dart';
import 'excel_service.dart';
import 'final.dart';
import 'history.dart';
import 'jk.dart';

// ── Static grade data for each preset template (index-matched to API list) ──
const List<List<Map<String, String>>> _kTemplateGrades = [
  // strict
  [
    {'g': 'A Grade', 'f': 'μ+1.5σ'}, {'g': 'A- Grade', 'f': 'μ+1σ'},
    {'g': 'B Grade', 'f': 'μ+0.5σ'}, {'g': 'B- Grade', 'f': 'μ'},
    {'g': 'C Grade', 'f': 'μ-0.5σ'}, {'g': 'C- Grade', 'f': 'μ-1σ'},
    {'g': 'D Grade', 'f': 'μ-1.5σ'}, {'g': 'F Grade', 'f': '<μ-1.5σ'},
  ],
  // moderate
  [
    {'g': 'A Grade', 'f': 'μ+1σ'},   {'g': 'A- Grade', 'f': 'μ+0.5σ'},
    {'g': 'B Grade', 'f': 'μ'},      {'g': 'B- Grade', 'f': 'μ-0.5σ'},
    {'g': 'C Grade', 'f': 'μ-1σ'},   {'g': 'C- Grade', 'f': 'μ-1.5σ'},
    {'g': 'D Grade', 'f': 'μ-2σ'},   {'g': 'F Grade',  'f': '<μ-2σ'},
  ],
  // lenient
  [
    {'g': 'A Grade', 'f': 'μ+2σ'},   {'g': 'A- Grade', 'f': 'μ+1.5σ'},
    {'g': 'B Grade', 'f': 'μ+0.8σ'}, {'g': 'B- Grade', 'f': 'μ+0.2σ'},
    {'g': 'C Grade', 'f': 'μ-0.5σ'}, {'g': 'C- Grade', 'f': 'μ-1σ'},
    {'g': 'D Grade', 'f': 'μ-1.5σ'}, {'g': 'F Grade',  'f': '<μ-1.5σ'},
  ],
  // bellcurve
  [
    {'g': 'A Grade', 'f': 'μ+2.5σ'}, {'g': 'A- Grade', 'f': 'μ+2σ'},
    {'g': 'B Grade', 'f': 'μ+1σ'},   {'g': 'B- Grade', 'f': 'μ'},
    {'g': 'C Grade', 'f': 'μ-1σ'},   {'g': 'C- Grade', 'f': 'μ-2σ'},
    {'g': 'D Grade', 'f': 'μ-2.5σ'}, {'g': 'F Grade',  'f': '<μ-2.5σ'},
  ],
  // flat
  [
    {'g': 'A Grade', 'f': 'μ+1.5σ'}, {'g': 'A- Grade', 'f': 'μ+1σ'},
    {'g': 'B Grade', 'f': 'μ+0.5σ'}, {'g': 'B- Grade', 'f': 'μ'},
    {'g': 'C Grade', 'f': 'μ-0.5σ'}, {'g': 'C- Grade', 'f': 'μ-1σ'},
    {'g': 'D Grade', 'f': 'μ-1.5σ'}, {'g': 'F Grade',  'f': '<μ-1.5σ'},
  ],
];

class Super extends StatefulWidget {
  const Super({
    super.key,
    required this.s,
    this.batch = '25-29',
    this.department = 'CSE',
    this.section,
    this.startInAiMode = false,
  });

  /// Division names entered in the dashboard.
  final List<String> s;
  final String batch;
  final String department;
  final String? section;

  /// If true, the user chose "Skip template — upload my own Excel (AI)" on
  /// the dashboard; jump straight into the AI-upload screen.
  final bool startInAiMode;

  @override
  State<Super> createState() => _SuperState();
}

class _SuperState extends State<Super> {
  List<dynamic> _templates = [];
  String? _template;
  bool _isLoadingTemplates = true;

  // Manual template state
  final List<Map<String, String>> _manualRows = [
    {'grade': 'A Grade', 'formula': 'μ+1.5σ'},
    {'grade': 'B Grade', 'formula': 'μ+0.5σ'},
    {'grade': 'C Grade', 'formula': 'μ-0.5σ'},
    {'grade': 'F Grade', 'formula': '<μ-0.5σ'},
  ];
  final List<TextEditingController> _gradeControllers = [];
  final List<TextEditingController> _formulaControllers = [];

  void _syncManualControllers() {
    while (_gradeControllers.length < _manualRows.length) {
      final i = _gradeControllers.length;
      _gradeControllers.add(TextEditingController(text: _manualRows[i]['grade']));
      _formulaControllers.add(TextEditingController(text: _manualRows[i]['formula']));
    }
    while (_gradeControllers.length > _manualRows.length) {
      _gradeControllers.removeLast().dispose();
      _formulaControllers.removeLast().dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncManualControllers();
    _loadTemplates();
    if (widget.startInAiMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openGradingPage(aiMode: true));
    }
  }

  @override
  void dispose() {
    for (final c in _gradeControllers) {
      c.dispose();
    }
    for (final c in _formulaControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final response = await http.get(Uri.parse('$url/templates'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _templates = data['templates'];
          _template = _templates.isNotEmpty ? _templates[0]['id'] as String : null;
          _isLoadingTemplates = false;
        });
      } else {
        setState(() => _isLoadingTemplates = false);
      }
    } catch (_) {
      setState(() => _isLoadingTemplates = false);
    }
  }

  // ── Build a single grade row chip pair ──
  Widget _gradeRow(String grade, String formula) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(children: [
        Expanded(child: _chip(grade, Colors.white)),
        const SizedBox(width: 8),
        Expanded(child: _chip(formula, Colors.amberAccent)),
      ]),
    );
  }

  Widget _chip(String text, Color textColor) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white54),
        borderRadius: BorderRadius.circular(80),
        color: Colors.black,
      ),
      child: Center(child: Text(text, style: TextStyle(color: textColor, fontSize: 14))),
    );
  }

  Widget _buildTemplateCard(int idx) {
    if (idx >= _templates.length) return const SizedBox.shrink();
    final grades = idx < _kTemplateGrades.length ? _kTemplateGrades[idx] : <Map<String, String>>[];
    final id = _templates[idx]['id'] as String;
    final name = (_templates[idx]['name'] ?? id) as String;
    final selected = _template == id;

    return GestureDetector(
      onTap: () {
        setState(() => _template = id);
        showAdaptiveDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(50),
              child: Column(children: [Lottie.asset("assets/done.json")]),
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? Colors.blue.shade300 : Colors.white,
            width: selected ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(24),
          color: Colors.black,
          boxShadow: selected
              ? [BoxShadow(color: Colors.blue.shade700, blurRadius: 14, spreadRadius: 2)]
              : [],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              gradient: LinearGradient(colors: [Colors.black, Colors.blue.shade900, Colors.black]),
            ),
            child: Column(children: [
              Text(id.toUpperCase(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(name, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(children: [
              Expanded(child: Center(child: Text("Grade", style: TextStyle(color: Colors.blue.shade200, fontSize: 11, fontWeight: FontWeight.w600)))),
              const SizedBox(width: 8),
              Expanded(child: Center(child: Text("μ±σ Boundary", style: TextStyle(color: Colors.blue.shade200, fontSize: 11, fontWeight: FontWeight.w600)))),
            ]),
          ),
          const SizedBox(height: 4),
          ...grades.map((r) => _gradeRow(r['g']!, r['f']!)),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _buildManualCard() {
    final selected = _template == 'manual';
    return StatefulBuilder(builder: (context, setCardState) {
      return GestureDetector(
        onTap: () {
          for (int i = 0; i < _manualRows.length; i++) {
            _manualRows[i]['grade'] = _gradeControllers[i].text;
            _manualRows[i]['formula'] = _formulaControllers[i].text;
          }
          setState(() => _template = 'manual');
          showAdaptiveDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(50),
                child: Column(children: [Lottie.asset("assets/done.json")]),
              ),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Colors.blue.shade300 : Colors.white,
              width: selected ? 2.5 : 1,
            ),
            borderRadius: BorderRadius.circular(24),
            color: Colors.black,
            boxShadow: selected
                ? [BoxShadow(color: Colors.blue.shade700, blurRadius: 14, spreadRadius: 2)]
                : [],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(colors: [Colors.black, Colors.blue.shade900, Colors.black]),
              ),
              child: const Column(children: [
                Text("MANUAL",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Text("Define your own μ±σ boundaries", style: TextStyle(fontSize: 11, color: Colors.white54)),
              ]),
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < _manualRows.length; i++) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _gradeControllers[i],
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      hintText: 'Grade',
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _formulaControllers[i],
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      hintText: 'μ+1σ',
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 18),
                  onPressed: _manualRows.length <= 2
                      ? null
                      : () => setCardState(() {
                            _manualRows.removeAt(i);
                            _syncManualControllers();
                          }),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextButton.icon(
                icon: const Icon(Icons.add, color: Colors.white, size: 16),
                label: const Text("Add row", style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () => setCardState(() {
                  _manualRows.add({'grade': 'X Grade', 'formula': 'μ'});
                  _syncManualControllers();
                }),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      );
    });
  }

  /// Context label for the header (e.g. "CSE-A  •  25-29").
  String get _scopeLabel {
    final sec = widget.section == null ? '' : '-${widget.section}';
    return '${widget.department}$sec  •  ${widget.batch}';
  }

  void _openGradingPage({required bool aiMode}) {
    if (_template == null && !aiMode) return;
    // Sync manual rows if needed
    for (int i = 0; i < _manualRows.length; i++) {
      _manualRows[i]['grade'] = _gradeControllers[i].text;
      _manualRows[i]['formula'] = _formulaControllers[i].text;
    }
    final manualBoundaries = _template == 'manual'
        ? {for (final r in _manualRows) r['grade']!: r['formula']!}
        : null;

    final divisionMap = {for (final name in widget.s) name: 0};

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessGradesPage(
          divisions: divisionMap,
          templateId: _template ?? 'strict',
          manualBoundaries: manualBoundaries,
          startInAiMode: aiMode,
          scope: _scopeLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Grading — $_scopeLabel',
            style: GoogleFonts.inconsolata(color: Colors.white, fontSize: 20)),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryPage())),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: isWide ? const AssetImage('assets/pc.png') : const AssetImage('assets/e.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _stepCard(
              number: 1,
              title: 'Download Excel template',
              subtitle:
                  'Template has the reg-no column, Max Marks row and Weight % row — fill inside Excel.',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text('Download Excel Template',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _showTemplateDialog,
                ),
              ]),
            ),
            const SizedBox(height: 18),
            _stepCard(
              number: 2,
              title: 'Pick a grading curve',
              subtitle: 'Preset μ±σ curves, or define your own.',
              child: _isLoadingTemplates
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator(color: Colors.white)),
                    )
                  : Column(children: [
                      for (int i = 0; i < _templates.length; i++) _buildTemplateCard(i),
                      _buildManualCard(),
                    ]),
            ),
            const SizedBox(height: 18),
            _stepCard(
              number: 3,
              title: 'Upload filled Excel & calculate grades',
              subtitle:
                  'Use the template you downloaded, OR upload any Excel — AI will auto-detect columns.',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _template == null ? Colors.grey.shade700 : Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload template & calculate',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _template == null ? null : () => _openGradingPage(aiMode: false),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Upload ANY Excel (AI auto-detect)'),
                  onPressed: () => _openGradingPage(aiMode: true),
                ),
              ]),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }

  Widget _stepCard({
    required int number,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.blue.shade700,
            child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 38),
          child: Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Template download dialog
  // ─────────────────────────────────────────────────────────
  Future<void> _showTemplateDialog() async {
    final hasTeam = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Team Divisions?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are there team divisions for $_scopeLabel?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('No — Individual only', style: TextStyle(color: Colors.blue.shade300))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
              child: const Text('Yes — choose team divisions',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (hasTeam == null) return;
    if (hasTeam) {
      await _showTeamDivisionsDialog();
    } else {
      await _downloadIndividualTemplate(widget.s);
    }
  }

  Future<void> _showTeamDivisionsDialog() async {
    final selected = <String>{};
    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B3E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Choose Team Divisions',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select the divisions that are team-wise. Max Marks and '
                  'Weight % are filled in the Excel file — not here.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ...widget.s.map((division) {
                  final isSelected = selected.contains(division);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.green.shade900.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.green.shade500 : Colors.white12,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      activeColor: Colors.green.shade600,
                      checkColor: Colors.white,
                      title: Text(division,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                      onChanged: (value) => setS(() {
                        if (value == true) {
                          selected.add(division);
                        } else {
                          selected.remove(division);
                        }
                      }),
                    ),
                  );
                }),
                if (selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'This creates one individual template and one separate team template.',
                      style: TextStyle(color: Colors.green.shade300, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      selected.isEmpty ? Colors.grey.shade700 : Colors.green.shade700),
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(dialogCtx);
                      await _downloadTeamTemplates(selected);
                    },
              child: const Text('Download Templates', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _filePrefix() {
    final sec = widget.section == null ? '' : '_${widget.section}';
    return '${widget.batch}_${widget.department}$sec';
  }

  Future<void> _downloadIndividualTemplate(List<String> names) async {
    try {
      final bytes = ExcelService.generateIndividualTemplate(
        batch: widget.batch,
        dept: widget.department,
        section: widget.section,
        divisionNames: names,
      );
      await _saveFile(bytes, '${_filePrefix()}_individual_template.xlsx');
    } catch (e) {
      _snack('Error: $e', err: true);
    }
  }

  Future<void> _downloadTeamTemplates(Set<String> teamNames) async {
    try {
      final individualNames = widget.s.where((n) => !teamNames.contains(n)).toList();
      if (individualNames.isNotEmpty) {
        final bytes = ExcelService.generateIndividualTemplate(
          batch: widget.batch,
          dept: widget.department,
          section: widget.section,
          divisionNames: individualNames,
        );
        await _saveFile(bytes, '${_filePrefix()}_individual_template.xlsx');
      }
      final teamBytes = ExcelService.generateTeamTemplate(
        batch: widget.batch,
        dept: widget.department,
        section: widget.section,
        teamDivisionNames: teamNames.toList(),
      );
      await _saveFile(teamBytes, '${_filePrefix()}_team_template.xlsx');
    } catch (e) {
      _snack('Error: $e', err: true);
    }
  }

  Future<void> _saveFile(Uint8List bytes, String filename) async {
    final where = await saveBytes(bytes: bytes, suggestedName: filename);
    if (!mounted) return;
    if (where == null) {
      _snack('Save cancelled');
    } else {
      _snack('Template saved: $filename');
    }
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: err ? Colors.red.shade700 : Colors.green.shade700,
      duration: const Duration(seconds: 3),
    ));
  }
}

// Pie chart helper kept for parity with the rest of the app (not used in
// this screen after the redesign but other screens import from here).
Widget kPieChart(Map<String, double> data) {
  return PieChart(dataMap: data);
}
