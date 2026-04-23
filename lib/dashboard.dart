import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:pragnaleader/division.dart";

class dash extends StatefulWidget {
  const dash({super.key});

  @override
  State<dash> createState() => _dashState();
}

class _dashState extends State<dash> {
  final TextEditingController _divcontroller = TextEditingController();
  final TextEditingController _percontroller = TextEditingController();
  bool com = false;
  int buc = 0;
  int count = 0;

  int num = 5;
  int b = 4;
  int c = 3;

  // Parallel lists: division names and their percentages
  List<String> s = [];
  List<String> bu = [];

  @override
  void dispose() {
    _divcontroller.dispose();
    _percontroller.dispose();
    super.dispose();
  }

  // ── Delete a division entry and update the running sum ──
  void _deleteDivision(int index) {
    setState(() {
      buc -= int.tryParse(bu[index]) ?? 0;
      s.removeAt(index);
      bu.removeAt(index);
      count = s.length;
    });
  }

  // ── Clear all entries ──
  void _clearAll() {
    setState(() {
      s.clear();
      bu.clear();
      buc = 0;
      count = 0;
      _divcontroller.clear();
      _percontroller.clear();
    });
  }

  // ── Add division with validation ──
  void _addDivision() {
    final String div = _divcontroller.text.trim();
    final String per = _percontroller.text.trim();

    if (div.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a division name"), backgroundColor: Colors.red.shade700),
      );
      return;
    }
    final int? parsed = int.tryParse(per);
    if (parsed == null || parsed <= 0 || parsed > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Percentage must be a number between 1 and 100"), backgroundColor: Colors.red.shade700),
      );
      return;
    }
    if (buc + parsed > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Total exceeds 100%. Remaining: ${100 - buc}%"), backgroundColor: Colors.orange.shade700),
      );
      return;
    }
    // B13 FIX: reject duplicate division names
    if (s.contains(div)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Division '$div' already added"), backgroundColor: Colors.red.shade700),
      );
      return;
    }
    setState(() {
      s.add(div);
      bu.add(per);
      buc += parsed;
      count = s.length;
      _divcontroller.clear();
      _percontroller.clear();
    });
  }

  // ── Determine % bar colour ──
  Color _bucColor() {
    if (buc < 80) return Colors.blue.shade400;
    if (buc < 100) return Colors.orange.shade400;
    return Colors.green.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 1000;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black87,
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
                Colors.black,
                Colors.blue.shade900,
                Colors.blue.shade900,
                Colors.black,
              ]),
            ),
          ),
          title: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 50, 50, 50),
              child: Text(
                "Dashboard",
                style: GoogleFonts.inconsolata(
                  color: Colors.white,
                  fontSize: isWide
                      ? MediaQuery.of(context).size.width * 0.041
                      : MediaQuery.of(context).size.width * 0.098,
                ),
              ),
            ),
          ),
        ),
        body: Container(
          height: double.infinity,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: isWide ? AssetImage("assets/pc.png") : AssetImage("assets/e.png"),
              fit: BoxFit.cover,
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              // ─────────────────────────────────────────────────────────
              //  BATCH YEAR SELECTION
              // ─────────────────────────────────────────────────────────
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final entry in [
                      [0, "22-26"],
                      [1, "23-27"],
                      [2, "24-28"],
                      [3, "25-29"],
                    ])
                      _chipButton(
                        label: entry[1] as String,
                        selected: num == entry[0] as int,
                        onTap: () => setState(() {
                          num = num != entry[0] ? entry[0] as int : 5;
                          // reset deeper selections when batch changes
                          if (num == 5) { b = 4; c = 3; com = false; }
                        }),
                        isWide: isWide,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─────────────────────────────────────────────────────────
              //  DEPARTMENT SELECTION (only when batch is chosen)
              // ─────────────────────────────────────────────────────────
              if (num != 5)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final entry in [
                        [0, "CSE"],
                        [1, "ECE"],
                        [2, "DSAI"],
                      ])
                        _chipButtonSm(
                          label: entry[1] as String,
                          selected: b == entry[0] as int,
                          onTap: () => setState(() {
                            if (b != entry[0]) {
                              b = entry[0] as int;
                              com = true;
                            } else {
                              b = 4;
                              com = false;
                            }
                          }),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ─────────────────────────────────────────────────────────
              //  SECTION SELECTION (only CSE has A/B/BOTH)
              // ─────────────────────────────────────────────────────────
              if (b == 0 && num != 5)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final entry in [
                        [0, "CSE-A"],
                        [1, "CSE-B"],
                        [2, "BOTH"],
                      ])
                        _chipButtonSm(
                          label: entry[1] as String,
                          selected: c == entry[0] as int,
                          onTap: () => setState(() {
                            if (c != entry[0]) {
                              c = entry[0] as int;
                              com = true;
                            } else {
                              c = 3;
                              com = false;
                            }
                          }),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // ─────────────────────────────────────────────────────────
              //  DIVISION ENTRY CARD  (only when com == true)
              // ─────────────────────────────────────────────────────────
              if (com)
                Padding(
                  padding: isWide
                      ? const EdgeInsets.fromLTRB(5, 0, 700, 0)
                      : const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Header row ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Divisions   ($count added)",
                              style: GoogleFonts.inconsolata(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (s.isNotEmpty)
                              TextButton.icon(
                                onPressed: _clearAll,
                                icon: Icon(Icons.delete_sweep, size: 16, color: Colors.red.shade700),
                                label: Text("Clear All", style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              ),
                          ],
                        ),

                        // ── % progress bar ──
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: buc / 100,
                                  minHeight: 10,
                                  backgroundColor: Colors.grey.shade300,
                                  valueColor: AlwaysStoppedAnimation<Color>(_bucColor()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "$buc / 100%",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _bucColor(),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ── Live list of added divisions (scrollable) ──
                        if (s.isNotEmpty) ...[
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: s.length,
                              itemBuilder: (context, i) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.blue.shade800,
                                      child: Text(
                                        "${i + 1}",
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                    title: Text(
                                      s[i],
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade800,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            "${bu[i]}%",
                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // ── DELETE BUTTON ──
                                        GestureDetector(
                                          onTap: () => _deleteDivision(i),
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.red.shade600,
                                            ),
                                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(),
                          const SizedBox(height: 8),
                        ],

                        // ── Input fields ──
                        TextField(
                          controller: _divcontroller,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            labelText: "Division name",
                            hintText: "e.g. CSE-A, Div-1 …",
                            prefixIcon: Icon(Icons.label_outline, color: Colors.blue.shade700),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _percontroller,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            labelText: "Percentage",
                            hintText: "e.g. 40  (remaining: ${100 - buc}%)",
                            prefixIcon: Icon(Icons.percent, color: Colors.blue.shade700),
                          ),
                        ),
                        const SizedBox(height: 14),

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text("Add Division", style: TextStyle(fontSize: 15)),
                          onPressed: buc < 100 ? _addDivision : null,
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ─────────────────────────────────────────────────────────
              //  "NEXT STEP" BUTTON — enabled only when total == 100%
              // ─────────────────────────────────────────────────────────
              if (com && s.isNotEmpty)
                Padding(
                  padding: isWide
                      ? const EdgeInsets.fromLTRB(5, 0, 700, 0)
                      : const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (buc != 100)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            buc < 100
                                ? "⚠️  Total is $buc%. Add ${100 - buc}% more to proceed."
                                : "✅  Total is exactly 100% — ready!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: buc < 100 ? Colors.orange.shade300 : Colors.green.shade300,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buc == 100 ? Colors.white : Colors.grey.shade600,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: buc == 100
                            ? () {
                                const batches  = ['22-26', '23-27', '24-28', '25-29'];
                                const depts    = ['CSE', 'ECE', 'DSAI'];
                                final batchStr = num < batches.length ? batches[num] : '25-29';
                                final deptStr  = b < depts.length    ? depts[b]    : 'CSE';
                                // section only for CSE-A (c==0) or CSE-B (c==1); BOTH → null
                                final secStr   = (b == 0 && c < 2) ? ['A', 'B'][c] : null;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Super(
                                      s: s, bu: bu,
                                      batch: batchStr,
                                      department: deptStr,
                                      section: secStr,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: Text(
                          "Next Step  →",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: buc == 100 ? Colors.black : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reusable helper chip (batch year size) ──
  Widget _chipButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isWide,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(60),
        child: Container(
          height: 50,
          width: isWide
              ? MediaQuery.of(context).size.width * 0.20
              : MediaQuery.of(context).size.width * 0.25,
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.4) : Colors.blue.shade900.withOpacity(0.4),
            borderRadius: BorderRadius.circular(60),
            border: Border.all(color: Colors.white),
          ),
          child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 18))),
        ),
      ),
    );
  }

  // ── Reusable helper chip (department / section size) ──
  Widget _chipButtonSm({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(60),
        child: Container(
          height: 38,
          constraints: const BoxConstraints(minWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.4) : Colors.blue.shade900.withOpacity(0.4),
            borderRadius: BorderRadius.circular(60),
            border: Border.all(color: Colors.white),
          ),
          child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16))),
        ),
      ),
    );
  }
}
