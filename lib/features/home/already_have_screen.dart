import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/inventory_rules.dart';
import '../../domain/models.dart';
import '../../services/scanner_screen.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../inventory/box_tile.dart';

/// B3: escanear una caja en la farmacia y saber si ya la tienes.
class AlreadyHaveScreen extends ConsumerStatefulWidget {
  const AlreadyHaveScreen({super.key});

  @override
  ConsumerState<AlreadyHaveScreen> createState() => _AlreadyHaveScreenState();
}

class _AlreadyHaveScreenState extends ConsumerState<AlreadyHaveScreen> {
  bool _loading = true;
  String? _gtin;
  Product? _product;
  List<Box> _boxes = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    setState(() => _loading = true);
    final r = await scanBarcode(context,
        title: '¿Ya lo tengo?', subtitle: 'Escanea la caja y te decimos si ya está en tu botiquín.');
    if (r == null) {
      if (mounted && _gtin == null) context.pop();
      if (mounted) setState(() => _loading = false);
      return;
    }
    final p = await ref.read(productRepoProvider).findByGtin(r.gtin14);
    final boxes = p == null ? <Box>[] : await ref.read(boxRepoProvider).activeForProduct(p.id!);
    if (!mounted) return;
    setState(() {
      _gtin = r.gtin14;
      _product = p;
      _boxes = boxes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profiles = {for (final p in ref.watch(profilesProvider).value ?? <Profile>[]) p.id: p};
    final today = dateOnly(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('¿Ya lo tengo?')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              if (_product == null || _boxes.isEmpty) ...[
                EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No tienes este medicamento',
                  body: _product == null
                      ? 'No está en tu botiquín.'
                      : '${productTitle(_product!)} está en tu catálogo, pero no tienes cajas activas.',
                  actions: [
                    FilledButton.icon(
                      onPressed: () => context.pushReplacement(_product == null
                          ? '/inventory/product?gtin=$_gtin'
                          : '/inventory/box?productId=${_product!.id}'),
                      icon: const Icon(Icons.add_box_outlined),
                      label: const Text('Registrar caja'),
                    ),
                  ],
                ),
              ] else ...[
                Plate(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Sí, ya lo tienes', style: context.text.headlineMedium!.copyWith(color: context.sign.onPlate)),
                    const SizedBox(height: 6),
                    Text(
                      '${productTitle(_product!)} · ${fmtUnits(_boxes.where((b) => !isExpired(b, today)).fold(0.0, (s, b) => s + b.unitsLeft))} '
                      '${unitWord(_product!, 2)} en ${_boxes.length} ${_boxes.length == 1 ? 'caja' : 'cajas'}',
                      style: numerals(context.text.bodyLarge!.copyWith(color: context.sign.onPlateSoft)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                for (final b in _boxes) ...[
                  BoxTile(box: b, product: _product!, owner: profiles[b.profileId]),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Escanear otra caja'),
              ),
            ]),
    );
  }
}
