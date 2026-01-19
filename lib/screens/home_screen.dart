import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/skill.dart';
import '../services/skill_service.dart';
import 'skill_detail_screen.dart';
import '../services/backup_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Skill> skills = [];
  final TextEditingController _skillController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  // スキル一覧の読み込み
  Future<void> _loadSkills() async {
    final prefs = await SharedPreferences.getInstance();
    // 保存されているキーの中から、システム用以外のものを探してスキルとみなす簡易ロジック
    // (本来は別途スキル名のリストを保存するのが確実ですが、今回は既存の仕組みに合わせてキー検索します)
    final keys = prefs.getKeys();

    // 除外するキーワード（履歴やタグなどのシステムデータ）
    final systemPrefixes = ['tags_', 'flutter.'];
    final systemSuffixes = ['_history'];

    final skillNames = keys.where((key) {
      // 数値(合計時間)が保存されているキーのみ対象
      if (prefs.get(key) is! int) return false;

      // 日付データ(yyyyMMdd)は除外
      // スキル名_yyyyMMdd の形式になっているはずなので、"_"が含まれ、かつ末尾が数字8桁なら除外
      if (key.contains('_')) {
        final parts = key.split('_');
        final potentialDate = parts.last;
        if (potentialDate.length == 8 && int.tryParse(potentialDate) != null) {
          return false;
        }
      }

      // 明らかなシステムキーを除外
      if (systemPrefixes.any((prefix) => key.startsWith(prefix))) return false;
      if (systemSuffixes.any((suffix) => key.endsWith(suffix))) return false;

      return true;
    }).toList();

    List<Skill> loadedSkills = [];
    for (String name in skillNames) {
      int seconds = prefs.getInt(name) ?? 0;
      loadedSkills.add(Skill(name: name, totalTime: Duration(seconds: seconds)));
    }

    // 時間が多い順にソート
    loadedSkills.sort((a, b) => b.totalTime.compareTo(a.totalTime));

    setState(() {
      skills = loadedSkills;
    });
  }

  Future<void> _addSkill(String name) async {
    if (name.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Skill already exists!")),
      );
      return;
    }
    await prefs.setInt(name, 0);
    _skillController.clear();
    _loadSkills();
  }

  // ★追加: 名前変更ダイアログ
  void _showRenameDialog(Skill skill) {
    TextEditingController renameController = TextEditingController(text: skill.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Skill"),
        content: TextField(
          controller: renameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: "New Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () async {
              final newName = renameController.text.trim();
              if (newName.isNotEmpty && newName != skill.name) {
                Navigator.pop(context);
                // Serviceを使ってリネーム
                await SkillService.renameSkill(skill, newName);
                _loadSkills(); // リスト再読み込み
              }
            },
            child: const Text("Rename", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 削除確認ダイアログ
  void _confirmDeleteSkill(Skill skill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Skill"),
        content: Text("Delete '${skill.name}' and all history?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              // Serviceを使って削除
              await SkillService.deleteSkill(skill.name);
              _loadSkills(); // リスト再読み込み
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 長押し時のメニュー（ボトムシート）
  void _showSkillOptions(Skill skill) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(skill);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteSkill(skill);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 設定メニューを表示
  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Backup & Restore", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Export Data'),
                subtitle: const Text('Save backup file'),
                onTap: () async {
                  Navigator.pop(context);
                  await BackupService.exportData(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Import Data'),
                subtitle: const Text('Restore from backup file'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    // 2. サービスを呼び出す (contextは渡さない)
                    bool success = await BackupService.importData();

                    // 3. 画面がまだ存在しているかチェック (非同期処理のお作法)
                    if (!mounted) return;

                    if (success) {
                      // 4. 成功したらリロードしてメッセージ表示
                      await _loadSkills();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Import Successful"),
                          content: const Text("Your data has been restored successfully."),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("OK"),
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    // エラー時のメッセージ表示
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Import Failed"),
                        content: Text("An error occurred: $e"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("OK"),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Time Bank", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: _showSettingsMenu,
          ),
        ],
      ),
      body: skills.isEmpty
          ? const Center(child: Text("Add a skill to start tracking!", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: skills.length,
              itemBuilder: (context, index) {
                final skill = skills[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    // ★タップで詳細へ
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SkillDetailScreen(skill: skill)),
                      );
                      _loadSkills(); // 戻ってきたら時間を更新するためにリロード
                    },
                    // ★長押しでメニュー表示
                    onLongPress: () {
                      _showSkillOptions(skill);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  skill.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${skill.totalTime.inHours}h ${skill.totalTime.inMinutes.remainder(60)}m",
                                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("New Skill"),
              content: TextField(
                controller: _skillController,
                autofocus: true,
                decoration: const InputDecoration(hintText: "Enter skill name"),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  onPressed: () {
                    _addSkill(_skillController.text.trim());
                    Navigator.pop(context);
                  },
                  child: const Text("Add", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
