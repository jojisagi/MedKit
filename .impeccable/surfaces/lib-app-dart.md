---
version: 1
slug: "lib-app-dart"
primary_target: "lib/app.dart"
related_targets: ["lib/features"]
---

# Superficie: App Mi Botiquín (todas las pantallas)

Modo: Operate. Cuidadores 30–60 años administran tomas de la familia con una mano ocupada. Tarea: ver la próxima toma, confirmarla (idealmente escaneando la caja), mantener el inventario real.

## Direction contract

THESIS: Cada integrante de la familia es una línea de color que se sigue, como la señalética pintada en el piso de un hospital; su próxima toma es la siguiente parada. Rechaza la app de salud de tarjetas blancas con acento turquesa.

OWN-WORLD: Fondo muro clínico #F4F6F3, placas azul marino #14213D con texto blanco, colores de zona por perfil (verde #1F7A5A, azul #2F5FD0, mostaza #B7791F, magenta #B83A72, petróleo #0F7C8C, ladrillo #B4532A). Pictogramas Material redondeados de trazo grueso, esquinas de placa 12 dp, cifras tabulares. Rojo #C8322C solo para omitida/caducada/caja equivocada.

STORY: El cuidador abre la app, ve de inmediato quién toma qué y cuándo, sigue la línea de esa persona, escanea la caja y ve la parada llenarse. Confía en que el inventario y el historial son reales.

FIRST VIEWPORT: Placa azul marino arriba: fecha y «Siguiente toma» con hora en cifras grandes, persona (chip de color) y medicamento. Debajo, una línea vertical por perfil con paradas por toma (relleno = tomada, anillo = pendiente, cruz roja = omitida); la siguiente pendiente se expande con «Confirmar» y «Escanear». Botón extendido fijo «Escanear para confirmar» 64 dp sobre la NavigationBar de 4 destinos (Hoy, Botiquín, Familia, Ajustes).

FORM: Señalética hospitalaria de líneas de color, candidato 4 de 7. seed:d3a3ff9fc4b20b98

Signature move: la línea de perfil con paradas espaciadas en proporción al tiempo; la parada actual crece y el resto baja de tono. Raises: foco único (muro de streaming), retícula 8 dp y cifras tabulares (Crouwel), espaciado proporcional al tiempo (Laban), destructivas aisladas en contorno (consola), color de perfil como código total pero siempre con nombre (Saville).

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
