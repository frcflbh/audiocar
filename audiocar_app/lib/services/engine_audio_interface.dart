/// Interface do motor de áudio do som de motor (Requisito 4.2 da RFP).
///
/// Há duas implementações selecionadas em tempo de compilação:
///   - `engine_audio_native.dart`  → flutter_soloud (Android / iOS / desktop)
///   - `engine_audio_web.dart`     → Web Audio API (navegador)
///
/// A seleção é feita por `engine_audio.dart` via conditional imports, de modo
/// que o código de plataforma indevido nem entra no build.
abstract class EngineAudio {
  bool get isReady;

  /// Inicializa o motor de áudio. Deve ser chamado a partir de um gesto do
  /// usuário (política de autoplay dos navegadores).
  Future<void> init();

  /// Atualiza pitch (RPM) e volume (aceleração).
  void update({required double rpm, required double throttle});

  Future<void> dispose();
}
