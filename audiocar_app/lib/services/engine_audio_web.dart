import 'dart:js_interop';

import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

import 'engine_audio_interface.dart';

/// Fábrica usada pelo conditional import em `engine_audio.dart`.
EngineAudio createEngineAudio() => WebEngineAudio();

/// Motor de áudio para navegador (Web Audio API).
///
/// Se houver um sample real em [_sampleAsset], ele é decodificado e tocado em
/// loop, com `playbackRate` seguindo o RPM (pitch). Caso contrário, faz
/// *fallback* para uma síntese com dois osciladores + filtro.
class WebEngineAudio implements EngineAudio {
  web.AudioContext? _ctx;
  web.GainNode? _gain;

  // Caminho com sample real.
  web.AudioBufferSourceNode? _bufferSource;
  bool _usingSample = false;

  // Caminho de síntese (fallback).
  web.OscillatorNode? _osc1;
  web.OscillatorNode? _osc2;
  web.BiquadFilterNode? _filter;

  bool _ready = false;

  static const String _sampleAsset = 'assets/audio/engine_loop.wav';
  static const double _sampleRefRpm = 1200;

  @override
  bool get isReady => _ready;

  @override
  Future<void> init() async {
    final ctx = web.AudioContext();
    await ctx.resume().toDart;

    final gain = ctx.createGain();
    gain.gain.value = 0;
    gain.connect(ctx.destination);

    // Tenta carregar e decodificar um sample real.
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

    if (_usingSample) {
      // Pitch do sample real segue o RPM.
      _bufferSource!.playbackRate.value =
          (rpm / _sampleRefRpm).clamp(0.5, 4.0);
      return;
    }

    // Síntese: frequência base "estilo motor" cresce com o RPM.
    final double base = (rpm / 10).clamp(40.0, 1200.0);
    _osc1!.frequency.value = base;
    _osc2!.frequency.value = base * 2;
    _filter!.frequency.value = (600 + throttle * 2600).clamp(600.0, 3200.0);
  }

  @override
  Future<void> dispose() async {
    try {
      _bufferSource?.stop();
      _osc1?.stop();
      _osc2?.stop();
    } catch (_) {}
    final ctx = _ctx;
    if (ctx != null) {
      await ctx.close().toDart;
    }
    _ready = false;
  }
}
