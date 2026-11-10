import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/inventory_rules.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'scan_flows.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(inventoryProvider);
    final today = dateOnly(DateTime.now());
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'scan-inventory',
        onPressed: () => registerByScan(context, ref),
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 26),
        label: const Text('Escanear caja'),
      ),
      body: CustomScrollView(slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(children: [
                Expanded(child: Text('Botiquín', style: context.text.displaySmall)),
                TextButton.icon(
                  onPressed: () => context.push('/inventory/product'),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Agregar a mano'),
                ),
              ]),
            ),
          ),
        ),
        ...switch (inv) {
          AsyncData(:final value) when value.isEmpty => [
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.medication_outlined,
                  title: 'Tu botiquín está vacío',
                  body: 'Escanea el código de barras de una caja: si ya la registraste antes, '
                      'sus datos se llenan solos.',
                  actions: [
                    FilledButton.icon(
                      onPressed: () => registerByScan(context, ref),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Escanear caja'),
                    ),
                  ],
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
                    final units = s.unitsUsable(today);
                    final next = s.nextToExpire;
                    final expired = s.boxes.where((b) => isExpired(b, today)).length;
                    final t = context.sign;
                    return Panel(
                      onTap: () => context.push('/inventory/product/${s.product.id}'),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(productTitle(s.product), style: context.text.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              s.boxes.isEmpty
                                  ? 'Sin cajas activas'
                                  : '${s.boxes.length} ${s.boxes.length == 1 ? 'caja' : 'cajas'} · ${s.product.form}',
                              style: context.text.bodyMedium,
                            ),
                            if (next != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                expired > 0
                                    ? '$expired ${expired == 1 ? 'caja caducada' : 'cajas caducadas'}'
                                    : daysUntilLabel(next.expiresOn, today),
                                style: numerals(context.text.labelMedium!.copyWith(
                                    color: expired > 0
                                        ? t.danger
                                        : next.expiresOn.difference(today).inDays <= 30
                                            ? t.caution
                                            : t.inkSoft)),
                              ),
                            ],
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(fmtUnits(units),
                              style: numerals(context.text.headlineMedium!
                                  .copyWith(color: units <= 0 ? t.danger : t.ink))),
                          Text(s.product.unit == 'ml' ? 'ml' : unitWord(s.product, units),
                              style: context.text.bodySmall),
                        ]),
                      ]),
                    );
                  },
                ),
              ),
            ],
          AsyncError(:final error) => [SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(24), child: Text('$error')))],
          _ => [const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())))],
        },
      ]),
    );
  }
}
