import 'package:flutter_test/flutter_test.dart';
import 'package:mi_botiquin/domain/profile_colors.dart';

void main() {
  final all = profilePalette.map((c) => c.argb).toList();

  test('10 colores distintos con nombre único', () {
    expect(all.length, 10);
    expect(all.toSet().length, 10);
    expect(profilePalette.map((c) => c.name).toSet().length, 10);
  });

  test('sugiere el primero libre', () {
    expect(suggestProfileColor([]), all[0]);
    expect(suggestProfileColor([all[0], all[1]]), all[2]);
  });

  test('no permite repetir mientras queden libres', () {
    expect(isProfileColorAvailable(all[0], [all[0]]), isFalse);
    expect(isProfileColorAvailable(all[1], [all[0]]), isTrue);
  });

  test('con los 10 ocupados permite repetir y sugiere el menos usado', () {
    final used = [...all, all[0], all[1]];
    expect(isProfileColorAvailable(all[0], used), isTrue);
    expect(suggestProfileColor(used), all[2]);
  });

  test('colores antiguos fuera de la paleta no bloquean nada', () {
    expect(isProfileColorAvailable(all[3], [0xFFA0661A]), isTrue);
  });
}
