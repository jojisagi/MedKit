import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/providers.dart';
import 'domain/models.dart';
import 'features/confirm/confirm_feedback.dart';
import 'router.dart';
import 'ui/theme.dart';

class MiBotiquinApp extends ConsumerStatefulWidget {
  final int? launchDoseId;
  const MiBotiquinApp({super.key, this.launchDoseId});

  @override
  ConsumerState<MiBotiquinApp> createState() => _MiBotiquinAppState();
}

class _MiBotiquinAppState extends ConsumerState<MiBotiquinApp> with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter();
  final _subs = <StreamSubscription<int>>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final n = ref.read(notificationsProvider);
    // Tocar la notificación abre el escáner con la toma preseleccionada (SPEC §5).
    _subs.add(n.taps.listen((id) => _router.push('/confirm-scan?doseId=$id')));
    // "Ya la tomé" con la app abierta.
    _subs.add(n.confirms.listen((id) async {
      final r = await ref.read(actionsProvider).confirm(id, ConfirmMethod.notification);
      final ctx = rootKey.currentContext;
      if (ctx != null && ctx.mounted) showConfirmResult(ctx, r);
    }));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await n.checkExactAlarms();
      await ref.read(actionsProvider).refreshSchedule();
      if (widget.launchDoseId != null) _router.push('/confirm-scan?doseId=${widget.launchDoseId}');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // R3: recalcular al volver; refleja confirmaciones hechas desde la notificación.
      ref.read(notificationsProvider).checkExactAlarms().then((_) => ref.read(actionsProvider).refreshSchedule());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Mi Botiquín',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        routerConfig: _router,
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      );
}
