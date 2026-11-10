import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const schemaVersion = 1;
const dbFileName = 'mi_botiquin.db';

/// Abre la base local. [path] = null → archivo privado de la app.
/// En pruebas: `databaseFactory = databaseFactoryFfi` y `path: inMemoryDatabasePath`.
Future<Database> openAppDatabase({String? path}) async {
  final file = path ?? p.join(await getDatabasesPath(), dbFileName);
  return openDatabase(
    file,
    version: schemaVersion,
    singleInstance: path != inMemoryDatabasePath,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, _) async {
      final b = db.batch();
      for (final sql in _schema) {
        b.execute(sql);
      }
      await b.commit(noResult: true);
    },
  );
}

const _schema = [
  '''CREATE TABLE profiles(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    color INTEGER,
    created_at INTEGER NOT NULL
  )''',
  '''CREATE TABLE products(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    gtin TEXT UNIQUE,
    name TEXT NOT NULL,
    active_ingredient TEXT,
    strength TEXT,
    form TEXT,
    unit TEXT NOT NULL DEFAULT 'pza',
    units_per_box REAL
  )''',
  '''CREATE TABLE boxes(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    profile_id INTEGER REFERENCES profiles(id) ON DELETE SET NULL,
    units_initial REAL NOT NULL,
    units_left REAL NOT NULL,
    expires_on INTEGER NOT NULL,
    lot TEXT,
    added_at INTEGER NOT NULL,
    archived INTEGER NOT NULL DEFAULT 0
  )''',
  '''CREATE TABLE treatments(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    dose REAL NOT NULL,
    schedule_type TEXT NOT NULL CHECK(schedule_type IN ('interval','fixed')),
    interval_hours INTEGER,
    fixed_times TEXT,
    starts_at INTEGER NOT NULL,
    ends_at INTEGER,
    tolerance_min INTEGER NOT NULL DEFAULT 10,
    miss_after_min INTEGER NOT NULL DEFAULT 60,
    notes TEXT,
    active INTEGER NOT NULL DEFAULT 1
  )''',
  '''CREATE TABLE doses(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    treatment_id INTEGER NOT NULL REFERENCES treatments(id) ON DELETE CASCADE,
    scheduled_at INTEGER NOT NULL,
    confirmed_at INTEGER,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','on_time','late','missed')),
    method TEXT CHECK(method IS NULL OR method IN ('app','notification','scan')),
    box_id INTEGER REFERENCES boxes(id) ON DELETE SET NULL,
    UNIQUE(treatment_id, scheduled_at)
  )''',
  'CREATE INDEX idx_doses_sched ON doses(scheduled_at)',
  'CREATE INDEX idx_boxes_product ON boxes(product_id)',
  '''CREATE TABLE settings(
    key TEXT PRIMARY KEY,
    value TEXT
  )''',
  "INSERT INTO settings(key, value) VALUES ('expiry_alert_days','30'), ('low_stock_days','5'), ('demo_mode','0')",
];
