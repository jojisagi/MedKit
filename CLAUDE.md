# Mi Botiquín — guía para Claude Code

App Flutter (solo Android) para inventario de medicamentos del hogar, tratamientos por paciente y recordatorios de tomas. 100 % offline: SQLite local, sin APIs, sin servicios de pago.

## Dónde está cada cosa
- Qué construir y reglas de negocio: `docs/SPEC.md` (leer solo la sección que pida la tarea)
- Orden de trabajo: `docs/superpowers/plans/2026-11-09-mi-botiquin.md`
- `docs/PRUEBAS_USUARIOS.md` NO es para código; no lo leas salvo que se pida.

## Stack fijo (no agregar paquetes sin preguntar)
flutter_riverpod (sin codegen) · sqflite (+ sqflite_common_ffi solo en tests) · flutter_local_notifications + timezone + flutter_timezone · mobile_scanner · go_router · intl

## Estructura
```
lib/domain/    lógica pura en Dart, sin Flutter ni IO (aquí van casi todos los tests)
lib/data/      db.dart (esquema), *_repository.dart
lib/services/  notifications, scanner, dose_confirmation
lib/features/<pantalla>/  UI + providers de esa pantalla
test/domain/   test/data/
```

## Comandos
- Tests rápidos: `flutter test test/domain`
- Todos: `flutter test` · Lint: `flutter analyze`
- Correr: `flutter run` (dispositivo físico: la cámara del emulador no sirve para escanear)
- APK: `flutter build apk --release`

## Reglas de trabajo (ahorro de tokens)
1. Una tarea del plan por sesión. Al terminar: tests verdes → commit → el usuario hará `/clear`.
2. Lee solo los archivos listados en la tarea; no explores `build/`, `.dart_tool/`, `android/.gradle/`.
3. Edita con cambios puntuales; no reescribas archivos completos.
4. Respuestas breves: qué cambió y resultado de tests. Sin explicar código obvio.
5. TDD en `lib/domain/` y `lib/data/`. En UI basta verificación manual descrita en la tarea.
6. Identificadores en inglés; textos de UI en español de México.
7. Si una decisión no está en SPEC ni en el plan, elige lo más simple y anótalo en el commit.

## Reglas de producto que nunca se rompen
- La app no diagnostica ni recomienda medicamentos; solo organiza lo que captura el usuario.
- Sin permiso INTERNET en release. Ningún dato sale del teléfono.
- Una toma solo descuenta inventario al confirmarse (nunca al omitirse).
