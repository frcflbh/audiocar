/// Interface do motor de áudio do som de motor (Requisito 4.2 da RFP).
///
/// Há duas implementações selecionadas em tempo de compilação:
///   - `engine_audio_native.dart`  → flutter_soloud (Android / iOS / desktop)
///   - `engine_audio_web.dart`     → Web Audio API (navegador)
///
/// A seleção é feita por `engine_audio.dart` via conditional imports, de modo
/// que o código de plataforma indevido nem entra no build.
/// Caráter sonoro do motor selecionado (banco "Sons de Motores").
/// Deriva o timbre do número de cilindros (frequência de combustão) e da
/// indução (assobio de turbo), dando som distinto a cada carro.
class EngineSoundCharacter {
  final int cylinders;
  final bool turbo;
  // Faixa de operação do motor (usada pra normalizar o RPM em t∈[0,1]
  // e mapear playback rate + abertura do filtro low-pass).
  final double idleRpm;
  final double redlineRpm;

  const EngineSoundCharacter({
    this.cylinders = 8,
    this.turbo = false,
    this.idleRpm = 900,
    this.redlineRpm = 7000,
  });

  /// Frequência de combustão (Hz) de um motor 4 tempos no RPM informado:
  /// (rpm/60) * (cilindros/2).
  double firingHz(double rpm) => (rpm / 60.0) * (cylinders / 2.0);

  /// Posição normalizada do RPM atual entre idle (0) e redline (1).
  /// Pode passar de 1 quando o RPM passa do redline; clampamos onde precisa.
  double t(double rpm) {
    final span = (redlineRpm - idleRpm).clamp(1.0, double.infinity);
    return (rpm - idleRpm) / span;
  }
}

abstract class EngineAudio {
  bool get isReady;

  /// Inicializa o motor de áudio. Deve ser chamado a partir de um gesto do
  /// usuário (política de autoplay dos navegadores).
  Future<void> init();

  /// Define o caráter sonoro do motor selecionado (timbre por carro).
  void setCharacter(EngineSoundCharacter character);

  /// Define a gravação real do motor a ser usada (loop, com pitch pelo RPM).
  /// Se [assetPath] for nulo ou falhar, usa a síntese como fallback.
  /// [refRpm] é o RPM aproximado da gravação (onde playbackRate = 1).
  void setSample(String? assetPath, double refRpm);

  /// Silencia/dessilencia o áudio sem perder o contexto.
  /// Útil para um toggle de "ligar/desligar áudio" pela UI.
  void setMuted(bool muted);

  /// Atualiza pitch (RPM) e volume (aceleração).
  void update({required double rpm, required double throttle});

  Future<void> dispose();
}
