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
  bool com = false;
  int count = 0;

  int num = 5;
  int b = 4;
  int c = 3;

  // Division names only — Max Marks and Weight % now live inside the
  // downloaded Excel template, not in the UI.
  List<String> s = [];

  @override
  void dispose() {
    _divcontroller.dispose();
    super.dispose();
  }

  // ── Delete a division entry ──
  void _deleteDivision(int index) {
    setState(() {
      s.removeAt(index);
      count = s.length;
    });
  }

  // ── Clear all entries ──
  void _clearAll() {
    setState(() {
      s.clear();
      count = 0;
      _divcontroller.clear();
    });
  }

  // ── Add division with validation ──
  void _addDivision() {
    final String div = _divcontroller.text.trim();

    if (div.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a division name"), backgroundColor: Colors.red.shade700),
      );
      return;
    }
    if (s.any((existing) => existing.toLowerCase() == div.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Division '$div' already added"), backgroundColor: Colors.red.shade700),
      );
      return;
    }
    setState(() {
      s.add(div);
      count = s.length;
      _divcontroller.clear();
    });
  }

  /// Resolve current chip selections to `(batch, dept, section?)` tuple.
  (String, String, String?) _selection() {
    const batches = ['22-26', '23-27', '24-28', '25-29'];
    const depts = ['CSE', 'ECE', 'DSAI'];
    final batchStr = num < batches.length ? batches[num] : '25-29';
    final deptStr = b < depts.length ? depts[b] : 'CSE';
    // section only for CSE-A (c==0) or CSE-B (c==1); BOTH → null
    final secStr = (b == 0 && c < 2) ? ['A', 'B'][c] : null;
    return (batchStr, deptStr, secStr);
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
                          // reset division inputs when leaving scope
                          if (num == 5) { s.clear(); count = 0; }
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
                              "Divisions   ($count added)  —  names only",

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

                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Max Marks and Weight % now live inside the Excel template — enter just the division names here.",
                                  style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
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

                        // ── Input field (name only) ──
                        TextField(
                          controller: _divcontroller,
                          onSubmitted: (_) => _addDivision(),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            labelText: "Division name",
                            hintText: "e.g. Mid Sem, End Sem, Lab, Project …",
                            prefixIcon: Icon(Icons.label_outline, color: Colors.blue.shade700),
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
                          onPressed: _addDivision,
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ─────────────────────────────────────────────────────────
              //  "NEXT STEP" BUTTONS — enabled when at least one division added
              // ─────────────────────────────────────────────────────────
              if (com)
                Padding(
                  padding: isWide
                      ? const EdgeInsets.fromLTRB(5, 0, 700, 0)
                      : const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: s.isNotEmpty ? Colors.white : Colors.grey.shade600,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: s.isEmpty
                            ? null
                            : () {
                                final (batchStr, deptStr, secStr) = _selection();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Super(
                                      s: s,
                                      batch: batchStr,
                                      department: deptStr,
                                      section: secStr,
                                    ),
                                  ),
                                );
                              },
                        child: Text(
                          "Next Step  →",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: s.isNotEmpty ? Colors.black : Colors.grey.shade400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ─── AI shortcut: skip template + upload directly ───
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
                        label: const Text(
                          "Skip template — upload my own Excel (AI)",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onPressed: s.isEmpty
                            ? null
                            : () {
                                final (batchStr, deptStr, secStr) = _selection();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Super(
                                      s: s,
                                      batch: batchStr,
                                      department: deptStr,
                                      section: secStr,
                                      startInAiMode: true,
                                    ),
                                  ),
                                );
                              },
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
