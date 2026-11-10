import 'package:sqflite/sqflite.dart';

import '../domain/barcode.dart';
import '../domain/models.dart';
import 'settings_repository.dart';

/// Códigos de demostración con prefijo 200 (reservado por GS1 para uso interno: nunca es un producto real).
final demoGtins = [
  gtinWithCheckDigit('200000000001'),
  gtinWithCheckDigit('200000000002'),
  gtinWithCheckDigit('200000000003'),
];

/// SPEC §7: 2 perfiles, 3 productos, cajas (una caduca en 10 días) y un tratamiento
/// con toma en +2 min, tolerancia 1 min y omisión a 3 min. Incluye historial de 5 días.
Future<void> seedDemo(Database db, {DateTime? now}) async {
  final at = now ?? DateTime.now();
  final today = DateTime(at.year, at.month, at.day);
  await db.transaction((txn) async {
    final rosa = await txn.insert('profiles',
        Profile(name: 'Rosa', color: 0xFF1F7A5A, createdAt: at).toMap()..remove('id'));
    final luis = await txn.insert('profiles',
        Profile(name: 'Don Luis', color: 0xFF2F5FD0, createdAt: at.add(const Duration(seconds: 1))).toMap()..remove('id'));

    Future<int> product(Product p) => txn.insert('products', p.toMap()..remove('id'));
    final ibu = await product(Product(
        gtin: normalizeGtin(demoGtins[0]), name: 'Ibuprofeno', activeIngredient: 'Ibuprofeno', strength: '400 mg',
        form: 'tableta', unitsPerBox: 20));
    final lora = await product(Product(
        gtin: normalizeGtin(demoGtins[1]), name: 'Loratadina', activeIngredient: 'Loratadina', strength: '10 mg',
        form: 'tableta', unitsPerBox: 10));
    final para = await product(Product(
        gtin: normalizeGtin(demoGtins[2]), name: 'Paracetamol', activeIngredient: 'Paracetamol', strength: '120 mg/5 ml',
        form: 'jarabe', unit: 'ml', unitsPerBox: 120));

    Future<void> box(int productId, int? profileId, double units, DateTime expires, double initial) => txn.insert(
        'boxes',
        Box(productId: productId, profileId: profileId, unitsInitial: initial, unitsLeft: units, expiresOn: expires,
                lot: 'DEMO', addedAt: at)
            .toMap()
          ..remove('id'));
    await box(ibu, rosa, 14, DateTime(today.year + 1, today.month, 1), 20);
    await box(lora, luis, 4, today.add(const Duration(days: 10)), 10); // caduca en 10 días
    await box(para, null, 120, DateTime(today.year + 1, 6, 30), 120);

    // Tratamiento de demostración: primera toma en +2 min.
    final start = DateTime(at.year, at.month, at.day, at.hour, at.minute).add(const Duration(minutes: 2));
    await txn.insert(
        'treatments',
        Treatment(
                profileId: rosa, productId: ibu, dose: 1, scheduleType: ScheduleType.interval, intervalHours: 8,
                startsAt: start, endsAt: today.add(const Duration(days: 5)), toleranceMin: 1, missAfterMin: 3,
                notes: 'Después de comer')
            .toMap()
          ..remove('id'));

    // Tratamiento con historial para ver cumplimiento.
    final histStart = today.subtract(const Duration(days: 5));
    final tLuis = await txn.insert(
        'treatments',
        Treatment(
                profileId: luis, productId: lora, dose: 1, scheduleType: ScheduleType.fixed, fixedTimes: '09:00,21:00',
                startsAt: histStart)
            .toMap()
          ..remove('id'));
    const pattern = [DoseStatus.onTime, DoseStatus.onTime, DoseStatus.late, DoseStatus.onTime, DoseStatus.missed];
    var i = 0;
    for (var d = histStart; d.isBefore(today); d = DateTime(d.year, d.month, d.day + 1)) {
      for (final h in const [9, 21]) {
        final s = DateTime(d.year, d.month, d.day, h);
        final st = pattern[i++ % pattern.length];
        await txn.insert(
            'doses',
            Dose(
              treatmentId: tLuis,
              scheduledAt: s,
              status: st,
              confirmedAt: st == DoseStatus.missed ? null : s.add(Duration(minutes: st == DoseStatus.late ? 25 : 4)),
              method: st == DoseStatus.missed ? null : (i.isEven ? ConfirmMethod.scan : ConfirmMethod.app),
            ).toMap()
              ..remove('id'));
      }
    }
    final s = SettingsRepository(txn);
    await s.set('demo_mode', '1');
    await s.set('demo_profiles', '$rosa,$luis');
    await s.set('demo_products', '$ibu,$lora,$para');
  });
}

List<int> _ids(String? csv) =>
    (csv ?? '').split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList();

/// Ids de tomas pendientes de demo (para cancelar sus notificaciones antes de borrar).
Future<List<int>> demoPendingDoseIds(Database db) async {
  final profiles = _ids(await SettingsRepository(db).get('demo_profiles'));
  if (profiles.isEmpty) return const [];
  final rows = await db.rawQuery(
      "SELECT d.id FROM doses d JOIN treatments t ON t.id = d.treatment_id "
      "WHERE d.status = 'pending' AND t.profile_id IN (${List.filled(profiles.length, '?').join(',')})",
      profiles);
  return rows.map((r) => r['id'] as int).toList();
}

Future<void> clearDemo(Database db) async {
  await db.transaction((txn) async {
    final s = SettingsRepository(txn);
    final profiles = _ids(await s.get('demo_profiles'));
    final products = _ids(await s.get('demo_products'));
    String marks(List<int> l) => List.filled(l.length, '?').join(',');
    if (profiles.isNotEmpty) await txn.delete('profiles', where: 'id IN (${marks(profiles)})', whereArgs: profiles);
    if (products.isNotEmpty) await txn.delete('products', where: 'id IN (${marks(products)})', whereArgs: products);
    await s.set('demo_mode', '0');
    await s.set('demo_profiles', '');
    await s.set('demo_products', '');
  });
}
