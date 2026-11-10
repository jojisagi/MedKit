import 'package:flutter_test/flutter_test.dart';
import 'package:mi_botiquin/domain/inventory_rules.dart';
import 'package:mi_botiquin/domain/models.dart';

Box box(int id, {int? profileId, double units = 10, required DateTime expires, bool archived = false}) => Box(
      id: id,
      productId: 1,
      profileId: profileId,
      unitsInitial: units,
      unitsLeft: units,
      expiresOn: expires,
      addedAt: DateTime(2026, 1, 1),
      archived: archived,
    );

void main() {
  final today = DateTime(2026, 11, 10);
  final a = box(1, profileId: 1, units: 4, expires: DateTime(2027, 1, 31));
  final b = box(2, units: 10, expires: DateTime(2026, 12, 31));
  final c = box(3, profileId: 1, units: 10, expires: DateTime(2026, 10, 1));

  String fmt(List<Deduction> d) => d.map((e) => '${e.boxId}:${e.units}').join(',');

  group('planDeduction', () {
    test('propio antes que compartida', () {
      final r = planDeduction([a, b, c], 1, profileId: 1, today: today);
      expect(fmt(r.deductions), '1:1.0');
      expect(r.shortfall, 0);
    });
    test('se reparte entre cajas', () {
      final r = planDeduction([a, b, c], 6, profileId: 1, today: today);
      expect(fmt(r.deductions), '1:4.0,2:2.0');
      expect(r.shortfall, 0);
    });
    test('caducada no cuenta aunque sea la única', () {
      final r = planDeduction([c], 1, profileId: 1, today: today);
      expect(r.deductions, isEmpty);
      expect(r.shortfall, 1);
    });
    test('media tableta', () {
      expect(fmt(planDeduction([a], 0.5, profileId: 1, today: today).deductions), '1:0.5');
    });
    test('cajas de otro perfil y archivadas se ignoran', () {
      final other = box(4, profileId: 2, expires: DateTime(2027, 1, 1));
      final arch = box(5, profileId: 1, expires: DateTime(2027, 1, 1), archived: true);
      final r = planDeduction([other, arch], 1, profileId: 1, today: today);
      expect(r.shortfall, 1);
    });
    test('FEFO dentro del mismo grupo', () {
      final late = box(6, profileId: 1, expires: DateTime(2027, 5, 1));
      final soon = box(7, profileId: 1, expires: DateTime(2026, 12, 1));
      expect(fmt(planDeduction([late, soon], 1, profileId: 1, today: today).deductions), '7:1.0');
    });
    test('insuficiente descuenta lo que hay', () {
      final r = planDeduction([a], 5, profileId: 1, today: today);
      expect(fmt(r.deductions), '1:4.0');
      expect(r.shortfall, 1);
    });
  });

  test('daysRemaining', () {
    final t = Treatment(
        id: 1, profileId: 1, productId: 1, dose: 1, scheduleType: ScheduleType.interval, intervalHours: 8, startsAt: today);
    expect(daysRemaining(10, t), closeTo(3.33, 0.01));
    expect(daysRemaining(10, t.copyWith(dose: 0)), double.infinity);
  });

  test('expiringBoxes', () {
    final in30 = box(10, expires: today.add(const Duration(days: 30)));
    final in31 = box(11, expires: today.add(const Duration(days: 31)));
    final arch = box(12, expires: today.add(const Duration(days: 5)), archived: true);
    expect(expiringBoxes([in30, in31, arch, c], today, 30).map((b) => b.id), [3, 10]);
  });

  test('isExpired', () {
    expect(isExpired(c, today), isTrue);
    expect(isExpired(box(1, expires: today), today), isFalse);
  });
}
