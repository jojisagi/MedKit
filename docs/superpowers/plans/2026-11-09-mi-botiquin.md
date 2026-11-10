# Mi Botiquín Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prototipo Android offline que gestiona perfiles, inventario por cajas (alta por código de barras), tratamientos, recordatorios con tolerancia/reintento y confirmación de tomas por app, notificación o escaneo de la caja (que además verifica el medicamento).

**Architecture:** Lógica pura en `lib/domain` (100 % testeada, sin IO); SQLite vía repositorios en `lib/data`; servicios de plataforma delgados en `lib/services`; UI por pantalla con Riverpod. Toda confirmación pasa por un único `DoseConfirmationService`.

**Tech Stack:** Flutter (Dart 3), flutter_riverpod, sqflite / sqflite_common_ffi (tests), flutter_local_notifications, timezone, flutter_timezone, mobile_scanner, go_router, intl.

**Spec:** `docs/SPEC.md`

## Global Constraints
- Solo Android, minSdk 23. Sin permiso INTERNET en release. Sin APIs ni paquetes de pago.
- Defaults: tolerancia 10 min, omisión 60 min, confirmación anticipada 30 min, ventana de programación 72 h, alerta de caducidad 30 días, stock bajo 5 días, alerta diaria 9:00.
- Códigos se guardan como GTIN-14 validado.
- Texto obligatorio en Ajustes: "Mi Botiquín no diagnostica ni recomienda medicamentos. Consulta siempre a tu médico."
- UI en español de México; identificadores en inglés.

## Review Focus
1. Tratamiento `interval` que cruza medianoche o cambio de día → las tomas deben seguir cada N h exactas, no reiniciarse a las 00:00. (Test en Task 2.)
2. Confirmar dos veces la misma toma (doble toque, notificación + escaneo) → solo descuenta una vez. (Test en Task 5.)
3. Caja caducada con unidades → no se usa para descontar, aunque sea la única. (Test en Task 3.)
4. Escaneo de UPC-A de 12 dígitos y del mismo producto en EAN-13 → deben resolver al mismo GTIN-14. (Test en Task 1.)
5. Teléfono reiniciado o app cerrada horas → al abrir, tomas vencidas pasan a `missed` y se reprograman las siguientes 72 h. (Test en Task 5.)

## Calendario (4 semanas, entrega ~30 nov)
- Semana 1 (9–15 nov): Tasks 0–4
- Semana 2 (16–22 nov): Tasks 5–8
- Semana 3 (23–27 nov): Tasks 9–11 + pruebas con usuarios
- Semana 4 (28 nov–): reporte, presentación, demo (fuera de este plan)

---

### Task 0: Proyecto base

**Files:** Create: `pubspec.yaml`, `lib/main.dart`, `lib/app.dart` (MaterialApp.router + tema), `analysis_options.yaml`, `android/app/src/main/AndroidManifest.xml` (permisos SPEC §8), `.gitignore`, `README.md` (stub)

- [ ] **Step 1:** `flutter create --org mx.lasalle --platforms android mi_botiquin` y `flutter pub add` del stack.
- [ ] **Step 2:** En `android/app/build.gradle`: minSdk 23, `coreLibraryDesugaringEnabled true` (lo exige flutter_local_notifications).
- [ ] **Step 3:** Manifest con permisos de SPEC §8 y receivers de flutter_local_notifications (`ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`, `ActionBroadcastReceiver`).
- [ ] **Step 4:** Verificar: `flutter analyze` sin errores; `flutter build apk --debug` OK.
- [ ] **Step 5:** Commit `chore: scaffold flutter project`.

### Task 1: Códigos de barras (dominio)

**Files:** Create: `lib/domain/barcode.dart`; Test: `test/domain/barcode_test.dart`

**Interfaces — Produces:**
- `enum BarcodeKind { ean13, ean8, upcA, upcE, dataMatrix, unknown }`
- `String? normalizeGtin(String raw, {BarcodeKind kind = BarcodeKind.unknown})` → GTIN-14 o null si inválido. `unknown` infiere por longitud (8 → EAN-8).
- `String expandUpcE(String upcE8)` → UPC-A 12 dígitos
- `class Gs1Data { String? gtin; DateTime? expiresOn; String? lot; }` y `Gs1Data? parseGs1(String raw)`

