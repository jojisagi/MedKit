import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

class TreatmentRepository {
  final DatabaseExecutor db;
  TreatmentRepository(this.db);

  Future<List<Treatment>> active() async =>
      (await db.query('treatments', where: 'active = 1', orderBy: 'id')).map(Treatment.fromMap).toList();

  Future<List<Treatment>> forProfile(int profileId) async => (await db.query(
    'treatments',
    where: 'profile_id = ?',
    whereArgs: [profileId],
    orderBy: 'active DESC, starts_at DESC',
  )).map(Treatment.fromMap).toList();

  Future<Treatment?> get(int id) async {
    final r = await db.query('treatments', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Treatment.fromMap(r.first);
  }

  Future<int> insert(Treatment t) => db.insert('treatments', t.toMap()..remove('id'));

  Future<void> update(Treatment t) => db.update('treatments', t.toMap(), where: 'id = ?', whereArgs: [t.id]);

  Future<void> delete(int id) => db.delete('treatments', where: 'id = ?', whereArgs: [id]);
}
