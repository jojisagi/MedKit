import 'package:flutter_test/flutter_test.dart';
import 'package:mi_botiquin/domain/barcode.dart';

void main() {
  group('normalizeGtin', () {
    test('EAN-13', () => expect(normalizeGtin('4006381333931'), '04006381333931'));
    test('UPC-A', () => expect(normalizeGtin('036000291452'), '00036000291452'));
    test('UPC-A y su forma EAN-13 resuelven igual', () {
      expect(normalizeGtin('0036000291452'), normalizeGtin('036000291452'));
    });
    test('EAN-8', () => expect(normalizeGtin('96385074'), '00000096385074'));
    test('UPC-E', () {
      expect(expandUpcE('04252614'), '042100005264');
      expect(normalizeGtin('04252614', kind: BarcodeKind.upcE), '00042100005264');
    });
    test('checksum inválido', () => expect(normalizeGtin('4006381333932'), isNull));
    test('no numérico', () => expect(normalizeGtin('12ab'), isNull));
    test('espacios se ignoran', () => expect(normalizeGtin(' 4006381333931 '), '04006381333931'));
    test('longitud inválida', () => expect(normalizeGtin('12345'), isNull));
  });

  group('parseGs1', () {
    test('GTIN, caducidad y lote', () {
      final g = parseGs1('01040063813339311728063010LOTE1')!;
      expect([g.gtin, g.expiresOn, g.lot], ['04006381333931', DateTime(2028, 6, 30), 'LOTE1']);
    });
    test('día 00 = último día del mes', () {
      expect(parseGs1('010400638133393117280600')?.expiresOn, DateTime(2028, 6, 30));
    });
    test('con prefijo de simbología y separador', () {
      final g = parseGs1(']d201040063813339311028A1\x1D17280630')!;
      expect(g.lot, '28A1');
      expect(g.expiresOn, DateTime(2028, 6, 30));
    });
    test('texto libre', () => expect(parseGs1('hola'), isNull));
  });
}