- [ ] **Step 1: Tests**
```dart
expect(normalizeGtin('4006381333931'), '04006381333931');           // EAN-13
expect(normalizeGtin('036000291452'), '00036000291452');            // UPC-A
expect(normalizeGtin('0036000291452'), normalizeGtin('036000291452')); // mismo producto
expect(normalizeGtin('96385074'), '00000096385074');                // EAN-8
expect(expandUpcE('04252614'), '042100005264');
expect(normalizeGtin('04252614', kind: BarcodeKind.upcE), '00042100005264');
expect(normalizeGtin('4006381333932'), isNull);                     // checksum malo
expect(normalizeGtin('12ab'), isNull);
final g = parseGs1('01040063813339311728063010LOTE1')!;
expect([g.gtin, g.expiresOn, g.lot], ['04006381333931', DateTime(2028, 6, 30), 'LOTE1']);
expect(parseGs1('010400638133393117280600')?.expiresOn, DateTime(2028, 6, 30)); // día 00
expect(parseGs1('hola'), isNull);
```
- [ ] **Step 2:** `flutter test test/domain/barcode_test.dart` → FAIL.
- [ ] **Step 3:** Implementar. Checksum GTIN: pesos 3,1 alternados desde el dígito anterior al verificador (derecha a izquierda). GS1: (01) 14 fijos, (17) 6 fijos, (10) variable hasta `\x1D` o fin; ignora `]d2` / `\x1D` inicial.
- [ ] **Step 4:** Test → PASS.
- [ ] **Step 5:** Commit `feat(domain): gtin normalization and gs1 parsing`.

### Task 2: Tomas y horarios (dominio)

**Files:** Create: `lib/domain/dose_rules.dart`, `lib/domain/models.dart`; Test: `test/domain/dose_rules_test.dart`

**Interfaces — Produces:**
- `models.dart`: clases inmutables `Profile`, `Product`, `Box`, `Treatment`, `Dose` con campos de SPEC §2 (camelCase), `copyWith`, `toMap()/fromMap()`; `enum DoseStatus { pending, onTime, late, missed }`, `enum ScheduleType { interval, fixed }`, `enum ConfirmMethod { app, notification, scan }`.
- `DoseStatus classifyDose({required DateTime scheduledAt, DateTime? confirmedAt, required DateTime now, int toleranceMin = 10, int missAfterMin = 60})`
- `bool canConfirm(DateTime scheduledAt, DateTime now, int missAfterMin)` (ventana −30 min … +missAfter)
- `List<DateTime> scheduleBetween(Treatment t, DateTime from, DateTime to)`
- `double takesPerDay(Treatment t)`

