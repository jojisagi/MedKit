import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/widgets.dart';

final _permState = FutureProvider<({bool notif, bool exact})>((ref) async {
  ref.watch(dataVersionProvider);
  final n = ref.watch(notificationsProvider);
  return (notif: await n.notificationsEnabled(), exact: await n.checkExactAlarms());
});

/// SPEC §8: cada permiso se pide con explicación previa; si falta, se lleva a ajustes.
class PermissionNotices extends ConsumerWidget {
  const PermissionNotices({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_permState).value;
    if (s == null || (s.notif && s.exact)) return const SizedBox.shrink();
    final n = ref.read(notificationsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(children: [
        if (!s.notif)
          Notice(
            tone: NoticeTone.caution,
            icon: Icons.notifications_off_outlined,
            title: 'Activa los recordatorios',
            body: 'Sin permiso de notificaciones no podemos avisarte a la hora de cada toma.',
            action: FilledButton(
              onPressed: () async {
                await n.requestNotificationPermission();
                ref.invalidate(_permState);
              },
              child: const Text('Permitir notificaciones'),
            ),
          ),
        if (!s.notif && !s.exact) const SizedBox(height: 8),
        if (!s.exact)
          Notice(
            tone: NoticeTone.caution,
            icon: Icons.alarm_off_rounded,
            title: 'Avisos a la hora exacta',
            body: 'Android puede retrasar los avisos varios minutos. Permite «Alarmas y recordatorios» '
                'para que lleguen puntuales.',
            action: OutlinedButton(
              onPressed: () async {
                await n.requestExactAlarms();
                ref.invalidate(_permState);
                await ref.read(actionsProvider).rescheduleAll();
              },
              child: const Text('Abrir ajustes de Android'),
            ),
          ),
      ]),
    );
  }
}
