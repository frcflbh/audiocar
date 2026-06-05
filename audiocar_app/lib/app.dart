import 'package:flutter/material.dart';
import 'theme.dart';
import 'ui/dashboard_screen.dart';

class AudioCarApp extends StatelessWidget {
  const AudioCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AUDIOCAR',
      debugShowCheckedModeBanner: false,
      theme: buildAudioCarTheme(),
      // Convidado-primeiro: o app abre direto no cockpit. O login é uma rota
      // acionada apenas quando o usuário vai comprar/salvar (Requisito 4.6/11).
      home: const DashboardScreen(),
    );
  }
}
