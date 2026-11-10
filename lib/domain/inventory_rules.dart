/// Reglas R4 (descuento FEFO), R5 (días restantes) y R6 (alertas).
library;

import 'dose_rules.dart';
import 'models.dart';

class Deduction {
  final int boxId;
  final double units;
  const Deduction(this.boxId, this.units);

  @override
  String toString() => 'Deduction($boxId, $units)';
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Una caja caduca al terminar su día de caducidad.
bool isExpired(Box b, DateTime today) => dateOnly(b.expiresOn).isBefore(dateOnly(today));

bool _usable(Box b, int profileId, DateTime today) =>
    !b.archived && b.unitsLeft > 0 && !isExpired(b, today) && (b.profileId == null || b.profileId == profileId);

/// Cajas utilizables para un perfil, en orden de consumo: propias, luego compartidas; FEFO.
List<Box> usableBoxes(List<Box> boxes, {required int profileId, required DateTime today}) {
  final list = boxes.where((b) => _usable(b, profileId, today)).toList()
    ..sort((a, b) {
      final ao = a.profileId == profileId ? 0 : 1;
      final bo = b.profileId == profileId ? 0 : 1;
      if (ao != bo) return ao - bo;
      final c = a.expiresOn.compareTo(b.expiresOn);
      return c != 0 ? c : (a.id ?? 0) - (b.id ?? 0);
    });
  return list;
}

({List<Deduction> deductions, double shortfall}) planDeduction(
  List<Box> boxes,
  double amount, {
  required int profileId,
  required DateTime today,
}) {
  var remaining = amount;
  final out = <Deduction>[];
  for (final b in usableBoxes(boxes, profileId: profileId, today: today)) {
    if (remaining <= 1e-9) break;
    final take = remaining < b.unitsLeft ? remaining : b.unitsLeft;
    out.add(Deduction(b.id!, take));
    remaining -= take;
  }
  return (deductions: out, shortfall: remaining <= 1e-9 ? 0.0 : remaining);
}

double unitsAvailable(List<Box> boxes, {required int profileId, required DateTime today}) =>
    usableBoxes(boxes, profileId: profileId, today: today).fold(0.0, (s, b) => s + b.unitsLeft);

double daysRemaining(double unitsAvailable, Treatment t) {
  final perDay = t.dose * takesPerDay(t);
  if (perDay <= 0) return double.infinity;
  return unitsAvailable / perDay;
}

/// Cajas activas que caducan en ≤ alertDays (incluye ya caducadas), ordenadas por fecha.
List<Box> expiringBoxes(List<Box> boxes, DateTime today, int alertDays) {
  final limit = dateOnly(today).add(Duration(days: alertDays));
  return boxes.where((b) => !b.archived && b.unitsLeft > 0 && !dateOnly(b.expiresOn).isAfter(limit)).toList()
    ..sort((a, b) => a.expiresOn.compareTo(b.expiresOn));
}
