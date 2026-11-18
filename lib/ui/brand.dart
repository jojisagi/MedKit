import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

const appName = 'Medkit';
const brandGreen = Color(0xFF2FBF86);

/// Logo de Medkit: placa redondeada con cruz blanca y la línea verde que se sigue.
/// Es el mismo dibujo que el ícono del launcher (ic_launcher_foreground.xml).
class MedkitLogo extends StatelessWidget {
  final double size;
  final Color plate;
  const MedkitLogo({super.key, this.size = 48, this.plate = Palette.plateRaised});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _LogoPainter(plate)),
  );
}

class _LogoPainter extends CustomPainter {
  final Color plate;
  _LogoPainter(this.plate);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.26)), Paint()..color = plate);
    final white = Paint()..color = Colors.white;
    final arm = s * 0.115, half = s * 0.27, cx = s / 2, cy = s * 0.44;
    final r = Radius.circular(s * 0.035);
    canvas.drawRRect(RRect.fromLTRBR(cx - arm, cy - half, cx + arm, cy + half, r), white);
    canvas.drawRRect(RRect.fromLTRBR(cx - half, cy - arm, cx + half, cy + arm, r), white);
    final ly = cy + half + s * 0.09;
    canvas.drawRRect(
      RRect.fromLTRBR(cx - half, ly, cx + half, ly + s * 0.07, Radius.circular(s * 0.035)),
      Paint()..color = brandGreen,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.plate != plate;
}

/// Banner superior de la pantalla principal: logo + nombre, a sangre bajo la barra de estado.
class MedkitBanner extends StatelessWidget {
  final Widget? trailing;
  const MedkitBanner({super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = context.sign;
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: t.plate,
        padding: EdgeInsets.only(top: top),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 16),
              child: Row(
                children: [
                  const MedkitLogo(size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appName,
                          style: context.text.headlineLarge!.copyWith(
                            color: t.onPlate,
                            fontSize: 32,
                            height: 1.0,
                            letterSpacing: -0.6,
                            fontVariations: const [FontVariation('wght', 800)],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Tu botiquín familiar', style: context.text.bodyMedium!.copyWith(color: t.onPlateSoft)),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            // La línea verde de señalética que remata el banner.
            Container(height: 5, color: brandGreen),
          ],
        ),
      ),
    );
  }
}
