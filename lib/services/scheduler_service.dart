import 'package:sqflite/sqflite.dart';

import '../data/dose_repository.dart';
import '../data/treatment_repository.dart';
import '../domain/dose_rules.dart';
import '../domain/models.dart';

/// R3: marca omitidas y materializa las tomas de las próximas 72 h.
class SchedulerService {
  final Database db;
  SchedulerService(this.db);

  /// Máximo hacia atrás que se rellenan tomas si la app estuvo cerrada mucho tiempo.
  static const backfillLimit = Duration(days: 7);

  /// Devuelve las tomas nuevas (con id) para programar sus notificaciones.
  Future<List<Dose>> refresh({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final created = await db.transaction((txn) async {
      final doses = DoseRepository(txn);
      final out = <Dose>[];
      for (final t in await TreatmentRepository(txn).active()) {
        final last = await doses.lastScheduled(t.id!);
        // Sin tomas aún: desde lo que todavía se puede confirmar. Con tomas: continúa tras la última.
        var from = last == null
            ? at.subtract(Duration(minutes: t.missAfterMin))
            : last.add(const Duration(milliseconds: 1));
        final floor = at.subtract(backfillLimit);
        if (from.isBefore(floor)) from = floor;
        final times = scheduleBetween(t, from, at.add(scheduleWindow));
        out.addAll(
          await doses.insertIgnoreDuplicates([for (final s in times) Dose(treatmentId: t.id!, scheduledAt: s)]),
        );
      }
      await doses.markMissed(at);
      return out;
    });
    // Las rellenadas en el pasado ya quedaron omitidas; NotificationService ignora horas pasadas.
    return created;
  }

  /// Termina un tratamiento: lo desactiva y borra sus tomas pendientes futuras.
  /// Devuelve los ids borrados para cancelar sus notificaciones.
  Future<List<int>> finishTreatment(int treatmentId, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    return db.transaction((txn) async {
      final repo = TreatmentRepository(txn);
      final t = await repo.get(treatmentId);
      if (t == null) return const <int>[];
      await repo.update(t.copyWith(active: false, endsAt: at));
      return DoseRepository(txn).deletePendingFrom(treatmentId, at);
    });
  }
}
