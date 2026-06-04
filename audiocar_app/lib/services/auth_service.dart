import 'package:flutter/foundation.dart';

/// Usuário da aplicação (Requisito 4.6 da RFP).
@immutable
class AppUser {
  final String email;
  final bool isPremium;
  const AppUser({required this.email, this.isPremium = false});

  AppUser copyWith({bool? isPremium}) =>
      AppUser(email: email, isPremium: isPremium ?? this.isPremium);
}

/// Serviço de autenticação e contas (Requisito 4.6 da RFP).
///
/// ATENÇÃO: esta é uma implementação **mock**, em memória, sem backend real e
/// sem armazenamento de senhas. Serve para validar o fluxo de UI (login,
/// cadastro, gate de conteúdo premium). Para produção, substituir por um
/// provedor real (Firebase Auth, OAuth/SSO, etc.) — a interface pública
/// (login/cadastro/logout/upgrade) permanece a mesma para a UI.
class AuthService extends ChangeNotifier {
  AppUser? _user;
  bool _busy = false;
  String? _error;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get busy => _busy;
  String? get error => _error;

  Future<bool> signIn(String email, String password) =>
      _authenticate(email, password, isSignUp: false);

  Future<bool> signUp(String email, String password) =>
      _authenticate(email, password, isSignUp: true);

  Future<bool> _authenticate(
    String email,
    String password, {
    required bool isSignUp,
  }) async {
    _setBusy(true);
    _error = null;

    // Validações locais simples (mock).
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
    if (!emailOk) {
      _fail('Informe um e-mail válido.');
      return false;
    }
    if (password.length < 6) {
      _fail('A senha deve ter ao menos 6 caracteres.');
      return false;
    }

    // Simula latência de rede.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    _user = AppUser(email: email.trim());
    _busy = false;
    notifyListeners();
    return true;
  }

  void upgradeToPremium() {
    final u = _user;
    if (u == null) return;
    _user = u.copyWith(isPremium: true);
    notifyListeners();
  }

  void signOut() {
    _user = null;
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

/// Instância única usada pelo app (simples, sem dependência de DI).
final AuthService authService = AuthService();
