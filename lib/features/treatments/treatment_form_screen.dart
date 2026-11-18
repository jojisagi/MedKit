import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/dose_rules.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class TreatmentFormScreen extends ConsumerStatefulWidget {
  final int? profileId;
  final int? productId;
  const TreatmentFormScreen({super.key, this.profileId, this.productId});

  @override
  ConsumerState<TreatmentFormScreen> createState() => _TreatmentFormScreenState();
}

class _TreatmentFormScreenState extends ConsumerState<TreatmentFormScreen> {
  final _form = GlobalKey<FormState>();
  late int? _profileId = widget.profileId;
  late int? _productId = widget.productId;
  double _dose = 1;
  final _doseMl = TextEditingController(text: '5');
  ScheduleType _type = ScheduleType.interval;
  int _hours = 8;
  final List<(int, int)> _times = [(8, 0), (20, 0)];
  late DateTime _start = _roundUp(DateTime.now());
  int? _days; // null = sin fecha de fin
  int _tolerance = 10;
  int _missAfter = 60;
  final _notes = TextEditingController();
  bool _saving = false;

  static DateTime _roundUp(DateTime d) {
    final m = (d.minute / 5).ceil() * 5;
    return DateTime(d.year, d.month, d.day, d.hour).add(Duration(minutes: m));
  }

