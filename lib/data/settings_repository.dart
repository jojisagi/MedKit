import 'package:sqflite/sqflite.dart';

class AppSettings {
  final int expiryAlertDays;
  final int lowStockDays;
  final bool demoMode;
  const AppSettings({this.expiryAlertDays = 30, this.lowStockDays = 5, this.demoMode = false});
}

class SettingsRepository {
  final DatabaseExecutor db;
  SettingsRepository(this.db);

  Future<String?> get(String key) async {
    final r = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> set(String key, String value) =>
      db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<AppSettings> load() async {
    final rows = await db.query('settings');
    final m = {for (final r in rows) r['key'] as String: r['value'] as String?};
    return AppSettings(
      expiryAlertDays: int.tryParse(m['expiry_alert_days'] ?? '') ?? 30,
      lowStockDays: int.tryParse(m['low_stock_days'] ?? '') ?? 5,
      demoMode: m['demo_mode'] == '1',
    );
  }
}
