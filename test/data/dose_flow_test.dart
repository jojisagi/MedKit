import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_botiquin/data/box_repository.dart';
import 'package:mi_botiquin/data/db.dart';
import 'package:mi_botiquin/data/dose_repository.dart';
import 'package:mi_botiquin/data/product_repository.dart';
import 'package:mi_botiquin/data/profile_repository.dart';
import 'package:mi_botiquin/data/treatment_repository.dart';
import 'package:mi_botiquin/domain/models.dart';
import 'package:mi_botiquin/services/dose_confirmation_service.dart';
import 'package:mi_botiquin/services/scheduler_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Database db;
  late int tid, boxId, prodId;
  final start = DateTime(2026, 11, 10, 8);
  final cancelled = <int>[];

  setUp(() async {
    cancelled.clear();
    db = await openAppDatabase(path: '${Directory.systemTemp.createTempSync('mb').path}/t.db');
    final pid = await ProfileRepository(db).insert(Profile(name: 'Ana', color: 1, createdAt: DateTime(2026)));
    prodId = await ProductRepository(db).upsert(const Product(gtin: '04006381333931', name: 'Ibuprofeno'));
    boxId = await BoxRepository(db).insert(Box(
        productId: prodId, profileId: pid, unitsInitial: 10, unitsLeft: 10, expiresOn: DateTime(2027), addedAt: start));
    tid = await TreatmentRepository(db).insert(Treatment(
        profileId: pid, productId: prodId, dose: 1, scheduleType: ScheduleType.interval, intervalHours: 8, startsAt: start));
  });
  tearDown(() => db.close());

  DoseConfirmationService svc() => DoseConfirmationService(db, onConfirmed: (id) async => cancelled.add(id));

  Future<Dose> firstDose() async {
    await SchedulerService(db).refresh(now: start);
    return (await DoseRepository(db).forTreatment(tid)).last;
  }

  test('confirmar a +5 min → a tiempo y descuenta 1', () async {
    final d = await firstDose();
    expect(d.scheduledAt, start);
    final r = await svc().confirm(d.id!, ConfirmMethod.app, now: start.add(const Duration(minutes: 5)));
    expect(r.status, DoseStatus.onTime);
    expect((await BoxRepository(db).get(boxId))!.unitsLeft, 9);
    expect((await DoseRepository(db).get(d.id!))!.boxId, boxId);
    expect(cancelled, [d.id]);
  });

  test('confirmar dos veces solo descuenta una', () async {
    final d = await firstDose();
    final now = start.add(const Duration(minutes: 1));
    final results = await Future.wait([
      svc().confirm(d.id!, ConfirmMethod.notification, now: now),
      svc().confirm(d.id!, ConfirmMethod.scan, now: now),
    ]);
    expect(results.where((r) => r.alreadyConfirmed).length, 1);
    expect((await BoxRepository(db).get(boxId))!.unitsLeft, 9);
  });

  test('sin inventario confirma con faltante', () async {
    await BoxRepository(db).applyDeductions([]);
    await db.update('boxes', {'units_left': 0, 'archived': 1});
    final d = await firstDose();
    final r = await svc().confirm(d.id!, ConfirmMethod.app, now: start);
    expect(r.shortfall, 1);
    expect((await DoseRepository(db).get(d.id!))!.status, DoseStatus.onTime);
  });

  test('fuera de ventana no confirma', () async {
    final d = await firstDose();
    final r = await svc().confirm(d.id!, ConfirmMethod.app, now: start.add(const Duration(minutes: 61)));
    expect(r.outOfWindow, isTrue);
    expect((await BoxRepository(db).get(boxId))!.unitsLeft, 10);
  });

  test('refresh tras 5 h: omitida sin descontar y 72 h sin duplicar', () async {
    final s = SchedulerService(db);
    await s.refresh(now: start);
    final n1 = (await DoseRepository(db).forTreatment(tid)).length;
    expect(n1, 9); // 72 h / 8 h, la de las 8:00 incluida
    await s.refresh(now: start.add(const Duration(hours: 5)));
    final all = await DoseRepository(db).forTreatment(tid);
    final first = all.firstWhere((d) => d.scheduledAt == start);
    expect(first.status, DoseStatus.missed);
    expect((await BoxRepository(db).get(boxId))!.unitsLeft, 10);
    expect(all.length, n1 + 1); // ventana hasta +77 h: entra la de +72 h
    await s.refresh(now: start.add(const Duration(hours: 9)));
    expect((await DoseRepository(db).forTreatment(tid)).length, n1 + 2);
    await s.refresh(now: start.add(const Duration(hours: 9)));
    expect((await DoseRepository(db).forTreatment(tid)).length, n1 + 2);
  });

  test('confirmableWithProduct respeta ventana', () async {
    await SchedulerService(db).refresh(now: start);
    final repo = DoseRepository(db);
    expect((await repo.confirmableWithProduct(prodId, start.subtract(const Duration(minutes: 31)))), isEmpty);
    final c = await repo.confirmableWithProduct(prodId, start.subtract(const Duration(minutes: 29)));
    expect(c.single.profile.name, 'Ana');
    expect(c.single.product.name, 'Ibuprofeno');
  });

  test('terminar tratamiento borra pendientes futuras', () async {
    final s = SchedulerService(db);
    await s.refresh(now: start);
    final ids = await s.finishTreatment(tid, now: start.add(const Duration(hours: 1)));
    expect(ids.length, 8);
    expect((await s.refresh(now: start.add(const Duration(hours: 2)))), isEmpty);
  });
}
