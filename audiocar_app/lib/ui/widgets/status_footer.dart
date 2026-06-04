import 'package:flutter/material.dart';
import '../../theme.dart';

/// Rodapé de status do cockpit (Requisito 5.1 da RFP):
/// Modo | Veículo | Status OBD2.
class StatusFooter extends StatelessWidget {
  final String mode;
  final String vehicle;
  final int gear;
  final bool obd2Connected;

  const StatusFooter({
    super.key,
    required this.mode,
    required this.vehicle,
    required this.gear,
    this.obd2Connected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: CockpitColors.panel,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _item(Icons.tune, 'Modo', mode),
          _item(Icons.directions_car, 'Veículo', vehicle),
          _item(Icons.swap_vert, 'Marcha', gear.toString()),
          _item(
            obd2Connected ? Icons.link : Icons.link_off,
            'OBD2',
            obd2Connected ? 'Conectado' : 'Off',
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: CockpitColors.accent),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    color: CockpitColors.textMuted, fontSize: 10)),
            Text(value,
                style: const TextStyle(
                    color: CockpitColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
