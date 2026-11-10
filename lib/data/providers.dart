import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/inventory_rules.dart';
import '../domain/models.dart';
import '../services/dose_confirmation_service.dart';
import '../services/notification_service.dart';
import '../services/scheduler_service.dart';
import 'box_repository.dart';
import 'dose_repository.dart';
import 'product_repository.dart';
import 'profile_repository.dart';
import 'settings_repository.dart';
import 'treatment_repository.dart';

/// Se sobrescribe en `main` con la base ya abierta.
final databaseProvider = Provider<Database>((ref) => throw UnimplementedError('databaseProvider sin override'));

final profileRepoProvider = Provider((ref) => ProfileRepository(ref.watch(databaseProvider)));
final productRepoProvider = Provider((ref) => ProductRepository(ref.watch(databaseProvider)));
final boxRepoProvider = Provider((ref) => BoxRepository(ref.watch(databaseProvider)));
final treatmentRepoProvider = Provider((ref) => TreatmentRepository(ref.watch(databaseProvider)));
final doseRepoProvider = Provider((ref) => DoseRepository(ref.watch(databaseProvider)));
final settingsRepoProvider = Provider((ref) => SettingsRepository(ref.watch(databaseProvider)));

final notificationsProvider = Provider((ref) => NotificationService.instance);
final schedulerProvider = Provider((ref) => SchedulerService(ref.watch(databaseProvider)));
final confirmationProvider = Provider((ref) {
  final n = ref.watch(notificationsProvider);
  return DoseConfirmationService(ref.watch(databaseProvider), onConfirmed: n.cancelDose);
});

/// Se incrementa tras cada escritura; las consultas lo observan para recargarse.
class DataVersion extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final dataVersionProvider = NotifierProvider<DataVersion, int>(DataVersion.new);

/// Reloj de la UI: recalcula estados cada 30 s.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

DateTime nowOf(Ref ref) => ref.watch(clockProvider).value ?? DateTime.now();

final settingsProvider = FutureProvider<AppSettings>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(settingsRepoProvider).load();
});

final profilesProvider = FutureProvider<List<Profile>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(profileRepoProvider).all();
});

/// Tomas de hoy con contexto. Marca omitidas de forma perezosa al leer (R2).
final todayDosesProvider = FutureProvider<List<DoseDetail>>((ref) async {
  ref.watch(dataVersionProvider);
  final now = nowOf(ref);
  final repo = ref.watch(doseRepoProvider);
  await repo.markMissed(now);
  final start = dateOnly(now);
  return repo.detailsBetween(start, start.add(const Duration(days: 1)));
});

class ProductStock {
  final Product product;
  final List<Box> boxes;
  const ProductStock(this.product, this.boxes);

  double unitsUsable(DateTime today) =>
      boxes.where((b) => !isExpired(b, today)).fold(0.0, (s, b) => s + b.unitsLeft);
  Box? get nextToExpire => boxes.isEmpty ? null : boxes.first;
}

final inventoryProvider = FutureProvider<List<ProductStock>>((ref) async {
  ref.watch(dataVersionProvider);
  final products = await ref.watch(productRepoProvider).all();
  final boxes = await ref.watch(boxRepoProvider).allActive();
  return [
    for (final p in products) ProductStock(p, boxes.where((b) => b.productId == p.id).toList()),
  ];
});

class LowStock {
  final Treatment treatment;
  final Product product;
  final Profile profile;
  final double days;
  const LowStock(this.treatment, this.product, this.profile, this.days);
}

class HomeAlerts {
  final List<(Box, Product)> expiring;
  final List<LowStock> lowStock;
  const HomeAlerts(this.expiring, this.lowStock);
  bool get isEmpty => expiring.isEmpty && lowStock.isEmpty;
}

