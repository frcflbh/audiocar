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
  List<EngineBand> _bands = const [];
  int _activeBandIdx = -1;

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
  void setBands(List<EngineBand> bands) {
    _bands = bands;
    _activeBandIdx = -1;
    if (_ready) unawaited(_applyInitialBand());
  }

  Future<void> _applyInitialBand() async {
    if (_bands.isEmpty) {
      _usingSample = false;
      _activeBandIdx = -1;
      await _swapSource(_buildEngineWav());
      return;
    }
    // Começa pela banda de RPM mais baixo (típicamente idle).
    await _loadBand(0);
  }

  Future<void> _loadBand(int idx) async {
    if (idx < 0 || idx >= _bands.length || idx == _activeBandIdx) return;
    final band = _bands[idx];
    try {
      final data = await rootBundle.load(band.assetPath);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await _swapSource(bytes);
      _usingSample = true;
      _sampleRefRpm = band.refRpm;
      _activeBandIdx = idx;
    } catch (_) {
      _usingSample = false;
      _activeBandIdx = -1;
      await _swapSource(_buildEngineWav());
    }
  }

  /// Escolhe a banda cujo refRpm é mais próximo do RPM atual e troca se mudar.
  /// (Multi-band crossfade real é complexo em SoLoud — no nativo fazemos
  /// step-change. No web a transição é contínua.)
  void _ensureBandForRpm(double rpm) {
    if (_bands.length <= 1) return;
    int best = 0;
    double bestDiff = (_bands[0].refRpm - rpm).abs();
    for (int i = 1; i < _bands.length; i++) {
      final d = (_bands[i].refRpm - rpm).abs();
      if (d < bestDiff) {
        best = i;
        bestDiff = d;
      }
    }
    if (best != _activeBandIdx) {
      unawaited(_loadBand(best));
    }
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

    // Síntese por padrão; a(s) gravação(ões) real(is) são aplicadas via setBands.
    _source = await _soloud.loadMem('audiocar_engine', _buildEngineWav());
    _handle = await _soloud.play(_source!, looping: true, volume: 0.0);
    _usingSample = false;
    _ready = true;

    if (_bands.isNotEmpty) {
      await _applyInitialBand();
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
    // Step-change para a banda mais próxima do RPM atual (no nativo).
    if (_usingSample) _ensureBandForRpm(rpm);
    final double refRpm = _usingSample ? _sampleRefRpm : _synthRefRpm;
    final double playSpeed = (rpm / refRpm).clamp(0.75, 1.6);
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
