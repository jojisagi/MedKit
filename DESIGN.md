# Mi Botiquín — Sistema visual

Mundo: **señalética de hospital**. Cada integrante de la familia es una línea de color que se sigue, como las franjas pintadas en el piso de una clínica; su próxima toma es la siguiente parada. Modo Operate: Material 3 manda en estructura y controles; el mundo aporta color, tipografía, densidad y un gesto propio.

Tokens en código: `lib/ui/theme.dart` (`Palette`, `SignTokens`, `buildTheme`). Componentes: `lib/ui/widgets.dart`.

## Color

| Rol | Claro | Oscuro | Uso |
|---|---|---|---|
| Muro (`wall`) | `#F4F6F3` | `#0D1424` | Fondo de todas las pantallas |
| Panel | `#FFFFFF` | `#151F35` | Agrupadores con borde `rule`, nunca anidados |
| Tinta (`ink`) | `#14213D` | `#EFF2F8` | Texto principal, botones primarios |
| Tinta suave | `#4A5670` | `#B4BDD0` | Texto secundario |
| Placa (`plate`) | `#14213D` | `#1E2E52` | Superficie de señalética: siguiente toma, resultados, avisos legales |
| Peligro | `#C8322C` | `#FF8A80` | **Solo** omitida, caducada, caja equivocada, acciones destructivas |
| Precaución | `#9A6200` | `#FFC94D` | Tardía, caduca pronto, inventario bajo, permisos |

Colores de zona (uno por persona, contraste ≥ 4.5:1 sobre blanco): verde `#1F7A5A`, azul `#2F5FD0`, mostaza `#A0661A`, magenta `#B83A72`, petróleo `#0F7484`, ladrillo `#B4532A`, violeta `#6A4FC4`. En oscuro se aclaran 35 % (`zoneOn`). El color de zona **nunca** aparece sin el nombre de la persona junto.

## Tipografía

Atkinson Hyperlegible Next (Braille Institute, OFL), variable 200–800, empaquetada en `assets/fonts`. Elegida por legibilidad para baja visión: público de 30–60 años. Peso aplicado con `FontVariation('wght')` explícito. Toda hora, cantidad y porcentaje usa cifras tabulares (`numerals()`).

Escala: display 56/44/34 · headline 30/26/22 · title 20/17/15 · body 17/16/14 · label 16/14/12.5. Texto base ≥ 16 sp.

## Forma y espacio

Retícula de 8 dp. Radios: controles 12, paneles 16, placas 20, hojas inferiores 24. Objetivos táctiles ≥ 48 dp; acción principal 56–64 dp. Sombras solo en placas y FAB (desplazamiento + desenfoque, nunca halos ni sombras duras).

## Gesto propio: la línea

`lib/features/home/profile_line.dart`. Columna de hora (tabular, alineada a la derecha) · línea de 6 dp del color de la persona · contenido.

- Distancia entre paradas = 12 dp + 5 dp por hora entre tomas (tope 56): la línea es un eje de tiempo real.
- Tramo recorrido sólido; tramo futuro al 28 %.
- Parada: disco relleno con ✓ (a tiempo), disco ámbar con ✓ (tardía), anillo rojo con ✕ (omitida), anillo del color de la persona (pendiente).
- Parada actual: 34 dp, anillo grueso con punto y un halo que late (respeta «reducir movimiento»); las demás pendientes bajan a 55 % de opacidad.
- Al confirmar, la parada se rellena con escala `easeOutBack` (420 ms). Es el único momento de movimiento autoral.

## Estados

Siempre ícono + palabra + color, nunca solo color. Caja equivocada: diálogo rojo a pantalla con «Esta caja no corresponde a <medicamento>. Revisa antes de tomarla.» y vibración.

## Rechazos deliberados

Sin tarjetas de ícono + título como estructura, sin franjas laterales de color en tarjetas, sin degradados, sin vidrio, sin etiquetas «eyebrow» sobre títulos, sin turquesa clínico genérico.