/// R6: caducidades próximas o vencidas + tratamientos con pocos días de inventario.
final alertsProvider = FutureProvider<HomeAlerts>((ref) async {
  ref.watch(dataVersionProvider);
  final settings = await ref.watch(settingsProvider.future);
  final today = dateOnly(DateTime.now());
  final products = {for (final p in await ref.watch(productRepoProvider).all()) p.id!: p};
  final profiles = {for (final p in await ref.watch(profileRepoProvider).all()) p.id!: p};
  final boxes = await ref.watch(boxRepoProvider).allActive();
  final expiring = [
    for (final b in expiringBoxes(boxes, today, settings.expiryAlertDays))
      if (products[b.productId] != null) (b, products[b.productId]!),
  ];
  final low = <LowStock>[];
  for (final t in await ref.watch(treatmentRepoProvider).active()) {
    final mine = boxes.where((b) => b.productId == t.productId).toList();
    final days = daysRemaining(unitsAvailable(mine, profileId: t.profileId, today: today), t);
    if (days <= settings.lowStockDays && products[t.productId] != null && profiles[t.profileId] != null) {
      low.add(LowStock(t, products[t.productId]!, profiles[t.profileId]!, days));
    }
  }
  low.sort((a, b) => a.days.compareTo(b.days));
  return HomeAlerts(expiring, low);
});

String alertsSummary(HomeAlerts a, DateTime today) {
  final parts = <String>[];
  final expired = a.expiring.where((e) => isExpired(e.$1, today)).length;
  final soon = a.expiring.length - expired;
  if (expired > 0) parts.add('$expired ${expired == 1 ? 'caja caducada' : 'cajas caducadas'}');
  if (soon > 0) parts.add('$soon por caducar');
  if (a.lowStock.isNotEmpty) {
    parts.add('${a.lowStock.length} ${a.lowStock.length == 1 ? 'tratamiento' : 'tratamientos'} con poco inventario');
  }
  return parts.join(' · ');
}

/// Acciones de alto nivel que tocan base + notificaciones y refrescan la UI.
class AppActions {
  final Ref ref;
  AppActions(this.ref);

  NotificationService get _n => ref.read(notificationsProvider);

  /// R3: marca omitidas, materializa 72 h y programa notificaciones de lo nuevo.
  Future<void> refreshSchedule() async {
    final created = await ref.read(schedulerProvider).refresh();
    final repo = ref.read(doseRepoProvider);
    for (final d in created) {
      final detail = await repo.detail(d.id!);
      if (detail != null) await _n.scheduleDose(detail);
    }
    ref.read(dataVersionProvider.notifier).bump();
    unawaited(_refreshDailyAlerts());
  }

  Future<void> _refreshDailyAlerts() async {
    try {
      final a = await ref.read(alertsProvider.future);
      await _n.scheduleDailyAlerts(a.isEmpty ? null : alertsSummary(a, DateTime.now()));
    } catch (_) {}
  }

  /// Reprograma todas las notificaciones pendientes (tras conceder alarmas exactas, por ejemplo).
  Future<void> rescheduleAll() async {
    final now = DateTime.now();
    final repo = ref.read(doseRepoProvider);
    for (final d in await repo.detailsBetween(now.subtract(const Duration(hours: 2)), now.add(const Duration(days: 4)))) {
      await _n.scheduleDose(d);
    }
  }

  Future<ConfirmResult> confirm(int doseId, ConfirmMethod method) async {
    final r = await ref.read(confirmationProvider).confirm(doseId, method);
    ref.read(dataVersionProvider.notifier).bump();
    return r;
  }

  Future<void> finishTreatment(int treatmentId) async {
    final ids = await ref.read(schedulerProvider).finishTreatment(treatmentId);
    for (final id in ids) {
      await _n.cancelDose(id);
    }
    ref.read(dataVersionProvider.notifier).bump();
  }

  void changed() => ref.read(dataVersionProvider.notifier).bump();
}

final actionsProvider = Provider((ref) => AppActions(ref));
