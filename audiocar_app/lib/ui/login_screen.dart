import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';

/// Tela de login / cadastro (Requisito 4.6 da RFP).
///
/// Usa o [authService] mock. Nenhuma credencial real é enviada a servidores.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text;
    final pass = _passCtrl.text;
    final ok = _isSignUp
        ? await authService.signUp(email, pass)
        : await authService.signIn(email, pass);
    // A navegação é feita pelo AuthGate ao observar authService.
    if (!ok) return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: AnimatedBuilder(
              animation: authService,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.directions_car_filled,
                        size: 56, color: CockpitColors.accent),
                    const SizedBox(height: 12),
                    const Text(
                      'AUDIOCAR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: CockpitColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      _isSignUp ? 'Criar sua conta' : 'Entrar na sua conta',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: CockpitColors.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      style: const TextStyle(color: CockpitColors.textPrimary),
                      decoration: _dec('E-mail', Icons.alternate_email),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      style: const TextStyle(color: CockpitColors.textPrimary),
                      decoration: _dec('Senha', Icons.lock_outline).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: CockpitColors.textMuted,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    if (authService.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        authService.error!,
                        style: const TextStyle(
                            color: CockpitColors.redline, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: authService.busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: CockpitColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: authService.busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isSignUp ? 'Criar conta' : 'Entrar'),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: authService.busy
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp
                            ? 'Já tem conta? Entrar'
                            : 'Não tem conta? Criar agora',
                        style: const TextStyle(color: CockpitColors.accent),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Demo: qualquer e-mail válido + senha de 6+ caracteres.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: CockpitColors.textMuted, fontSize: 11),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: CockpitColors.textMuted),
      prefixIcon: Icon(icon, color: CockpitColors.textMuted),
      filled: true,
      fillColor: CockpitColors.panel,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CockpitColors.gaugeTrack),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CockpitColors.accent),
      ),
    );
  }
}
