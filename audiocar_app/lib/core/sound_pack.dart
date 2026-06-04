/// Pacote de sons (Requisitos 4.3 e 11 da RFP).
///
/// Agrupa perfis do banco "Sons de Motores" para distribuição/venda.
/// Inspirado nos packs do RevHeadz (gratuito + pagos).
class SoundPack {
  final String id;
  final String name;
  final String description;
  final bool isFree;

  /// Preço em centavos (0 quando gratuito). Exibido na loja (§11).
  final int priceCents;

  /// Se requer assinatura/compra premium para uso.
  final bool isPremium;

  const SoundPack({
    required this.id,
    required this.name,
    required this.description,
    required this.isFree,
    this.priceCents = 0,
    this.isPremium = false,
  });

  String get priceLabel =>
      isFree ? 'Grátis' : 'R\$ ${(priceCents / 100).toStringAsFixed(2)}';

  factory SoundPack.fromJson(Map<String, dynamic> j) => SoundPack(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        isFree: j['isFree'] as bool,
        priceCents: (j['priceCents'] as num?)?.toInt() ?? 0,
        isPremium: j['isPremium'] as bool? ?? false,
      );
}
