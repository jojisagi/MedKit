/// Catálogo de referencia empaquetado (assets/catalog/medicamentos.csv).
/// Solo datos de identificación del producto: nunca dosis ni indicaciones.
/// Lógica pura: recibe el texto CSV, no lee archivos.
library;

import 'barcode.dart';
import 'models.dart';

class Catalog {
  /// GTIN-14 → producto sin id (aún no está en la base del usuario).
  final Map<String, Product> entries;

  /// Filas descartadas por código vacío o inválido.
  final int rejected;
  const Catalog(this.entries, this.rejected);

  static const empty = Catalog({}, 0);

  Product? lookup(String gtin14) => entries[gtin14];
}

String _fold(String s) => s
    .toLowerCase()
    .trim()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');

/// RFC 4180 mínimo: comillas dobles, comas dentro de comillas y "" escapadas.
List<List<String>> _parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  row.add(cell.toString());
  if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
  return rows;
}

/// "40" → "40 mg"; "650, 65" → "650 mg / 65 mg"; con unidad escrita se respeta.
/// Supuesto: la hoja trae miligramos cuando el número va solo.
String? formatStrength(String raw, {String unit = 'mg'}) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (RegExp(r'[a-zA-Zµ%]').hasMatch(s)) return s;
  return s.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).map((p) => '$p $unit').join(' / ');
}

String normalizeForm(String raw) {
  final f = _fold(raw);
  if (f.startsWith('tablet') || f.startsWith('comprimid') || f.startsWith('gragea')) return 'tableta';
  if (f.startsWith('capsul')) return 'cápsula';
  if (f.startsWith('jarabe')) return 'jarabe';
  if (f.startsWith('gota')) return 'gotas';
  if (f.startsWith('suspens')) return 'suspensión';
  return 'otro';
}

String _titleIfLower(String s) {
  final t = s.trim();
  if (t.isEmpty || t != t.toLowerCase()) return t;
  return t[0].toUpperCase() + t.substring(1);
}

/// Columnas reconocidas (sin importar mayúsculas ni acentos):
/// barcode/código, nombre, sustancia, concentración, presentación, unidad (opcional), contenido de caja.
Catalog parseCatalogCsv(String text) {
  final rows = _parseCsv(text.replaceFirst('﻿', ''));
  if (rows.isEmpty) return Catalog.empty;
  final header = rows.first.map(_fold).toList();
  int col(List<String> names) => header.indexWhere((h) => names.any(h.startsWith));
  final cCode = col(['barcode', 'codigo', 'gtin', 'ean']);
  final cName = col(['nombre']);
  final cIngr = col(['sustancia', 'principio']);
  final cStr = col(['concentracion', 'dosis por unidad']);
  final cForm = col(['presentacion', 'forma']);
  final cUnit = col(['unidad']);
  final cQty = col(['contenido']);
  String at(List<String> r, int i) => i < 0 || i >= r.length ? '' : r[i].trim();

  final out = <String, Product>{};
  var rejected = 0;
  for (final r in rows.skip(1)) {
    final gtin = normalizeGtin(at(r, cCode).replaceAll(RegExp(r'\s'), ''));
    final name = _titleIfLower(at(r, cName));
    if (gtin == null || name.isEmpty) {
      rejected++;
      continue;
    }
    final form = normalizeForm(at(r, cForm));
    final unitRaw = _fold(at(r, cUnit));
    final unit = unitRaw.startsWith('ml') || (unitRaw.isEmpty && (form == 'jarabe' || form == 'suspensión'))
        ? 'ml'
        : 'pza';
    out[gtin] = Product(
      gtin: gtin,
      name: name,
      activeIngredient: at(r, cIngr).isEmpty ? null : at(r, cIngr),
      strength: formatStrength(at(r, cStr)),
      form: form,
      unit: unit,
      unitsPerBox: double.tryParse(at(r, cQty).replaceAll(',', '.')) ?? 0,
    );
  }
  return Catalog(out, rejected);
}
