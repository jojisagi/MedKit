import 'package:flutter_test/flutter_test.dart';
import 'package:mi_botiquin/domain/dose_rules.dart';
import 'package:mi_botiquin/domain/models.dart';

Duration m(int v) => Duration(minutes: v);

Treatment tr({
  ScheduleType type = ScheduleType.interval,
  int? hours,
  String? times,
  required DateTime startsAt,
  DateTime? endsAt,
  double dose = 1,
}) =>
    Treatment(
      id: 1,
      profileId: 1,
      productId: 1,
      dose: dose,
      scheduleType: type,
      intervalHours: hours,
      fixedTimes: times,
      startsAt: startsAt,
      endsAt: endsAt,
    );

void main() {
  final s = DateTime(2026, 11, 10, 8);
  final x = DateTime(2026, 11, 12);

  group('classifyDose', () {
    test('a tiempo dentro de tolerancia', () {
      expect(classifyDose(scheduledAt: s, confirmedAt: s.add(m(10)), now: x), DoseStatus.onTime);
    });
    test('tardía', () {
      expect(classifyDose(scheduledAt: s, confirmedAt: s.add(m(11)), now: x), DoseStatus.late);
      expect(classifyDose(scheduledAt: s, confirmedAt: s.add(m(60)), now: x), DoseStatus.late);
    });
    test('omitida', () => expect(classifyDose(scheduledAt: s, now: s.add(m(61))), DoseStatus.missed));
    test('pendiente', () => expect(classifyDose(scheduledAt: s, now: s.add(m(30))), DoseStatus.pending));
    test('anticipada', () {
      expect(classifyDose(scheduledAt: s, confirmedAt: s.subtract(m(20)), now: x), DoseStatus.onTime);
    });
    test('tolerancias personalizadas', () {
      expect(
          classifyDose(scheduledAt: s, confirmedAt: s.add(m(2)), now: x, toleranceMin: 1, missAfterMin: 3),
          DoseStatus.late);
      expect(classifyDose(scheduledAt: s, now: s.add(m(4)), toleranceMin: 1, missAfterMin: 3), DoseStatus.missed);
    });
  });

  test('canConfirm ventana -30 … +missAfter', () {
    expect(canConfirm(s, s.subtract(m(31)), 60), isFalse);
    expect(canConfirm(s, s.subtract(m(30)), 60), isTrue);
    expect(canConfirm(s, s.add(m(60)), 60), isTrue);
    expect(canConfirm(s, s.add(m(61)), 60), isFalse);
  });

  group('scheduleBetween', () {
    test('interval cruza medianoche sin reiniciarse', () {
      final t = tr(hours: 8, startsAt: DateTime(2026, 11, 1, 20));
      expect(scheduleBetween(t, DateTime(2026, 11, 1), DateTime(2026, 11, 3)), [
        DateTime(2026, 11, 1, 20),
        DateTime(2026, 11, 2, 4),
        DateTime(2026, 11, 2, 12),
        DateTime(2026, 11, 2, 20),
      ]);
    });
    test('interval con ventana que empieza después del inicio', () {
      final t = tr(hours: 8, startsAt: DateTime(2026, 11, 1, 20));
      expect(scheduleBetween(t, DateTime(2026, 11, 2, 5), DateTime(2026, 11, 2, 21)), [
        DateTime(2026, 11, 2, 12),
        DateTime(2026, 11, 2, 20),
      ]);
    });
    test('fixed respeta endsAt', () {
      final t = tr(
          type: ScheduleType.fixed,
          times: '08:00,20:00',
          startsAt: DateTime(2026, 11, 1),
          endsAt: DateTime(2026, 11, 2, 10));
      expect(scheduleBetween(t, DateTime(2026, 11, 1), DateTime(2026, 11, 3)), [
        DateTime(2026, 11, 1, 8),
        DateTime(2026, 11, 1, 20),
        DateTime(2026, 11, 2, 8),
      ]);
    });
    test('fixed no programa antes de startsAt', () {
      final t = tr(type: ScheduleType.fixed, times: '08:00,20:00', startsAt: DateTime(2026, 11, 1, 9));
      expect(scheduleBetween(t, DateTime(2026, 11, 1), DateTime(2026, 11, 2)), [DateTime(2026, 11, 1, 20)]);
    });
  });

  test('takesPerDay', () {
    expect(takesPerDay(tr(hours: 8, startsAt: s)), 3);
    expect(takesPerDay(tr(type: ScheduleType.fixed, times: '08:00,14:00,20:00', startsAt: s)), 3);
  });

  test('parseFixedTimes ordena y limpia', () {
    expect(parseFixedTimes(' 20:00, 08:00 ,'), [(8, 0), (20, 0)]);
  });
}
