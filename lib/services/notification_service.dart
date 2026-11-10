import 'dart:async';
import 'dart:ui' show Color, DartPluginRegistrant;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/db.dart';
import '../data/dose_repository.dart';
import '../domain/dose_rules.dart';
import '../domain/models.dart';
import '../ui/widgets.dart' show doseLabel, productTitle;
import 'dose_confirmation_service.dart';

const _channelDoses = AndroidNotificationChannel(
  'doses',
  'Recordatorios de tomas',
  description: 'Avisos a la hora de cada toma y un recordatorio si sigue pendiente.',
  importance: Importance.max,
);

const _channelAlerts = AndroidNotificationChannel(
  'alerts',
  'Alertas del botiquín',
  description: 'Resumen diario de caducidades e inventario bajo.',
  importance: Importance.defaultImportance,
);

const actionConfirm = 'confirm';
const _dailyAlertId = 2000000000;

String formatUnits(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Acción "Ya la tomé" con la app cerrada: corre en un isolate aparte.
@pragma('vm:entry-point')
void onBackgroundAction(NotificationResponse r) async {
  if (r.actionId != actionConfirm) return;
  final id = int.tryParse(r.payload ?? '');
  if (id == null) return;
  DartPluginRegistrant.ensureInitialized();
  final db = await openAppDatabase();
  final plugin = FlutterLocalNotificationsPlugin();
  await DoseConfirmationService(
    db,
    onConfirmed: (doseId) async {
      await plugin.cancel(id: notificationId(doseId));
      await plugin.cancel(id: notificationId(doseId, retry: true));
    },
  ).confirm(id, ConfirmMethod.notification);
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool exactAllowed = true;

  /// Toque en el cuerpo de una notificación de toma → doseId.
  final _taps = StreamController<int>.broadcast();
  Stream<int> get taps => _taps.stream;

  /// Confirmación desde la acción con la app abierta → doseId.
  final _confirms = StreamController<int>.broadcast();
  Stream<int> get confirms => _confirms.stream;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Devuelve el doseId si la app se abrió tocando una notificación.
  Future<int?> init() async {
    if (_ready) return null;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Mexico_City'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_stat_pill')),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundAction,
    );
    await _android?.createNotificationChannel(_channelDoses);
    await _android?.createNotificationChannel(_channelAlerts);
    _ready = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final r = launch!.notificationResponse;
      if (r != null && r.actionId == null) return int.tryParse(r.payload ?? '');
    }
    return null;
  }

  void _onResponse(NotificationResponse r) {
    final id = int.tryParse(r.payload ?? '');
    if (id == null) return;
    if (r.actionId == actionConfirm) {
      _confirms.add(id);
    } else {
      _taps.add(id);
    }
  }

  Future<bool> requestNotificationPermission() async => await _android?.requestNotificationsPermission() ?? true;

  Future<bool> checkExactAlarms() async {
    exactAllowed = await _android?.canScheduleExactNotifications() ?? true;
    return exactAllowed;
  }

  Future<void> requestExactAlarms() async {
    await _android?.requestExactAlarmsPermission();
    await checkExactAlarms();
  }

  Future<bool> notificationsEnabled() async => await _android?.areNotificationsEnabled() ?? true;

  /// [timeoutMin]: la principal se retira sola cuando llega el reintento (no se duplican).
  NotificationDetails _doseDetails(Profile profile, {int? timeoutMin}) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelDoses.id,
      _channelDoses.name,
      channelDescription: _channelDoses.description,
      timeoutAfter: timeoutMin == null ? null : timeoutMin * 60000,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      color: Color(profile.color),
      colorized: false,
      ticker: 'Toma de ${profile.name}',
      actions: const [AndroidNotificationAction(actionConfirm, 'Ya la tomé', cancelNotification: true)],
    ),
  );

  /// R2: principal a la hora exacta + reintento a +tolerancia. Ignora horas pasadas.
  Future<void> scheduleDose(DoseDetail d, {DateTime? now}) async {
    if (!_ready || d.dose.status != DoseStatus.pending) return;
    final at = now ?? DateTime.now();
    final p = d.product;
    final title = 'Toma de ${d.profile.name}';
    final body = '${doseLabel(p, d.treatment.dose)} de ${productTitle(p)} · Escanea la caja para confirmar';
    final mode = exactAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    final main = d.dose.scheduledAt;
    final retry = main.add(Duration(minutes: d.treatment.toleranceMin));
    if (main.isAfter(at)) {
      await _plugin.zonedSchedule(
        id: notificationId(d.dose.id!),
        scheduledDate: tz.TZDateTime.from(main, tz.local),
        notificationDetails: _doseDetails(d.profile, timeoutMin: d.treatment.toleranceMin),
        androidScheduleMode: mode,
        title: title,
        body: body,
        payload: '${d.dose.id}',
      );
    }
    if (retry.isAfter(at)) {
      await _plugin.zonedSchedule(
        id: notificationId(d.dose.id!, retry: true),
        scheduledDate: tz.TZDateTime.from(retry, tz.local),
        notificationDetails: _doseDetails(d.profile),
        androidScheduleMode: mode,
        title: 'Sigue pendiente: $title',
        body: body,
        payload: '${d.dose.id}',
      );
    }
  }

  Future<void> cancelDose(int doseId) async {
    if (!_ready) return;
    await _plugin.cancel(id: notificationId(doseId));
    await _plugin.cancel(id: notificationId(doseId, retry: true));
  }

  /// R6: una notificación diaria a las 9:00 con el resumen vigente (se reescribe al abrir la app).
  Future<void> scheduleDailyAlerts(String? summary) async {
    if (!_ready) return;
    await _plugin.cancel(id: _dailyAlertId);
    if (summary == null) return;
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _dailyAlertId,
      scheduledDate: next,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelAlerts.id,
          _channelAlerts.name,
          channelDescription: _channelAlerts.description,
          styleInformation: BigTextStyleInformation(summary),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      title: 'Revisa tu botiquín',
      body: summary,
    );
  }

  static String timeLabel(DateTime d) => DateFormat('HH:mm').format(d);
}
