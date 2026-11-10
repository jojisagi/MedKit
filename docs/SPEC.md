# Mi Botiquín — Especificación (v2, 9 nov 2026)

Equipo Inmóviles: Héctor Armando González Espinosa, Juan Manuel Palafox Valdés, Jorge Sánchez Girón.
Base: propuesta del 2 nov 2026 con dos cambios: (a) el escaneo de código de barras pasa de "desarrollo a futuro" al prototipo; (b) la confirmación por NFC se reemplaza por confirmación escaneando la caja. Motivo, pensando en el usuario: no necesita comprar ni pegar etiquetas, cualquier Android tiene cámara, y escanear la caja verifica que se toma el medicamento correcto (NFC solo identificaba al paciente).

## 1. Alcance
Prototipo Android en Flutter, un solo usuario administra el botiquín y registra perfiles de cada integrante de la familia. Offline total.

**Criterios de éxito (se demuestran al profesor):**
1. Flujo completo sin errores: crear perfil → registrar medicamento (escaneando la caja) → programar tratamiento → recibir recordatorio → confirmar toma → ver inventario actualizado.
2. Cada toma queda como a tiempo / tardía / omitida según la tolerancia.
3. Escanear la caja del medicamento confirma la toma pendiente correcta; escanear una caja equivocada muestra advertencia y no confirma.
4. Escanear una caja ya registrada autocompleta sus datos.
5. El inventario se descuenta en cada toma y persiste al cerrar y reabrir la app.
6. Ningún servicio, API ni biblioteca de pago; APK release sin permiso INTERNET.

**Fuera de alcance:** NFC, sincronización, cuentas, iOS, PDF, foto de receta, PIN/biometría, lista de compras con notificación, guía de desecho (quedan como trabajo futuro en el reporte).

## 2. Modelo de datos (SQLite, `lib/data/db.dart`, versión de esquema 1)
Fechas como INTEGER epoch ms (hora local del dispositivo). Unidades como REAL (permite 0.5).

| Tabla | Columnas |
|---|---|
| `profiles` | id PK, name TEXT NOT NULL, color INTEGER, created_at |
| `products` (catálogo que aprende) | id PK, gtin TEXT UNIQUE NULL, name TEXT NOT NULL, active_ingredient TEXT, strength TEXT ("500 mg"), form TEXT (tableta·cápsula·jarabe·gotas·suspensión·otro), unit TEXT ('pza'·'ml'), units_per_box REAL |
| `boxes` (cada caja física) | id PK, product_id FK, profile_id FK NULL (NULL = compartida), units_initial REAL, units_left REAL, expires_on INTEGER, lot TEXT NULL, added_at, archived INTEGER 0/1 |
| `treatments` | id PK, profile_id FK, product_id FK, dose REAL, schedule_type TEXT ('interval'·'fixed'), interval_hours INTEGER NULL, fixed_times TEXT NULL ("08:00,20:00"), starts_at, ends_at NULL, tolerance_min INTEGER DEFAULT 10, miss_after_min INTEGER DEFAULT 60, notes TEXT, active INTEGER |
| `doses` | id PK, treatment_id FK, scheduled_at, confirmed_at NULL, status TEXT ('pending'·'on_time'·'late'·'missed'), method TEXT NULL ('app'·'notification'·'scan'), box_id FK NULL. UNIQUE(treatment_id, scheduled_at) |
| `settings` | key PK, value TEXT. Claves: `expiry_alert_days`=30, `low_stock_days`=5, `demo_mode`=0 |

## 3. Reglas de negocio
**R1 Estado de una toma** (`toleranceMin`=10, `missAfterMin`=60 por defecto, configurables por tratamiento):
- confirmada ≤ programada + tolerancia → `on_time`
- confirmada ≤ programada + missAfter → `late`
- sin confirmar y ahora > programada + missAfter → `missed` (no descuenta)
- en otro caso → `pending`
- Confirmar antes de la hora programada se permite hasta 30 min antes → `on_time`.

**R2 Recordatorios** por toma: notificación principal a la hora exacta con acción "Ya la tomé"; reintento a +tolerancia si sigue pendiente. Al confirmar se cancelan ambas. La toma se marca `missed` de forma perezosa (al abrir la app o al leer tomas), no con alarma.

**R3 Programación:** se materializan tomas en `doses` para una ventana móvil de 72 h; se recalcula al abrir la app, al crear/editar tratamiento y tras reinicio. `interval`: desde `starts_at` cada N horas. `fixed`: cada día en `fixed_times`. Nada después de `ends_at`.

**R4 Inventario:** al confirmar una toma se descuenta `dose` de las cajas del producto, primero la que caduca antes (FEFO), prefiriendo cajas del mismo perfil y luego compartidas; ignora cajas caducadas o archivadas. Si no alcanza, confirma igual, descuenta lo que haya y muestra aviso "Inventario insuficiente". Caja con `units_left` = 0 se archiva.

