import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'data/db.dart';
import 'data/providers.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es_MX';
  await initializeDateFormatting('es_MX');
  final db = await openAppDatabase();
  final launchDoseId = await NotificationService.instance.init();
  runApp(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MiBotiquinApp(launchDoseId: launchDoseId),
  ));
}
