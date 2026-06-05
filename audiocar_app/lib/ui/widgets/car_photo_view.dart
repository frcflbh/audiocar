import 'package:flutter/material.dart';
import '../../theme.dart';

/// Foto estática do veículo selecionado, exibida no palco central.
///
/// Se o perfil não tiver [imageAsset] (ex.: motores genéricos), mostra um
/// placeholder discreto. Para os veículos reais, a foto licenciada é embarcada
/// em assets/images/ (ver assets/images/CREDITS.md).
class CarPhotoView extends StatelessWidget {
  final String? imageAsset;
  final String label;

  const CarPhotoView({super.key, required this.imageAsset, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFFFCFAF4), CockpitColors.background],
          radius: 0.95,
        ),
      ),
      alignment: Alignment.center,
      child: imageAsset == null
          ? _placeholder()
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                imageAsset!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _placeholder(),
              ),
            ),
    );
  }

  Widget _placeholder() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.directions_car_filled,
            size: 56, color: CockpitColors.accentSoft),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
              color: CockpitColors.textMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        const Text('sem foto disponível',
            style: TextStyle(color: CockpitColors.textMuted, fontSize: 11)),
      ],
    );
  }
}
