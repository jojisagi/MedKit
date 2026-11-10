import 'package:flutter_test/flutter_test.dart';
import 'package:mi_botiquin/domain/dose_rules.dart';
import 'package:mi_botiquin/domain/models.dart';

void main() {
  const ibu = Product(id: 1, name: 'Ibuprofeno');
  const para = Product(id: 2, name: 'Paracetamol');
  final d1 = Dose(id: 1, treatmentId: 1, scheduledAt: DateTime(2026, 11, 10, 8));
  final d2 = Dose(id: 2, treatmentId: 2, scheduledAt: DateTime(2026, 11, 10, 8));

  test('matchScan', () {
    expect(matchScan(scanned: null, confirmable: []), ScanMatchKind.unknownProduct);
    expect(matchScan(scanned: ibu, confirmable: []), ScanMatchKind.noPending);
    expect(matchScan(scanned: ibu, confirmable: [d1]), ScanMatchKind.confirmOne);
    expect(matchScan(scanned: ibu, confirmable: [d1, d2]), ScanMatchKind.choose);
    expect(matchScan(scanned: para, expectedProductId: ibu.id, confirmable: [d1]), ScanMatchKind.wrongProduct);
    expect(matchScan(scanned: null, expectedProductId: ibu.id, confirmable: []), ScanMatchKind.wrongProduct);
    expect(matchScan(scanned: ibu, expectedProductId: ibu.id, confirmable: [d1]), ScanMatchKind.confirmOne);
  });

  test('notificationId sin choques', () {
    expect([notificationId(0), notificationId(0, retry: true)], [0, 1]);
    expect([notificationId(7), notificationId(7, retry: true)], [14, 15]);
    final ids = <int>{};
    for (var i = 1; i <= 1000; i++) {
      ids..add(notificationId(i))..add(notificationId(i, retry: true));
    }
    expect(ids.length, 2000);
  });

  group('compliance', () {
    Dose d(DoseStatus s) => Dose(treatmentId: 1, scheduledAt: DateTime(2026), status: s);
    test('2/3', () {
      expect(compliance([d(DoseStatus.onTime), d(DoseStatus.late), d(DoseStatus.missed), d(DoseStatus.pending)]),
          closeTo(2 / 3, 1e-9));
    });
    test('sin cerradas', () {
      expect(compliance([d(DoseStatus.pending)]), isNull);
      expect(compliance([]), isNull);
    });
  });
}
