import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_botiquin/data/db.dart';
import 'package:mi_botiquin/data/demo_seed.dart';
import 'package:mi_botiquin/data/dose_repository.dart';
import 'package:mi_botiquin/data/settings_repository.dart';
import 'package:mi_botiquin/domain/barcode.dart';
import 'package:mi_botiquin/services/scheduler_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('códigos demo válidos', () {
    for (final g in demoGtins) {
      expect(normalizeGtin(g), isNotNull);
    }
  });

  test('seed + refresh + clear', () async {
    final db = await openAppDatabase(path: '${Directory.systemTemp.createTempSync('mb').path}/t.db');
    final now = DateTime(2026, 11, 10, 10, 0, 30);
    await seedDemo(db, now: now);
    expect((await SettingsRepository(db).load()).demoMode, isTrue);
    await SchedulerService(db).refresh(now: now);
    final soon = await DoseRepository(db).detailsBetween(now, now.add(const Duration(minutes: 5)));
    expect(soon.single.dose.scheduledAt, DateTime(2026, 11, 10, 10, 2));
    expect(soon.single.profile.name, 'Rosa');
    expect((await demoPendingDoseIds(db)), isNotEmpty);
    await clearDemo(db);
    expect((await db.query('profiles')), isEmpty);
    expect((await db.query('doses')), isEmpty);
    expect((await db.query('boxes')), isEmpty);
    await db.close();
  });
}
