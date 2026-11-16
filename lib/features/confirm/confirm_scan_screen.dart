import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/dose_repository.dart';
import '../../data/providers.dart';
import '../../domain/dose_rules.dart';
import '../../domain/inventory_rules.dart';
import '../../domain/models.dart';
import '../../services/dose_confirmation_service.dart';
import '../../services/scanner_screen.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'confirm_feedback.dart';
import 'pending_picker_sheet.dart';

sealed class _Outcome {
  const _Outcome();
}

class _Working extends _Outcome {
  const _Working();
}

class _Cancelled extends _Outcome {
  const _Cancelled();
}

class _Confirmed extends _Outcome {
  final DoseDetail detail;
  final ConfirmResult result;
  final double unitsLeft;
  const _Confirmed(this.detail, this.result, this.unitsLeft);
}

class _Message extends _Outcome {
  final IconData icon;
  final String title;
  final String body;
  final String? gtinToRegister;
  final bool danger;
  const _Message(this.icon, this.title, this.body, {this.gtinToRegister, this.danger = false});
}

/// SPEC §5. Con [doseId] verifica que la caja corresponda; sin él busca tomas confirmables.
class ConfirmScanScreen extends ConsumerStatefulWidget {
  final int? doseId;
  const ConfirmScanScreen({super.key, this.doseId});

  @override
  ConsumerState<ConfirmScanScreen> createState() => _ConfirmScanScreenState();
}

class _ConfirmScanScreenState extends ConsumerState<ConfirmScanScreen> {
  _Outcome _outcome = const _Working();
  DoseDetail? _target;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    setState(() => _outcome = const _Working());
    final doses = ref.read(doseRepoProvider);
    if (widget.doseId != null) {
      _target = await doses.detail(widget.doseId!);
      if (_target == null) {
        return _set(
          const _Message(
            Icons.help_outline_rounded,
            'Esta toma ya no existe',
            'El tratamiento pudo haberse terminado. Revisa la pantalla Hoy.',
          ),
        );
      }
      final now = DateTime.now();
      await doses.markMissed(now);
      _target = await doses.detail(widget.doseId!);
      final d = _target!;
      if (d.dose.status != DoseStatus.pending) {
        return _set(
          _Message(
            d.dose.isConfirmed ? Icons.check_circle_outline_rounded : Icons.event_busy_rounded,
            d.dose.isConfirmed ? 'Esta toma ya está registrada' : 'Esta toma ya se marcó como omitida',
            '${productTitle(d.product)} de ${d.profile.name} · ${fmtTime(d.dose.scheduledAt)}',
          ),
        );
      }
      if (!canConfirm(d.dose.scheduledAt, now, d.treatment.missAfterMin)) {
        return _set(
          _Message(
            Icons.schedule_rounded,
            'Aún es temprano',
            'Podrás confirmar esta toma desde las ${fmtTime(d.dose.scheduledAt.subtract(const Duration(minutes: earlyConfirmMin)))}.',
          ),
        );
      }
    }
    if (!mounted) return;
    final t = _target;
    final scan = await scanBarcode(
      context,
      title: t == null ? 'Escanea la caja para confirmar' : 'Escanea la caja de ${t.product.name}',
      subtitle: t == null
          ? 'Buscaremos la toma pendiente de ese medicamento.'
          : 'Toma de ${t.profile.name} · ${fmtTime(t.dose.scheduledAt)}',
    );
    if (scan == null) return _set(const _Cancelled());
    final product = await ref.read(productRepoProvider).findByGtin(scan.gtin14);

    if (t != null) {
      final kind = matchScan(scanned: product, expectedProductId: t.product.id, confirmable: [t.dose]);
      if (kind == ScanMatchKind.wrongProduct) {
        HapticFeedback.vibrate();
        if (!mounted) return;
        await _wrongBoxDialog(t.product);
        return _set(
          _Message(
            Icons.warning_amber_rounded,
            'No se registró la toma',
            'La caja escaneada no es ${t.product.name}. Busca la caja correcta y vuelve a escanear.',
            danger: true,
          ),
        );
      }
      return _confirm(t);
    }

