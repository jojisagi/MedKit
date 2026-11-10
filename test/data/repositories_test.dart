import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_botiquin/data/box_repository.dart';
import 'package:mi_botiquin/data/db.dart';
import 'package:mi_botiquin/data/dose_repository.dart';
import 'package:mi_botiquin/data/product_repository.dart';
import 'package:mi_botiquin/data/profile_repository.dart';
import 'package:mi_botiquin/data/settings_repository.dart';
import 'package:mi_botiquin/data/treatment_repository.dart';
import 'package:mi_botiquin/domain/inventory_rules.dart';
import 'package:mi_botiquin/domain/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Database db;

  setUp(() async => db = await openAppDatabase(path: '${Directory.systemTemp.createTempSync('mb').path}/t.db'));
  tearDown(() => db.close());

  Future<(int, int)> seed() async {
    final pid = await ProfileRepository(db).insert(Profile(name: 'Ana', color: 1, createdAt: DateTime(2026)));
    final prod = await ProductRepository(db).upsert(const Product(gtin: '04006381333931', name: 'Ibuprofeno'));
    return (pid, prod);
  }

  test('crea y lee perfil, producto y caja', () async {
    final (pid, prod) = await seed();
    expect((await ProfileRepository(db).get(pid))!.name, 'Ana');
    final bid = await BoxRepository(db).insert(Box(
        productId: prod,
        profileId: pid,
        unitsInitial: 10,
        unitsLeft: 10,
        expiresOn: DateTime(2027, 1, 1),
        addedAt: DateTime(2026)));
    final b = (await BoxRepository(db).get(bid))!;
    expect([b.unitsLeft, b.profileId, b.expiresOn], [10.0, pid, DateTime(2027, 1, 1)]);
  });

  test('findByGtin y GTIN duplicado', () async {
    await seed();
    expect((await ProductRepository(db).findByGtin('04006381333931'))!.name, 'Ibuprofeno');
    expect(await ProductRepository(db).findByGtin('00000000000000'), isNull);
    expect(() => ProductRepository(db).upsert(const Product(gtin: '04006381333931', name: 'Otro')),
        throwsA(isA<DatabaseException>()));
  });

  test('insertIgnoreDuplicates deja una sola fila', () async {
    final (pid, prod) = await seed();
    final tid = await TreatmentRepository(db).insert(Treatment(
        profileId: pid, productId: prod, dose: 1, scheduleType: ScheduleType.interval, intervalHours: 8, startsAt: DateTime(2026)));
    final d = Dose(treatmentId: tid, scheduledAt: DateTime(2026, 11, 10, 8));
    expect((await DoseRepository(db).insertIgnoreDuplicates([d])).length, 1);
    expect((await DoseRepository(db).insertIgnoreDuplicates([d])), isEmpty);
    expect((await DoseRepository(db).forTreatment(tid)).length, 1);
  });

  test('applyDeductions archiva al llegar a 0', () async {
    final (_, prod) = await seed();
    final repo = BoxRepository(db);
    final id = await repo.insert(
        Box(productId: prod, unitsInitial: 2, unitsLeft: 2, expiresOn: DateTime(2027), addedAt: DateTime(2026)));
    await repo.applyDeductions([Deduction(id, 2)]);
    final b = (await repo.get(id))!;
    expect([b.unitsLeft, b.archived], [0.0, true]);
  });

  test('llaves foráneas activas', () async {
    expect(
        () => BoxRepository(db).insert(
            Box(productId: 999, unitsInitial: 1, unitsLeft: 1, expiresOn: DateTime(2027), addedAt: DateTime(2026))),
        throwsA(isA<DatabaseException>()));
  });

  test('ajustes por defecto', () async {
    final s = await SettingsRepository(db).load();
    expect([s.expiryAlertDays, s.lowStockDays, s.demoMode], [30, 5, false]);
  });
}
