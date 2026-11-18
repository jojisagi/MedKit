import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/profile_colors.dart';
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
  int _color = profilePalette.first.argb;

  /// Colores de las demás personas: no se pueden repetir.
  List<int> _usedByOthers = const [];

  @override
  void initState() {
    super.initState();
    ref.read(profileRepoProvider).all().then((all) {
      if (!mounted) return;
      final me = widget.profileId == null ? null : all.where((p) => p.id == widget.profileId).firstOrNull;
      setState(() {
        _usedByOthers = [
          for (final p in all)
            if (p.id != widget.profileId) p.color,
        ];
        if (me != null) {
          _editing = me;
          _name.text = me.name;
          _color = me.color;
        } else {
          _color = suggestProfileColor(_usedByOthers);
        }
      });
    });
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
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
            Text(
              'Identifica su línea de tomas, sus cajas y sus notificaciones. '
              'Los colores tachados ya los usa otra persona.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 4,
              runSpacing: 12,
              children: [
                for (final c in profilePalette)
                  _Swatch(
                    color: Color(c.argb),
                    name: c.name,
                    selected: _color == c.argb,
                    available: isProfileColorAvailable(c.argb, _usedByOthers),
                    onTap: () => setState(() => _color = c.argb),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Panel(
              child: Row(
                children: [
                  ProfileAvatar(preview, size: 52),
                  const SizedBox(width: 16),
                  Expanded(child: ProfileTag(preview, large: true)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(onPressed: _save, child: Text(_editing == null ? 'Guardar persona' : 'Guardar cambios')),
          ],
        ),
      ),
    );
  }
}

/// Muestra de color con nombre. Ocupada = tachada y deshabilitada.
class _Swatch extends StatelessWidget {
  final Color color;
  final String name;
  final bool selected;
  final bool available;
  final VoidCallback onTap;
  const _Swatch({
    required this.color,
    required this.name,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.sign;
    return Semantics(
      button: true,
      selected: selected,
      enabled: available,
      label: available ? name : '$name, ya lo usa otra persona',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: available ? onTap : null,
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: available ? color : color.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: selected ? t.ink : Colors.transparent, width: 3),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 30)
                    : (available ? null : Icon(Icons.block_rounded, color: t.inkSoft, size: 26)),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: context.text.labelSmall!.copyWith(color: available ? t.inkSoft : t.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
