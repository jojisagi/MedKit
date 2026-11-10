import 'package:flutter/material.dart';

import '../../data/dose_repository.dart';
import '../../domain/dose_rules.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Firma visual: la línea de color de un integrante, con una parada por toma.
/// La distancia entre paradas crece con el tiempo entre tomas; la toma actual
/// crece y late, el resto de lo pendiente baja de tono.
class ProfileLine extends StatelessWidget {
  final Profile profile;
  final List<DoseDetail> doses;
  final DateTime now;
  final int? focusDoseId;

  /// La toma que ya muestra la placa de Inicio: su parada no repite los botones.
  final int? plateDoseId;
  final void Function(DoseDetail) onOpen;
  final void Function(DoseDetail) onScan;
  final void Function(DoseDetail) onManual;

  const ProfileLine({
    super.key,
    required this.profile,
    required this.doses,
    required this.now,
    required this.focusDoseId,
    this.plateDoseId,
    required this.onOpen,
    required this.onScan,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    final zone = zoneOn(context, Color(profile.color));
    final taken = doses.where((d) => d.dose.isConfirmed).length;
    // Índice de la primera toma no cerrada: lo anterior ya es "camino recorrido".
    final firstOpen = doses.indexWhere((d) => d.dose.status == DoseStatus.pending);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Expanded(child: ProfileTag(profile, large: true)),
              Text(
                '$taken de ${doses.length}',
                style: numerals(context.text.titleSmall!.copyWith(color: context.sign.inkSoft)),
              ),
              const SizedBox(width: 4),
              Text('tomadas', style: context.text.bodySmall),
            ],
          ),
        ),
        for (var i = 0; i < doses.length; i++)
          _Stop(
            detail: doses[i],
            zone: zone,
            now: now,
            isFirst: i == 0,
            isLast: i == doses.length - 1,
            travelledIn: firstOpen == -1 || i <= firstOpen,
            travelledOut: firstOpen == -1 || i < firstOpen,
            gapAfter: i == doses.length - 1
                ? Duration.zero
                : doses[i + 1].dose.scheduledAt.difference(doses[i].dose.scheduledAt),
            focus: doses[i].dose.id == focusDoseId,
            showActions: doses[i].dose.id != plateDoseId,
            dimmed:
                focusDoseId != null && doses[i].dose.status == DoseStatus.pending && doses[i].dose.id != focusDoseId,
            onOpen: () => onOpen(doses[i]),
            onScan: () => onScan(doses[i]),
            onManual: () => onManual(doses[i]),
          ),
      ],
    );
  }
}

class _Stop extends StatelessWidget {
  final DoseDetail detail;
  final Color zone;
  final DateTime now;
  final bool isFirst, isLast, travelledIn, travelledOut, focus, dimmed, showActions;
  final Duration gapAfter;
  final VoidCallback onOpen, onScan, onManual;

