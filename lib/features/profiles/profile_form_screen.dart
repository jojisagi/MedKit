import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class ProfileFormScreen extends ConsumerStatefulWidget {
  final int? profileId;
  const ProfileFormScreen({super.key, this.profileId});

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  Profile? _editing;
  int _color = Palette.zones.first.toARGB32();

  @override
  void initState() {
    super.initState();
    if (widget.profileId != null) {
      ref.read(profileRepoProvider).get(widget.profileId!).then((p) {
        if (p == null || !mounted) return;
        setState(() {
          _editing = p;
          _name.text = p.name;
          _color = p.color;
        });
      });
    } else {
      // Sugerir el primer color que nadie usa.
      ref.read(profileRepoProvider).all().then((all) {
        final used = all.map((p) => p.color).toSet();
        final free = Palette.zones.map((c) => c.toARGB32()).where((c) => !used.contains(c));
        if (free.isNotEmpty && mounted) setState(() => _color = free.first);
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(profileRepoProvider);
    final name = _name.text.trim();
    if (_editing == null) {
      final id = await repo.insert(Profile(name: name, color: _color, createdAt: DateTime.now()));
      ref.read(actionsProvider).changed();
      if (mounted) context.pushReplacement('/profiles/$id');
    } else {
      await repo.update(_editing!.copyWith(name: name, color: _color));
      ref.read(actionsProvider).changed();
      if (mounted) context.pop();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = Profile(name: _name.text.isEmpty ? 'Nombre' : _name.text, color: _color, createdAt: DateTime.now());
    return Scaffold(
      appBar: AppBar(title: Text(_editing == null ? 'Nueva persona' : 'Editar persona')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          TextFormField(
            controller: _name,
            autofocus: _editing == null,
            textCapitalization: TextCapitalization.words,
            style: context.text.titleLarge,
            decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Abuela Carmen'),
            onChanged: (_) => setState(() {}),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
          ),
          const SectionTitle('Su color', padding: EdgeInsets.fromLTRB(0, 28, 0, 6)),
          Text('Identifica su línea de tomas, sus cajas y sus notificaciones.', style: context.text.bodyMedium),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < Palette.zones.length; i++)
              Semantics(
                button: true,
                selected: _color == Palette.zones[i].toARGB32(),
                label: Palette.zoneNames[i],
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _color = Palette.zones[i].toARGB32()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Palette.zones[i],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _color == Palette.zones[i].toARGB32() ? context.sign.ink : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: _color == Palette.zones[i].toARGB32()
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 30)
                        : null,
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 28),
          Panel(
            child: Row(children: [
              ProfileAvatar(preview, size: 52),
              const SizedBox(width: 16),
              Expanded(child: ProfileTag(preview, large: true)),
            ]),
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: _save, child: Text(_editing == null ? 'Guardar persona' : 'Guardar cambios')),
        ]),
      ),
    );
  }
}
