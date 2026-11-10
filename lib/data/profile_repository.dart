import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

class ProfileRepository {
  final DatabaseExecutor db;
  ProfileRepository(this.db);

  Future<List<Profile>> all() async =>
      (await db.query('profiles', orderBy: 'created_at, id')).map(Profile.fromMap).toList();

  Future<Profile?> get(int id) async {
    final r = await db.query('profiles', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Profile.fromMap(r.first);
  }

  Future<int> insert(Profile p) => db.insert('profiles', p.toMap()..remove('id'));

  Future<void> update(Profile p) => db.update('profiles', p.toMap(), where: 'id = ?', whereArgs: [p.id]);

  Future<void> delete(int id) => db.delete('profiles', where: 'id = ?', whereArgs: [id]);
}
