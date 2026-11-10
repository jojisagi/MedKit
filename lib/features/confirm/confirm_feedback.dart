import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models.dart';
import '../../services/dose_confirmation_service.dart';
import '../../ui/widgets.dart';

String statusWord(DoseStatus s) => switch (s) {
      DoseStatus.onTime => 'a tiempo',
      DoseStatus.late => 'tardía',
      DoseStatus.missed => 'omitida',
      DoseStatus.pending => 'pendiente',
    };

/// Mensaje tras confirmar: "Toma de Rosa registrada (a tiempo)" + aviso de inventario (R4).
void showConfirmResult(BuildContext context, ConfirmResult r, {String? profileName}) {
  if (r.alreadyConfirmed) {
    showMessage(context, 'Esta toma ya estaba registrada. No se descontó de nuevo.');
    return;
  }
  if (r.outOfWindow) {
    showMessage(context, r.status == DoseStatus.missed
        ? 'Esta toma ya se marcó como omitida.'
        : 'Aún es temprano: puedes confirmar desde 30 min antes.');
    return;
  }
  HapticFeedback.mediumImpact();
  final who = profileName == null ? 'Toma' : 'Toma de $profileName';
  final base = '$who registrada (${statusWord(r.status)})';
  showMessage(context, r.shortfall > 0 ? '$base. Inventario insuficiente: registra una caja nueva.' : base);
}
