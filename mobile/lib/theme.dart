import 'package:flutter/material.dart';

const waGreen = Color(0xFF075E54);
const waAccent = Color(0xFF25D366);
const waChatBg = Color(0xFFECE5DD);
const waOutgoing = Color(0xFFDCF8C6);
const waIncoming = Color(0xFFFFFFFF);
const waMuted = Color(0xFF667781);

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: false,
    colorScheme: const ColorScheme.light(
      primary: waGreen,
      secondary: waAccent,
      background: waChatBg,
    ),
    scaffoldBackgroundColor: const Color(0xFFF2F2F2),
    appBarTheme: const AppBarTheme(
      backgroundColor: waGreen,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: Colors.black12,
      thickness: 1,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: waGreen, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: waAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: waGreen,
        side: const BorderSide(color: Colors.black26),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: waGreen,
      ),
    ),
  );
}
