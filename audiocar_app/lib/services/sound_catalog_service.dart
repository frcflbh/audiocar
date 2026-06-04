import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/engine_profile.dart';
import '../core/sound_pack.dart';

/// Carrega e expõe o banco "Sons de Motores" (Requisitos 4.3 e 11 da RFP).
///
/// Hoje lê de um asset JSON versionado; no futuro, a mesma interface pode
/// buscar de um endpoint remoto (download remoto de veículos) sem mudar o app.
class SoundCatalogService {
  static const String _asset = 'assets/sounds/engine_catalog.json';

  int version = 0;
  List<SoundPack> packs = const [];
  List<EngineProfile> profiles = const [];

  bool get isLoaded => profiles.isNotEmpty;

  Future<void> load() async {
    final raw = await rootBundle.loadString(_asset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    version = (json['version'] as num?)?.toInt() ?? 0;
    packs = (json['packs'] as List)
        .map((e) => SoundPack.fromJson(e as Map<String, dynamic>))
        .toList();
    profiles = (json['profiles'] as List)
        .map((e) => EngineProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  SoundPack? packById(String id) {
    for (final p in packs) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Perfis disponíveis ao usuário: packs gratuitos sempre; packs premium só
  /// quando [hasPremium] (Requisitos 4.6 e 11 da RFP).
  List<EngineProfile> availableProfiles({required bool hasPremium}) {
    return profiles.where((p) {
      final pack = packById(p.packId);
      if (pack == null) return false;
      return pack.isFree || (pack.isPremium && hasPremium) || !pack.isPremium;
    }).toList();
  }

  /// Indica se um perfil está bloqueado (pack premium e usuário sem premium).
  bool isLocked(EngineProfile profile, {required bool hasPremium}) {
    final pack = packById(profile.packId);
    if (pack == null) return true;
    return pack.isPremium && !hasPremium;
  }
}

/// Instância única usada pelo app.
final SoundCatalogService soundCatalog = SoundCatalogService();
