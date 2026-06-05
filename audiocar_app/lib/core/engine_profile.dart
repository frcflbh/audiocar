// Modelo do banco "Sons de Motores" (Requisitos 4.3 e 11 da RFP).
//
// Cada EngineProfile é uma entrada do banco — um motor descrito por sua
// especificação, faixa de operação, câmbio e o sample/parametrização de áudio.
// A estrutura é inspirada nos apps de referência (ver docs/engine_sounds_reference.md).

enum EngineLayout { inline, vee, flat, rotary, vtwin, single }

enum Induction { naturalAspirated, turbo, supercharger }

enum EngineEffect { turboWhistle, backfire, supercharger, blowoff }

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

  /// Sample de áudio real (opcional) e o RPM em que foi gravado.
  final String? sampleAsset;
  final double sampleRefRpm;

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
    this.sampleAsset,
    this.sampleRefRpm = 1200,
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

  factory EngineProfile.fromJson(Map<String, dynamic> j) => EngineProfile(
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
        sampleAsset: j['sampleAsset'] as String?,
        sampleRefRpm: (j['sampleRefRpm'] as num?)?.toDouble() ?? 1200,
        modelAsset: j['modelAsset'] as String?,
        imageAsset: j['imageAsset'] as String?,
        effects: ((j['effects'] as List?) ?? const [])
            .map((e) => EngineEffect.values.byName(e as String))
            .toList(),
      );
}
