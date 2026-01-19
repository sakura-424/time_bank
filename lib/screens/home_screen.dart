import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/skill.dart';
import '../services/skill_service.dart';
import 'skill_detail_screen.dart';
import '../services/backup_service.dart';
import '../utils/app_utils.dart';
import '../main.dart';

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
      loadedSkills.add(
        Skill(
          name: name,
          totalTime: Duration(seconds: seconds),
        ),
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Skill already exists!")));
      return;
    }
    await prefs.setInt(name, 0);
    _skillController.clear();
    _loadSkills();
  }

  // ★追加: 名前変更ダイアログ
  void _showRenameDialog(Skill skill) {
    TextEditingController renameController = TextEditingController(
      text: skill.name,
    );
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
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

  // 設定メニューを表示
  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        // 現在のモードがダークかどうか判定
        final isDark = themeNotifier.value == ThemeMode.dark;

        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  "Settings",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),

              // ★追加: ダークモード切り替えスイッチ
              SwitchListTile(
                title: const Text("Dark Mode"),
                secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                value: isDark,
                onChanged: (bool value) {
                  // スイッチ切り替えでモードを変更
                  themeNotifier.value = value
                      ? ThemeMode.dark
                      : ThemeMode.light;
                  Navigator.pop(context); // メニューを閉じる
                },
              ),

              const Divider(), // 区切り線

              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  "Backup & Restore",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
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
                    bool success = await BackupService.importData();
                    if (!mounted) return;
                    if (success) {
                      await _loadSkills();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Import Successful"),
                          content: const Text(
                            "Your data has been restored successfully.",
                          ),
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
      // AppBarは設定アイコンだけ置く（タイトルはbodyに書く）
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined), // アウトラインアイコンの方が今っぽい
            onPressed: _showSettingsMenu,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ★ヘッダー部分
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Time Bank",
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2D3436),
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Invest your time wisely.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ★リスト部分
          Expanded(
            child: skills.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: skills.length,
                    itemBuilder: (context, index) {
                      final skill = skills[index];
                      final hours = skill.totalTime.inHours;
                      final minutes = skill.totalTime.inMinutes.remainder(60);
                      final levelInfo = AppUtils.getLevelInfo(hours);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        // InkWellの波紋を綺麗に見せるためにMaterialで包む
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SkillDetailScreen(skill: skill),
                                ),
                              );
                              _loadSkills();
                            },
                            // onLongPress: () => _showSkillOptions(skill),
                            borderRadius: BorderRadius.circular(20),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardTheme.color,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.05),
                                    spreadRadius: 0,
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  8,
                                  20,
                                ),
                                child: Row(
                                  children: [
                                    // 左側のアイコン（レベルに応じて変化）
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: (levelInfo['color'] as Color)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Icon(
                                        levelInfo['icon'],
                                        color: levelInfo['color'],
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // 真ん中の情報
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            skill.name,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.color ??
                                                  const Color(0xFF2D3436),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // レベルバッジ
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              levelInfo['label'],
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 右側の時間
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${hours}h",
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight:
                                                FontWeight.w900, // 数字を強調
                                            color:
                                                Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium?.color ??
                                                const Color(0xFF2D3436),
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        Text(
                                          "${minutes}m",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[500],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    //「︙」メニューボタン
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert,
                                        color: Colors.grey[400],
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      onSelected: (value) {
                                        if (value == 'rename') {
                                          _showRenameDialog(skill);
                                        } else if (value == 'delete') {
                                          _confirmDeleteSkill(skill);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) =>
                                          <PopupMenuEntry<String>>[
                                            const PopupMenuItem<String>(
                                              value: 'rename',
                                              child: ListTile(
                                                leading: Icon(
                                                  Icons.edit,
                                                  size: 20,
                                                ),
                                                title: Text('Rename'),
                                                contentPadding: EdgeInsets.zero,
                                                dense: true,
                                              ),
                                            ),
                                            const PopupMenuDivider(),
                                            const PopupMenuItem<String>(
                                              value: 'delete',
                                              child: ListTile(
                                                leading: Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                title: Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                                contentPadding: EdgeInsets.zero,
                                                dense: true,
                                              ),
                                            ),
                                          ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2D3436), // 黒に近いグレー
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("New Skill"),
              content: TextField(
                controller: _skillController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Enter skill name",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _addSkill(_skillController.text.trim());
                    Navigator.pop(context);
                  },
                  child: const Text("Add"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            "No skills yet",
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Start investing your time today.",
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
