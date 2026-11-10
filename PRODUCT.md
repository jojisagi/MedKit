# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Stack

Flutter (Dart 3), Material 3, solo Android (minSdk 23). Paquetes fijos: flutter_riverpod, sqflite, flutter_local_notifications, timezone, flutter_timezone, mobile_scanner, go_router, intl. Ver `CLAUDE.md`.

## Users

Cuidadores de 30 a 60 años que administran los medicamentos de toda la familia desde un solo teléfono, incluidos los de adultos mayores e hijos. Lo usan en casa, frente al botiquín o la caja del medicamento, muchas veces con prisa o con la otra mano ocupada (sosteniendo la caja, un vaso de agua, al paciente).

## Product Purpose

Organizar el botiquín del hogar: qué medicamentos hay, cuántas unidades quedan y cuándo caducan; programar tratamientos por persona; recordar cada toma y registrar si se tomó a tiempo, tarde u omitida. Éxito = ninguna toma olvidada, ninguna caja caducada sin aviso, inventario siempre real.

## Positioning

Confirmar la toma escaneando el código de barras de la caja: además de registrar, verifica que se está dando el medicamento correcto a la persona correcta. 100 % offline: ningún dato sale del teléfono.

## Operating Context

Uso doméstico. Flujo crítico: llega la notificación → se toma la caja → se escanea → queda registrada. Prueba con usuarios reales y demo ante profesor (proyecto de curso, Equipo Inmóviles, entrega ~30 nov 2026). Modo demo con datos precargados.

## Capabilities and Constraints

Ver `docs/SPEC.md`. Perfiles, inventario por cajas (FEFO), tratamientos por intervalo u horarios fijos, recordatorios con reintento, confirmación por botón / notificación / escaneo, historial con % de cumplimiento, alertas de caducidad y stock bajo. Sin INTERNET, sin cuentas, sin APIs.

## Brand Commitments

Nombre: "Mi Botiquín". Sin identidad visual previa (delegada al diseño). Textos en español de México. Aviso obligatorio: "Mi Botiquín no diagnostica ni recomienda medicamentos. Consulta siempre a tu médico."

## Evidence on Hand

No hay testimonios, logos ni capturas. No inventar cifras, usuarios ni avales médicos.

## Product Principles

1. Lo urgente primero: la siguiente toma pendiente siempre es lo más visible.
2. Verificar antes que confiar: el escaneo es la vía recomendada y una caja equivocada se advierte con claridad.
3. Nunca diagnosticar: la app organiza lo que el usuario captura, no sugiere.
4. Privado por diseño: todo vive en el teléfono.

## Accessibility & Inclusion

Cuidadores de mediana edad: texto base ≥ 16 sp, objetivos táctiles ≥ 48 dp (acciones principales ≥ 56 dp), contraste AA, estados nunca solo por color (ícono + texto), respetar escala de fuente del sistema.
