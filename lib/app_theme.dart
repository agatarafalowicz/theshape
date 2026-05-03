import 'package:flutter/material.dart';

class AppColors {
  static const indigo900 = Color(0xFF312E81);
  static const purple900 = Color(0xFF581C87);
  static const blue900 = Color(0xFF1E3A8A);

  static const yellow400 = Color(0xFFFACC15);
  static const orange500 = Color(0xFFF97316);

  static const purple200 = Color(0xFFE9D5FF);
  static const purple300 = Color(0xFFD8B4FE);
  static const purple400 = Color(0xFFC084FC);
  static const purple500 = Color(0xFFA855F7);

  static const indigo400 = Color(0xFF818CF8);
  static const indigo500 = Color(0xFF6366F1);
  static const purple600 = Color(0xFF9333EA);

  static const green300 = Color(0xFF86EFAC);
  static const green400 = Color(0xFF4ADE80);
  static const emerald500 = Color(0xFF10B981);

  static const amber300 = Color(0xFFFCD34D);
  static const amber400 = Color(0xFFFBBF24);

  static const red300 = Color(0xFFFCA5A5);
  static const red400 = Color(0xFFF87171);
  static const red500 = Color(0xFFEF4444);

  static const blue400 = Color(0xFF60A5FA);
  static const blue500 = Color(0xFF3B82F6);

  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray900 = Color(0xFF111827);

  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo900, purple900, blue900],
  );

  static const ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [yellow400, orange500],
  );

  static const indigoPurpleGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [indigo500, purple600],
  );

  static const greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green400, emerald500],
  );
}
