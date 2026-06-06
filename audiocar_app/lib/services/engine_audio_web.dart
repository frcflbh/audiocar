import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import 'engine_audio_interface.dart';

/// Fábrica usada pelo conditional import em `engine_audio.dart`.
EngineAudio createEngineAudio() => WebEngineAudio();

/// Banda individual no grafo de áudio web: loop da gravação + ganho próprio.
class _WebBand {
  final web.AudioBufferSourceNode source;
  final web.GainNode gain;
  final double refRpm;
  _WebBand(this.source, this.gain, this.refRpm);
}

/// Motor de áudio web com **crossfade multi-band**:
///
/// - Cada carro pode ter 1+ gravações (`EngineBand`) em RPMs diferentes
///   (idle / mid / high / redline).
/// - Em runtime, calcula pesos de equal-power crossfade entre as 2 bandas
///   adjacentes ao RPM atual, dando uma transição contínua.
/// - Cada banda toca em `playbackRate = (rpm/refRpm)` clampado em faixa
///   estreita (0.75–1.5x) pra evitar "chipmunk" — quando o RPM passa muito
///   da refRpm da banda atual, a outra banda já assume o som.
/// - Filtro low-pass dinâmico (compartilhado entre bandas) abre conforme o
///   RPM, simulando o motor "abrindo" ao acelerar.
/// - Whistle sintético somado por cima em carros turbo (a gravação genérica
///   não tem o assobio autêntico do carro).
/// - Fallback para síntese pura se nenhuma banda decodificar.
class WebEngineAudio implements EngineAudio {
  web.AudioContext? _ctx;
  web.GainNode? _master;
  web.GainNode? _oscGain; // sintese
  web.GainNode? _sampleGain; // soma de todas as bandas
  web.BiquadFilterNode? _sampleFilter; // filtro dinâmico compartilhado

  // Síntese (fallback).
  web.OscillatorNode? _osc1;
  web.OscillatorNode? _osc2;
  web.BiquadFilterNode? _filter;
  web.OscillatorNode? _whistle;
  web.GainNode? _whistleGain;

  // Bandas reais.
  List<_WebBand> _bands = [];
  bool _usingSample = false;

  bool _ready = false;
  bool _muted = false;
  EngineSoundCharacter _char = const EngineSoundCharacter();
  List<EngineBand> _pendingBands = const [];

  @override
  bool get isReady => _ready;

  @override
  void setCharacter(EngineSoundCharacter character) => _char = character;

  @override
  void setBands(List<EngineBand> bands) {
    _pendingBands = bands;
    if (_ready) _applyBands(bands);
  }

  @override
  Future<void> init() async {
    final ctx = web.AudioContext();
    await ctx.resume().toDart;

    final master = ctx.createGain()..gain.value = 0;
    master.connect(ctx.destination);

    final oscGain = ctx.createGain()..gain.value = 1;
    final sampleGain = ctx.createGain()..gain.value = 0;
    oscGain.connect(master);
    sampleGain.connect(master);

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

    if (_pendingBands.isNotEmpty) {
      await _applyBands(_pendingBands);
    }
  }

