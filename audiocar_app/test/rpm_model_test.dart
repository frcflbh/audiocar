import 'package:flutter_test/flutter_test.dart';
import 'package:audiocar_app/core/rpm_model.dart';

void main() {
  final model = RpmModel();

  group('RpmModel.rpmForSpeed', () {
    test('parado retorna marcha lenta (idle)', () {
      expect(model.rpmForSpeed(0), RpmModel.idleRpm);
      expect(model.rpmForSpeed(0.4), RpmModel.idleRpm);
    });

    test('nunca ultrapassa o RPM máximo', () {
      for (double kmh = 0; kmh <= 260; kmh += 5) {
        final rpm = model.rpmForSpeed(kmh);
        expect(rpm, lessThanOrEqualTo(RpmModel.maxRpm),
            reason: 'velocidade $kmh gerou RPM acima do máximo');
        expect(rpm, greaterThanOrEqualTo(RpmModel.idleRpm));
      }
    });

    test('RPM sobe dentro da mesma marcha', () {
      // Marcha 1 vai de 0 a 25 km/h.
      final low = model.rpmForSpeed(5);
      final high = model.rpmForSpeed(20);
      expect(high, greaterThan(low));
    });

    test('topo de marcha atinge ~redline', () {
      // No topo da 1ª marcha (25 km/h) o RPM deve estar próximo do redline.
      final rpm = model.rpmForSpeed(25);
      expect(rpm, greaterThan(RpmModel.idleRpm + 4000));
      expect(rpm, lessThanOrEqualTo(RpmModel.redlineRpm + 0.001));
    });

    test('troca de marcha derruba o RPM', () {
      // Logo abaixo do topo da 1ª marcha (25) o RPM é alto;
      // logo acima (entrando na 2ª) o RPM deve cair.
      final antesDaTroca = model.rpmForSpeed(24.9);
      final depoisDaTroca = model.rpmForSpeed(25.1);
      expect(depoisDaTroca, lessThan(antesDaTroca),
          reason: 'ao subir de marcha o RPM deveria reduzir');
    });
  });

  group('RpmModel.gearForSpeed', () {
    test('marcha 1 em baixas velocidades', () {
      expect(model.gearForSpeed(0), 1);
      expect(model.gearForSpeed(25), 1);
    });

    test('marchas progridem com a velocidade', () {
      expect(model.gearForSpeed(40), 2);
      expect(model.gearForSpeed(70), 3);
      expect(model.gearForSpeed(100), 4);
      expect(model.gearForSpeed(150), 5);
      expect(model.gearForSpeed(200), 6);
    });

    test('acima do topo permanece na última marcha', () {
      expect(model.gearForSpeed(999), model.gearCount);
    });
  });

  group('RpmModel.throttleForRpm', () {
    test('marcha lenta = throttle ~0', () {
      expect(model.throttleForRpm(RpmModel.idleRpm), closeTo(0.0, 0.001));
    });

    test('redline = throttle ~1', () {
      expect(model.throttleForRpm(RpmModel.redlineRpm), closeTo(1.0, 0.001));
    });

    test('sempre dentro de [0,1]', () {
      expect(model.throttleForRpm(0), inInclusiveRange(0.0, 1.0));
      expect(model.throttleForRpm(99999), inInclusiveRange(0.0, 1.0));
    });
  });
}
