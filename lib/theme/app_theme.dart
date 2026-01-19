import 'package:flutter/material.dart';

class AppTheme {
  // インスタンス化させないためのプライベートコンストラクタ
  AppTheme._();

  // === 共通カラー定義 (Variables) ===
  static const Color _lightPrimary = Color(0xFF2D3436); // 黒に近いグレー
  static const Color _lightBg = Color(0xFFF5F7FA);      // 薄いグレー背景
  static const Color _darkBg = Color(0xFF121212);       // ダークモード背景
  static const Color _darkSurface = Color(0xFF1E1E1E);  // ダークモードのカード色

  // === ライトモード設定 ===
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lightBg,

    // カラーパレット定義
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.black,
      primary: _lightPrimary,           // メインカラー
      secondary: const Color(0xFF636E72), // サブテキストなど
      surface: Colors.white,            // カードなどの表面色
      onSurface: _lightPrimary,         // 表面の上の文字色
    ),

    // AppBarのスタイル
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: _lightPrimary),
      titleTextStyle: TextStyle(
        color: _lightPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),
    // カードのスタイル
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
      ),
    ),
    // ダイアログのスタイル
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
  );

  // === ダークモード設定 ===
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _darkBg,

    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.white,
      brightness: Brightness.dark,
      primary: Colors.white,
      secondary: const Color(0xFFB0BEC5),
      surface: _darkSurface,
      onSurface: Colors.white,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: _darkSurface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
