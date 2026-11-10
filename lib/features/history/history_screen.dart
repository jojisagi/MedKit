import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/dose_rules.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../treatments/schedule_text.dart';

class _History {
  final Treatment treatment;
  final Product product;
  final Profile profile;
  final List<Dose> doses;
  const _History(this.treatment, this.product, this.profile, this.doses);
}

final _historyProvider = FutureProvider.family<_History?, int>((ref, id) async {
  ref.watch(dataVersionProvider);
  final t = await ref.watch(treatmentRepoProvider).get(id);
  if (t == null) return null;
  final p = await ref.watch(productRepoProvider).get(t.productId);
  final f = await ref.watch(profileRepoProvider).get(t.profileId);
  if (p == null || f == null) return null;
  await ref.watch(doseRepoProvider).markMissed(DateTime.now());
  final doses = await ref.watch(doseRepoProvider).forTreatment(id, until: DateTime.now().add(const Duration(days: 1)));
  return _History(t, p, f, doses);
});

/// SPEC §6.5: tomas con estado y % de cumplimiento = (a tiempo + tardías) ÷ (a tiempo + tardías + omitidas).
class HistoryScreen extends ConsumerWidget {
  final int treatmentId;
  const HistoryScreen({super.key, required this.treatmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(_historyProvider(treatmentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: switch (h) {
        AsyncData(value: null) => const Center(child: Text('Este tratamiento ya no existe.')),
        AsyncData(value: final _History h) => _body(context, ref, h),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, _History h) {
    final c = compliance(h.doses);
    final onTime = h.doses.where((d) => d.status == DoseStatus.onTime).length;
    final late = h.doses.where((d) => d.status == DoseStatus.late).length;
    final missed = h.doses.where((d) => d.status == DoseStatus.missed).length;
    final past = h.doses.where((d) => d.status != DoseStatus.pending || d.scheduledAt.isBefore(DateTime.now())).toList();
    final t = context.sign;

    // Agrupar por día.
    final byDay = <DateTime, List<Dose>>{};
    for (final d in past) {
      byDay.putIfAbsent(DateTime(d.scheduledAt.year, d.scheduledAt.month, d.scheduledAt.day), () => []).add(d);
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
      ProfileTag(h.profile, large: true),
      const SizedBox(height: 8),
      Text(productTitle(h.product), style: context.text.headlineMedium),
      Text('${doseLabel(h.product, h.treatment.dose)} · ${scheduleText(h.treatment)}',
          style: numerals(context.text.bodyLarge!.copyWith(color: t.inkSoft))),
      const SizedBox(height: 20),
      Plate(
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cumplimiento', style: context.text.titleMedium!.copyWith(color: t.onPlate)),
              const SizedBox(height: 4),
              Text(c == null ? '—' : '${(c * 100).round()} %',
                  style: numerals(context.text.displayMedium!.copyWith(color: t.onPlate, height: 1))),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _Count('A tiempo', onTime, t.onPlate),
            _Count('Tardías', late, const Color(0xFFFFD873)),
            _Count('Omitidas', missed, const Color(0xFFFFB4AB)),
          ]),
        ]),
      ),
      // Banda de días: un bloque por toma, la secuencia real del tratamiento.
      if (past.isNotEmpty) ...[
        const SizedBox(height: 16),
        _Strip(doses: past.reversed.toList(), zone: zoneOn(context, Color(h.profile.color))),
      ],
      for (final day in byDay.keys) ...[
        SectionTitle(fmtDay(day), padding: const EdgeInsets.fromLTRB(4, 24, 0, 8)),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (final (i, d) in byDay[day]!.indexed) ...[
              if (i > 0) const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: SizedBox(
                  width: 56,
                  child: Text(fmtTime(d.scheduledAt), style: numerals(context.text.titleMedium!)),
                ),
                title: StatusLabel(d.status),
                subtitle: d.confirmedAt == null
                    ? null
                    : Text(
                        'Confirmada ${fmtTime(d.confirmedAt!)} · ${switch (d.method) {
                          ConfirmMethod.scan => 'escaneando la caja',
                          ConfirmMethod.notification => 'desde la notificación',
                          _ => 'en la app',
                        }}',
                        style: numerals(context.text.bodySmall!)),
              ),
            ],
          ]),
        ),
      ],
      if (past.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Text('Todavía no hay tomas registradas.', style: context.text.bodyMedium),
        ),
      if (h.treatment.active) ...[
        const SizedBox(height: 40),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: t.danger, side: BorderSide(color: t.danger)),
          onPressed: () => _finish(context, ref, h),
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Terminar tratamiento'),
        ),
      ],
    ]);
  }

  Future<void> _finish(BuildContext context, WidgetRef ref, _History h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Terminar tratamiento?'),
        content: Text('Se cancelan las tomas y recordatorios pendientes de ${h.product.name} para ${h.profile.name}. '
            'El historial se conserva.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.sign.danger),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Terminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(actionsProvider).finishTreatment(h.treatment.id!);
    if (context.mounted) {
      showMessage(context, 'Tratamiento terminado');
      context.pop();
    }
  }
}

class _Count extends StatelessWidget {
  final String label;
  final int n;
  final Color color;
  const _Count(this.label, this.n, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text('$label  $n', style: numerals(context.text.labelLarge!.copyWith(color: color))),
      );
}

class _Strip extends StatelessWidget {
  final List<Dose> doses;
  final Color zone;
  const _Strip({required this.doses, required this.zone});

  @override
  Widget build(BuildContext context) {
    final t = context.sign;
    return Semantics(
      label: 'Secuencia de tomas',
      child: Wrap(spacing: 4, runSpacing: 4, children: [
        for (final d in doses)
          Container(
            width: 14,
            height: 22,
            decoration: BoxDecoration(
              color: switch (d.status) {
                DoseStatus.onTime => zone,
                DoseStatus.late => t.caution,
                DoseStatus.missed => t.danger,
                DoseStatus.pending => t.rule,
              },
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ]),
    );
  }
}
