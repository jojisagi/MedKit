import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../services/scanner_screen.dart';

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Parámetros GS1 (B6) para precargar caducidad y lote.
String gs1Query(ScanResult r) => [
      if (r.gs1?.expiresOn != null) 'exp=${_isoDate(r.gs1!.expiresOn!)}',
      if (r.gs1?.lot != null) 'lot=${Uri.encodeQueryComponent(r.gs1!.lot!)}',
    ].map((e) => '&$e').join();

/// B2: escanear → si el GTIN existe, formulario de caja precargado; si no, producto nuevo con GTIN fijo.
Future<void> registerByScan(BuildContext context, WidgetRef ref, {bool replace = false}) async {
  final r = await scanBarcode(context, title: 'Registrar caja', subtitle: 'Escanea el código de barras de la caja.');
  if (r == null || !context.mounted) return;
  final product = await ref.read(productRepoProvider).findByGtin(r.gtin14);
  if (!context.mounted) return;
  final route = product == null
      ? '/inventory/product?gtin=${r.gtin14}${gs1Query(r)}'
      : '/inventory/box?productId=${product.id}${gs1Query(r)}';
  replace ? context.pushReplacement(route) : context.push(route);
}
