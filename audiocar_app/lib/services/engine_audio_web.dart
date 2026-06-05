import 'dart:js_interop';

import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

import 'engine_audio_interface.dart';

/// Fábrica usada pelo conditional import em `engine_audio.dart`.
EngineAudio createEngineAudio() => WebEngineAudio();

/// Motor de áudio para navegador (Web Audio API).
///
/// Sintetiza o som com base na frequência de combustão do motor selecionado
/// (nº de cilindros), com um assobio de turbo opcional — dando timbre distinto
/// a cada carro. Se houver um sample real em [sampleAsset] padrão, ele é tocado
/// em loop com `playbackRate` seguindo o RPM.
class WebEngineAudio implements EngineAudio {
  web.AudioContext? _ctx;
  web.GainNode? _gain;

  web.AudioBufferSourceNode? _bufferSource;
  bool _usingSample = false;

  web.OscillatorNode? _osc1;
  web.OscillatorNode? _osc2;
  web.BiquadFilterNode? _filter;

  // Assobio de turbo.
  web.OscillatorNode? _whistle;
  web.GainNode? _whistleGain;

  bool _ready = false;
  EngineSoundCharacter _char = const EngineSoundCharacter();

  static const String _sampleAsset = 'assets/audio/engine_loop.wav';
  static const double _sampleRefRpm = 1200;

  @override
  bool get isReady => _ready;

  @override
  void setCharacter(EngineSoundCharacter character) => _char = character;

  @override
  Future<void> init() async {
    final ctx = web.AudioContext();
    await ctx.resume().toDart;

    final gain = ctx.createGain();
    gain.gain.value = 0;
    gain.connect(ctx.destination);

    // Assobio de turbo (sempre criado; ganho 0 quando não há turbo).
    final whistle = ctx.createOscillator()..type = 'sine';
    final whistleGain = ctx.createGain();
    whistleGain.gain.value = 0;
    whistle.connect(whistleGain);
    whistleGain.connect(ctx.destination);
    whistle.start();

    try {
      final data = await rootBundle.load(_sampleAsset);
      final buffer = await ctx.decodeAudioData(data.buffer.toJS).toDart;
      final src = ctx.createBufferSource();
      src.buffer = buffer;
      src.loop = true;
      src.connect(gain);
      src.start();
      _bufferSource = src;
      _usingSample = true;
    } catch (_) {
      _buildOscillators(ctx, gain);
      _usingSample = false;
    }

    _ctx = ctx;
    _gain = gain;
    _whistle = whistle;
    _whistleGain = whistleGain;
    _ready = true;
  }

  void _buildOscillators(web.AudioContext ctx, web.GainNode gain) {
    final osc1 = ctx.createOscillator()..type = 'sawtooth';
    final osc2 = ctx.createOscillator()..type = 'square';
    osc2.detune.value = -8;

    final filter = ctx.createBiquadFilter()..type = 'lowpass';
    filter.frequency.value = 1100;

    osc1.connect(filter);
    osc2.connect(filter);
    filter.connect(gain);

    osc1.start();
    osc2.start();

    _osc1 = osc1;
    _osc2 = osc2;
    _filter = filter;
  }

  @override
  void update({required double rpm, required double throttle}) {
    if (!_ready) return;
    final double vol = (0.05 + throttle * 0.22).clamp(0.0, 0.3);
    _gain!.gain.value = vol;

    // Assobio de turbo: sobe com o RPM, só audível ao acelerar.
    if (_char.turbo) {
      _whistle!.frequency.value = (1800 + rpm * 0.6).clamp(1500.0, 6500.0);
      _whistleGain!.gain.value = (throttle * throttle * 0.04).clamp(0.0, 0.05);
    } else {
      _whistleGain!.gain.value = 0;
    }

    if (_usingSample) {
      _bufferSource!.playbackRate.value =
          (rpm / _sampleRefRpm).clamp(0.5, 4.0);
      return;
    }

    // Frequência de combustão → timbre por nº de cilindros.
    final double firing = _char.firingHz(rpm);
    _osc1!.frequency.value = (firing).clamp(28.0, 1400.0);
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
