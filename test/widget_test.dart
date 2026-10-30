import 'package:flutter_test/flutter_test.dart';
import 'package:trustride/core/models.dart';
import 'package:trustride/services/auth_service.dart';

void main() {
  test('fare uses base + distance + time', () {
    final car = AppConfig.defaults.ride('car');
    // 20 + 12 * 5 km + 0.8 * 15 min = 92
    expect(car.fareFor(5, 15), 92);
  });

  test('fare never goes below the minimum', () {
    final car = AppConfig.defaults.ride('car');
    expect(car.fareFor(0.2, 1), car.minFare);
  });

  test('config falls back to defaults when empty', () {
    final c = AppConfig.fromMap(null);
    expect(c.rideTypes.length, AppConfig.defaults.rideTypes.length);
    expect(c.commission, 0.15);
  });

  test('config round-trips through a map', () {
    final c = AppConfig.defaults.copyWith(commission: 0.2, supportPhone: '+23276000000');
    final back = AppConfig.fromMap(c.toMap());
    expect(back.commission, 0.2);
    expect(back.supportPhone, '+23276000000');
    expect(back.ride('okada').perKm, c.ride('okada').perKm);
  });

  test('phone numbers are normalised to +232', () {
    expect(AuthService.normalise('076 123 456'), '+23276123456');
    expect(AuthService.normalise('76123456'), '+23276123456');
    expect(AuthService.normalise('+232 76 123 456'), '+23276123456');
  });
}