- [ ] **Step 1: Tests** (s = 8:00 de un día fijo)
```dart
classifyDose(scheduledAt: s, confirmedAt: s.add(10.min), now: x) == onTime
classifyDose(scheduledAt: s, confirmedAt: s.add(11.min), now: x) == late
classifyDose(scheduledAt: s, confirmedAt: s.add(60.min), now: x) == late
classifyDose(scheduledAt: s, now: s.add(61.min)) == missed
classifyDose(scheduledAt: s, now: s.add(30.min)) == pending
classifyDose(scheduledAt: s, confirmedAt: s.subtract(20.min), now: x) == onTime
canConfirm(s, s.subtract(31.min), 60) == false
// interval 8 h desde 20:00 del día 1, ventana día1 00:00–día3 00:00 → [d1 20:00, d2 04:00, d2 12:00, d2 20:00]
// fixed "08:00,20:00", endsAt = d2 10:00 → [d1 08:00, d1 20:00, d2 08:00]
takesPerDay(interval 8) == 3; takesPerDay(fixed "08:00,14:00,20:00") == 3
```
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implementar (interval: `startsAt + k·N h`, nunca anclado a medianoche). **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(domain): dose status and schedule rules`.

### Task 3: Inventario y alertas (dominio)

**Files:** Create: `lib/domain/inventory_rules.dart`; Test: `test/domain/inventory_rules_test.dart`

**Interfaces — Produces:**
- `class Deduction { int boxId; double units; }`
- `({List<Deduction> deductions, double shortfall}) planDeduction(List<Box> boxes, double amount, {required int profileId, required DateTime today})`
- `double daysRemaining(double unitsAvailable, Treatment t)` (∞ → `double.infinity` si dosis 0)
- `List<Box> expiringBoxes(List<Box> boxes, DateTime today, int alertDays)`

- [ ] **Step 1: Tests**
```dart
// cajas A(perfil 1, 4 u, caduca ene), B(compartida, 10 u, caduca dic), C(perfil 1, 10 u, caducada)
planDeduction([A,B,C], 1, profileId:1, today) → [A:1], shortfall 0      // propio antes que compartida
planDeduction([A,B,C], 6, ...) → [A:4, B:2], shortfall 0
planDeduction([C], 1, ...) → [], shortfall 1                             // caducada no cuenta
planDeduction([A], 0.5, ...) → [A:0.5]
daysRemaining(10, interval 8 h, dose 1) closeTo 3.33
expiringBoxes(today+30 incluida, today+31 excluida, archivada excluida)
```
- [ ] **Step 2–4:** FAIL → implementar (orden: perfil propio, luego compartidas; dentro, `expiresOn` asc) → PASS.
- [ ] **Step 5:** Commit `feat(domain): fefo deduction and alerts`.

### Task 4: Base de datos y repositorios

**Files:** Create: `lib/data/db.dart`, `lib/data/profile_repository.dart`, `product_repository.dart`, `box_repository.dart`, `treatment_repository.dart`, `dose_repository.dart`, `settings_repository.dart`, `lib/data/providers.dart`; Test: `test/data/repositories_test.dart`

**Interfaces — Consumes:** modelos de Task 2. **Produces:**
- `Future<Database> openAppDatabase({String? path})` (path null → archivo de la app; tests usan `inMemoryDatabasePath` con ffi)
- `ProductRepository.findByGtin(String gtin14) → Future<Product?>`, `upsert(Product)`
- `BoxRepository.activeForProduct(int productId)`, `insert`, `applyDeductions(List<Deduction>)` (archiva si llega a 0)
- `DoseRepository.insertIgnoreDuplicates(List<Dose>)`, `pendingBetween(DateTime, DateTime)`, `updateStatus(...)`, `forTreatment(int)`
- `DoseRepository.confirmableWithProduct(int productId, DateTime now)` → tomas pendientes en ventana −30 min … +missAfter, con perfil
- Providers Riverpod de cada repositorio en `providers.dart`.

- [ ] **Step 1: Tests:** crear perfil/producto/caja y leerlos; `findByGtin` encuentra; GTIN duplicado lanza; `insertIgnoreDuplicates` dos veces con la misma toma deja 1 fila; `applyDeductions` deja 0 y `archived=1`; FKs activas (`PRAGMA foreign_keys=ON`).
- [ ] **Step 2–4:** FAIL → esquema de SPEC §2 + repos → `flutter test test/data` PASS.
- [ ] **Step 5:** Commit `feat(data): sqlite schema and repositories`.

### Task 5: Servicio de confirmación y programación

**Files:** Create: `lib/services/dose_confirmation_service.dart`, `lib/services/scheduler_service.dart`; Test: `test/data/dose_flow_test.dart`

**Interfaces — Consumes:** Tasks 2–4. **Produces:**
- `DoseConfirmationService.confirm(int doseId, ConfirmMethod method, {DateTime? now}) → Future<ConfirmResult>`; `ConfirmResult { DoseStatus status; double shortfall; bool alreadyConfirmed; }`. Transacción única: clasifica, aplica `planDeduction`, guarda `box_id`, llama `onConfirmed(doseId)` (callback para cancelar notificaciones; inyectado).
- `SchedulerService.refresh({DateTime? now})`: marca `missed` las vencidas y materializa 72 h; devuelve `List<Dose>` nuevas para que Task 7 las programe.

- [ ] **Step 1: Tests:** confirmar a +5 min → onTime y caja baja 1; confirmar dos veces → segunda `alreadyConfirmed=true` y caja intacta; confirmar con inventario 0 → `shortfall=1`, estado guardado; `refresh(now: +5 h)` marca missed la toma vieja sin descontar y crea las siguientes 72 h sin duplicar al llamarlo otra vez.
- [ ] **Step 2–4:** FAIL → implementar → PASS.
- [ ] **Step 5:** Commit `feat: dose confirmation and scheduler`.

### Task 6: Pantallas de perfiles, inventario y tratamientos

**Files:** Create: `lib/router.dart`, `lib/features/home/home_screen.dart`, `lib/features/profiles/{profiles_screen,profile_detail_screen}.dart`, `lib/features/inventory/{inventory_screen,product_form_screen,box_form_screen}.dart`, `lib/features/treatments/treatment_form_screen.dart`

**Interfaces — Consumes:** providers de Task 4, `SchedulerService.refresh`. **Produces:** rutas `/`, `/profiles`, `/profiles/:id`, `/inventory`, `/inventory/product?gtin=`, `/inventory/box?productId=`, `/treatments/new?profileId=`.

- [ ] **Step 1:** Formularios con validación: nombre obligatorio, dosis > 0 y múltiplo de 0.5 en `pza`, caducidad futura (advertencia si ya pasó), al menos un horario en `fixed`.
- [ ] **Step 2:** Inicio muestra tomas de hoy por perfil con color por estado (verde onTime, ámbar late, rojo missed, gris pending) y botón "Confirmar".
- [ ] **Step 3:** Guardar tratamiento llama `SchedulerService.refresh()`.
- [ ] **Step 4: Verificación manual:** crear perfil → producto → caja → tratamiento; ver tomas en Inicio; confirmar baja unidades en Inventario; cerrar y reabrir conserva todo. `flutter analyze` limpio.
- [ ] **Step 5:** Commit `feat(ui): profiles, inventory and treatments`.

### Task 7: Notificaciones

**Files:** Create: `lib/services/notification_service.dart`; Modify: `lib/main.dart`; Test: `test/domain/notification_ids_test.dart`

**Interfaces — Produces:** `int notificationId(int doseId, {bool retry = false})` = `doseId * 2 + (retry ? 1 : 0)`; `NotificationService.init()`, `scheduleDose(Dose, Treatment, Product, Profile)`, `cancelDose(int doseId)`, `scheduleDailyAlerts()`; handler top-level `@pragma('vm:entry-point') void onBackgroundAction(NotificationResponse r)`.

- [ ] **Step 1:** Test de `notificationId` (0→0/1, 7→14/15, sin choques en 1..1000).
- [ ] **Step 2:** `zonedSchedule` con `AndroidScheduleMode.exactAllowWhileIdle`; principal a la hora con acción `confirm` ("Ya la tomé"), reintento a +tolerancia. Título "Toma de <perfil>", cuerpo "<dosis> <unidad> de <producto> · Escanea la caja para confirmar". Tocar la notificación abre `/confirm-scan?doseId=`.
- [ ] **Step 3:** `onBackgroundAction` abre su propia conexión con `openAppDatabase()` y llama `DoseConfirmationService.confirm(id, notification)`; el payload es el `doseId`. Si el isolate falla, usar `showsUserInterface: true` como respaldo.
- [ ] **Step 4:** En `main`: init tz, pedir POST_NOTIFICATIONS y exact alarm (pantalla explicativa si falta), `refresh()` y programar lo nuevo.
- [ ] **Step 5: Verificación manual** (con modo demo de Task 10 o tratamiento a +2 min): llega principal; sin confirmar llega reintento; "Ya la tomé" desde la notificación con la app cerrada → al abrir, toma onTime e inventario descontado.
- [ ] **Step 6:** Commit `feat: local notifications with retry and action`.

### Task 8: Escáner de código de barras

**Files:** Create: `lib/services/scanner_screen.dart` (pantalla reutilizable que hace `pop` con `ScanResult { String gtin14; Gs1Data? gs1; }`), `lib/features/inventory/scan_flows.dart`, `lib/features/home/already_have_screen.dart`; Modify: `home_screen.dart`, `inventory_screen.dart`

**Interfaces — Consumes:** `normalizeGtin`, `parseGs1`, `ProductRepository.findByGtin`. **Produces:** `Future<ScanResult?> scanBarcode(BuildContext)`.

- [ ] **Step 1:** `MobileScanner` limitado a formatos de SPEC §4; mapear `BarcodeFormat` → `BarcodeKind`; descartar lecturas inválidas y requerir 2 lecturas iguales seguidas antes de aceptar; vibración al aceptar; botón linterna; botón "Capturar a mano" (B5).
- [ ] **Step 2:** B2 alta por escaneo, B3 ¿Ya lo tengo?, B6 precarga de caducidad/lote si hay GS1.
- [ ] **Step 3:** Cámara denegada → mensaje y salida a captura manual.
- [ ] **Step 4: Verificación manual:** escanear caja nueva → formulario con GTIN; guardar; reescanear → precargado; "¿Ya lo tengo?" la encuentra; caja no registrada → "No tienes este medicamento".
- [ ] **Step 5:** Commit `feat: barcode registration and lookup`.

### Task 9: Confirmar toma escaneando la caja

**Files:** Create: `lib/features/confirm/confirm_scan_screen.dart`, `lib/features/confirm/pending_picker_sheet.dart`; Modify: `lib/domain/dose_rules.dart`, `home_screen.dart`, `lib/router.dart`; Test: `test/domain/scan_match_test.dart`

**Interfaces — Consumes:** `scanBarcode`, `ProductRepository.findByGtin`, `DoseRepository.confirmableWithProduct`, `DoseConfirmationService.confirm`. **Produces:**
- `enum ScanMatchKind { confirmOne, choose, noPending, unknownProduct, wrongProduct }`
- `ScanMatchKind matchScan({Product? scanned, int? expectedProductId, required List<Dose> confirmable})` (pura)
- ruta `/confirm-scan?doseId=` (doseId opcional = toma preseleccionada)

- [ ] **Step 1: Tests**
```dart
matchScan(scanned: null, confirmable: []) == unknownProduct
matchScan(scanned: ibu, confirmable: []) == noPending
matchScan(scanned: ibu, confirmable: [d1]) == confirmOne
matchScan(scanned: ibu, confirmable: [d1, d2]) == choose
matchScan(scanned: para, expectedProductId: ibu.id, confirmable: [d1]) == wrongProduct
matchScan(scanned: ibu, expectedProductId: ibu.id, confirmable: [d1]) == confirmOne
```
- [ ] **Step 2–4:** FAIL → implementar `matchScan` → PASS.
- [ ] **Step 5:** UI según SPEC §5 con los textos exactos de ahí; `wrongProduct` → diálogo rojo, no confirma; `unknownProduct` → botón a alta B2; botón "Confirmar escaneando" en cada tarjeta de toma pendiente; botón principal en Inicio.
- [ ] **Step 6: Verificación manual:** tratamiento demo → escanear su caja confirma; dos perfiles con el mismo medicamento → aparece selector; caja de otro medicamento → advertencia; tocar notificación abre el escáner con la toma preseleccionada; inventario baja una vez.
- [ ] **Step 7:** Commit `feat: scan-to-confirm doses`.

### Task 10: Historial, alertas, ajustes y modo demo

**Files:** Create: `lib/domain/compliance.dart`, `lib/features/history/history_screen.dart`, `lib/features/settings/settings_screen.dart`, `lib/data/demo_seed.dart`; Test: `test/domain/compliance_test.dart`

**Interfaces — Produces:** `double? compliance(List<Dose> doses)` → (onTime+late)/(onTime+late+missed), null si no hay cerradas; `Future<void> seedDemo(Database)`, `clearDemo(Database)`.

- [ ] **Step 1:** Tests: `[onTime, late, missed, pending]` → 2/3; `[pending]` → null; `[]` → null.
- [ ] **Step 2:** FAIL → implementar → PASS.
- [ ] **Step 3:** Historial por tratamiento; alertas R6 en Inicio; Ajustes con días de alerta, modo demo (SPEC §7) y "Acerca de" con los textos obligatorios.
- [ ] **Step 4: Verificación manual:** activar demo → en ~2 min llega notificación, a +1 min reintento, a +3 min queda omitida; alerta de caducidad visible.
- [ ] **Step 5:** Commit `feat: history, alerts, settings and demo mode`.

### Task 11: Release y repositorio

**Files:** Modify: `README.md`, `android/app/src/main/AndroidManifest.xml`; Create: `docs/screenshots/` (capturas)

- [ ] **Step 1:** Verificar que el manifest merged de release no tiene INTERNET: `flutter build apk --release` y `aapt dump permissions build/app/outputs/flutter-apk/app-release.apk` (o `apkanalyzer manifest permissions`). Si aparece por un paquete, quitarlo con `tools:node="remove"`.
- [ ] **Step 2:** README: descripción, capturas, cómo compilar, permisos y por qué, arquitectura (diagrama de carpetas), equipo, aviso de no diagnóstico.
- [ ] **Step 3:** `flutter analyze` y `flutter test` verdes.
- [ ] **Step 4:** Commit `docs: readme and release build`; tag `v1.0`.
