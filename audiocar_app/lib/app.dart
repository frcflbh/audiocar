import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'theme.dart';
import 'ui/dashboard_screen.dart';
import 'ui/login_screen.dart';

class AudioCarApp extends StatelessWidget {
  const AudioCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AUDIOCAR',
      debugShowCheckedModeBanner: false,
      theme: buildAudioCarTheme(),
      home: const _AuthGate(),
    );
  }
}

/// Decide entre a tela de login e o dashboard conforme o estado de autenticação
/// (Requisito 4.6 da RFP).
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authService,
      builder: (context, _) {
        return authService.isLoggedIn
            ? const DashboardScreen()
            : const LoginScreen();
      },
    );
  }
}
