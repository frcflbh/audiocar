import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';

/// Tela de login / cadastro (Requisito 4.6 da RFP).
///
/// Acionada como rota (convidado-primeiro): o usuário pode voltar ao app sem
/// logar. Fecha-se (pop) ao autenticar com sucesso. Usa o [authService] mock —
/// nenhuma credencial real é enviada a servidores.
class LoginScreen extends StatefulWidget {
  /// Mensagem opcional de contexto (ex.: "Entre para comprar este pacote").
  final String? reason;
  const LoginScreen({super.key, this.reason});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();
  bool _isSignUp = false;
  bool _obscure = true;
  String? _emailError;
  String? _passError;

  @override
  void initState() {
    super.initState();
    authService.clearError();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    setState(() {
      _emailError = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
          ? null
          : 'E-mail inválido';
      _passError = pass.length >= 6 ? null : 'Mínimo 6 caracteres';
    });
    return _emailError == null && _passError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    final ok = _isSignUp
        ? await authService.signUp(_emailCtrl.text, _passCtrl.text)
        : await authService.signIn(_emailCtrl.text, _passCtrl.text);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _social(String provider) async {
    final ok = await authService.signInWithProvider(provider);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  void _forgotPassword() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CockpitColors.panel,
        title: const Text('Recuperar senha'),
        content: const Text(
          'Em produção, enviaríamos um link de redefinição ao seu e-mail. '
          '(Fluxo mock nesta versão.)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Voltar ao app',
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                        size: 52, color: CockpitColors.accent),
                    const SizedBox(height: 10),
                    const Text(
                      'AUDIOCAR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: CockpitColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      widget.reason ??
                          (_isSignUp
                              ? 'Crie sua conta para salvar e comprar'
                              : 'Entre para salvar sua garagem e comprar packs'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: CockpitColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // --- Login social ---
                    _socialButton(
                      label: 'Continuar com Google',
                      leading: _googleLogo(),
                      onTap: authService.busy ? null : () => _social('google'),
                    ),
                    const SizedBox(height: 10),
                    _socialButton(
                      label: 'Continuar com Apple',
                      leading: const Icon(Icons.apple,
                          color: CockpitColors.textPrimary, size: 22),
                      onTap: authService.busy ? null : () => _social('apple'),
                    ),
                    const SizedBox(height: 18),
                    const Row(children: [
                      Expanded(child: Divider(color: CockpitColors.gaugeTrack)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('ou', style: TextStyle(color: CockpitColors.textMuted)),
                      ),
                      Expanded(child: Divider(color: CockpitColors.gaugeTrack)),
                    ]),
                    const SizedBox(height: 18),

                    // --- E-mail / senha ---
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      onSubmitted: (_) => _passFocus.requestFocus(),
                      style: const TextStyle(color: CockpitColors.textPrimary),
                      decoration: _dec('E-mail', Icons.alternate_email, _emailError),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passCtrl,
                      focusNode: _passFocus,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(color: CockpitColors.textPrimary),
                      decoration: _dec('Senha', Icons.lock_outline, _passError).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                            color: CockpitColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),

                    if (!_isSignUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: const Text('Esqueci minha senha',
                              style: TextStyle(color: CockpitColors.textMuted)),
                        ),
                      ),

                    if (authService.error != null) ...[
                      const SizedBox(height: 8),
                      Text(authService.error!,
                          style: const TextStyle(
                              color: CockpitColors.redline, fontSize: 13)),
                    ],
                    const SizedBox(height: 16),
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
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isSignUp ? 'Criar conta' : 'Entrar'),
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 6),
                    const Text.rich(
                      TextSpan(
                        text: 'Ao continuar, você aceita os ',
                        children: [
                          TextSpan(
                              text: 'Termos',
                              style: TextStyle(color: CockpitColors.accent)),
                          TextSpan(text: ' e a '),
                          TextSpan(
                              text: 'Política de Privacidade',
                              style: TextStyle(color: CockpitColors.accent)),
                          TextSpan(text: '.'),
                        ],
                      ),
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

  Widget _socialButton({
    required String label,
    required Widget leading,
    required VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: leading,
      label: Text(label,
          style: const TextStyle(color: CockpitColors.textPrimary)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: CockpitColors.gaugeTrack),
      ),
    );
  }

  /// Logo "G" do Google (placeholder de marca; em produção, usar o asset oficial).
  Widget _googleLogo() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: CockpitColors.gaugeTrack),
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon, String? error) {
    return InputDecoration(
      labelText: label,
      errorText: error,
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
