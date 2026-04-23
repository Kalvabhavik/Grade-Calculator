import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import "package:pie_chart/pie_chart.dart";
import "package:http/http.dart" as http;
import "dart:convert";
import "dart:typed_data";
import "package:file_selector/file_selector.dart";
import "jk.dart";
import "final.dart";
import "history.dart";
import "excel_service.dart";
import "package:lottie/lottie.dart";

// ── Static grade data for each preset template (index-matched to API list) ──
const List<List<Map<String, String>>> _kTemplateGrades = [
  // index 0
  [
    {'g': 'A Grade',  'f': 'μ+1.5σ'}, {'g': 'A- Grade', 'f': 'μ+1σ'},
    {'g': 'B Grade',  'f': 'μ+0.5σ'}, {'g': 'B- Grade', 'f': 'μ'},
    {'g': 'C Grade',  'f': 'μ-0.5σ'}, {'g': 'C- Grade', 'f': 'μ-1σ'},
    {'g': 'D Grade',  'f': 'μ-1.5σ'}, {'g': 'F Grade',  'f': '<μ-1.5σ'},
  ],
  // index 1 (placeholder – same as 0 if API changes)
  [
    {'g': 'A Grade',  'f': 'μ+1.5σ'}, {'g': 'A- Grade', 'f': 'μ+1σ'},
    {'g': 'B Grade',  'f': 'μ+0.5σ'}, {'g': 'B- Grade', 'f': 'μ'},
    {'g': 'C Grade',  'f': 'μ-0.5σ'}, {'g': 'C- Grade', 'f': 'μ-1σ'},
    {'g': 'D Grade',  'f': 'μ-1.5σ'}, {'g': 'F Grade',  'f': '<μ-1.5σ'},
  ],
  // index 2
  [
    {'g': 'A Grade',  'f': 'μ+1σ'},   {'g': 'A- Grade', 'f': 'μ+0.5σ'},
    {'g': 'B Grade',  'f': 'μ'},      {'g': 'B- Grade', 'f': 'μ-0.5σ'},
    {'g': 'C Grade',  'f': 'μ-1σ'},   {'g': 'C- Grade', 'f': 'μ-1.5σ'},
    {'g': 'D Grade',  'f': 'μ-2σ'},   {'g': 'F Grade',  'f': '<μ-2σ'},
  ],
  // index 3
  [
    {'g': 'A Grade',  'f': 'μ+2.5σ'}, {'g': 'A- Grade', 'f': 'μ+2σ'},
    {'g': 'B Grade',  'f': 'μ+1σ'},   {'g': 'B- Grade', 'f': 'μ'},
    {'g': 'C Grade',  'f': 'μ-1σ'},   {'g': 'C- Grade', 'f': 'μ-2σ'},
    {'g': 'D Grade',  'f': 'μ-2.5σ'}, {'g': 'F Grade',  'f': '<μ-2.5σ'},
  ],
  // index 4
  [
    {'g': 'A Grade',  'f': 'μ+2σ'},   {'g': 'A- Grade', 'f': 'μ+1.5σ'},
    {'g': 'B Grade',  'f': 'μ+0.8σ'}, {'g': 'B- Grade', 'f': 'μ+0.2σ'},
    {'g': 'C Grade',  'f': 'μ-0.5σ'}, {'g': 'C- Grade', 'f': 'μ-1σ'},
    {'g': 'D Grade',  'f': 'μ-1.5σ'}, {'g': 'F Grade',  'f': '<μ-1.5σ'},
  ],
];

class Super extends StatefulWidget {
  const Super({
    super.key,
    required this.s,
    required this.bu,
    this.batch = '25-29',
    this.department = 'CSE',
    this.section,
  });
  final List<String> s;
  final List<String> bu;
  final String batch;
  final String department;
  final String? section;

  @override
  State<Super> createState() => _SuperState();
}

class _SuperState extends State<Super> {
  List _templates = [];
  String? _template;
  bool _isloadingtempltes = true;
  Map<String, double> datas = {};

  // Manual template state
  List<Map<String, String>> _manualRows = [
    {'grade': 'A Grade', 'formula': 'μ+1.5σ'},
    {'grade': 'B Grade', 'formula': 'μ+0.5σ'},
    {'grade': 'C Grade', 'formula': 'μ-0.5σ'},
    {'grade': 'F Grade', 'formula': '<μ-0.5σ'},
  ];
  final List<TextEditingController> _gradeControllers = [];
  final List<TextEditingController> _formulaControllers = [];

