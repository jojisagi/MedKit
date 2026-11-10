import 'package:sqflite/sqflite.dart';

import '../domain/inventory_rules.dart';
import '../domain/models.dart';

class BoxRepository {
  final DatabaseExecutor db;
  BoxRepository(this.db);

  Future<List<Box>> activeForProduct(int productId) async => (await db.query(
    'boxes',
    where: 'product_id = ? AND archived = 0',
    whereArgs: [productId],
    orderBy: 'expires_on, id',
  )).map(Box.fromMap).toList();

  Future<List<Box>> allActive() async =>
      (await db.query('boxes', where: 'archived = 0', orderBy: 'expires_on, id')).map(Box.fromMap).toList();

  Future<Box?> get(int id) async {
    final r = await db.query('boxes', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Box.fromMap(r.first);
  }

  Future<int> insert(Box b) => db.insert('boxes', b.toMap()..remove('id'));

  Future<void> update(Box b) => db.update('boxes', b.toMap(), where: 'id = ?', whereArgs: [b.id]);

  Future<void> archive(int id) => db.update('boxes', {'archived': 1}, where: 'id = ?', whereArgs: [id]);

  Future<void> delete(int id) => db.delete('boxes', where: 'id = ?', whereArgs: [id]);

  /// Resta unidades; una caja que llega a 0 se archiva (R4).
  Future<void> applyDeductions(List<Deduction> deductions) async {
    for (final d in deductions) {
      await db.rawUpdate(
        '''UPDATE boxes SET units_left = MAX(0, units_left - ?),
           archived = CASE WHEN units_left - ? <= 0.000001 THEN 1 ELSE archived END
           WHERE id = ?''',
        [d.units, d.units, d.boxId],
      );
    }
  }
}
