import 'package:flutter/material.dart';
import 'app.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restaura a sessão salva (se houver) antes de montar a UI.
  await authService.loadSession();
  runApp(const AudioCarApp());
}