  const _Stop({
    required this.detail,
    required this.zone,
    required this.now,
    required this.isFirst,
    required this.isLast,
    required this.travelledIn,
    required this.travelledOut,
    required this.gapAfter,
    required this.focus,
    required this.dimmed,
    this.showActions = true,
    required this.onOpen,
    required this.onScan,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    final d = detail.dose;
    final p = detail.product;
    final t = context.sign;
    // Espacio proporcional al tiempo: 12 dp base + 5 dp por hora, tope 56.
    final gap = isLast ? 8.0 : (12 + gapAfter.inMinutes / 60 * 5).clamp(12.0, 56.0);
    final confirmable = d.status == DoseStatus.pending && canConfirm(d.scheduledAt, now, detail.treatment.missAfterMin);
    final faded = zone.withValues(alpha: 0.28);

    String? suffix;
    if (d.confirmedAt != null) suffix = fmtTime(d.confirmedAt!);
    if (d.status == DoseStatus.pending) suffix = relative(d.scheduledAt, now);

    final content = Padding(
      padding: EdgeInsets.only(bottom: gap, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(productTitle(p), style: focus ? context.text.titleLarge : context.text.titleMedium),
          const SizedBox(height: 2),
          Text(doseLabel(p, detail.treatment.dose), style: context.text.bodyMedium),
          const SizedBox(height: 6),
          StatusLabel(d.status, suffix: suffix),
          if (focus && confirmable && showActions) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Confirmar escaneando'),
                ),
                OutlinedButton(onPressed: onManual, child: const Text('Ya la tomó')),
              ],
            ),
          ] else if (focus && d.status == DoseStatus.pending && !confirmable) ...[
            const SizedBox(height: 8),
            Text(
              'Podrás confirmarla desde las ${fmtTime(d.scheduledAt.subtract(const Duration(minutes: earlyConfirmMin)))}',
              style: numerals(context.text.bodySmall!),
            ),
          ],
        ],
      ),
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      opacity: dimmed ? 0.55 : 1,
      child: InkWell(
        onTap: onOpen,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Columna de hora: cifras tabulares alineadas a la derecha.
              SizedBox(
                width: 72,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: Text(
                    fmtTime(d.scheduledAt),
                    textAlign: TextAlign.right,
                    style: numerals(
                      (focus ? context.text.titleLarge : context.text.titleMedium)!.copyWith(
                        color: d.status == DoseStatus.pending ? t.ink : t.inkSoft,
                      ),
                    ),
                  ),
                ),
              ),
              // La línea.
              SizedBox(
                width: 44,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned.fill(
                      child: Column(
                        children: [
                          Container(
                            width: 6,
                            height: 14,
                            color: isFirst ? Colors.transparent : (travelledIn ? zone : faded),
                          ),
                          Expanded(
                            child: Container(
                              width: 6,
                              color: isLast ? Colors.transparent : (travelledOut ? zone : faded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: focus ? 0 : 3),
                      child: _Node(status: d.status, zone: zone, focus: focus),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  final DoseStatus status;
  final Color zone;
  final bool focus;
  const _Node({required this.status, required this.zone, required this.focus});

  @override
  Widget build(BuildContext context) {
    final t = context.sign;
    final size = focus ? 34.0 : 26.0;
    final Widget node = switch (status) {
      DoseStatus.onTime => _disc(size, zone, Icons.check_rounded, Colors.white),
      DoseStatus.late => _disc(size, t.caution, Icons.check_rounded, Colors.white),
      DoseStatus.missed => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: t.panel,
          shape: BoxShape.circle,
          border: Border.all(color: t.danger, width: 3),
        ),
        child: Icon(Icons.close_rounded, size: size * 0.6, color: t.danger),
      ),
      DoseStatus.pending =>
        focus
            ? _PulseRing(size: size, color: zone, ground: t.wall)
            : Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: t.wall,
                  shape: BoxShape.circle,
                  border: Border.all(color: zone, width: 4),
                ),
              ),
    };
    // La parada "se llena" al confirmarse.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: KeyedSubtree(key: ValueKey('${status.name}$focus'), child: node),
    );
  }

  Widget _disc(double size, Color bg, IconData icon, Color fg) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    child: Icon(icon, size: size * 0.62, color: fg),
  );
}

/// La parada actual: anillo grueso con un punto que late. Respeta "reducir movimiento".
class _PulseRing extends StatefulWidget {
  final double size;
  final Color color;
  final Color ground;
  const _PulseRing({required this.size, required this.color, required this.ground});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = Curves.easeOutCubic.transform(_c.value);
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Halo que se expande y se desvanece.
              Container(
                width: s + 14 * v,
                height: s + 14 * v,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.22 * (1 - v)),
                ),
              ),
              Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  color: widget.ground,
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.color, width: 5),
                ),
              ),
              Container(
                width: s * 0.32,
                height: s * 0.32,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
            ],
          );
        },
      ),
    );
  }
}
