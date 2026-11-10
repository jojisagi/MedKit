import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/barcode.dart';
import '../ui/theme.dart';

class ScanResult {
  final String gtin14;
  final Gs1Data? gs1;
  const ScanResult(this.gtin14, [this.gs1]);
}

const _formats = [
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
  BarcodeFormat.dataMatrix,
];

BarcodeKind _kind(BarcodeFormat f) => switch (f) {
      BarcodeFormat.ean13 => BarcodeKind.ean13,
      BarcodeFormat.ean8 => BarcodeKind.ean8,
      BarcodeFormat.upcA => BarcodeKind.upcA,
      BarcodeFormat.upcE => BarcodeKind.upcE,
      BarcodeFormat.dataMatrix => BarcodeKind.dataMatrix,
      _ => BarcodeKind.unknown,
    };

/// Convierte una lectura cruda en GTIN-14 validado (B1) o null.
ScanResult? interpretRaw(String raw, BarcodeKind kind) {
  if (kind == BarcodeKind.dataMatrix || raw.startsWith(']d2') || raw.startsWith('01') && raw.length > 16) {
    final g = parseGs1(raw);
    if (g?.gtin != null) return ScanResult(g!.gtin!, g);
    if (kind == BarcodeKind.dataMatrix) return null;
  }
  final gtin = normalizeGtin(raw, kind: kind == BarcodeKind.dataMatrix ? BarcodeKind.unknown : kind);
  return gtin == null ? null : ScanResult(gtin);
}

/// Abre el escáner y devuelve el código leído o capturado a mano (null si se cancela).
Future<ScanResult?> scanBarcode(BuildContext context, {String? title, String? subtitle}) =>
    Navigator.of(context, rootNavigator: true).push<ScanResult>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ScannerScreen(title: title, subtitle: subtitle),
    ));

class ScannerScreen extends StatefulWidget {
  final String? title;
  final String? subtitle;
  const ScannerScreen({super.key, this.title, this.subtitle});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(formats: _formats, detectionSpeed: DetectionSpeed.normal);
  String? _last;
  bool _done = false;
  bool _torch = false;
  String? _hint;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final r = interpretRaw(raw, _kind(b.format));
      if (r == null) {
        setState(() => _hint = 'Código no válido, intenta de nuevo o captúralo a mano');
        _last = null;
        continue;
      }
      // Dos lecturas iguales seguidas antes de aceptar.
      if (_last == r.gtin14) {
        _done = true;
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop(r);
        return;
      }
      _last = r.gtin14;
    }
  }

  Future<void> _manual() async {
    final r = await showDialog<ScanResult>(context: context, builder: (_) => const ManualCodeDialog());
    if (r != null && mounted) Navigator.of(context).pop(r);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final window = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.82,
      height: size.width * 0.5,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraError(
                denied: error.errorCode == MobileScannerErrorCode.permissionDenied,
                onManual: _manual,
              ),
            ),
          ),
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _WindowPainter(window)))),
          // Encabezado tipo placa.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.title ?? 'Escanea el código de la caja',
                          style: context.text.headlineSmall!.copyWith(color: Colors.white)),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(widget.subtitle!, style: context.text.bodyLarge!.copyWith(color: Palette.onPlateSoft)),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: window.bottom + 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _hint ?? 'Centra el código de barras en el recuadro. Se lee solo.',
                key: ValueKey(_hint),
                textAlign: TextAlign.center,
                style: context.text.bodyLarge!.copyWith(color: _hint == null ? Colors.white : const Color(0xFFFFD873)),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  IconButton.filledTonal(
                    tooltip: _torch ? 'Apagar linterna' : 'Encender linterna',
                    style: IconButton.styleFrom(
                        minimumSize: const Size(56, 56),
                        backgroundColor: _torch ? Colors.white : const Color(0x33FFFFFF),
                        foregroundColor: _torch ? Palette.ink : Colors.white),
                    onPressed: () async {
                      await _controller.toggleTorch();
                      setState(() => _torch = !_torch);
                    },
                    icon: Icon(_torch ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.white, foregroundColor: Palette.ink, minimumSize: const Size(48, 56)),
                      onPressed: _manual,
                      icon: const Icon(Icons.keyboard_rounded),
                      label: const Text('Capturar a mano'),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Oscurece todo menos la ventana de lectura y dibuja esquinas de señalética.
class _WindowPainter extends CustomPainter {
  final Rect window;
  _WindowPainter(this.window);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(window, const Radius.circular(18));
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(r)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = const Color(0xB3000000));
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 34.0;
    final w = window;
    for (final (o, dx, dy) in [
      (w.topLeft, 1.0, 1.0),
      (w.topRight, -1.0, 1.0),
      (w.bottomLeft, 1.0, -1.0),
      (w.bottomRight, -1.0, -1.0),
    ]) {
      final c = o.translate(dx * 2, dy * 2);
      canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy + dy * l)
            ..lineTo(c.dx, c.dy + dy * 14)
            ..quadraticBezierTo(c.dx, c.dy, c.dx + dx * 14, c.dy)
            ..lineTo(c.dx + dx * l, c.dy),
          p);
    }
  }

  @override
  bool shouldRepaint(_WindowPainter old) => old.window != window;
}

class _CameraError extends StatelessWidget {
  final bool denied;
  final VoidCallback onManual;
  const _CameraError({required this.denied, required this.onManual});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Palette.ink,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(denied ? 'Sin acceso a la cámara' : 'La cámara no está disponible',
                  style: context.text.headlineSmall!.copyWith(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                denied
                    ? 'Puedes permitirla en Ajustes de Android > Apps > Mi Botiquín > Permisos, o escribir el código a mano.'
                    : 'Escribe el número que aparece debajo del código de barras.',
                style: context.text.bodyLarge!.copyWith(color: Palette.onPlateSoft),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Palette.ink),
                onPressed: onManual,
                child: const Text('Capturar a mano'),
              ),
            ]),
          ),
        ),
      );
}

/// B5: captura manual del número impreso bajo el código.
class ManualCodeDialog extends StatefulWidget {
  const ManualCodeDialog({super.key});

  @override
  State<ManualCodeDialog> createState() => _ManualCodeDialogState();
}

class _ManualCodeDialogState extends State<ManualCodeDialog> {
  final _c = TextEditingController();
  String? _error;

  void _submit() {
    final raw = _c.text.replaceAll(RegExp(r'\s'), '');
    var gtin = normalizeGtin(raw);
    // Un UPC-E de 8 dígitos que empieza en 0/1 y no valida como EAN-8 se intenta como UPC-E.
    if (gtin == null && raw.length == 8) gtin = normalizeGtin(raw, kind: BarcodeKind.upcE);
    if (gtin == null) {
      setState(() => _error = 'Código no válido. Revisa los dígitos.');
      return;
    }
    Navigator.pop(context, ScanResult(gtin));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Escribe el código'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Son los 8, 12 o 13 números que aparecen debajo de las barras.', style: context.text.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(17)],
            style: numerals(context.text.headlineSmall!),
            decoration: InputDecoration(hintText: '7501234567893', errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _submit, child: const Text('Usar código')),
        ],
      );
}
