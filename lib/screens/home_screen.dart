import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/skill.dart';
import 'skill_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Skill> mySkills = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      List<String>? savedSkillNames = prefs.getStringList('skill_names');
      if (savedSkillNames != null) {
        mySkills = savedSkillNames.map((name) => Skill(name: name)).toList();
      } else {
        mySkills = [Skill(name: "Programming"), Skill(name: "English")];
      }
      for (var skill in mySkills) {
        int seconds = prefs.getInt(skill.name) ?? 0;
        skill.totalTime = Duration(seconds: seconds);
      }
    });
  }

  Future<void> _addNewSkill(String newSkillName) async {
    if (newSkillName.isEmpty)
      return ;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      mySkills.add(Skill(name: newSkillName));
    });
    List<String> nameList = mySkills.map((skill) => skill.name).toList();
    await prefs.setStringList('skill_names', nameList);
  }

  String _formatTotalTime(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = d.inHours.toString();
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return '${hours}h ${minutes}m ${seconds}s';
  }

  void _showAddSkillDialog() {
    String newName = "";
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("New Skill"),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: "Enter skill nmae"),
            onChanged: (value) => newName = value,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () {
                _addNewSkill(newName);
                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Time Assets')),
      body: mySkills.isEmpty
        ? const Center(child: Text("Press + to add a skill"))
        : ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: mySkills.length,
          separatorBuilder: (context, index) => const Divider(height: 30),
          itemBuilder: (context, index) {
            final skill = mySkills[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(skill.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              trailing: Text(
                _formatTotalTime(skill.totalTime),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SkillDetailScreen(skill: skill)),
                );
                _loadData();
              },
            );
          },
        ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: _showAddSkillDialog,
      ),
    );
  }
}
