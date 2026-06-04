import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_soloud/flutter_soloud.dart';

import 'engine_audio_interface.dart';

/// Fábrica usada pelo conditional import em `engine_audio.dart`.
EngineAudio createEngineAudio() => SoLoudEngineAudio();

/// Motor de áudio para plataformas nativas (Android / iOS / desktop).
///
/// Sintetiza proceduralmente, em runtime, um loop de motor (sem embarcar
/// arquivos de áudio) e ajusta pitch (velocidade de reprodução) e volume
/// conforme o RPM. Latência baixa (alvo < 50 ms da Seção 8.1 da RFP).
class SoLoudEngineAudio implements EngineAudio {
  final SoLoud _soloud = SoLoud.instance;
  AudioSource? _source;
  SoundHandle? _handle;
  bool _ready = false;

  static const int _sampleRate = 44100;
  static const double _refRpm = 900; // RPM de referência da síntese procedural

  /// Sample de motor real (opcional). Se presente, é usado no lugar da síntese.
  static const String _sampleAsset = 'assets/audio/engine_loop.wav';

  /// RPM aproximado em que o sample real foi gravado (ajuste conforme o arquivo).
  static const double _sampleRefRpm = 1200;

  bool _usingSample = false;

  @override
  bool get isReady => _ready;

  @override
  Future<void> init() async {
    try {
      await _soloud.init();
    } catch (e) {
      bool already = false;
      try {
        already = _soloud.isInitialized;
      } catch (_) {
        already = false;
      }
      if (!already) rethrow;
    }

    // Tenta usar um sample real; se não houver, cai na síntese procedural.
    Uint8List bytes;
    try {
      final data = await rootBundle.load(_sampleAsset);
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      _usingSample = true;
    } catch (_) {
      bytes = _buildEngineWav();
      _usingSample = false;
    }

    _source = await _soloud.loadMem('audiocar_engine', bytes);
    _handle = await _soloud.play(_source!, looping: true, volume: 0.0);
    _ready = true;
  }

  @override
  void update({required double rpm, required double throttle}) {
    final handle = _handle;
    if (!_ready || handle == null) return;
    final double refRpm = _usingSample ? _sampleRefRpm : _refRpm;
    final double playSpeed = (rpm / refRpm).clamp(0.4, 4.5);
    _soloud.setRelativePlaySpeed(handle, playSpeed);
    final double volume = (0.22 + throttle * 0.78).clamp(0.0, 1.0);
    _soloud.setVolume(handle, volume);
  }

  @override
  Future<void> dispose() async {
    final handle = _handle;
    if (handle != null) {
      await _soloud.stop(handle);
    }
    final source = _source;
    if (source != null) {
      await _soloud.disposeSource(source);
    }
    _ready = false;
  }

  // --- Síntese procedural do loop de motor -----------------------------------

  Uint8List _buildEngineWav() {
    const int n = _sampleRate; // 1.0 s
    const double f0 = 60.0; // Hz inteiro => loop sem clique
    const List<double> harmonicAmps = [
      1.0, 0.62, 0.46, 0.32, 0.24, 0.17, 0.12, 0.08,
    ];

    final Float64List buf = Float64List(n);
    final Random rand = Random(7);
    double maxAbs = 0.0;

    for (int i = 0; i < n; i++) {
      final double t = i / _sampleRate;
      double s = 0.0;
      for (int k = 0; k < harmonicAmps.length; k++) {
        final int h = k + 1;
        s += harmonicAmps[k] * sin(2 * pi * f0 * h * t);
      }
      final double am = 0.82 + 0.18 * sin(2 * pi * 30 * t);
      s *= am;
      s += (rand.nextDouble() * 2 - 1) * 0.04;
      buf[i] = s;
      final double a = s.abs();
      if (a > maxAbs) maxAbs = a;
    }

    final double scale = maxAbs > 0 ? 0.9 / maxAbs : 1.0;
    final Int16List pcm = Int16List(n);
    for (int i = 0; i < n; i++) {
      final double v = buf[i] * scale * 32767.0;
      pcm[i] = v.clamp(-32768.0, 32767.0).toInt();
    }

    return _wrapWavPcm16Mono(pcm, _sampleRate);
  }

  Uint8List _wrapWavPcm16Mono(Int16List pcm, int sampleRate) {
    final int dataLen = pcm.length * 2;
    final BytesBuilder out = BytesBuilder();

    void writeStr(String s) => out.add(s.codeUnits);
    void writeU32(int v) {
      final b = ByteData(4)..setUint32(0, v, Endian.little);
      out.add(b.buffer.asUint8List());
    }

    void writeU16(int v) {
      final b = ByteData(2)..setUint16(0, v, Endian.little);
      out.add(b.buffer.asUint8List());
    }

    writeStr('RIFF');
    writeU32(36 + dataLen);
    writeStr('WAVE');
    writeStr('fmt ');
    writeU32(16);
    writeU16(1);
    writeU16(1);
    writeU32(sampleRate);
    writeU32(sampleRate * 2);
    writeU16(2);
    writeU16(16);
    writeStr('data');
    writeU32(dataLen);

    final ByteData pcmData = ByteData(dataLen);
    for (int i = 0; i < pcm.length; i++) {
      pcmData.setInt16(i * 2, pcm[i], Endian.little);
    }
    out.add(pcmData.buffer.asUint8List());

    return out.toBytes();
  }
}
