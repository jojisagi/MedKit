import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'box_fields.dart';

/// Caja nueva de un producto conocido (B2 precargado): solo caducidad, dueño y unidades.
class BoxFormScreen extends ConsumerStatefulWidget {
  final int productId;
  final int? boxId;
  final String? lot;
  final String? expires;
  const BoxFormScreen({super.key, required this.productId, this.boxId, this.lot, this.expires});

  @override
  ConsumerState<BoxFormScreen> createState() => _BoxFormScreenState();
}

class _BoxFormScreenState extends ConsumerState<BoxFormScreen> {
  final _form = GlobalKey<FormState>();
  Product? _product;
  late final BoxDraft _draft = BoxDraft(expiresOn: parseIsoDate(widget.expires), lot: widget.lot);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref.read(productRepoProvider).get(widget.productId).then((p) {
      if (!mounted || p == null) return;
      setState(() => _product = p);
      if (_draft.units.text.isEmpty && p.unitsPerBox > 0) _draft.units.text = fmtUnits(p.unitsPerBox);
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref.read(boxRepoProvider).insert(boxFromDraft(_draft, widget.productId));
    ref.read(actionsProvider).changed();
    if (!mounted) return;
    showMessage(context, 'Caja de ${_product?.name ?? 'medicamento'} registrada');
    context.pop();
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    final profiles = ref.watch(profilesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva caja')),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Plate(
                    child: Row(
                      children: [
                        Icon(Icons.verified_rounded, color: context.sign.onPlate, size: 30),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productTitle(p),
                                style: context.text.titleLarge!.copyWith(color: context.sign.onPlate),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.gtin == null
                                    ? 'Ya está en tu catálogo'
                                    : 'Reconocido por su código · datos precargados',
                                style: context.text.bodyMedium!.copyWith(color: context.sign.onPlateSoft),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  BoxFields(draft: _draft, profiles: profiles, unitLabel: p.unit == 'ml' ? 'ml' : 'pzas'),
                  const SizedBox(height: 28),
                  FilledButton(onPressed: _saving ? null : _save, child: const Text('Guardar caja')),
                ],
              ),
            ),
    );
  }
}