  void _syncManualControllers() {
    while (_gradeControllers.length < _manualRows.length) {
      int i = _gradeControllers.length;
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
    _dash();
    for (int i = 0; i < widget.s.length; i++) {
      datas[widget.s[i]] = double.parse(widget.bu[i]);
    }
    _syncManualControllers();
  }

  @override
  void dispose() {
    for (var c in _gradeControllers) { c.dispose(); }
    for (var c in _formulaControllers) { c.dispose(); }
    super.dispose();
  }

  Future<void> _dash() async {
    try {
      final response = await http.get(Uri.parse('$url/templates'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _templates = data['templates'];
          _template = _templates.isNotEmpty ? _templates[0]['id'] : null;
          _isloadingtempltes = false;
        });
      } else {
        setState(() { _isloadingtempltes = false; });
      }
    } catch (e) {
      setState(() { _isloadingtempltes = false; });
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

  // ── Build a preset template card ──
  Widget _buildTemplateCard(int idx) {
    // Issue #6: guard against out-of-bounds
    if (idx >= _templates.length) return const SizedBox.shrink();
    final grades = idx < _kTemplateGrades.length ? _kTemplateGrades[idx] : <Map<String,String>>[];
    final id = _templates[idx]['id'] as String;
    final name = (_templates[idx]['name'] ?? id) as String;
    final bool selected = _template == id;

    return GestureDetector(
      onTap: () {
        setState(() { _template = id; });
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
          // Header
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
          // Column labels
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

  // B8 FIX: _syncManualControllers only called from initState & explicit mutations,
  // NOT from build() — side effects in build() cause subtle state bugs.
  Widget _buildManualCard() {
    // Do NOT call _syncManualControllers() here.
    final bool selected = _template == 'manual';
    return StatefulBuilder(builder: (context, setCardState) {
      return GestureDetector(
        onTap: () {
          for (int i = 0; i < _manualRows.length; i++) {
            _manualRows[i]['grade'] = _gradeControllers[i].text;
            _manualRows[i]['formula'] = _formulaControllers[i].text;
          }
          setState(() { _template = 'manual'; });
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
            border: Border.all(color: selected ? Colors.blue.shade300 : Colors.white, width: selected ? 2.5 : 1),
            borderRadius: BorderRadius.circular(24),
            color: Colors.black,
            boxShadow: selected ? [BoxShadow(color: Colors.blue.shade700, blurRadius: 14, spreadRadius: 2)] : [],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(colors: [Colors.black, Colors.blue.shade900, Colors.black]),
              ),
              child: const Center(child: Text("MANUAL TEMPLATE",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(children: [
                Expanded(child: Center(child: Text("Grade", style: TextStyle(color: Colors.blue.shade200, fontSize: 11, fontWeight: FontWeight.w600)))),
                const SizedBox(width: 8),
                Expanded(child: Center(child: Text("μ±σ Formula", style: TextStyle(color: Colors.blue.shade200, fontSize: 11, fontWeight: FontWeight.w600)))),
                const SizedBox(width: 32),
              ]),
            ),
            const SizedBox(height: 4),
            ...List.generate(_manualRows.length, (i) => Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
              child: Row(children: [
                Expanded(child: _editableChip(_gradeControllers[i], Colors.white, (v) => _manualRows[i]['grade'] = v)),
                const SizedBox(width: 6),
                Expanded(child: _editableChip(_formulaControllers[i], Colors.amberAccent, (v) => _manualRows[i]['formula'] = v)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    if (_manualRows.length > 1) {
                      _gradeControllers[i].dispose();
                      _formulaControllers[i].dispose();
                      setCardState(() {
                        _manualRows.removeAt(i);
                        _gradeControllers.removeAt(i);
                        _formulaControllers.removeAt(i);
                      });
                    }
                  },
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.shade900.withOpacity(0.7)),
                    child: const Icon(Icons.remove, size: 14, color: Colors.white),
                  ),
                ),
              ]),
            )),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setCardState(() {
                  _manualRows.add({'grade': 'New Grade', 'formula': 'μ'});
                  _gradeControllers.add(TextEditingController(text: 'New Grade'));
                  _formulaControllers.add(TextEditingController(text: 'μ'));
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 30),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.shade300),
                  borderRadius: BorderRadius.circular(40),
                  color: Colors.blue.shade900.withOpacity(0.3),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add, color: Colors.blue.shade200, size: 16),
                  const SizedBox(width: 6),
                  Text("Add Grade Row", style: TextStyle(color: Colors.blue.shade200, fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                "Tap card to select. Use μ and σ in formulas (e.g. μ+1.5σ, μ-1σ).",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      );
    });
  }

  Widget _editableChip(TextEditingController ctrl, Color textColor, ValueChanged<String> onChanged) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white38),
        borderRadius: BorderRadius.circular(80),
        color: Colors.white10,
      ),
      child: Center(
        child: TextField(
          controller: ctrl,
          onChanged: onChanged,
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontSize: 12),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          elevation: 10,
          shadowColor: Colors.white60,
          leading: BackButton(
            color: Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: [
                Colors.black, Colors.blue.shade900, Colors.blue.shade900, Colors.black
              ]),
            ),
          ),
          title: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 50, 50, 50),
              child: Text("Division",
                  style: GoogleFonts.inconsolata(
                    color: Colors.white,
                    fontSize: MediaQuery.of(context).size.width > 1000
                        ? MediaQuery.of(context).size.width * 0.041
                        : MediaQuery.of(context).size.width * 0.098,
                  )),
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              ),
              icon: const Icon(Icons.history, color: Colors.white),
              tooltip: "Grading History",
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
                colors: [Colors.blue.shade900, Colors.black], radius: 0.63),
          ),
          height: double.infinity,
          width: double.infinity,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Division names + pie chart ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(60, 39, 8, 10),
                  child: Row(children: [
                    _labelBadge("DIVISION"),
                    const SizedBox(width: 60),
                    _labelBadge("%"),
                  ]),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    // Division list
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: SizedBox(
                        height: 600,
                        width: 340,
                        child: ListView.builder(
                          itemCount: widget.s.length,
                          itemBuilder: (context, i) => Row(children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(15, 10, 8, 15),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                height: 60, width: 200,
                                child: Center(child: Text(widget.s[i],
                                    style: const TextStyle(color: Colors.white, fontSize: 22))),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 5, 15),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                height: 50, width: 90,
                                child: Center(child: Text(widget.bu[i],
                                    style: const TextStyle(color: Colors.white, fontSize: 18))),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 200),
                    // Pie chart
                    if (datas.isNotEmpty)
                      PieChart(
                        dataMap: datas,
                        animationDuration: const Duration(milliseconds: 1000),
                        chartLegendSpacing: 32,
                        chartRadius: MediaQuery.of(context).size.width / 4,
                        colorList: const [
                          Colors.blue, Colors.orange, Colors.purple,
                          Colors.green, Colors.red, Colors.cyan
                        ],
                        chartType: ChartType.disc,
                        legendOptions: const LegendOptions(
                          legendPosition: LegendPosition.right,
                          showLegends: true,
                          legendTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        chartValuesOptions: const ChartValuesOptions(
                          showChartValues: true,
                          showChartValuesInPercentage: true,
                          decimalPlaces: 0,
                        ),
                      ),
                    const SizedBox(width: 350),

                    // ── Template cards ──
                    SizedBox(
                      // Issue #5: responsive width, unbounded height (shrinkwrap)
                      width: 300,
                      child: _isloadingtempltes
                          ? SizedBox(height: 300, child: Lottie.asset("assets/div.json"))
                          : Column(
                              children: [
                                // Issue #6: guard with isNotEmpty / length checks
                                // Issue #12: dynamic loop instead of copy-paste
                                ...List.generate(
                                  _templates.length.clamp(0, _kTemplateGrades.length),
                                  (i) => _buildTemplateCard(i),
                                ),
                                _buildManualCard(),
                              ],
                            ),
                    ),
                  ]),
                ),

                // ── Select Grading Curve dropdown ──
                const Padding(
                  padding: EdgeInsets.fromLTRB(30, 20, 30, 0),
                  child: Text("Select Grading Curve:",
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white),
                    ),
                    child: _isloadingtempltes
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(color: Colors.white))
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: Colors.blue.shade900,
                              value: _template,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              items: [
                                ..._templates.map<DropdownMenuItem<String>>((t) =>
                                    DropdownMenuItem<String>(
                                      value: t['id'] as String,
                                      child: Text("${t['name']} — ${t['tag']}"),
                                    )),
                                const DropdownMenuItem<String>(
                                  value: 'manual',
                                  child: Text("Custom Manual — Define your own μ±σ"),
                                ),
                              ],
                              onChanged: (v) => setState(() { _template = v; }),
                            ),
                          ),
                  ),
                ),

                // Issue #7: warning when no template selected
                if (_template == null)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(30, 8, 30, 0),
                    child: Text("⚠️  Please select or tap a grading curve above.",
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 13)),
                  ),

                const SizedBox(height: 20),

                // ── Download Excel Template button ──
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text("Download Excel Template", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: () => _showTemplateDialog(context),
                  ),
                ),

                const SizedBox(height: 40),

                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      // Issue #7: disable when no template selected
                      backgroundColor: _template != null ? Colors.white : Colors.grey.shade700,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _template == null
                        ? null
                        : () {
                            final Map<String, int> divisionMap = {};
                            for (int i = 0; i < widget.s.length; i++) {
                              divisionMap[widget.s[i]] = int.parse(widget.bu[i]);
                            }
                            // Sync manual controllers → rows
                            for (int i = 0; i < _manualRows.length; i++) {
                              _manualRows[i]['grade'] = _gradeControllers[i].text;
                              _manualRows[i]['formula'] = _formulaControllers[i].text;
                            }
                            final Map<String, String>? manualBoundaries = _template == 'manual'
                                ? {for (var r in _manualRows) r['grade']!: r['formula']!}
                                : null;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProcessGradesPage(
                                  divisions: divisionMap,
                                  templateId: _template!,
                                  manualBoundaries: manualBoundaries,
                                ),
                              ),
                            );
                          },
                    child: Text(
                      "CALCULATE GRADES",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _template != null ? Colors.black : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _labelBadge(String text) => Container(
        height: 50,
        width: text == "%" ? 65 : 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.black, Colors.blue.shade900, Colors.black]),
          border: Border.all(color: Colors.white),
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [BoxShadow(blurRadius: 8, spreadRadius: 1, color: Colors.white)],
        ),
        child: Center(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 20))),
      );

  // ── Build divisions map with max marks from user input ──
  Map<String, int> _buildDivisionsMap() {
    final map = <String, int>{};
    for (int i = 0; i < widget.s.length; i++) {
      map[widget.s[i]] = int.tryParse(widget.bu[i]) ?? 0;
    }
    return map;
  }

  Map<String, int> _filterDivisions(Set<String> names) {
    final all = _buildDivisionsMap();
    return {
      for (final entry in all.entries)
        if (names.contains(entry.key)) entry.key: entry.value,
    };
  }

  String _filePrefix() {
    final section = widget.section == null ? '' : '_${widget.section}';
    return '${widget.batch}_${widget.department}$section';
  }

  // ── Template download dialog ──
  Future<void> _showTemplateDialog(BuildContext ctx) async {
    // Ask if team divisions exist
    final hasTeam = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Team Divisions?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are there team divisions for ${widget.section != null ? '${widget.department}-${widget.section}' : widget.department}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('No - Individual Only', style: TextStyle(color: Colors.blue.shade300))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            child: const Text('Yes - Choose Team Divisions', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (hasTeam == null) return;

    if (hasTeam) {
      await _showTeamDivisionsDialog(ctx);
    } else {
      await _downloadIndividualTemplate(ctx);
    }
  }

  Future<void> _showTeamDivisionsDialog(BuildContext ctx) async {
    final selected = <String>{};

    await showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B3E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Choose Team Divisions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select the divisions that are team-wise. Max marks are filled in the Excel file, not here.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ...widget.s.map((division) {
                  final isSelected = selected.contains(division);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.green.shade900.withOpacity(0.35)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.green.shade500 : Colors.white12,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      activeColor: Colors.green.shade600,
                      checkColor: Colors.white,
                      title: Text(
                        division,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${_buildDivisionsMap()[division] ?? 0}% weight',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
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
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: selected.isEmpty ? Colors.grey.shade700 : Colors.green.shade700),
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(dialogCtx);
                      await _downloadTeamTemplates(ctx, selected);
                    },
              child: const Text('Download Templates', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Download helpers ──
  Future<void> _downloadIndividualTemplate(BuildContext ctx) async {
    try {
      final bytes = ExcelService.generateIndividualTemplate(
        batch: widget.batch,
        dept: widget.department,
        section: widget.section,
        divisions: _buildDivisionsMap(),
      );
      await _saveFile(bytes, '${_filePrefix()}_individual_template.xlsx', ctx);
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  Future<void> _downloadTeamTemplates(BuildContext ctx, Set<String> teamNames) async {
    try {
      final all = _buildDivisionsMap();
      final individualNames = all.keys.where((name) => !teamNames.contains(name)).toSet();
      final individualBytes = ExcelService.generateIndividualTemplate(
        batch: widget.batch,
        dept: widget.department,
        section: widget.section,
        divisions: _filterDivisions(individualNames),
      );
      await _saveFile(individualBytes, '${_filePrefix()}_individual_template.xlsx', ctx);

      final teamBytes = ExcelService.generateTeamTemplate(
        batch: widget.batch,
        dept: widget.department,
        section: widget.section,
        teamDivisions: _filterDivisions(teamNames),
      );
      await _saveFile(teamBytes, '${_filePrefix()}_team_template.xlsx', ctx);
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  Future<void> _saveFile(Uint8List bytes, String filename, BuildContext ctx) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Excel workbook',
          extensions: ['xlsx'],
          mimeTypes: ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
        ),
      ],
      suggestedName: filename,
      confirmButtonText: 'Save',
    );
    if (location == null) return;

    final file = XFile.fromData(
      bytes,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      name: filename,
    );
    await file.saveTo(location.path);

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('Template saved: $filename'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 4),
      ));
    }
  }
}
