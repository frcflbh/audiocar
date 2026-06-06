// Modelo do banco "Sons de Motores" (Requisitos 4.3 e 11 da RFP).
//
// Cada EngineProfile é uma entrada do banco — um motor descrito por sua
// especificação, faixa de operação, câmbio e o(s) sample(s) de áudio em
// múltiplas bandas de RPM (para crossfade em tempo real).

enum EngineLayout { inline, vee, flat, rotary, vtwin, single }

enum Induction { naturalAspirated, turbo, supercharger }

enum EngineEffect { turboWhistle, backfire, supercharger, blowoff }

/// Uma "banda" de áudio: gravação correspondente a uma faixa de RPM.
class EngineSample {
  /// Path do asset (ex.: `assets/audio/ferrari_f40_high.ogg`).
  final String asset;

  /// RPM em que a gravação foi feita. Usado pelo motor de áudio para
  /// (a) ajustar o playbackRate (pitch ≈ rpmAtual/refRpm) e
  /// (b) escolher pesos entre bandas adjacentes no crossfade.
  final double refRpm;

  const EngineSample({required this.asset, required this.refRpm});

  factory EngineSample.fromJson(Map<String, dynamic> j) => EngineSample(
        asset: j['asset'] as String,
        refRpm: (j['rpm'] ?? j['refRpm'] as num).toDouble(),
      );
}

class EngineProfile {
  final String id;
  final String name; // descrição genérica (sem marca registrada)
  final String category; // ex.: "Supercarro", "Muscle", "Moto"
  final double displacementL; // cilindrada em litros
  final int cylinders;
  final EngineLayout layout;
  final Induction induction;

  final double idleRpm;
  final double redlineRpm;
  final double maxRpm;

  /// Velocidade (km/h) no topo de cada marcha — define as relações do câmbio.
  final List<double> gearTopSpeedKmh;

  /// Bandas de áudio do motor (ordenadas por refRpm). Pode ter 1+ entradas.
  /// Vazio = sem gravação; cai na síntese.
  final List<EngineSample> samples;

  /// Modelo 3D glTF/GLB real do veículo (opcional). Slot p/ asset licenciado.
  final String? modelAsset;

  /// Foto estática do veículo (opcional). Exibida no palco central.
  final String? imageAsset;

  final List<EngineEffect> effects;
  final String packId;

  bool get isTurbo => induction == Induction.turbo;

  const EngineProfile({
    required this.id,
    required this.name,
    required this.category,
    required this.displacementL,
    required this.cylinders,
    required this.layout,
    required this.induction,
    required this.idleRpm,
    required this.redlineRpm,
    required this.maxRpm,
    required this.gearTopSpeedKmh,
    required this.packId,
    this.samples = const [],
    this.modelAsset,
    this.imageAsset,
    this.effects = const [],
  });

  /// Rótulo curto estilo RevHeadz: "6.0L V12 · Supercarro".
  String get specLabel {
    final layoutStr = switch (layout) {
      EngineLayout.inline => 'I$cylinders',
      EngineLayout.vee => 'V$cylinders',
      EngineLayout.flat => 'F$cylinders',
      EngineLayout.rotary => 'Rotativo',
      EngineLayout.vtwin => 'V-Twin',
      EngineLayout.single => 'Monocilíndrico',
    };
    return '${displacementL.toStringAsFixed(1)}L $layoutStr · $category';
  }

  factory EngineProfile.fromJson(Map<String, dynamic> j) {
    // Aceita formato novo (`samples: [...]`) e legado (`sampleAsset` + `sampleRefRpm`).
    final samplesJson = j['samples'] as List?;
    final List<EngineSample> samples;
    if (samplesJson != null && samplesJson.isNotEmpty) {
      samples = samplesJson
          .map((e) => EngineSample.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.refRpm.compareTo(b.refRpm));
    } else if (j['sampleAsset'] is String) {
      samples = [
        EngineSample(
          asset: j['sampleAsset'] as String,
          refRpm: (j['sampleRefRpm'] as num?)?.toDouble() ?? 1200,
        )
      ];
    } else {
      samples = const [];
    }

    return EngineProfile(
      id: j['id'] as String,
      name: j['name'] as String,
      category: j['category'] as String,
      displacementL: (j['displacementL'] as num).toDouble(),
      cylinders: (j['cylinders'] as num).toInt(),
      layout: EngineLayout.values.byName(j['layout'] as String),
      induction: Induction.values.byName(j['induction'] as String),
      idleRpm: (j['idleRpm'] as num).toDouble(),
      redlineRpm: (j['redlineRpm'] as num).toDouble(),
      maxRpm: (j['maxRpm'] as num).toDouble(),
      gearTopSpeedKmh: (j['gearTopSpeedKmh'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      packId: j['packId'] as String,
      samples: samples,
      modelAsset: j['modelAsset'] as String?,
      imageAsset: j['imageAsset'] as String?,
      effects: ((j['effects'] as List?) ?? const [])
          .map((e) => EngineEffect.values.byName(e as String))
          .toList(),
    );
  }
}
