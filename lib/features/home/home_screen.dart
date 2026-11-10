import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/dose_repository.dart';
import '../../data/providers.dart';
import '../../domain/dose_rules.dart';
import '../../domain/inventory_rules.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../confirm/confirm_feedback.dart';
import 'permission_notices.dart';
import 'profile_line.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final doses = ref.watch(todayDosesProvider);
    final profiles = ref.watch(profilesProvider);

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (profiles.value?.isEmpty ?? true)
          ? null
          : FloatingActionButton.extended(
              heroTag: 'scan-home',
              onPressed: () => context.push('/confirm-scan'),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 28),
              label: const Text('Escanear para confirmar'),
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(actionsProvider).refreshSchedule(),
        child: CustomScrollView(
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hoy', style: context.text.displaySmall),
                            const SizedBox(height: 2),
                            Text(fmtDay(now), style: context.text.bodyLarge!.copyWith(color: context.sign.inkSoft)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '¿Ya lo tengo?',
                        onPressed: () => context.push('/already-have'),
                        icon: const Icon(Icons.manage_search_rounded, size: 28),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Conserva los datos previos mientras se recarga (sin parpadeo de carga).
            ...switch ((doses.value, profiles.value, doses.error ?? profiles.error)) {
              (final List<DoseDetail> list, final List<Profile> people, _) => _content(context, ref, list, people, now),
              (_, _, final Object error) => [
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'No pudimos leer tus datos',
                    body: '$error',
                  ),
                ),
              ],
              _ => [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
            },
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    List<DoseDetail> doses,
    List<Profile> people,
    DateTime now,
  ) {
    if (people.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.signpost_outlined,
            title: 'Empieza por tu familia',
            body:
                'Agrega a cada persona que toma medicamentos. Cada una tendrá su color, '
                'y aquí verás su línea con las tomas del día.',
            actions: [
              FilledButton.icon(
                onPressed: () => context.push('/profiles/new'),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Agregar persona'),
              ),
              OutlinedButton(onPressed: () => context.go('/settings'), child: const Text('Probar con datos demo')),
            ],
          ),
        ),
      ];
    }

    final pending = doses.where((d) => d.dose.status == DoseStatus.pending).toList();
    final next = pending.isEmpty ? null : pending.first;
    // Una toma "foco" por perfil: su primera pendiente.
    final focusByProfile = <int, int>{};
    for (final d in pending) {
      focusByProfile.putIfAbsent(d.profile.id!, () => d.dose.id!);
    }
    final byProfile = <int, List<DoseDetail>>{};
    for (final d in doses) {
      byProfile.putIfAbsent(d.profile.id!, () => []).add(d);
    }
    final ordered = people.where((p) => byProfile.containsKey(p.id)).toList();

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: _NextPlate(next: next, doses: doses, now: now),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/inventory/product'),
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Registrar caja'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/already-have'),
                  icon: const Icon(Icons.manage_search_rounded),
                  label: const Text('¿Ya lo tengo?'),
                ),
              ),
            ],
          ),
        ),
      ),
      if (doses.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.event_available_rounded,
            title: 'Sin tomas programadas hoy',
            body: 'Crea un tratamiento desde la ficha de una persona para que aparezca su línea.',
            actions: [
              FilledButton.icon(
                onPressed: () => context.push('/treatments/new'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo tratamiento'),
              ),
            ],
          ),
        )
      else ...[
        const SliverToBoxAdapter(child: SectionTitle('Tomas de hoy')),
        for (final p in ordered) ...[
          SliverToBoxAdapter(
            child: ProfileLine(
              profile: p,
              doses: byProfile[p.id]!,
              now: now,
              focusDoseId: focusByProfile[p.id],
              plateDoseId: next?.dose.id,
              onOpen: (d) => showDoseSheet(context, ref, d),
              onScan: (d) => context.push('/confirm-scan?doseId=${d.dose.id}'),
              onManual: (d) => confirmManually(context, ref, d),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ],
      const SliverToBoxAdapter(child: _AlertsBlock()),
      const SliverToBoxAdapter(child: PermissionNotices()),
    ];
  }
}

Future<void> confirmManually(BuildContext context, WidgetRef ref, DoseDetail d) async {
  final r = await ref.read(actionsProvider).confirm(d.dose.id!, ConfirmMethod.app);
  if (context.mounted) showConfirmResult(context, r, profileName: d.profile.name);
}

