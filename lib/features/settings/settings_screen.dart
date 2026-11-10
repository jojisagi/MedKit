import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/demo_seed.dart';
import '../../data/providers.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).value;
    final t = context.sign;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Ajustes', style: context.text.displaySmall),
            ),
          ),
          if (s != null) ...[
            const SectionTitle('Alertas'),
            _Stepper(
              title: 'Avisar caducidad con',
              value: s.expiryAlertDays,
              unit: 'días de anticipación',
              options: const [7, 15, 30, 60, 90],
              onChanged: (v) => _set(ref, 'expiry_alert_days', '$v'),
            ),
            _Stepper(
              title: 'Avisar inventario bajo cuando queden',
              value: s.lowStockDays,
              unit: 'días o menos',
              options: const [2, 3, 5, 7, 10],
              onChanged: (v) => _set(ref, 'low_stock_days', '$v'),
            ),
            const SectionTitle('Modo demo'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Panel(
                onTap: () => s.demoMode ? _clearDemo(context, ref) : _loadDemo(context, ref),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.demoMode ? 'Datos demo cargados' : 'Cargar datos de prueba',
                            style: context.text.titleMedium,
                          ),
                        ),
                        Switch(
                          value: s.demoMode,
                          onChanged: (on) => on ? _loadDemo(context, ref) : _clearDemo(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Agrega a Rosa y Don Luis, tres medicamentos, una caja que caduca en 10 días y una toma '
                      'en 2 minutos (tolerancia 1 min, omitida a los 3 min). Ideal para presentar la app.',
                      style: context.text.bodyMedium,
                    ),
                    if (s.demoMode) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: t.danger,
                          side: BorderSide(color: t.danger),
                        ),
                        onPressed: () => _clearDemo(context, ref),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Borrar datos demo'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SectionTitle('Acerca de'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Plate(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.health_and_safety_outlined, color: t.onPlate, size: 30),
                      const SizedBox(width: 12),
                      Text('Mi Botiquín', style: context.text.headlineSmall!.copyWith(color: t.onPlate)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mi Botiquín no diagnostica ni recomienda medicamentos. Consulta siempre a tu médico.',
                    style: context.text.bodyLarge!.copyWith(color: t.onPlate),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded, color: t.onPlateSoft, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tus datos se guardan solo en este teléfono.',
                          style: context.text.bodyLarge!.copyWith(color: t.onPlateSoft),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Text(
              'Versión 1.0 · Equipo Inmóviles: Héctor Armando González Espinosa, '
              'Juan Manuel Palafox Valdés, Jorge Sánchez Girón.',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _set(WidgetRef ref, String key, String value) async {
    await ref.read(settingsRepoProvider).set(key, value);
    ref.read(actionsProvider).changed();
  }

  Future<void> _loadDemo(BuildContext context, WidgetRef ref) async {
    await seedDemo(ref.read(databaseProvider));
    await ref.read(actionsProvider).refreshSchedule();
    if (context.mounted) {
      showMessage(context, 'Datos demo cargados. La primera toma llega en 2 minutos.');
      context.go('/');
    }
  }

  Future<void> _clearDemo(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    for (final id in await demoPendingDoseIds(db)) {
      await ref.read(notificationsProvider).cancelDose(id);
    }
    await clearDemo(db);
    ref.read(actionsProvider).changed();
    if (context.mounted) showMessage(context, 'Datos demo borrados');
  }
}

class _Stepper extends StatelessWidget {
  final String title;
  final int value;
  final String unit;
  final List<int> options;
  final ValueChanged<int> onChanged;
  const _Stepper({
    required this.title,
    required this.value,
    required this.unit,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.bodyLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              ChoiceChip(label: Text('$o'), selected: value == o, onSelected: (_) => onChanged(o)),
          ],
        ),
        const SizedBox(height: 4),
        Text(unit, style: context.text.bodySmall),
      ],
    ),
  );
}
