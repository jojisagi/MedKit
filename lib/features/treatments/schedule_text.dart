import '../../domain/dose_rules.dart';
import '../../domain/models.dart';

/// "Cada 8 h" o "08:00 y 20:00".
String scheduleText(Treatment t) {
  if (t.scheduleType == ScheduleType.interval) return 'cada ${t.intervalHours} h';
  final times = formatFixedTimes(parseFixedTimes(t.fixedTimes)).split(',');
  if (times.length <= 1) return 'a las ${times.join()}';
  return 'a las ${times.sublist(0, times.length - 1).join(', ')} y ${times.last}';
}
