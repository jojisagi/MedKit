import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_botiquin/domain/barcode.dart';
import 'package:mi_botiquin/domain/catalog.dart';

void main() {
  const csv = '''barcode,nombre,sustancia,concentracion,presentacion,contenido de caja
7501298215099,Sedalmerk Max,"Paracetamol, Cafeína","650, 65",tabletas,24
650240017094,XL-3 Xtra,"Clorfenamina, Fenilefrina, Dextrometorfano, Paracetamol","2, 5, 10, 250",tabletas,12
7501318652453,actron,Ibuprofeno,600,tabletas,10
1234567890123,Malo,X,1,tabletas,1
,Sin código,X,1,tabletas,1
''';

  test('parsea comillas, normaliza GTIN y descarta códigos inválidos', () {
    final c = parseCatalogCsv(csv);
    expect(c.entries.keys, ['07501298215099', '00650240017094', '07501318652453']);
    expect(c.rejected, 2);
  });

  test('combinaciones: sustancias y concentraciones en mg', () {
    final p = parseCatalogCsv(csv).entries['07501298215099']!;
    expect(p.name, 'Sedalmerk Max');
    expect(p.activeIngredient, 'Paracetamol, Cafeína');
    expect(p.strength, '650 mg / 65 mg');
    expect(p.form, 'tableta');
    expect(p.unit, 'pza');
    expect(p.unitsPerBox, 24);
    expect(p.gtin, '07501298215099');
    expect(p.id, isNull);
  });

  test('nombre en minúsculas se capitaliza', () {
    expect(parseCatalogCsv(csv).entries['07501318652453']!.name, 'Actron');
  });

  test('UPC-A del catálogo y su forma EAN-13 dan el mismo producto', () {
    final c = parseCatalogCsv(csv);
    expect(c.lookup(normalizeGtin('0650240017094')!)?.name, 'XL-3 Xtra');
    expect(c.lookup(normalizeGtin('650240017094')!)?.name, 'XL-3 Xtra');
  });

  test('formatStrength respeta unidades escritas', () {
    expect(formatStrength('40'), '40 mg');
    expect(formatStrength('120 mg/5 ml'), '120 mg/5 ml');
    expect(formatStrength('0.5'), '0.5 mg');
    expect(formatStrength(''), isNull);
  });

  test('presentaciones', () {
    expect(normalizeForm('Tabletas'), 'tableta');
    expect(normalizeForm('cápsulas'), 'cápsula');
    expect(normalizeForm('capsulas'), 'cápsula');
    expect(normalizeForm('Jarabe'), 'jarabe');
    expect(normalizeForm('suspension'), 'suspensión');
    expect(normalizeForm('gotas'), 'gotas');
    expect(normalizeForm('parche'), 'otro');
  });

  test('líquidos usan ml', () {
    final c = parseCatalogCsv('barcode,nombre,sustancia,concentracion,presentacion,contenido de caja\n'
        '7501644753060,Jarabe X,Ambroxol,15 mg/5 ml,jarabe,120\n');
    expect(c.entries.values.single.unit, 'ml');
  });

  test('el catálogo empaquetado es válido completo', () {
    final c = parseCatalogCsv(File('assets/catalog/medicamentos.csv').readAsStringSync());
    expect(c.rejected, 0);
    expect(c.entries.length, 7);
    expect(c.lookup('07502001166400')!.strength, '40 mg');
  });
}
