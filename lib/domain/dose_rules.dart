/// Reglas R1 (estado de toma), R3 (programación) y emparejamiento de escaneo (SPEC §5).
library;

import 'models.dart';

/// Minutos antes de la hora programada en los que ya se permite confirmar.
const earlyConfirmMin = 30;

/// Ventana móvil de materialización de tomas (R3).
const scheduleWindow = Duration(hours: 72);

DoseStatus classifyDose({
  required DateTime scheduledAt,
  DateTime? confirmedAt,
  required DateTime now,
  int toleranceMin = 10,
  int missAfterMin = 60,
}) {
  if (confirmedAt != null) {
    if (!confirmedAt.isAfter(scheduledAt.add(Duration(minutes: toleranceMin)))) return DoseStatus.onTime;
    return DoseStatus.late;
  }
  if (now.isAfter(scheduledAt.add(Duration(minutes: missAfterMin)))) return DoseStatus.missed;
  return DoseStatus.pending;
}

/// Ventana de confirmación: −30 min … +missAfter.
bool canConfirm(DateTime scheduledAt, DateTime now, int missAfterMin) =>
    !now.isBefore(scheduledAt.subtract(const Duration(minutes: earlyConfirmMin))) &&
    !now.isAfter(scheduledAt.add(Duration(minutes: missAfterMin)));

/// "08:00, 20:00" → [(8,0), (20,0)] ordenado, sin duplicados ni basura.
List<(int, int)> parseFixedTimes(String? raw) {
  if (raw == null) return const [];
  final out = <(int, int)>{};
  for (final part in raw.split(',')) {
    final p = part.trim();
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(p);
    if (m == null) continue;
    final h = int.parse(m.group(1)!);
    final mi = int.parse(m.group(2)!);
    if (h > 23 || mi > 59) continue;
    out.add((h, mi));
  }
  final list = out.toList()..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  return list;
}

String formatFixedTimes(List<(int, int)> times) =>
    times.map((t) => '${t.$1.toString().padLeft(2, '0')}:${t.$2.toString().padLeft(2, '0')}').join(',');

/// Horarios del tratamiento en [from, to). Nunca antes de startsAt ni después de endsAt.
List<DateTime> scheduleBetween(Treatment t, DateTime from, DateTime to) {
  final out = <DateTime>[];
  final lower = from.isAfter(t.startsAt) ? from : t.startsAt;
  bool inRange(DateTime d) => !d.isBefore(lower) && d.isBefore(to) && (t.endsAt == null || !d.isAfter(t.endsAt!));

  switch (t.scheduleType) {
    case ScheduleType.interval:
      final n = t.intervalHours ?? 0;
      if (n <= 0) return out;
      final step = Duration(hours: n);
      var k = 0;
      if (lower.isAfter(t.startsAt)) {
        final elapsed = lower.difference(t.startsAt).inMicroseconds;
        k = (elapsed / step.inMicroseconds).ceil();
      }
      // Siempre desde startsAt + k·N h: no se ancla a medianoche.
      for (var d = t.startsAt.add(step * k); d.isBefore(to); k++, d = t.startsAt.add(step * k)) {
        if (t.endsAt != null && d.isAfter(t.endsAt!)) break;
        if (inRange(d)) out.add(d);
      }
    case ScheduleType.fixed:
      final times = parseFixedTimes(t.fixedTimes);
      if (times.isEmpty) return out;
      var day = DateTime(lower.year, lower.month, lower.day);
      while (day.isBefore(to)) {
        for (final (h, mi) in times) {
          final d = DateTime(day.year, day.month, day.day, h, mi);
          if (inRange(d)) out.add(d);
        }
        day = DateTime(day.year, day.month, day.day + 1);
      }
  }
  return out;
}

double takesPerDay(Treatment t) => switch (t.scheduleType) {
  ScheduleType.interval => (t.intervalHours ?? 0) > 0 ? 24 / t.intervalHours! : 0,
  ScheduleType.fixed => parseFixedTimes(t.fixedTimes).length.toDouble(),
};

enum ScanMatchKind { confirmOne, choose, noPending, unknownProduct, wrongProduct }

/// Decide qué hacer tras escanear una caja (SPEC §5). Pura.
/// [scanned]: producto encontrado por GTIN (null = desconocido).
/// [expectedProductId]: si se confirma una toma concreta.
/// [confirmable]: tomas confirmables ahora del producto escaneado.
ScanMatchKind matchScan({Product? scanned, int? expectedProductId, required List<Dose> confirmable}) {
  if (expectedProductId != null) {
    if (scanned == null || scanned.id != expectedProductId) return ScanMatchKind.wrongProduct;
    return ScanMatchKind.confirmOne;
  }
  if (scanned == null) return ScanMatchKind.unknownProduct;
  if (confirmable.isEmpty) return ScanMatchKind.noPending;
  if (confirmable.length == 1) return ScanMatchKind.confirmOne;
  return ScanMatchKind.choose;
}

/// IDs de notificación sin choques: principal = 2·id, reintento = 2·id + 1.
int notificationId(int doseId, {bool retry = false}) => doseId * 2 + (retry ? 1 : 0);

/// Cumplimiento = (onTime + late) / (onTime + late + missed); null si no hay tomas cerradas.
double? compliance(Iterable<Dose> doses) {
  var taken = 0, closed = 0;
  for (final d in doses) {
    if (d.status == DoseStatus.pending) continue;
    closed++;
    if (d.isConfirmed) taken++;
  }
  return closed == 0 ? null : taken / closed;
}
