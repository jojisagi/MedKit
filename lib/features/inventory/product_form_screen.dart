import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/box_repository.dart';
import '../../data/product_repository.dart';
import '../../data/providers.dart';
import '../../domain/barcode.dart';
import '../../domain/models.dart';
import '../../services/scanner_screen.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'box_fields.dart';
import 'scan_flows.dart';

/// Alta de producto + su primera caja (B2), o edición de un producto existente.
class ProductFormScreen extends ConsumerStatefulWidget {
  final int? productId;
  final String? gtin;
  final String? lot;
  final String? expires;
  const ProductFormScreen({super.key, this.productId, this.gtin, this.lot, this.expires});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _ingredient = TextEditingController();
  final _strength = TextEditingController();
  final _perBox = TextEditingController();
  String _presentation = 'tableta';
  String _unit = 'pza';
  String? _gtin;
  Product? _editing;
  late final BoxDraft _box =
      BoxDraft(expiresOn: parseIsoDate(widget.expires), lot: widget.lot);
  bool _saving = false;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    _gtin = widget.gtin == null ? null : normalizeGtin(widget.gtin!);
    if (_isEdit) _load();
    _perBox.addListener(() {
      // Copia el contenido por caja a "unidades en la caja" mientras el usuario no lo cambie.
      if (!_isEdit && (_box.units.text.isEmpty || _box.units.text == _lastAutoUnits)) {
        _box.units.text = _perBox.text;
        _lastAutoUnits = _perBox.text;
      }
    });
  }

  String? _lastAutoUnits;

  Future<void> _load() async {
    final p = await ref.read(productRepoProvider).get(widget.productId!);
    if (p == null || !mounted) return;
    setState(() {
      _editing = p;
      _gtin = p.gtin;
      _name.text = p.name;
      _ingredient.text = p.activeIngredient ?? '';
      _strength.text = p.strength ?? '';
      _perBox.text = p.unitsPerBox > 0 ? fmtUnits(p.unitsPerBox) : '';
      _presentation = productForms.contains(p.form) ? p.form : 'otro';
      _unit = p.unit;
    });
  }

  Future<void> _scanCode() async {
    final r = await scanBarcode(context, title: 'Código de la caja');
    if (r == null || !mounted) return;
    final existing = await ref.read(productRepoProvider).findByGtin(r.gtin14);
    if (!mounted) return;
    if (existing != null && existing.id != widget.productId) {
      // Ya existe: el catálogo lo conoce, solo falta la caja.
      context.pushReplacement('/inventory/box?productId=${existing.id}${gs1Query(r)}');
      return;
    }
    setState(() {
      _gtin = r.gtin14;
      if (r.gs1?.expiresOn != null) _box.setExpires(r.gs1!.expiresOn!);
      if (r.gs1?.lot != null) _box.lot.text = r.gs1!.lot!;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final p = Product(
      id: _editing?.id,
      gtin: _gtin,
      name: _name.text.trim(),
      activeIngredient: _ingredient.text.trim().isEmpty ? null : _ingredient.text.trim(),
      strength: _strength.text.trim().isEmpty ? null : _strength.text.trim(),
      form: _presentation,
      unit: _unit,
      unitsPerBox: double.tryParse(_perBox.text.replaceAll(',', '.')) ?? 0,
    );
    try {
      final db = ref.read(databaseProvider);
      int? newId;
      await db.transaction((txn) async {
        final id = await ProductRepository(txn).upsert(p);
        newId = id;
        if (!_isEdit) await BoxRepository(txn).insert(boxFromDraft(_box, id));
      });
      ref.read(actionsProvider).changed();
      if (!mounted) return;
      showMessage(context, _isEdit ? 'Medicamento actualizado' : '${p.name} agregado a tu botiquín');
      if (_isEdit) {
        context.pop();
      } else {
        context.pushReplacement('/inventory/product/$newId');
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) showMessage(context, 'Ese código ya pertenece a otro medicamento.');
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _ingredient, _strength, _perBox]) {
      c.dispose();
    }
    _box.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider).value ?? const [];
    final t = context.sign;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Editar medicamento' : 'Nuevo medicamento')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          // Código de barras: fijo si vino del escáner.
          Panel(
            child: Row(children: [
              Icon(_gtin == null ? Icons.qr_code_2_rounded : Icons.verified_outlined,
                  color: _gtin == null ? t.inkSoft : zoneOn(context, Palette.ok), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_gtin == null ? 'Sin código de barras' : 'Código de barras', style: context.text.titleSmall),
                  Text(_gtin ?? 'Escanéalo para reconocer esta caja la próxima vez.',
                      style: _gtin == null ? context.text.bodySmall : numerals(context.text.bodyMedium!)),
                ]),
              ),
              if (widget.gtin == null)
                TextButton(onPressed: _scanCode, child: Text(_gtin == null ? 'Escanear' : 'Cambiar')),
            ]),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre comercial', hintText: 'Ej. Ibuprofeno'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'El nombre es obligatorio' : null,
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _ingredient,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Sustancia activa'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 132,
              child: TextFormField(
                controller: _strength,
                decoration: const InputDecoration(labelText: 'Concentración', hintText: '500 mg'),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Text('Presentación', style: context.text.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in productForms)
              ChoiceChip(
                label: Text(f[0].toUpperCase() + f.substring(1)),
                selected: _presentation == f,
                onSelected: (_) => setState(() {
                  _presentation = f;
                  _unit = (f == 'jarabe' || f == 'suspensión') ? 'ml' : 'pza';
                }),
              ),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pza', label: Text('Piezas')),
                  ButtonSegment(value: 'ml', label: Text('Mililitros')),
                ],
                selected: {_unit},
                onSelectionChanged: (s) => setState(() => _unit = s.first),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          TextFormField(
            controller: _perBox,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: numerals(context.text.bodyLarge!),
            decoration: InputDecoration(labelText: 'Contenido de una caja nueva', suffixText: _unit == 'ml' ? 'ml' : 'pzas'),
          ),
          if (!_isEdit) ...[
            const SectionTitle('Esta caja', padding: EdgeInsets.fromLTRB(0, 32, 0, 12)),
            BoxFields(draft: _box, profiles: profiles, unitLabel: _unit == 'ml' ? 'ml' : 'pzas'),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_isEdit ? 'Guardar cambios' : 'Guardar medicamento y caja'),
          ),
        ]),
      ),
    );
  }
}
