import 'dart:async';
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
  // RPM de referência da síntese (onde a frequência base do loop corresponde
  // à frequência de combustão do motor). Ver _buildEngineWav.
  static const double _synthRefRpm = 1500;

  bool _usingSample = false;
  bool _muted = false;
  double _sampleRefRpm = 1200;
  EngineSoundCharacter _char = const EngineSoundCharacter();
  String? _pendingSample;
  double _pendingRefRpm = 1200;

  @override
  bool get isReady => _ready;

  @override
  void setCharacter(EngineSoundCharacter character) {
    _char = character;
    // Reconstrói o loop com a frequência base do novo motor (timbre por carro).
    if (_ready && !_usingSample) {
      unawaited(_reloadSynth());
    }
  }

  Future<void> _reloadSynth() async {
    await _swapSource(_buildEngineWav());
  }

  @override
  void setSample(String? assetPath, double refRpm) {
    _pendingSample = assetPath;
    _pendingRefRpm = refRpm;
    if (_ready) unawaited(_applySample(assetPath, refRpm));
  }

  Future<void> _applySample(String? assetPath, double refRpm) async {
    Uint8List bytes;
    if (assetPath == null) {
      _usingSample = false;
      bytes = _buildEngineWav();
    } else {
      try {
        final data = await rootBundle.load(assetPath);
        bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        _usingSample = true;
        _sampleRefRpm = refRpm;
      } catch (_) {
        _usingSample = false;
        bytes = _buildEngineWav();
      }
    }
    await _swapSource(bytes);
  }

  Future<void> _swapSource(Uint8List bytes) async {
    final oldHandle = _handle;
    final oldSource = _source;
    _source = await _soloud.loadMem('audiocar_engine', bytes);
    _handle = await _soloud.play(_source!, looping: true, volume: 0.0);
    if (oldHandle != null) await _soloud.stop(oldHandle);
    if (oldSource != null) await _soloud.disposeSource(oldSource);
  }

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

    // Síntese por padrão; a gravação real (se houver) é aplicada via setSample.
    _source = await _soloud.loadMem('audiocar_engine', _buildEngineWav());
    _handle = await _soloud.play(_source!, looping: true, volume: 0.0);
    _usingSample = false;
    _ready = true;

    if (_pendingSample != null) {
      await _applySample(_pendingSample, _pendingRefRpm);
    }
  }

  @override
  void setMuted(bool muted) {
    _muted = muted;
    final handle = _handle;
    if (_ready && handle != null && muted) {
      _soloud.setVolume(handle, 0);
    }
  }

  @override
  void update({required double rpm, required double throttle}) {
    final handle = _handle;
    if (!_ready || handle == null) return;
    if (_muted) {
      _soloud.setVolume(handle, 0);
      return;
    }
    final double refRpm = _usingSample ? _sampleRefRpm : _synthRefRpm;
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
    // Frequência base = frequência de combustão no RPM de referência:
    // (1500/60) * (cilindros/2) = 12.5 * cilindros. Inteiro p/ cilindros pares
    // => loop sem clique. Mais cilindros = som mais "cheio" e agudo.
    final double f0 = (12.5 * _char.cylinders).clamp(25.0, 200.0);
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