/// Placa principal: la siguiente toma pendiente del día, con cifras grandes.
class _NextPlate extends ConsumerWidget {
  final DoseDetail? next;
  final List<DoseDetail> doses;
  final DateTime now;
  const _NextPlate({required this.next, required this.doses, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.sign;
    final soft = context.text.bodyLarge!.copyWith(color: t.onPlateSoft);
    final taken = doses.where((d) => d.dose.isConfirmed).length;
    final missed = doses.where((d) => d.dose.status == DoseStatus.missed).length;
    final daySummary = doses.isEmpty
        ? 'Hoy no hubo tomas programadas.'
        : 'Hoy: $taken de ${doses.length} tomadas${missed > 0 ? ' · $missed ${missed == 1 ? 'omitida' : 'omitidas'}' : ''}.';
    // Si hoy ya no queda nada, la placa anuncia la próxima toma de otro día.
    final upcoming = next ?? ref.watch(nextPendingProvider).value;
    if (upcoming == null) {
      final clean = missed == 0;
      return Plate(
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: clean ? Palette.ok : Palette.caution,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(clean ? Icons.done_all_rounded : Icons.event_note_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doses.isEmpty ? 'Nada pendiente' : (clean ? 'Todo al día' : 'Día terminado'),
                    style: context.text.headlineSmall!.copyWith(color: t.onPlate),
                  ),
                  const SizedBox(height: 2),
                  Text(daySummary, style: numerals(soft)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final d = upcoming;
    final otherDay = next == null;
    final zone = Color(d.profile.color);
    final confirmable = canConfirm(d.dose.scheduledAt, now, d.treatment.missAfterMin);
    final overdue = now.isAfter(d.dose.scheduledAt.add(Duration(minutes: d.treatment.toleranceMin)));
    return Plate(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overdue
                ? 'Toma atrasada'
                : (otherDay ? 'Siguiente toma · ${dayWord(d.dose.scheduledAt, now)}' : 'Siguiente toma'),
            style: context.text.titleMedium!.copyWith(color: overdue ? const Color(0xFFFFD873) : t.onPlate),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtTime(d.dose.scheduledAt),
                style: numerals(context.text.displayLarge!.copyWith(color: t.onPlate, height: 0.95)),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(relative(d.dose.scheduledAt, now), style: numerals(soft)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${doseLabel(d.product, d.treatment.dose)} de ${productTitle(d.product)}',
            style: context.text.titleLarge!.copyWith(color: t.onPlate),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 22,
                height: 8,
                decoration: BoxDecoration(color: zone, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(d.profile.name, style: context.text.titleMedium!.copyWith(color: t.onPlate)),
              ),
              if (d.treatment.notes?.isNotEmpty ?? false) ...[
                Text('  ·  ', style: soft),
                Flexible(
                  child: Text(d.treatment.notes!, style: soft, overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          if (confirmable)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Palette.ink,
                      minimumSize: const Size(48, 56),
                    ),
                    onPressed: () => context.push('/confirm-scan?doseId=${d.dose.id}'),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Escanear la caja'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x80FFFFFF), width: 1.5),
                    minimumSize: const Size(48, 56),
                  ),
                  onPressed: () => confirmManually(context, ref, d),
                  child: const Text('Ya la tomó'),
                ),
              ],
            )
          else
            Text(
              'Podrás confirmarla desde las ${fmtTime(d.dose.scheduledAt.subtract(const Duration(minutes: earlyConfirmMin)))}.',
              style: numerals(soft),
            ),
          if (otherDay) ...[
            const SizedBox(height: 14),
            Divider(color: t.onPlateSoft.withValues(alpha: 0.25)),
            const SizedBox(height: 10),
            Text(daySummary, style: numerals(soft)),
          ],
        ],
      ),
    );
  }
}

/// R6: caducidades y stock bajo, con el rojo reservado a lo ya caducado.
class _AlertsBlock extends ConsumerWidget {
  const _AlertsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider).value;
    if (alerts == null || alerts.isEmpty) return const SizedBox.shrink();
    final today = dateOnly(DateTime.now());
    final items = <Widget>[
      for (final (box, product) in alerts.expiring.take(3))
        Notice(
          tone: isExpired(box, today) ? NoticeTone.danger : NoticeTone.caution,
          icon: isExpired(box, today) ? Icons.block_rounded : Icons.event_busy_rounded,
          title: '${productTitle(product)}: ${daysUntilLabel(box.expiresOn, today).toLowerCase()}',
          body:
              '${fmtUnits(box.unitsLeft)} ${unitWord(product, box.unitsLeft)} en la caja · ${fmtDateShort(box.expiresOn)}',
          onTap: () => context.push('/inventory/product/${product.id}'),
        ),
      for (final l in alerts.lowStock.take(3))
        Notice(
          tone: NoticeTone.caution,
          icon: Icons.inventory_2_outlined,
          title: l.days < 1
              ? '${l.product.name} para ${l.profile.name}: se termina hoy'
              : '${l.product.name} para ${l.profile.name}: quedan ${l.days.floor()} ${l.days.floor() == 1 ? 'día' : 'días'}',
          body: 'Registra una caja nueva para no quedarte sin medicamento.',
          onTap: () => context.push('/inventory/product/${l.product.id}'),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Avisos'),
        for (final w in items) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: w),
      ],
    );
  }
}

/// Detalle de una toma: acciones y acceso al historial.
Future<void> showDoseSheet(BuildContext context, WidgetRef ref, DoseDetail d) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheet) {
      final now = DateTime.now();
      final confirmable =
          d.dose.status == DoseStatus.pending && canConfirm(d.dose.scheduledAt, now, d.treatment.missAfterMin);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileTag(d.profile, large: true),
              const SizedBox(height: 12),
              Text(productTitle(d.product), style: context.text.headlineMedium),
              const SizedBox(height: 4),
              Text(
                '${doseLabel(d.product, d.treatment.dose)} · ${fmtTime(d.dose.scheduledAt)}',
                style: numerals(context.text.bodyLarge!),
              ),
              if (d.treatment.notes?.isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Text(d.treatment.notes!, style: context.text.bodyMedium),
              ],
              const SizedBox(height: 12),
              StatusLabel(
                d.dose.status,
                suffix: d.dose.confirmedAt == null
                    ? null
                    : '${fmtTime(d.dose.confirmedAt!)}${d.dose.method == ConfirmMethod.scan ? ' · escaneada' : ''}',
              ),
              const SizedBox(height: 20),
              if (confirmable) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheet);
                      context.push('/confirm-scan?doseId=${d.dose.id}');
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Confirmar escaneando'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheet);
                      confirmManually(context, ref, d);
                    },
                    child: const Text('Ya la tomó (sin escanear)'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheet);
                    context.push('/treatments/${d.treatment.id}');
                  },
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Ver historial del tratamiento'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
