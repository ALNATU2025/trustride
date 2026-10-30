import 'package:flutter_test/flutter_test.dart';
import 'package:trustride/core/app_state.dart';
import 'package:trustride/core/data.dart';

void main() {
  test('fares are calculated from distance', () {
    final car = Mock.rides.firstWhere((r) => r.id == 'car');
    expect(car.fareFor(4.2), 85);
  });

  test('wallet payment deducts the fare', () {
    final s = AppState()..setPayment('wallet');
    final before = s.wallet;
    expect(s.pay(), isTrue);
    expect(s.wallet, before - s.fare);
  });

  test('approving a driver clears them from the queue', () {
    final s = AppState();
    final pending = s.pendingCount;
    s.review(s.applicants.first, 'approved');
    expect(s.pendingCount, pending - 1);
  });
}
