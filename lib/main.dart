import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

// ★追加: アプリ全体で共有するテーマ管理のスイッチ
// (どこからでもアクセスできるようにトップレベルに置きます)
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  runApp(const TimeBankApp());
}

class TimeBankApp extends StatelessWidget {
  const TimeBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ★変更: ValueListenableBuilderで囲み、通知が来たら再描画するようにする
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'Time Bank',
          debugShowCheckedModeBanner: false,

          // ★今のモード（light または dark）
          themeMode: mode,

          // === ライトモード（既存のデザイン） ===
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.black,
              primary: const Color(0xFF2D3436),
              secondary: const Color(0xFF636E72),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(
                color: Color(0xFF2D3436),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              iconTheme: IconThemeData(color: Color(0xFF2D3436)),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D3436),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),

          // === ★追加: ダークモード（黒ベースのかっこいいデザイン） ===
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            // 真っ黒すぎない目に優しいダークグレー
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.white,
              brightness: Brightness.dark,
              primary: Colors.white, // メインカラーは白
              secondary: const Color(0xFFB0BEC5),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(
                color: Colors.white, // タイトルは白
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              iconTheme: IconThemeData(color: Colors.white),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              // カードは背景より少し明るいグレー
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
              ),
            ),
            // リストタイルや文字色調整
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Color(0xFFEEEEEE)),
              bodySmall: TextStyle(color: Color(0xFFB0BEC5)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, // ボタンは白
                foregroundColor: Colors.black, // 文字は黒
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            // ダイアログなどの背景
            dialogBackgroundColor: const Color(0xFF1E1E1E),
          ),

          home: const HomeScreen(),
        );
      },
    );
  }
}
