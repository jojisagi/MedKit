import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import 'theme.dart';

// ── Formato ────────────────────────────────────────────────────────────────

final _time = DateFormat('HH:mm');
String fmtTime(DateTime d) => _time.format(d);
String fmtDate(DateTime d) => DateFormat("d 'de' MMMM 'de' y", 'es_MX').format(d);
String fmtDateShort(DateTime d) => DateFormat("d MMM yyyy", 'es_MX').format(d).replaceAll('.', '');
String fmtDay(DateTime d) {
  final s = DateFormat("EEEE d 'de' MMMM", 'es_MX').format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String fmtUnits(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
}

String unitWord(Product p, double v) {
  if (p.unit == 'ml') return 'ml';
  return switch (p.form) {
    'cápsula' => v == 1 ? 'cápsula' : 'cápsulas',
    'tableta' => v == 1 ? 'tableta' : 'tabletas',
    'gotas' => v == 1 ? 'gota' : 'gotas',
    _ => v == 1 ? 'pieza' : 'piezas',
  };
}

String doseLabel(Product p, double dose) => '${fmtUnits(dose)} ${unitWord(p, dose)}';

String productTitle(Product p) => p.strength == null || p.strength!.isEmpty ? p.name : '${p.name} ${p.strength}';

/// "en 25 min", "hace 2 h", "ahora".
String relative(DateTime target, DateTime now) {
  final diff = target.difference(now);
  final mins = diff.inMinutes;
  if (mins.abs() < 1) return 'ahora';
  String span(int m) {
    final a = m.abs();
    if (a < 60) return '$a min';
    final h = a ~/ 60, r = a % 60;
    return r == 0 ? '$h h' : '$h h $r min';
  }

  return mins > 0 ? 'en ${span(mins)}' : 'hace ${span(mins)}';
}

String daysUntilLabel(DateTime expires, DateTime today) {
  final d = DateTime(expires.year, expires.month, expires.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (d < 0) return 'Caducó hace ${-d} ${-d == 1 ? 'día' : 'días'}';
  if (d == 0) return 'Caduca hoy';
  if (d == 1) return 'Caduca mañana';
  return 'Caduca en $d días';
}

// ── Estados ────────────────────────────────────────────────────────────────

class StatusStyle {
  final String label;
  final IconData icon;
  final Color color;
  const StatusStyle(this.label, this.icon, this.color);
}

StatusStyle statusStyle(BuildContext context, DoseStatus s) {
  final t = context.sign;
  return switch (s) {
    DoseStatus.onTime => StatusStyle('A tiempo', Icons.check_rounded, zoneOn(context, Palette.ok)),
    DoseStatus.late => StatusStyle('Tardía', Icons.schedule_rounded, t.caution),
    DoseStatus.missed => StatusStyle('Omitida', Icons.close_rounded, t.danger),
    DoseStatus.pending => StatusStyle('Pendiente', Icons.radio_button_unchecked_rounded, t.inkSoft),
  };
}

/// Ícono + texto: el estado nunca depende solo del color.
class StatusLabel extends StatelessWidget {
  final DoseStatus status;
  final String? suffix;
  const StatusLabel(this.status, {super.key, this.suffix});

  @override
  Widget build(BuildContext context) {
    final s = statusStyle(context, status);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(s.icon, size: 18, color: s.color),
      const SizedBox(width: 4),
      Text(suffix == null ? s.label : '${s.label} · $suffix',
          style: numerals(context.text.labelMedium!.copyWith(color: s.color))),
    ]);
  }
}

// ── Perfil ─────────────────────────────────────────────────────────────────

/// Franja de color + nombre, como el rótulo de una línea en el piso.
class ProfileTag extends StatelessWidget {
  final Profile profile;
  final bool large;
  const ProfileTag(this.profile, {super.key, this.large = false});

  @override
  Widget build(BuildContext context) {
    final c = zoneOn(context, Color(profile.color));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: large ? 22 : 14,
        height: large ? 8 : 6,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
      ),
      SizedBox(width: large ? 10 : 8),
      Flexible(
        child: Text(profile.name,
            overflow: TextOverflow.ellipsis,
            style: (large ? context.text.titleLarge : context.text.labelLarge)!.copyWith(color: c)),
      ),
    ]);
  }
}

class ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double size;
  const ProfileAvatar(this.profile, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = Color(profile.color);
    final initial = profile.name.trim().isEmpty ? '?' : profile.name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Text(initial,
          style: TextStyle(
              fontFamily: 'Atkinson',
              fontSize: size * 0.46,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontVariations: const [FontVariation('wght', 700)])),
    );
  }
}

// ── Superficies ────────────────────────────────────────────────────────────

/// Placa de señalética: azul marino, texto blanco.
class Plate extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? radius;
  const Plate({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: context.sign.plate,
          borderRadius: radius ?? BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x2914213D), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: DefaultTextStyle.merge(style: TextStyle(color: context.sign.onPlate), child: child),
      );
}

/// Panel blanco sobre el muro: agrupa sin anidar tarjetas.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: context.sign.panel,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.sign.rule),
            ),
            child: child,
          ),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  const SectionTitle(this.title, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(20, 28, 12, 10)});

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(children: [
          Expanded(child: Text(title, style: context.text.titleLarge)),
          if (trailing != null) trailing!,
        ]),
      );
}

enum NoticeTone { info, caution, danger }

/// Aviso con fondo tintado e ícono. Sin franjas laterales.
class Notice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final NoticeTone tone;
  final Widget? action;
  final VoidCallback? onTap;
  const Notice({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.tone = NoticeTone.info,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.sign;
    final (bg, fg) = switch (tone) {
      NoticeTone.info => (Theme.of(context).colorScheme.primaryContainer, t.ink),
      NoticeTone.caution => (t.cautionWash, t.caution),
      NoticeTone.danger => (t.dangerWash, t.danger),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: fg, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.text.titleSmall!.copyWith(color: tone == NoticeTone.info ? t.ink : fg)),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(body!, style: context.text.bodySmall!.copyWith(color: t.ink.withValues(alpha: 0.78))),
                ],
                if (action != null) ...[const SizedBox(height: 8), action!],
              ]),
            ),
            if (onTap != null && action == null) Icon(Icons.chevron_right_rounded, color: fg),
          ]),
        ),
      ),
    );
  }
}

/// Estado vacío con pictograma de señalética y una acción clara.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.actions = const []});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: context.sign.plate, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: context.sign.onPlate, size: 34),
          ),
          const SizedBox(height: 20),
          Text(title, style: context.text.headlineSmall),
          const SizedBox(height: 8),
          Text(body, style: context.text.bodyLarge!.copyWith(color: context.sign.inkSoft)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 12, children: actions),
          ],
        ]),
      );
}

/// Fila "etiqueta / valor" con cifras tabulares.
class FactRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const FactRow(this.label, this.value, {super.key, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: context.text.bodyMedium)),
          Text(value, style: numerals(context.text.titleSmall!.copyWith(color: valueColor))),
        ]),
      );
}

void showMessage(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));
}
