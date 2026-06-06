import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'engine_audio_interface.dart';

/// Fábrica usada pelo conditional import em `engine_audio.dart`.
EngineAudio createEngineAudio() => WebEngineAudio();

/// Motor de áudio para navegador (Web Audio API) com engenharia de áudio
/// pra extrair mais realismo do single sample real:
///
/// - `playbackRate` em faixa **estreita** (0.75x–1.65x) → evita o efeito
///   "chipmunk" em RPM alto.
/// - **Filtro low-pass dinâmico** entre BufferSource e ganho do sample: a
///   frequência de corte abre conforme o RPM, simulando o motor "abrindo"
///   ao acelerar (idle → 500 Hz; redline → 6 kHz).
/// - Assobio de turbo (oscilador sintético) **somado por cima** da gravação
///   em carros turbo, pra entregar a parte do timbre que a gravação genérica
///   não tem.
/// - Fallback para síntese pura (osciladores + ruído) se a gravação falhar.
class WebEngineAudio implements EngineAudio {
  web.AudioContext? _ctx;
  web.GainNode? _master; // volume geral (throttle)
  web.GainNode? _oscGain; // seletor: síntese
  web.GainNode? _sampleGain; // seletor: gravação real
  web.BiquadFilterNode? _sampleFilter; // filtro dinâmico do sample

  // Síntese (fallback).
  web.OscillatorNode? _osc1;
  web.OscillatorNode? _osc2;
  web.BiquadFilterNode? _filter;
  web.OscillatorNode? _whistle;
  web.GainNode? _whistleGain;

  // Gravação real.
  web.AudioBufferSourceNode? _bufferSource;
  bool _usingSample = false;

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

    // Filtro dinâmico do sample: BufferSource → filtro → sampleGain.
    // Inicia com cutoff baixo (idle); update() abre conforme o RPM.
    final sampleFilter = ctx.createBiquadFilter()
      ..type = 'lowpass'
      ..frequency.value = 800
      ..Q.value = 0.7;
    sampleFilter.connect(sampleGain);

    // Síntese (fallback).
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
    _sampleFilter = sampleFilter;
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
      // Fetch direto no path do asset (respeita o <base href> da página).
      // Mais confiável que rootBundle.load em release builds.
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
      // BufferSource → filtro dinâmico → sampleGain → master
      src.connect(_sampleFilter!);
      src.start();
      _bufferSource = src;
      _usingSample = true;
      _oscGain!.gain.value = 0; // silencia a síntese
      _sampleGain!.gain.value = 1;
    } catch (_) {
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
    if (_muted) {
      _master!.gain.value = 0;
      return;
    }
    // Volume geral cresce com o pedal.
    _master!.gain.value = (0.07 + throttle * 0.55).clamp(0.0, 0.65);

    if (_usingSample) {
      // RPM normalizado em [0..1+] do idle ao redline do motor selecionado.
      final t = _char.t(rpm).clamp(0.0, 1.2);

      // Playback rate em faixa NATURAL: evita "chipmunk" no redline.
      // Em idle toca 25% mais lento, no redline 65% mais rápido.
      _bufferSource?.playbackRate.value = 0.75 + t * 0.9;

      // Filtro low-pass abre com o RPM: dá a sensação de motor "abrindo".
      // Idle ≈ 600 Hz, redline ≈ 6 kHz. Pedal adiciona até +1 kHz pra brilho.
      _sampleFilter!.frequency.value =
          (600 + t * 5400 + throttle * 1000).clamp(500.0, 8000.0);
      // Resonância sobe um pouco com o RPM pra dar mordida no alto.
      _sampleFilter!.Q.value = (0.5 + t * 0.8).clamp(0.5, 1.5);

      // Carros turbo: mistura o assobio sintético por cima da gravação real,
      // já que a gravação que temos é de outro motor (não tem o whistle dele).
      if (_char.turbo) {
        _whistle!.frequency.value = (1800 + rpm * 0.5).clamp(1500.0, 6000.0);
        // Mais sutil quando há sample: só uma camada de cor.
        _whistleGain!.gain.value =
            (throttle * throttle * 0.025).clamp(0.0, 0.03);
      } else {
        _whistleGain!.gain.value = 0;
      }
      return;
    }

    // Síntese (fallback): osciladores + assobio.
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