  Future<void> _applyBands(List<EngineBand> bands) async {
    final ctx = _ctx;
    final filterNode = _sampleFilter;
    if (ctx == null || filterNode == null) return;

    // Desliga as bandas anteriores.
    for (final b in _bands) {
      try {
        b.source.stop();
      } catch (_) {}
      try {
        b.source.disconnect();
        b.gain.disconnect();
      } catch (_) {}
    }
    _bands = [];

    if (bands.isEmpty) {
      _usingSample = false;
      _oscGain!.gain.value = 1;
      _sampleGain!.gain.value = 0;
      return;
    }

    final List<_WebBand> loaded = [];
    for (final b in bands) {
      try {
        final url = 'assets/${b.assetPath}';
        final response = await web.window.fetch(url.toJS).toDart;
        if (!response.ok) continue;
        final ab = await response.arrayBuffer().toDart;
        final buffer = await ctx.decodeAudioData(ab).toDart;
        final src = ctx.createBufferSource();
        src.buffer = buffer;
        src.loop = true;
        final gain = ctx.createGain()..gain.value = 0;
        src.connect(gain);
        gain.connect(filterNode);
        src.start();
        loaded.add(_WebBand(src, gain, b.refRpm));
      } catch (_) {
        // Banda específica falhou; segue tentando as outras.
      }
    }

    if (loaded.isEmpty) {
      _usingSample = false;
      _oscGain!.gain.value = 1;
      _sampleGain!.gain.value = 0;
      return;
    }

    // Garante ordem por refRpm (defensivo; já vem ordenado).
    loaded.sort((a, b) => a.refRpm.compareTo(b.refRpm));
    _bands = loaded;
    _usingSample = true;
    _oscGain!.gain.value = 0;
    _sampleGain!.gain.value = 1;
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
    _master!.gain.value = (0.07 + throttle * 0.55).clamp(0.0, 0.65);

    if (_usingSample && _bands.isNotEmpty) {
      _updateBands(rpm);

      // Filtro low-pass abre com o RPM (mais brilho ao acelerar).
      final t = _char.t(rpm).clamp(0.0, 1.2);
      _sampleFilter!.frequency.value =
          (600 + t * 5400 + throttle * 1000).clamp(500.0, 8000.0);
      _sampleFilter!.Q.value = (0.5 + t * 0.8).clamp(0.5, 1.5);

      // Whistle de turbo somado por cima em carros turbo.
      if (_char.turbo) {
        _whistle!.frequency.value = (1800 + rpm * 0.5).clamp(1500.0, 6000.0);
        _whistleGain!.gain.value =
            (throttle * throttle * 0.025).clamp(0.0, 0.03);
      } else {
        _whistleGain!.gain.value = 0;
      }
      return;
    }

    // Síntese (fallback).
    if (_char.turbo) {
      _whistle!.frequency.value = (1800 + rpm * 0.6).clamp(1500.0, 6500.0);
      _whistleGain!.gain.value = (throttle * throttle * 0.04).clamp(0.0, 0.05);
    } else {
      _whistleGain!.gain.value = 0;
    }
    final firing = _char.firingHz(rpm);
    _osc1!.frequency.value = firing.clamp(28.0, 1400.0);
    _osc2!.frequency.value = (firing * 2).clamp(40.0, 3000.0);
    _filter!.frequency.value = (600 + throttle * 2600).clamp(600.0, 3200.0);
  }

  /// Distribui pesos de equal-power crossfade entre as 2 bandas adjacentes
  /// ao RPM atual e ajusta o playbackRate de cada uma.
  void _updateBands(double rpm) {
    final n = _bands.length;
    if (n == 1) {
      final b = _bands[0];
      b.gain.gain.value = 1;
      b.source.playbackRate.value = (rpm / b.refRpm).clamp(0.5, 2.0);
      return;
    }

    // Encontra a banda imediatamente abaixo e a imediatamente acima do RPM.
    int lower = 0;
    for (int i = 0; i < n - 1; i++) {
      if (rpm >= _bands[i].refRpm) lower = i;
    }
    int upper = math.min(lower + 1, n - 1);
    if (rpm < _bands[0].refRpm) {
      lower = 0;
      upper = 0;
    } else if (rpm >= _bands[n - 1].refRpm) {
      lower = n - 1;
      upper = n - 1;
    }

    // Peso entre as duas bandas (equal-power).
    final double tBand = (lower == upper)
        ? 0.0
        : ((rpm - _bands[lower].refRpm) /
                (_bands[upper].refRpm - _bands[lower].refRpm))
            .clamp(0.0, 1.0);
    final double wLow = math.sqrt(1 - tBand);
    final double wHigh = math.sqrt(tBand);

    for (int i = 0; i < n; i++) {
      final b = _bands[i];
      double g = 0;
      if (i == lower && i == upper) {
        g = 1;
      } else if (i == lower) {
        g = wLow;
      } else if (i == upper) {
        g = wHigh;
      }
      b.gain.gain.value = g;
      // playbackRate clampado pra evitar pitch-shift agressivo (cada banda
      // só estica um pouco; quando o RPM passa, a próxima banda assume).
      b.source.playbackRate.value = (rpm / b.refRpm).clamp(0.75, 1.5);
    }
  }

  @override
  Future<void> dispose() async {
    try {
      for (final b in _bands) {
        b.source.stop();
      }
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
