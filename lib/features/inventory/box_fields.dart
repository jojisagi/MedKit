import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/inventory_rules.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Estado editable de una caja (caducidad, unidades, dueño, lote).
class BoxDraft extends ChangeNotifier {
  DateTime? expiresOn;
  int? profileId; // null = compartida
  final units = TextEditingController();
  final lot = TextEditingController();

  BoxDraft({this.expiresOn, String? lot, double? units, this.profileId}) {
    if (lot != null) this.lot.text = lot;
    if (units != null && units > 0) this.units.text = fmtUnits(units);
  }

  double? get unitsValue => double.tryParse(units.text.replaceAll(',', '.'));

  void setExpires(DateTime d) {
    expiresOn = d;
    notifyListeners();
  }

  void setOwner(int? id) {
    profileId = id;
    notifyListeners();
  }

  @override
  void dispose() {
    units.dispose();
    lot.dispose();
    super.dispose();
  }
}

DateTime? parseIsoDate(String? s) => s == null ? null : DateTime.tryParse(s);

class BoxFields extends StatelessWidget {
  final BoxDraft draft;
  final List<Profile> profiles;
  final String unitLabel;
  const BoxFields({super.key, required this.draft, required this.profiles, required this.unitLabel});

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: draft.expiresOn ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 10),
      helpText: 'Fecha de caducidad',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (d != null) draft.setExpires(d);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: draft,
        builder: (context, _) {
          final t = context.sign;
          final today = dateOnly(DateTime.now());
          final expired = draft.expiresOn != null && dateOnly(draft.expiresOn!).isBefore(today);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FormField<DateTime>(
              validator: (_) => draft.expiresOn == null ? 'Indica la fecha de caducidad' : null,
              builder: (state) => InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pickDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Caducidad',
                    errorText: state.errorText,
                    suffixIcon: const Icon(Icons.event_rounded),
                    helperText: expired ? null : 'Viene impresa en la caja como CAD o EXP.',
                  ),
                  child: Text(
                    draft.expiresOn == null ? 'Elegir fecha' : fmtDate(draft.expiresOn!),
                    style: numerals(context.text.bodyLarge!.copyWith(color: draft.expiresOn == null ? t.inkFaint : t.ink)),
                  ),
                ),
              ),
            ),
            if (expired) ...[
              const SizedBox(height: 8),
              const Notice(
                tone: NoticeTone.danger,
                icon: Icons.block_rounded,
                title: 'Esta caja ya caducó',
                body: 'Puedes registrarla, pero no se usará para descontar tomas.',
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: draft.units,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              style: numerals(context.text.bodyLarge!),
              decoration: InputDecoration(labelText: 'Unidades en la caja', suffixText: unitLabel),
              validator: (_) {
                final v = draft.unitsValue;
                if (v == null || v <= 0) return 'Escribe cuántas unidades tiene';
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text('¿De quién es?', style: context.text.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                avatar: const Icon(Icons.groups_2_outlined, size: 20),
                label: const Text('Compartida'),
                selected: draft.profileId == null,
                onSelected: (_) => draft.setOwner(null),
              ),
              for (final p in profiles)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: Color(p.color), radius: 8),
                  label: Text(p.name),
                  selected: draft.profileId == p.id,
                  onSelected: (_) => draft.setOwner(p.id),
                ),
            ]),
            const SizedBox(height: 6),
            Text('Las tomas de cada persona usan primero sus cajas y luego las compartidas.',
                style: context.text.bodySmall),
            const SizedBox(height: 16),
            TextFormField(
              controller: draft.lot,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Lote (opcional)'),
            ),
          ]);
        },
      );
}

Box boxFromDraft(BoxDraft d, int productId) {
  final u = d.unitsValue!;
  return Box(
    productId: productId,
    profileId: d.profileId,
    unitsInitial: u,
    unitsLeft: u,
    expiresOn: d.expiresOn!,
    lot: d.lot.text.trim().isEmpty ? null : d.lot.text.trim(),
    addedAt: DateTime.now(),
  );
}
