import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Usuário da aplicação (Requisito 4.6 da RFP).
@immutable
class AppUser {
  final String email;
  final bool isPremium;
  final String provider; // 'email' | 'google' | 'apple'
  const AppUser({
    required this.email,
    this.isPremium = false,
    this.provider = 'email',
  });

  AppUser copyWith({bool? isPremium}) => AppUser(
        email: email,
        isPremium: isPremium ?? this.isPremium,
        provider: provider,
      );
}

/// Serviço de autenticação e contas (Requisito 4.6 da RFP).
///
/// Implementação **mock**, em memória + persistência local (shared_preferences),
/// sem backend real e sem armazenar senhas. Valida o fluxo de UI (convidado,
/// login, cadastro, login social, premium, persistência de sessão). Para
/// produção, trocar por um provedor real (Firebase Auth, OAuth/SSO); a interface
/// pública permanece a mesma para a UI.
class AuthService extends ChangeNotifier {
  static const _kEmail = 'auth_email';
  static const _kPremium = 'auth_premium';
  static const _kProvider = 'auth_provider';

  AppUser? _user;
  bool _busy = false;
  String? _error;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isGuest => _user == null; // app é utilizável como convidado
  bool get busy => _busy;
  String? get error => _error;

  /// Restaura a sessão salva (chamado no início do app).
  Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_kEmail);
      if (email != null && email.isNotEmpty) {
        _user = AppUser(
          email: email,
          isPremium: prefs.getBool(_kPremium) ?? false,
          provider: prefs.getString(_kProvider) ?? 'email',
        );
        notifyListeners();
      }
    } catch (_) {
      // Sem persistência disponível: segue como convidado.
    }
  }

  Future<bool> signIn(String email, String password) =>
      _authenticate(email, password, isSignUp: false);

  Future<bool> signUp(String email, String password) =>
      _authenticate(email, password, isSignUp: true);

  /// Login social (mock). Em produção, integrar google_sign_in / Sign in with Apple.
  Future<bool> signInWithProvider(String provider) async {
    _setBusy(true);
    _error = null;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final email = provider == 'apple'
        ? 'usuario@privaterelay.appleid.com'
        : 'usuario@gmail.com';
    _user = AppUser(email: email, provider: provider);
    _busy = false;
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> _authenticate(
    String email,
    String password, {
    required bool isSignUp,
  }) async {
    _setBusy(true);
    _error = null;

    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
    if (!emailOk) {
      _fail('Informe um e-mail válido.');
      return false;
    }
    if (password.length < 6) {
      _fail('A senha deve ter ao menos 6 caracteres.');
      return false;
    }

    await Future<void>.delayed(const Duration(milliseconds: 600));

    _user = AppUser(email: email.trim(), provider: 'email');
    _busy = false;
    await _persist();
    notifyListeners();
    return true;
  }

  void upgradeToPremium() {
    final u = _user;
    if (u == null) return;
    _user = u.copyWith(isPremium: true);
    _persist();
    notifyListeners();
  }

  Future<void> signOut() async {
    _user = null;
    _error = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kEmail);
      await prefs.remove(_kPremium);
      await prefs.remove(_kProvider);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persist() async {
    final u = _user;
    if (u == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kEmail, u.email);
      await prefs.setBool(_kPremium, u.isPremium);
      await prefs.setString(_kProvider, u.provider);
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  void _fail(String message) {
    _error = message;
    _busy = false;
    notifyListeners();
  }
}

/// Instância única usada pelo app.
final AuthService authService = AuthService();
