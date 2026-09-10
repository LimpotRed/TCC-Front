import 'dart:async';

import 'package:flutter/material.dart';

import 'brand.dart';
import 'login_screen.dart';
export 'login_screen.dart' show LoginScreen;

// Ponto de entrada do aplicativo.
void main() {
  runApp(const GhydroApp());
}

class GhydroApp extends StatelessWidget {
  const GhydroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Ghydro',
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Começa os 2 segundos depois que a logo aparece na tela.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        // Abre o login sem deixar a splash no botão de voltar.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        );
      });
    });
  }

  @override
  void dispose() {
    // Evita abrir o login se esta tela já tiver sido fechada.
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: splashBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GhydroLogo(),
                  SizedBox(height: 40),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: brandColor,
                      semanticsLabel: 'Carregando',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
