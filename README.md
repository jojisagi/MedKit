# Mi Botiquín

App Android (Flutter) para organizar el botiquín del hogar: inventario por cajas, tratamientos por persona, recordatorios de cada toma y confirmación **escaneando el código de barras de la caja**, que además verifica que se está dando el medicamento correcto.

**100 % offline.** No hay cuentas, servidores ni APIs: todo se guarda en SQLite dentro del teléfono y el APK de release no pide permiso de Internet.

> Mi Botiquín no diagnostica ni recomienda medicamentos. Consulta siempre a tu médico.

Equipo Inmóviles: Héctor Armando González Espinosa, Juan Manuel Palafox Valdés, Jorge Sánchez Girón.

## Qué hace

| Pantalla | Para qué |
|---|---|
| **Hoy** | Placa con la siguiente toma, una línea de color por persona con sus tomas del día (a tiempo, tardía, omitida, pendiente), avisos de caducidad e inventario bajo y botón principal «Escanear para confirmar». |
| **Botiquín** | Medicamentos con unidades disponibles y caducidad. Alta escaneando la caja: si el código ya existe, el formulario se llena solo. Lee caducidad y lote de códigos GS1 DataMatrix. |
| **Familia** | Personas con su color y cumplimiento; tratamientos por intervalo (cada N h) u horas fijas, dosis en medios, tolerancia y límite de omisión configurables. |
| **Historial** | Tomas por tratamiento y % de cumplimiento = (a tiempo + tardías) ÷ (a tiempo + tardías + omitidas). |
| **Ajustes** | Días de alerta, modo demo y aviso legal. |

Formas de confirmar una toma: botón en la app, acción «Ya la tomé» en la notificación (funciona con la app cerrada) o escaneando la caja. Si se escanea una caja que no corresponde, aparece una advertencia roja y la toma **no** se confirma. El inventario se descuenta solo al confirmar, primero de la caja que caduca antes (FEFO) y nunca de cajas caducadas.

## Compilar

> **Para simularla en la Mac (o si tienes iPhone):** sigue [run.txt](run.txt) o corre `./run.sh`, que abre el emulador Android, instala el APK y abre la app.

Requisitos: Flutter 3.35+, Android SDK, **JDK 17 o 21** (Gradle 8.12 no soporta Java 25).

```bash
flutter pub get
flutter test                 # 55 pruebas de dominio y datos
flutter analyze
flutter run                  # usar teléfono físico para escanear
flutter build apk --release  # build/app/outputs/flutter-apk/app-release.apk
```

Si Flutter detecta Java 25 (Gradle 8.12 no lo soporta), apúntalo a un JDK 21:

```bash
flutter config --jdk-dir=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
```

El APK release pesa ~73 MB porque incluye todas las arquitecturas y el modelo de lectura de códigos (funciona sin Internet). Para APKs más ligeros por arquitectura: `flutter build apk --release --split-per-abi`.

## Permisos y por qué

| Permiso | Uso |
|---|---|
| `CAMERA` | Leer el código de barras de la caja. Si se niega, siempre queda la captura manual. |
| `POST_NOTIFICATIONS` | Avisar a la hora de cada toma (se pide con explicación previa al crear el primer tratamiento). |
| `SCHEDULE_EXACT_ALARM` | Que el aviso llegue a la hora exacta; si falta, Inicio muestra un aviso que lleva a ajustes. |
| `RECEIVE_BOOT_COMPLETED` | Reprogramar recordatorios tras reiniciar el teléfono. |
| `VIBRATE` | Confirmar la lectura del código. |
| ~~`INTERNET`~~, ~~`ACCESS_NETWORK_STATE`~~ | Removidos explícitamente del manifest (`tools:node="remove"`); verificado con `aapt dump permissions` sobre el APK release. |

## Arquitectura

```
lib/domain/    lógica pura: GTIN/GS1, estado de tomas, programación, FEFO, cumplimiento
lib/data/      SQLite (esquema v1), repositorios, providers de Riverpod, modo demo
lib/services/  confirmación de tomas (única puerta), programación 72 h, notificaciones, escáner
lib/features/  una carpeta por pantalla
lib/ui/        tema «señalética hospitalaria» y componentes compartidos
test/          pruebas de dominio y de base de datos (sqflite_common_ffi)
```

Toda confirmación pasa por `DoseConfirmationService` dentro de una transacción con actualización condicional: confirmar dos veces la misma toma (notificación + escaneo) solo descuenta una vez.

## Modo demo

Ajustes → Modo demo carga a Rosa y Don Luis, tres medicamentos (una caja caduca en 10 días), cinco días de historial y una toma en +2 min con tolerancia 1 min y omisión a 3 min. Los códigos demo usan el prefijo GS1 `200` (uso interno, nunca un producto real); para probar el escaneo, captúralos a mano o imprime su código.

## Diseño

Dirección visual: **señalética de hospital**. Cada integrante de la familia es una línea de color que se sigue, como las del piso de una clínica; su próxima toma es la siguiente parada. Tipografía Atkinson Hyperlegible Next (Braille Institute, licencia OFL, incluida en `assets/fonts`), pensada para baja visión.