  @override
  void dispose() {
    _doseMl.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha de inicio',
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
      helpText: 'Primera toma',
    );
    if (t == null) return;
    setState(() => _start = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _addTime() async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 14, minute: 0));
    if (t == null) return;
    setState(() {
      if (!_times.contains((t.hour, t.minute))) _times.add((t.hour, t.minute));
      _times.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    });
  }

  Future<void> _save(Product product) async {
    if (!_form.currentState!.validate()) return;
    if (_profileId == null) return showMessage(context, 'Elige para quién es el tratamiento');
    if (_type == ScheduleType.fixed && _times.isEmpty) return showMessage(context, 'Agrega al menos un horario');
    if (_missAfter <= _tolerance) {
      return showMessage(context, 'El límite para omitir debe ser mayor que la tolerancia');
    }
    final dose = product.unit == 'ml' ? double.parse(_doseMl.text.replaceAll(',', '.')) : _dose;
    setState(() => _saving = true);
    final startsAt = _type == ScheduleType.fixed ? DateTime(_start.year, _start.month, _start.day) : _start;
    final t = Treatment(
      profileId: _profileId!,
      productId: product.id!,
      dose: dose,
      scheduleType: _type,
      intervalHours: _type == ScheduleType.interval ? _hours : null,
      fixedTimes: _type == ScheduleType.fixed ? formatFixedTimes(_times) : null,
      startsAt: _type == ScheduleType.fixed && _isToday(startsAt)
          ? DateTime.now().subtract(const Duration(minutes: 1))
          : startsAt,
      endsAt: _days == null ? null : DateTime(_start.year, _start.month, _start.day + _days!, 23, 59),
      toleranceMin: _tolerance,
      missAfterMin: _missAfter,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    await ref.read(treatmentRepoProvider).insert(t);
    await _askNotificationsOnce();
    await ref.read(actionsProvider).refreshSchedule();
    if (!mounted) return;
    showMessage(context, 'Tratamiento programado');
    context.pop();
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  /// Explicación previa antes de pedir el permiso (SPEC §8).
  Future<void> _askNotificationsOnce() async {
    final n = ref.read(notificationsProvider);
    if (await n.notificationsEnabled() || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined, size: 36),
        title: const Text('¿Te avisamos a la hora de cada toma?'),
        content: const Text(
          'Medkit te mandará una notificación a la hora exacta y otra si la toma sigue '
          'pendiente. Las notificaciones se generan en tu teléfono; nada sale de él.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Ahora no')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Sí, avisarme')),
        ],
      ),
    );
    if (ok == true) await n.requestNotificationPermission();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider).value ?? const <Profile>[];
    final products = ref.watch(inventoryProvider).value?.map((s) => s.product).toList() ?? const <Product>[];
    final product = products.where((p) => p.id == _productId).firstOrNull;
    final t = context.sign;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo tratamiento')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text('¿Para quién?', style: context.text.titleMedium),
            const SizedBox(height: 10),
            if (profiles.isEmpty)
              OutlinedButton.icon(
                onPressed: () => context.push('/profiles/new'),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Agregar persona'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in profiles)
                    ChoiceChip(
                      avatar: CircleAvatar(backgroundColor: Color(p.color), radius: 9),
                      label: Text(p.name),
                      selected: _profileId == p.id,
                      onSelected: (_) => setState(() => _profileId = p.id),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            Text('Medicamento', style: context.text.titleMedium),
            const SizedBox(height: 10),
            if (products.isEmpty)
              Notice(
                icon: Icons.medication_outlined,
                title: 'Primero registra el medicamento',
                body: 'Escanea su caja en Botiquín y vuelve aquí.',
                action: OutlinedButton(
                  onPressed: () => context.push('/inventory/product'),
                  child: const Text('Registrar medicamento'),
                ),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _productId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Elige de tu botiquín'),
                items: [for (final p in products) DropdownMenuItem(value: p.id, child: Text(productTitle(p)))],
                validator: (v) => v == null ? 'Elige un medicamento' : null,
                onChanged: (v) => setState(() => _productId = v),
              ),
            if (product != null) ...[
              const SizedBox(height: 24),
              Text('Dosis por toma', style: context.text.titleMedium),
              const SizedBox(height: 10),
              if (product.unit == 'ml')
                TextFormField(
                  controller: _doseMl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  style: numerals(context.text.titleLarge!),
                  decoration: const InputDecoration(suffixText: 'ml'),
                  validator: (v) {
                    final d = double.tryParse((v ?? '').replaceAll(',', '.'));
                    return d == null || d <= 0 ? 'La dosis debe ser mayor que 0' : null;
                  },
                )
              else
                _DoseStepper(
                  value: _dose,
                  label: unitWord(product, _dose),
                  onChanged: (v) => setState(() => _dose = v),
                ),
            ],
            const SizedBox(height: 28),
            Text('Horario', style: context.text.titleMedium),
            const SizedBox(height: 10),
            SegmentedButton<ScheduleType>(
              segments: const [
                ButtonSegment(
                  value: ScheduleType.interval,
                  label: Text('Cada N horas'),
                  icon: Icon(Icons.repeat_rounded),
                ),
                ButtonSegment(
                  value: ScheduleType.fixed,
                  label: Text('Horas fijas'),
                  icon: Icon(Icons.schedule_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            if (_type == ScheduleType.interval) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in const [4, 6, 8, 12, 24])
                    ChoiceChip(
                      label: Text('Cada $h h'),
                      selected: _hours == h,
                      onSelected: (_) => setState(() => _hours = h),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _PickerRow(
                icon: Icons.play_circle_outline_rounded,
                label: 'Primera toma',
                value: '${fmtDateShort(_start)} · ${fmtTime(_start)}',
                onTap: _pickStart,
              ),
            ] else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final time in _times)
                    InputChip(
                      label: Text(formatFixedTimes([time]), style: numerals(context.text.labelLarge!)),
                      onDeleted: () => setState(() => _times.remove(time)),
                      deleteButtonTooltipMessage: 'Quitar horario',
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded),
                    label: const Text('Agregar hora'),
                    onPressed: _addTime,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _PickerRow(
                icon: Icons.play_circle_outline_rounded,
                label: 'Empieza',
                value: _isToday(_start) ? 'Hoy' : fmtDateShort(_start),
                onTap: _pickStart,
              ),
            ],
            const SizedBox(height: 24),
            Text('Duración', style: context.text.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Sin fecha de fin'),
                  selected: _days == null,
                  onSelected: (_) => setState(() => _days = null),
                ),
                for (final d in const [3, 5, 7, 10, 14, 30])
                  ChoiceChip(
                    label: Text('$d días'),
                    selected: _days == d,
                    onSelected: (_) => setState(() => _days = d),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Tolerancia y omisión', style: context.text.titleSmall),
                subtitle: Text(
                  'A tiempo hasta $_tolerance min · omitida después de $_missAfter min',
                  style: numerals(context.text.bodySmall!),
                ),
                children: [
                  _MinutesSlider(
                    label: 'Se considera a tiempo hasta',
                    value: _tolerance,
                    options: const [1, 5, 10, 15, 20, 30],
                    onChanged: (v) => setState(() => _tolerance = v),
                  ),
                  _MinutesSlider(
                    label: 'Se marca como omitida después de',
                    value: _missAfter,
                    options: const [3, 30, 45, 60, 90, 120],
                    onChanged: (v) => setState(() => _missAfter = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Indicaciones (opcional)', hintText: 'Ej. Después de comer'),
            ),
            const SizedBox(height: 12),
            Text(
              'Captura las indicaciones tal como las dio el médico. Medkit no recomienda dosis.',
              style: context.text.bodySmall!.copyWith(color: t.inkSoft),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || product == null ? null : () => _save(product),
              child: const Text('Programar tratamiento'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dosis en pasos de media pieza (0.5 permitido).
class _DoseStepper extends StatelessWidget {
  final double value;
  final String label;
  final ValueChanged<double> onChanged;
  const _DoseStepper({required this.value, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Media menos',
          onPressed: value > 0.5 ? () => onChanged(value - 0.5) : null,
          icon: const Icon(Icons.remove_rounded),
          style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
        ),
        Expanded(
          child: Column(
            children: [
              Text(fmtUnits(value), style: numerals(context.text.headlineLarge!)),
              Text(label, style: context.text.bodyMedium),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Media más',
          onPressed: value < 20 ? () => onChanged(value + 0.5) : null,
          icon: const Icon(Icons.add_rounded),
          style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
        ),
      ],
    ),
  );
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _PickerRow({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => Panel(
    onTap: onTap,
    child: Row(
      children: [
        Icon(icon, color: context.sign.inkSoft),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: context.text.bodyLarge)),
        Text(value, style: numerals(context.text.titleSmall!)),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right_rounded, color: context.sign.inkFaint),
      ],
    ),
  );
}

class _MinutesSlider extends StatelessWidget {
  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;
  const _MinutesSlider({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              ChoiceChip(label: Text('$o min'), selected: value == o, onSelected: (_) => onChanged(o)),
          ],
        ),
      ],
    ),
  );
}
