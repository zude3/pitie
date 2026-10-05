import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: const Color(0xFFF8F8FC),

    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5265F5)),

    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
