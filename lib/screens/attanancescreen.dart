import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Map<String, dynamic>> subjects = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('subjects');
    if (data != null) {
      subjects = List<Map<String, dynamic>>.from(json.decode(data));
    }
    setState(() {});
  }

  Future<void> _saveSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subjects', json.encode(subjects));
  }

  void _addSubject(String name) {
    subjects.add({
      'name': name,
      'present': 0.0,
      'total': 0,
    });
    _saveSubjects();
    setState(() {});
  }

  void _markPresent(int i) {
    subjects[i]['present'] += 1;
    subjects[i]['total'] += 1;
    _saveSubjects();
    setState(() {});
  }

  void _markAbsent(int i) {
    subjects[i]['total'] += 1;
    _saveSubjects();
    setState(() {});
  }

  void _markHalfDay(int i) {
    subjects[i]['present'] += 0.5;
    subjects[i]['total'] += 1;
    _saveSubjects();
    setState(() {});
  }

  void _resetSubject(int index) {
    subjects[index]['present'] = 0.0;
    subjects[index]['total'] = 0;
    _saveSubjects();
    setState(() {});
  }

  void _deleteSubject(int index) {
    subjects.removeAt(index);
    _saveSubjects();
    setState(() {});
  }

  double _percentage(Map<String, dynamic> s) {
    if (s['total'] == 0) return 0;
    return (s['present'] / s['total']) * 100;
  }

  int _absentDays(Map<String, dynamic> s) {
    return s['total'] - s['present'].floor();
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Subject"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Subject name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addSubject(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _confirmReset(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset Attendance"),
        content: const Text(
          "This will reset present, absent and total days for this subject. Continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              _resetSubject(index);
              Navigator.pop(context);
            },
            child: const Text("Reset"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Tracker",style: TextStyle(fontWeight: FontWeight.bold),),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: subjects.isEmpty
          ? const Center(
        child: Text(
          "No subjects added\nTap + to add",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subjects.length,
        itemBuilder: (_, index) {
          final s = subjects[index];
          final percent = _percentage(s);
          final absent = _absentDays(s);

          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh,
                                color: Colors.orange),
                            onPressed: () => _confirmReset(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red),
                            onPressed: () => _deleteSubject(index),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // PROGRESS BAR
                  LayoutBuilder(
                    builder: (_, c) => Stack(
                      children: [
                        Container(
                          height: 14,
                          width: c.maxWidth,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        Container(
                          height: 14,
                          width: max(0, c.maxWidth * percent / 100),
                          decoration: BoxDecoration(
                            color: percent >= 75
                                ? Colors.green
                                : Colors.red,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // STATS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Present: ${s['present']}"),
                      Text("Absent: $absent"),
                      Text("Total: ${s['total']}"),
                    ],
                  ),

                  const SizedBox(height: 6),
                  Text(
                    "${percent.toStringAsFixed(1)}%",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // BUTTONS
                  Row(
                    children: [
                      _actionButton(
                        "Present",
                        Colors.green,
                            () => _markPresent(index),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        "Absent",
                        Colors.red,
                            () => _markAbsent(index),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        "Half Day",
                        Colors.orange,
                            () => _markHalfDay(index),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _actionButton(String text, Color color, VoidCallback onTap) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextButton(
          onPressed: onTap,
          child: Text(
            text,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
