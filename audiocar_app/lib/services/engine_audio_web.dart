import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'engine_audio_interface.dart';

/// Fábrica usada pelo conditional import em `engine_audio.dart`.
EngineAudio createEngineAudio() => WebEngineAudio();

/// Motor de áudio para navegador (Web Audio API).
///
/// Toca a **gravação real** do motor selecionado (loop, com pitch seguindo o
/// RPM). Se não houver gravação, cai na síntese (osciladores + assobio de turbo).
class WebEngineAudio implements EngineAudio {
  web.AudioContext? _ctx;
  web.GainNode? _master; // volume geral (throttle)
  web.GainNode? _oscGain; // seletor: síntese
  web.GainNode? _sampleGain; // seletor: gravação real

  // Síntese (fallback).
  web.OscillatorNode? _osc1;
  web.OscillatorNode? _osc2;
  web.BiquadFilterNode? _filter;
  web.OscillatorNode? _whistle;
  web.GainNode? _whistleGain;

  // Gravação real.
  web.AudioBufferSourceNode? _bufferSource;
  bool _usingSample = false;
  double _sampleRefRpm = 1200;

  bool _ready = false;
  bool _muted = false;
  EngineSoundCharacter _char = const EngineSoundCharacter();
  String? _pendingSample;
  double _pendingRefRpm = 1200;

  @override
  bool get isReady => _ready;

  @override
  void setCharacter(EngineSoundCharacter character) => _char = character;

  @override
  void setSample(String? assetPath, double refRpm) {
    _pendingSample = assetPath;
    _pendingRefRpm = refRpm;
    if (_ready) _applySample(assetPath, refRpm);
  }

  @override
  Future<void> init() async {
    final ctx = web.AudioContext();
    await ctx.resume().toDart;

    final master = ctx.createGain();
    master.gain.value = 0;
    master.connect(ctx.destination);

    final oscGain = ctx.createGain()..gain.value = 1; // síntese por padrão
    final sampleGain = ctx.createGain()..gain.value = 0;
    oscGain.connect(master);
    sampleGain.connect(master);

    // Síntese.
    final osc1 = ctx.createOscillator()..type = 'sawtooth';
    final osc2 = ctx.createOscillator()..type = 'square';
    osc2.detune.value = -8;
    final filter = ctx.createBiquadFilter()..type = 'lowpass';
    filter.frequency.value = 1100;
    osc1.connect(filter);
    osc2.connect(filter);
    filter.connect(oscGain);
    osc1.start();
    osc2.start();

    final whistle = ctx.createOscillator()..type = 'sine';
    final whistleGain = ctx.createGain()..gain.value = 0;
    whistle.connect(whistleGain);
    whistleGain.connect(master);
    whistle.start();

    _ctx = ctx;
    _master = master;
    _oscGain = oscGain;
    _sampleGain = sampleGain;
    _osc1 = osc1;
    _osc2 = osc2;
    _filter = filter;
    _whistle = whistle;
    _whistleGain = whistleGain;
    _ready = true;

    if (_pendingSample != null) {
      await _applySample(_pendingSample, _pendingRefRpm);
    }
  }

  Future<void> _applySample(String? assetPath, double refRpm) async {
    final ctx = _ctx;
    if (ctx == null) return;

    // Para a gravação anterior, se houver.
    try {
      _bufferSource?.stop();
    } catch (_) {}
    _bufferSource = null;

    if (assetPath == null) {
      _usingSample = false;
      _oscGain!.gain.value = 1;
      _sampleGain!.gain.value = 0;
      return;
    }

    try {
      // No web, vamos direto pelo fetch (mais confiável que rootBundle.load em
      // release builds, que serializa assets num bundle compartilhado e podia
      // devolver um ByteData vazio neste fluxo).
      // O fetch relativo respeita o <base href> da página (ex.: /audiocar/).
      // Flutter publica assets em 'assets/<path>', então prefixamos.
      final url = 'assets/$assetPath';
      final response = await web.window.fetch(url.toJS).toDart;
      if (!response.ok) {
        throw StateError('HTTP ${response.status} para $assetPath');
      }
      final ab = await response.arrayBuffer().toDart;
      final buffer = await ctx.decodeAudioData(ab).toDart;
      final src = ctx.createBufferSource();
      src.buffer = buffer;
      src.loop = true;
      src.connect(_sampleGain!);
      src.start();
      _bufferSource = src;
      _sampleRefRpm = refRpm;
      _usingSample = true;
      _oscGain!.gain.value = 0; // silencia a síntese
      _sampleGain!.gain.value = 1;
    } catch (_) {
      // Falhou: mantém a síntese.
      _usingSample = false;
      _oscGain!.gain.value = 1;
      _sampleGain!.gain.value = 0;
    }
  }

  @override
  void setMuted(bool muted) {
    _muted = muted;
    if (_ready) _master!.gain.value = muted ? 0 : _master!.gain.value;
  }

  @override
  void update({required double rpm, required double throttle}) {
    if (!_ready) return;
    _master!.gain.value =
        _muted ? 0 : (0.06 + throttle * 0.5).clamp(0.0, 0.6);

    if (_usingSample) {
      _bufferSource?.playbackRate.value =
          (rpm / _sampleRefRpm).clamp(0.5, 3.5);
      _whistleGain!.gain.value = 0; // a gravação já tem o som do turbo
      return;
    }

    // Síntese: assobio de turbo + frequência de combustão por cilindros.
    if (_char.turbo) {
      _whistle!.frequency.value = (1800 + rpm * 0.6).clamp(1500.0, 6500.0);
      _whistleGain!.gain.value = (throttle * throttle * 0.04).clamp(0.0, 0.05);
    } else {
      _whistleGain!.gain.value = 0;
    }
    final double firing = _char.firingHz(rpm);
    _osc1!.frequency.value = firing.clamp(28.0, 1400.0);
    _osc2!.frequency.value = (firing * 2).clamp(40.0, 3000.0);
    _filter!.frequency.value = (600 + throttle * 2600).clamp(600.0, 3200.0);
  }

  @override
  Future<void> dispose() async {
    try {
      _bufferSource?.stop();
      _osc1?.stop();
      _osc2?.stop();
      _whistle?.stop();
    } catch (_) {}
    final ctx = _ctx;
    if (ctx != null) {
      await ctx.close().toDart;
    }
    _ready = false;
  }
}
