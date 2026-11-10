/// Normalización de códigos de barras a GTIN-14 y lectura de GS1 DataMatrix.
/// Lógica pura: sin Flutter ni IO (SPEC §4).
library;

enum BarcodeKind { ean13, ean8, upcA, upcE, dataMatrix, unknown }

final _digits = RegExp(r'^\d+$');

/// Valida el dígito verificador GTIN (pesos 3,1 alternados de derecha a izquierda,
/// empezando por el dígito anterior al verificador).
bool _validCheckDigit(String code) {
  var sum = 0;
  for (var i = code.length - 2, w = 3; i >= 0; i--, w = w == 3 ? 1 : 3) {
    sum += (code.codeUnitAt(i) - 48) * w;
  }
  final check = (10 - sum % 10) % 10;
  return check == code.codeUnitAt(code.length - 1) - 48;
}

/// Expande un UPC-E de 8 dígitos (sistema + 6 + verificador) a UPC-A de 12.
String expandUpcE(String upcE8) {
  final c = upcE8.trim();
  if (c.length != 8 || !_digits.hasMatch(c)) {
    throw ArgumentError.value(upcE8, 'upcE8', 'UPC-E debe tener 8 dígitos');
  }
  final ns = c[0];
  final d = c.substring(1, 7);
  final check = c[7];
  final last = d[5];
  final String body;
  switch (last) {
    case '0':
    case '1':
    case '2':
      body = '${d.substring(0, 2)}${last}0000${d.substring(2, 5)}';
    case '3':
      body = '${d.substring(0, 3)}00000${d.substring(3, 5)}';
    case '4':
      body = '${d.substring(0, 4)}00000${d[4]}';
    default:
      body = '${d.substring(0, 5)}0000$last';
  }
  return '$ns$body$check';
}

/// Devuelve el GTIN-14 (relleno con ceros) o `null` si el código no es válido.
/// Con [BarcodeKind.unknown] se infiere el tipo por longitud (8 → EAN-8).
String? normalizeGtin(String raw, {BarcodeKind kind = BarcodeKind.unknown}) {
  var code = raw.trim();
  if (code.isEmpty || !_digits.hasMatch(code)) return null;
  if (kind == BarcodeKind.upcE) {
    if (code.length != 8) return null;
    code = expandUpcE(code);
  }
  if (![8, 12, 13, 14].contains(code.length)) return null;
  if (!_validCheckDigit(code)) return null;
  return code.padLeft(14, '0');
}

class Gs1Data {
  final String? gtin;
  final DateTime? expiresOn;
  final String? lot;
  const Gs1Data({this.gtin, this.expiresOn, this.lot});
}

const _gs = '\x1D';

DateTime? _parseYymmdd(String s) {
  if (s.length != 6 || !_digits.hasMatch(s)) return null;
  final y = 2000 + int.parse(s.substring(0, 2));
  final m = int.parse(s.substring(2, 4));
  final d = int.parse(s.substring(4, 6));
  if (m < 1 || m > 12) return null;
  if (d == 0) return DateTime(y, m + 1, 0); // día 00 = último día del mes
  final date = DateTime(y, m, d);
  return date.month == m ? date : null;
}

/// Interpreta una cadena GS1 (AIs 01, 17, 10; tolera 11, 15, 21).
/// Devuelve `null` si no contiene un GTIN (01) válido.
Gs1Data? parseGs1(String raw) {
  var s = raw;
  for (final p in const [']d2', ']C1', ']Q3', ']e0']) {
    if (s.startsWith(p)) {
      s = s.substring(p.length);
      break;
    }
  }
  while (s.startsWith(_gs)) {
    s = s.substring(1);
  }
  String? gtin;
  DateTime? expires;
  String? lot;
  var i = 0;
  String? readFixed(int len) {
    if (i + len > s.length) return null;
    final v = s.substring(i, i + len);
    i += len;
    return v;
  }

  String readVariable() {
    final end = s.indexOf(_gs, i);
    final v = end == -1 ? s.substring(i) : s.substring(i, end);
    i = end == -1 ? s.length : end + 1;
    return v;
  }

  while (i + 2 <= s.length) {
    final ai = s.substring(i, i + 2);
    i += 2;
    switch (ai) {
      case '01':
        final v = readFixed(14);
        if (v == null) return null;
        gtin = normalizeGtin(v);
        if (gtin == null) return null;
      case '17':
        final v = readFixed(6);
        if (v == null) return null;
        expires = _parseYymmdd(v);
      case '11':
      case '15':
        if (readFixed(6) == null) return null;
      case '10':
        lot = readVariable();
      case '21':
        readVariable();
      default:
        i = s.length; // AI desconocido: se detiene sin descartar lo leído
    }
    while (i < s.length && s[i] == _gs) {
      i++;
    }
  }
  if (gtin == null) return null;
  return Gs1Data(gtin: gtin, expiresOn: expires, lot: lot);
}
