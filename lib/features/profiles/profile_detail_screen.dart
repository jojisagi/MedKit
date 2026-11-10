import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/dose_rules.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../treatments/schedule_text.dart';
import 'profiles_screen.dart' show pct;

class TreatmentRow {
  final Treatment treatment;
  final Product product;
  final double? compliance;
  const TreatmentRow(this.treatment, this.product, this.compliance);
}

final _profileDetail = FutureProvider.family<(Profile?, List<TreatmentRow>), int>((ref, id) async {
  ref.watch(dataVersionProvider);
  final p = await ref.watch(profileRepoProvider).get(id);
  if (p == null) return (null, <TreatmentRow>[]);
  final rows = <TreatmentRow>[];
  for (final t in await ref.watch(treatmentRepoProvider).forProfile(id)) {
    final prod = await ref.watch(productRepoProvider).get(t.productId);
    if (prod == null) continue;
    final doses = await ref.watch(doseRepoProvider).forTreatment(t.id!, until: DateTime.now());
    rows.add(TreatmentRow(t, prod, compliance(doses)));
  }
  return (p, rows);
});

class ProfileDetailScreen extends ConsumerWidget {
  final int profileId;
  const ProfileDetailScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_profileDetail(profileId)).value;
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final (p, rows) = data;
    if (p == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Esta persona ya no existe.')));
    final active = rows.where((r) => r.treatment.active).toList();
    final ended = rows.where((r) => !r.treatment.active).toList();
    final zone = Color(p.color);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: () => context.push('/profiles/${p.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') await _delete(context, ref, p);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Text('Eliminar persona', style: TextStyle(color: context.sign.danger)),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-treatment',
        onPressed: () => context.push('/treatments/new?profileId=${p.id}'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo tratamiento'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), children: [
        Row(children: [
          ProfileAvatar(p, size: 64),
          const SizedBox(width: 16),
          Expanded(child: Text(p.name, style: context.text.headlineLarge)),
        ]),
        const SizedBox(height: 16),
        // Su línea: franja continua que conecta todo lo de esta persona.
        Container(height: 8, decoration: BoxDecoration(color: zone, borderRadius: BorderRadius.circular(4))),
        const SectionTitle('Tratamientos activos', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
        if (active.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Sin tratamientos activos. Agrega uno para programar sus tomas y recordatorios.',
                style: context.text.bodyMedium),
          ),
        for (final r in active) ...[_TreatmentPanel(row: r, zone: zone), const SizedBox(height: 10)],
        if (ended.isNotEmpty) ...[
          const SectionTitle('Terminados', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
          for (final r in ended) ...[_TreatmentPanel(row: r, zone: zone), const SizedBox(height: 10)],
        ],
      ]),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Profile p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('¿Eliminar a ${p.name}?'),
        content: const Text('Se borran sus tratamientos e historial. Sus cajas pasan a ser compartidas. '
            'No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.sign.danger),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final t in await ref.read(treatmentRepoProvider).forProfile(p.id!)) {
      await ref.read(actionsProvider).finishTreatment(t.id!);
    }
    await ref.read(profileRepoProvider).delete(p.id!);
    ref.read(actionsProvider).changed();
    if (context.mounted) context.pop();
  }
}

class _TreatmentPanel extends StatelessWidget {
  final TreatmentRow row;
  final Color zone;
  const _TreatmentPanel({required this.row, required this.zone});

  @override
  Widget build(BuildContext context) {
    final t = row.treatment;
    return Panel(
      onTap: () => context.push('/treatments/${t.id}'),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(productTitle(row.product), style: context.text.titleMedium),
            const SizedBox(height: 2),
            Text('${doseLabel(row.product, t.dose)} · ${scheduleText(t)}', style: numerals(context.text.bodyMedium!)),
            if (t.endsAt != null) ...[
              const SizedBox(height: 2),
              Text(t.active ? 'Hasta el ${fmtDateShort(t.endsAt!)}' : 'Terminó el ${fmtDateShort(t.endsAt!)}',
                  style: numerals(context.text.bodySmall!)),
            ],
          ]),
        ),
        if (row.compliance != null) ...[
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(pct(row.compliance!), style: numerals(context.text.titleLarge!)),
            Text('cumplimiento', style: context.text.bodySmall),
          ]),
        ],
        Icon(Icons.chevron_right_rounded, color: context.sign.inkFaint),
      ]),
    );
  }
}
