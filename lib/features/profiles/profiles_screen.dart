import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/dose_rules.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class ProfileSummary {
  final Profile profile;
  final int activeTreatments;
  final double? compliance;
  const ProfileSummary(this.profile, this.activeTreatments, this.compliance);
}

final profileSummariesProvider = FutureProvider<List<ProfileSummary>>((ref) async {
  ref.watch(dataVersionProvider);
  final profiles = await ref.watch(profilesProvider.future);
  final treatments = ref.watch(treatmentRepoProvider);
  final doses = ref.watch(doseRepoProvider);
  final out = <ProfileSummary>[];
  for (final p in profiles) {
    final ts = await treatments.forProfile(p.id!);
    final all = <Dose>[];
    for (final t in ts) {
      all.addAll(await doses.forTreatment(t.id!, until: DateTime.now()));
    }
    out.add(ProfileSummary(p, ts.where((t) => t.active).length, compliance(all)));
  }
  return out;
});

String pct(double v) => '${(v * 100).round()} %';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(profileSummariesProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-profile',
        onPressed: () => context.push('/profiles/new'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Agregar persona'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Familia', style: context.text.displaySmall),
              ),
            ),
          ),
          ...switch (data.hasValue ? AsyncData(data.requireValue) : data) {
            AsyncData(:final value) when value.isEmpty => [
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'Nadie registrado todavía',
                  body:
                      'Cada persona tiene su color: lo verás en su línea de tomas, en sus cajas y en las notificaciones.',
                ),
              ),
            ],
            AsyncData(:final value) => [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList.separated(
                  itemCount: value.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = value[i];
                    return Panel(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                      onTap: () => context.push('/profiles/${s.profile.id}'),
                      child: Row(
                        children: [
                          ProfileAvatar(s.profile, size: 52),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.profile.name, style: context.text.titleLarge),
                                const SizedBox(height: 2),
                                Text(
                                  s.activeTreatments == 0
                                      ? 'Sin tratamientos activos'
                                      : '${s.activeTreatments} ${s.activeTreatments == 1 ? 'tratamiento activo' : 'tratamientos activos'}',
                                  style: context.text.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          if (s.compliance != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(pct(s.compliance!), style: numerals(context.text.titleLarge!)),
                                Text('cumplimiento', style: context.text.bodySmall),
                              ],
                            ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, color: context.sign.inkFaint),
                        ],
                      ),
                    );
                  },
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
        ],
      ),
    );
  }
}
