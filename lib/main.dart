import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TimeBankApp());
}

class TimeBankApp extends StatelessWidget {
  const TimeBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time Bank',
      debugShowCheckedModeBanner: false,
      // ★ここがポイント: 全体のテーマをモダンにする
      theme: ThemeData(
        useMaterial3: true,
        // 背景色をうっすらグレーに（カードが映える）
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        // メインカラーを「黒」に近いグレーに（高級感）
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: const Color(0xFF2D3436),
          secondary: const Color(0xFF636E72),
        ),
        // AppBarは透明にして背景に馴染ませる
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF2D3436),
            fontSize: 24,
            fontWeight: FontWeight.w800, // 極太フォント
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFF2D3436)),
        ),
        // カードのデザインを統一
        cardTheme: CardThemeData(
          elevation: 0, // 影をなくす（フラットデザイン）
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // 角丸を大きく
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1), // うっすら枠線
          ),
        ),
        // ボタンのデザイン
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
      home: const HomeScreen(),
    );
  }
}
