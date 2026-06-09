import 'package:flutter/material.dart';
import 'screens/listagem_screen.dart';

void main() {
  runApp(const AutotrixApp());
}

class AutotrixApp extends StatelessWidget {
  const AutotrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:        'Autotrix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor:   const Color(0xFF1565C0),
          brightness:  Brightness.light,
        ),
        useMaterial3:    true,
        fontFamily:      'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle:  true,
          elevation:    0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          elevation:    0,
          shape:        RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const ListagemScreen(),
    );
  }
}
