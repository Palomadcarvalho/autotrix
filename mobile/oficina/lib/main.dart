import 'package:flutter/material.dart';
import 'services/oficina_service.dart';
import 'screens/login_screen.dart';
import 'screens/listagem_screen.dart';
import 'widgets/widgets.dart';

void main() {
  runApp(const AutotrixOficinaApp());
}

class AutotrixOficinaApp extends StatelessWidget {
  const AutotrixOficinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:        'Autotrix — Oficina',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor:  kOrange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle:              true,
          elevation:                0,
          scrolledUnderElevation:   1,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificarLogin();
  }

  Future<void> _verificarLogin() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final oficina = await OficinaService().getOficinaLogada();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => oficina != null
            ? const ListagemScreen()
            : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOrange,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.build_outlined,
                color:  Colors.white,
                size:   42,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Autotrix',
              style: TextStyle(
                color:      Colors.white,
                fontSize:   28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Painel da oficina',
              style: TextStyle(
                color:    Colors.white.withOpacity(0.75),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color:       Colors.white,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}