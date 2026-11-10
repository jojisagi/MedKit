import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

class ProductRepository {
  final DatabaseExecutor db;
  ProductRepository(this.db);

  Future<List<Product>> all() async =>
      (await db.query('products', orderBy: 'name COLLATE NOCASE')).map(Product.fromMap).toList();

  Future<Product?> get(int id) async {
    final r = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Product.fromMap(r.first);
  }

  /// [gtin14] ya normalizado (ver `normalizeGtin`).
  Future<Product?> findByGtin(String gtin14) async {
    final r = await db.query('products', where: 'gtin = ?', whereArgs: [gtin14]);
    return r.isEmpty ? null : Product.fromMap(r.first);
  }

  /// Inserta (id null) o actualiza. Un GTIN repetido lanza `DatabaseException`.
  Future<int> upsert(Product p) async {
    if (p.id == null) return db.insert('products', p.toMap()..remove('id'), conflictAlgorithm: ConflictAlgorithm.abort);
    await db.update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
    return p.id!;
  }

  Future<void> delete(int id) => db.delete('products', where: 'id = ?', whereArgs: [id]);
}