    final confirmable = product == null
        ? <DoseDetail>[]
        : await ref.read(doseRepoProvider).confirmableWithProduct(product.id!, DateTime.now());
    switch (matchScan(scanned: product, confirmable: [for (final c in confirmable) c.dose])) {
      case ScanMatchKind.unknownProduct:
        final known = (await ref.read(catalogProvider.future)).lookup(scan.gtin14);
        return _set(
          _Message(
            Icons.inventory_2_outlined,
            known == null ? 'Este medicamento no está en tu botiquín' : '${productTitle(known)} no está en tu botiquín',
            'Regístralo para que la próxima vez se reconozca al escanearlo.',
            gtinToRegister: scan.gtin14,
          ),
        );
      case ScanMatchKind.noPending:
        return _set(
          _Message(
            Icons.event_available_rounded,
            'No hay tomas pendientes de ${product!.name} ahora',
            'Solo se puede confirmar desde 30 min antes de la hora programada.',
          ),
        );
      case ScanMatchKind.confirmOne:
        return _confirm(confirmable.single);
      case ScanMatchKind.choose:
        if (!mounted) return;
        final picked = await showPendingPicker(context, confirmable);
        if (picked == null) return _set(const _Cancelled());
        return _confirm(picked);
      case ScanMatchKind.wrongProduct:
        return; // solo ocurre con toma preseleccionada
    }
  }

  Future<void> _confirm(DoseDetail d) async {
    final r = await ref.read(actionsProvider).confirm(d.dose.id!, ConfirmMethod.scan);
    if (!r.ok) {
      if (mounted) showConfirmResult(context, r, profileName: d.profile.name);
      return _set(const _Cancelled());
    }
    HapticFeedback.mediumImpact();
    final boxes = await ref.read(boxRepoProvider).activeForProduct(d.product.id!);
    final left = unitsAvailable(boxes, profileId: d.profile.id!, today: DateTime.now());
    _set(_Confirmed(d, r, left));
  }

  void _set(_Outcome o) {
    if (!mounted) return;
    if (o is _Cancelled) {
      if (context.canPop()) context.pop();
      return;
    }
    setState(() => _outcome = o);
  }

  Future<void> _wrongBoxDialog(Product expected) => showDialog(
    context: context,
    builder: (c) {
      final t = c.sign;
      return AlertDialog(
        backgroundColor: t.danger,
        icon: const Icon(Icons.dangerous_rounded, color: Colors.white, size: 44),
        title: Text('Caja equivocada', style: c.text.headlineSmall!.copyWith(color: Colors.white)),
        content: Text(
          'Esta caja no corresponde a ${expected.name}. Revisa antes de tomarla.',
          style: c.text.bodyLarge!.copyWith(color: Colors.white),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: t.danger),
            onPressed: () => Navigator.pop(c),
            child: const Text('Entendido'),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar toma')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: switch (_outcome) {
          _Working() || _Cancelled() => const Center(child: CircularProgressIndicator()),
          _Confirmed(:final detail, :final result, :final unitsLeft) => _ConfirmedView(
            detail: detail,
            result: result,
            unitsLeft: unitsLeft,
            onAgain: _restart,
          ),
          final _Message m => _MessageView(m: m, onAgain: _restart),
        },
      ),
    );
  }

  void _restart() {
    if (widget.doseId != null && _outcome is _Confirmed) {
      context.pushReplacement('/confirm-scan');
      return;
    }
    _run();
  }
}

class _ConfirmedView extends StatelessWidget {
  final DoseDetail detail;
  final ConfirmResult result;
  final double unitsLeft;
  final VoidCallback onAgain;
  const _ConfirmedView({required this.detail, required this.result, required this.unitsLeft, required this.onAgain});

  @override
  Widget build(BuildContext context) {
    final zone = Color(detail.profile.color);
    final t = context.sign;
    final late = result.status == DoseStatus.late;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Plate(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutBack,
                builder: (_, v, child) => Transform.scale(scale: v, alignment: Alignment.centerLeft, child: child),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: late ? t.caution : zone, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Toma de ${detail.profile.name} registrada',
                style: context.text.headlineMedium!.copyWith(color: t.onPlate),
              ),
              const SizedBox(height: 6),
              Text(
                '${statusWord(result.status)[0].toUpperCase()}${statusWord(result.status).substring(1)} · '
                '${doseLabel(detail.product, detail.treatment.dose)} de ${productTitle(detail.product)}',
                style: context.text.bodyLarge!.copyWith(color: t.onPlateSoft),
              ),
              const SizedBox(height: 4),
              Text(
                'La caja coincide con el medicamento.',
                style: context.text.bodyLarge!.copyWith(color: t.onPlateSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (result.shortfall > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Notice(
              tone: NoticeTone.danger,
              icon: Icons.inventory_2_outlined,
              title: 'Inventario insuficiente',
              body:
                  'Faltaron ${fmtUnits(result.shortfall)} ${unitWord(detail.product, result.shortfall)}. '
                  'Registra una caja nueva para mantener el conteo real.',
            ),
          ),
        Panel(
          child: Column(
            children: [
              FactRow(
                'Quedan para ${detail.profile.name}',
                '${fmtUnits(unitsLeft)} ${unitWord(detail.product, unitsLeft)}',
              ),
              FactRow('Confirmada', fmtTime(DateTime.now())),
              FactRow('Programada', fmtTime(detail.dose.scheduledAt)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => context.pop(), child: const Text('Listo')),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onAgain,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Escanear otra caja'),
        ),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  final _Message m;
  final VoidCallback onAgain;
  const _MessageView({required this.m, required this.onAgain});

  @override
  Widget build(BuildContext context) {
    final t = context.sign;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: m.danger ? t.danger : t.plate, borderRadius: BorderRadius.circular(16)),
            child: Icon(m.icon, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 20),
        Text(m.title, style: context.text.headlineMedium!.copyWith(color: m.danger ? t.danger : null)),
        const SizedBox(height: 8),
        Text(m.body, style: context.text.bodyLarge!.copyWith(color: t.inkSoft)),
        const SizedBox(height: 28),
        if (m.gtinToRegister != null) ...[
          FilledButton.icon(
            onPressed: () => context.pushReplacement('/inventory/product?gtin=${m.gtinToRegister}'),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Registrar este medicamento'),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: onAgain,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Escanear de nuevo'),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: () => context.pop(), child: const Text('Volver')),
      ],
    );
  }
}