**R5 Días restantes** = unidades disponibles del producto para ese perfil ÷ (dosis × tomas por día). Tomas por día: `interval` → 24 / N; `fixed` → número de horarios.

**R6 Alertas** (pantalla Inicio + una notificación diaria a las 9:00): cajas que caducan en ≤ `expiry_alert_days`; tratamientos con días restantes ≤ `low_stock_days`; cajas ya caducadas en rojo.

## 4. Código de barras (nuevo)
Paquete `mobile_scanner` (lectura en el dispositivo, gratuita). Formatos: EAN-13, EAN-8, UPC-A, UPC-E; DataMatrix GS1 como extra.
En México las cajas suelen traer EAN-13 (prefijo 750); UPC-A es el mismo sistema GTIN con 12 dígitos.

- **B1 Normalización:** todo código se guarda como GTIN-14 (relleno con ceros a la izquierda) tras validar dígito verificador. UPC-E se expande a UPC-A antes. Código inválido → "Código no válido, intenta de nuevo o captúralo a mano".
- **B2 Alta por escaneo:** Inventario → "Escanear caja". Si el GTIN existe en `products` → formulario precargado; solo pide caducidad, perfil (o compartida) y unidades si difieren. Si no existe → formulario de producto con GTIN fijado; al guardar se crea producto + caja (el catálogo aprende).
- **B3 ¿Ya lo tengo?:** botón en Inicio. Escanea y muestra cajas activas de ese producto (unidades, caducidad, perfil) o "No tienes este medicamento".
- **B4 Confirmar toma escaneando:** ver §5.
- **B5 Captura manual** del código como respaldo (cámara denegada o código dañado).
- **B6 (extra) GS1 DataMatrix:** si el código trae AIs (01) GTIN, (17) caducidad AAMMDD, (10) lote, se precargan caducidad y lote. Día `00` = último día del mes.

## 5. Confirmar toma escaneando la caja (reemplaza NFC)
Formas de confirmar: botón en la app, acción "Ya la tomé" en la notificación, o escaneo. El escaneo es la forma recomendada porque además verifica el medicamento.
- **Desde Inicio** (botón grande "Escanear para confirmar"): se escanea la caja → se buscan tomas confirmables (ventana −30 min … +missAfter) cuyo producto tenga ese GTIN.
  - 1 coincidencia → confirma con `method='scan'` y muestra "Toma de <perfil> registrada (<estado>)".
  - Varias (p. ej. dos perfiles toman lo mismo) → lista por perfil para elegir.
  - 0 coincidencias pero el producto existe → "No hay tomas pendientes de <medicamento> ahora". Producto desconocido → "Este medicamento no está en tu botiquín" con botón para registrarlo (B2).
- **Desde una toma concreta** (botón "Confirmar escaneando" en la tarjeta de la toma): GTIN coincide → confirma. No coincide → diálogo rojo "Esta caja no corresponde a <medicamento>. Revisa antes de tomarla." y no confirma.
- **Desde la notificación:** el cuerpo incluye "Escanea la caja para confirmar"; tocar la notificación abre directo el escáner con esa toma preseleccionada.
- El descuento sigue FEFO (R4): el código identifica el producto, no la caja física.
- Cámara denegada o código ilegible → siempre queda el botón manual.

## 6. Pantallas
1. **Inicio:** tomas de hoy agrupadas por perfil (estado con color), alertas R6, botón principal "Escanear para confirmar" y secundarios "Registrar caja" y "¿Ya lo tengo?".
2. **Perfiles:** lista → detalle (tratamientos, cumplimiento).
3. **Inventario:** productos con unidades totales, cajas y caducidad; alta manual o por escaneo.
4. **Tratamiento (form):** perfil, producto, dosis (0.5 permitido), tipo de horario, duración, tolerancia, límite de omisión.
5. **Historial:** por tratamiento, lista de tomas con estado y % de cumplimiento = (on_time + late) ÷ (on_time + late + missed).
6. **Ajustes:** días de alerta, modo demo, "Acerca de" con aviso: "Mi Botiquín no diagnostica ni recomienda medicamentos. Consulta siempre a tu médico." y "Tus datos se guardan solo en este teléfono."

## 7. Modo demo (para pruebas con usuarios y presentación)
Ajustes → "Modo demo": carga 2 perfiles, 3 productos, cajas (una que caduca en 10 días) y un tratamiento con toma en +2 min, tolerancia 1 min y omisión a 3 min. Botón "Borrar datos demo".

## 8. Permisos Android
CAMERA, POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM (con pantalla que lleve a ajustes si no está concedido), RECEIVE_BOOT_COMPLETED, VIBRATE. minSdk 23. Pedir cada permiso en el momento de uso, con explicación previa en español.

## 9. Entregables del curso (no son código; contexto)
Reporte en formato de práctica con pruebas con usuarios reales (ver `docs/PRUEBAS_USUARIOS.md`) y conclusiones individuales (importancia de apps móviles para el ingeniero en cibernética; uso ético), repositorio GitHub, presentación ante grupo, demo al profesor.
