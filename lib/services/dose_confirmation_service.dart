import 'package:sqflite/sqflite.dart';

import '../data/box_repository.dart';
import '../data/dose_repository.dart';
import '../data/treatment_repository.dart';
import '../domain/dose_rules.dart';
import '../domain/inventory_rules.dart';
import '../domain/models.dart';

class ConfirmResult {
  final DoseStatus status;
  final double shortfall;
  final bool alreadyConfirmed;
  final bool outOfWindow;
  const ConfirmResult({
    required this.status,
    this.shortfall = 0,
    this.alreadyConfirmed = false,
    this.outOfWindow = false,
  });

  bool get ok => !alreadyConfirmed && !outOfWindow;
}

/// Única puerta para confirmar tomas (app, notificación o escaneo).
class DoseConfirmationService {
  final Database db;
  final Future<void> Function(int doseId)? onConfirmed;
  DoseConfirmationService(this.db, {this.onConfirmed});

  Future<ConfirmResult> confirm(int doseId, ConfirmMethod method, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final result = await db.transaction((txn) async {
      final doses = DoseRepository(txn);
      final dose = await doses.get(doseId);
      if (dose == null) throw StateError('La toma $doseId no existe');
      if (dose.status != DoseStatus.pending) {
        return ConfirmResult(status: dose.status, alreadyConfirmed: dose.isConfirmed, outOfWindow: !dose.isConfirmed);
      }
      final t = (await TreatmentRepository(txn).get(dose.treatmentId))!;
      if (!canConfirm(dose.scheduledAt, at, t.missAfterMin)) {
        final s = classifyDose(scheduledAt: dose.scheduledAt, now: at, missAfterMin: t.missAfterMin);
        return ConfirmResult(status: s, outOfWindow: true);
      }
      final status = classifyDose(
        scheduledAt: dose.scheduledAt,
        confirmedAt: at,
        now: at,
        toleranceMin: t.toleranceMin,
        missAfterMin: t.missAfterMin,
      );
      final boxes = BoxRepository(txn);
      final plan = planDeduction(await boxes.activeForProduct(t.productId), t.dose,
          profileId: t.profileId, today: at);
      final updated = await doses.markConfirmed(doseId,
          status: status,
          confirmedAt: at,
          method: method,
          boxId: plan.deductions.isEmpty ? null : plan.deductions.first.boxId);
      if (!updated) return ConfirmResult(status: status, alreadyConfirmed: true);
      await boxes.applyDeductions(plan.deductions);
      return ConfirmResult(status: status, shortfall: plan.shortfall);
    });
    if (result.ok) await onConfirmed?.call(doseId);
    return result;
  }
}
