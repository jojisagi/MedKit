import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/inventory_rules.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'box_tile.dart';

final _productProvider = FutureProvider.family<(Product?, List<Box>), int>((ref, id) async {
  ref.watch(dataVersionProvider);
  final p = await ref.watch(productRepoProvider).get(id);
  final boxes = await ref.watch(boxRepoProvider).activeForProduct(id);
  return (p, boxes);
});

class ProductDetailScreen extends ConsumerWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_productProvider(productId)).value;
    final profiles = {for (final p in ref.watch(profilesProvider).value ?? <Profile>[]) p.id: p};
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final (p, boxes) = data;
    if (p == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Este medicamento ya no existe.')));
    }
    final today = dateOnly(DateTime.now());
    final usable = boxes.where((b) => !isExpired(b, today)).fold(0.0, (s, b) => s + b.unitsLeft);
    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            tooltip: 'Editar medicamento',
            onPressed: () => context.push('/inventory/product?id=${p.id}'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        Plate(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(productTitle(p), style: context.text.headlineSmall!.copyWith(color: context.sign.onPlate)),
            if (p.activeIngredient != null && p.activeIngredient != p.name)
              Text(p.activeIngredient!, style: context.text.bodyLarge!.copyWith(color: context.sign.onPlateSoft)),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmtUnits(usable),
                  style: numerals(context.text.displayMedium!.copyWith(color: context.sign.onPlate, height: 1))),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${unitWord(p, usable)} disponibles',
                    style: context.text.bodyLarge!.copyWith(color: context.sign.onPlateSoft)),
              ),
            ]),
            if (p.gtin != null) ...[
              const SizedBox(height: 12),
              Text('Código ${p.gtin}', style: numerals(context.text.bodySmall!.copyWith(color: context.sign.onPlateSoft))),
            ],
          ]),
        ),
        SectionTitle('Cajas', padding: const EdgeInsets.fromLTRB(4, 28, 0, 10), trailing: TextButton.icon(
          onPressed: () => context.push('/inventory/box?productId=${p.id}'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nueva caja'),
        )),
        if (boxes.isEmpty)
          Text('No hay cajas activas. Las cajas vacías se archivan solas.', style: context.text.bodyMedium)
        else
          for (final b in boxes) ...[
            BoxTile(box: b, product: p, owner: profiles[b.profileId], onTap: () => _boxSheet(context, ref, b, p)),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.push('/treatments/new?productId=${p.id}'),
          icon: const Icon(Icons.event_repeat_rounded),
          label: const Text('Programar tratamiento con este medicamento'),
        ),
      ]),
    );
  }

  Future<void> _boxSheet(BuildContext context, WidgetRef ref, Box b, Product p) => showModalBottomSheet(
        context: context,
        builder: (sheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Caja de ${p.name}', style: context.text.headlineSmall),
              const SizedBox(height: 4),
              Text('Caduca el ${fmtDate(b.expiresOn)}', style: numerals(context.text.bodyMedium!)),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: () async {
                  Navigator.pop(sheet);
                  await _adjust(context, ref, b, p);
                },
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Corregir unidades'),
              ),
              const SizedBox(height: 24),
              // Acción destructiva aislada y en contorno.
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: context.sign.danger, side: BorderSide(color: context.sign.danger)),
                onPressed: () async {
                  Navigator.pop(sheet);
                  await ref.read(boxRepoProvider).archive(b.id!);
                  ref.read(actionsProvider).changed();
                  if (context.mounted) showMessage(context, 'Caja retirada del botiquín');
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Retirar caja (se terminó o se desechó)'),
              ),
            ]),
          ),
        ),
      );

  Future<void> _adjust(BuildContext context, WidgetRef ref, Box b, Product p) async {
    final c = TextEditingController(text: fmtUnits(b.unitsLeft));
    final v = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Unidades que quedan'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: numerals(context.text.headlineSmall!),
          decoration: InputDecoration(suffixText: p.unit == 'ml' ? 'ml' : 'pzas'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(d, double.tryParse(c.text.replaceAll(',', '.'))),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (v == null || v < 0) return;
    await ref.read(boxRepoProvider).update(b.copyWith(unitsLeft: v, archived: v <= 0));
    ref.read(actionsProvider).changed();
  }
}
