import 'package:sqflite/sqflite.dart';

import '../domain/dose_rules.dart';
import '../domain/models.dart';

/// Toma con su contexto para mostrarla o notificarla.
class DoseDetail {
  final Dose dose;
  final Treatment treatment;
  final Product product;
  final Profile profile;
  const DoseDetail(this.dose, this.treatment, this.product, this.profile);
}

const _detailSelect = '''
SELECT d.id AS d_id, d.treatment_id AS d_treatment_id, d.scheduled_at AS d_scheduled_at,
       d.confirmed_at AS d_confirmed_at, d.status AS d_status, d.method AS d_method, d.box_id AS d_box_id,
       t.id AS t_id, t.profile_id AS t_profile_id, t.product_id AS t_product_id, t.dose AS t_dose,
       t.schedule_type AS t_schedule_type, t.interval_hours AS t_interval_hours, t.fixed_times AS t_fixed_times,
       t.starts_at AS t_starts_at, t.ends_at AS t_ends_at, t.tolerance_min AS t_tolerance_min,
       t.miss_after_min AS t_miss_after_min, t.notes AS t_notes, t.active AS t_active,
       p.id AS p_id, p.gtin AS p_gtin, p.name AS p_name, p.active_ingredient AS p_active_ingredient,
       p.strength AS p_strength, p.form AS p_form, p.unit AS p_unit, p.units_per_box AS p_units_per_box,
       f.id AS f_id, f.name AS f_name, f.color AS f_color, f.created_at AS f_created_at
FROM doses d
JOIN treatments t ON t.id = d.treatment_id
JOIN products p ON p.id = t.product_id
JOIN profiles f ON f.id = t.profile_id
''';

Map<String, Object?> _strip(Map<String, Object?> row, String prefix) => {
  for (final e in row.entries)
    if (e.key.startsWith(prefix)) e.key.substring(prefix.length): e.value,
};

DoseDetail _detail(Map<String, Object?> r) => DoseDetail(
  Dose.fromMap(_strip(r, 'd_')),
  Treatment.fromMap(_strip(r, 't_')),
  Product.fromMap(_strip(r, 'p_')),
  Profile.fromMap(_strip(r, 'f_')),
);

class DoseRepository {
  final DatabaseExecutor db;
  DoseRepository(this.db);

  /// Inserta ignorando duplicados (treatment_id, scheduled_at). Devuelve solo las nuevas, con id.
  Future<List<Dose>> insertIgnoreDuplicates(List<Dose> doses) async {
    final out = <Dose>[];
    for (final d in doses) {
      final id = await db.insert('doses', d.toMap()..remove('id'), conflictAlgorithm: ConflictAlgorithm.ignore);
      if (id > 0) out.add(d.copyWith(id: id));
    }
    return out;
  }

  Future<Dose?> get(int id) async {
    final r = await db.query('doses', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Dose.fromMap(r.first);
  }

  Future<DoseDetail?> detail(int id) async {
    final r = await db.rawQuery('$_detailSelect WHERE d.id = ?', [id]);
    return r.isEmpty ? null : _detail(r.first);
  }

  Future<List<Dose>> pendingBetween(DateTime from, DateTime to) async => (await db.query(
    'doses',
    where: "status = 'pending' AND scheduled_at >= ? AND scheduled_at < ?",
    whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    orderBy: 'scheduled_at',
  )).map(Dose.fromMap).toList();

  Future<List<DoseDetail>> detailsBetween(DateTime from, DateTime to) async => (await db.rawQuery(
    '$_detailSelect WHERE d.scheduled_at >= ? AND d.scheduled_at < ? ORDER BY d.scheduled_at, f.id',
    [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
  )).map(_detail).toList();

  Future<List<Dose>> forTreatment(int treatmentId, {DateTime? until}) async => (await db.query(
    'doses',
    where: 'treatment_id = ?${until == null ? '' : ' AND scheduled_at <= ?'}',
    whereArgs: [treatmentId, if (until != null) until.millisecondsSinceEpoch],
    orderBy: 'scheduled_at DESC',
  )).map(Dose.fromMap).toList();

  Future<DateTime?> lastScheduled(int treatmentId) async {
    final r = await db.rawQuery('SELECT MAX(scheduled_at) AS m FROM doses WHERE treatment_id = ?', [treatmentId]);
    final v = r.first['m'] as int?;
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  /// Confirma solo si sigue pendiente. Devuelve false si otra vía ya la confirmó.
  Future<bool> markConfirmed(
    int id, {
    required DoseStatus status,
    required DateTime confirmedAt,
    required ConfirmMethod method,
    int? boxId,
  }) async {
    final n = await db.update(
      'doses',
      {'status': status.db, 'confirmed_at': confirmedAt.millisecondsSinceEpoch, 'method': method.name, 'box_id': boxId},
      where: "id = ? AND status = 'pending'",
      whereArgs: [id],
    );
    return n == 1;
  }

  /// R2: pendientes cuya ventana venció pasan a `missed` (perezoso). Devuelve cuántas.
  Future<int> markMissed(DateTime now) => db.rawUpdate(
    '''
      UPDATE doses SET status = 'missed'
      WHERE status = 'pending' AND id IN (
        SELECT d.id FROM doses d JOIN treatments t ON t.id = d.treatment_id
        WHERE d.status = 'pending' AND d.scheduled_at + t.miss_after_min * 60000 < ?
      )''',
    [now.millisecondsSinceEpoch],
  );

  /// Tomas pendientes confirmables ahora (−30 min … +missAfter) cuyo producto es [productId].
  Future<List<DoseDetail>> confirmableWithProduct(int productId, DateTime now) async {
    final ms = now.millisecondsSinceEpoch;
    return (await db.rawQuery(
      "$_detailSelect WHERE d.status = 'pending' AND t.product_id = ? "
      'AND d.scheduled_at - ? <= ? AND d.scheduled_at + t.miss_after_min * 60000 >= ? '
      'ORDER BY d.scheduled_at, f.name',
      [productId, earlyConfirmMin * 60000, ms, ms],
    )).map(_detail).toList();
  }

  /// Borra pendientes futuras de un tratamiento (al desactivarlo). Devuelve sus ids.
  Future<List<int>> deletePendingFrom(int treatmentId, DateTime from) async {
    final rows = await db.query(
      'doses',
      columns: ['id'],
      where: "treatment_id = ? AND status = 'pending' AND scheduled_at >= ?",
      whereArgs: [treatmentId, from.millisecondsSinceEpoch],
    );
    final ids = rows.map((r) => r['id'] as int).toList();
    if (ids.isNotEmpty) {
      await db.delete('doses', where: 'id IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids);
    }
    return ids;
  }
}
