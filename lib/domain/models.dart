/// Modelos inmutables (SPEC §2). Fechas como epoch ms en SQLite.
library;

enum DoseStatus { pending, onTime, late, missed }

enum ScheduleType { interval, fixed }

enum ConfirmMethod { app, notification, scan }

const _statusDb = {
  DoseStatus.pending: 'pending',
  DoseStatus.onTime: 'on_time',
  DoseStatus.late: 'late',
  DoseStatus.missed: 'missed',
};

extension DoseStatusDb on DoseStatus {
  String get db => _statusDb[this]!;
  static DoseStatus parse(String v) => _statusDb.entries.firstWhere((e) => e.value == v).key;
}

int? _ms(DateTime? d) => d?.millisecondsSinceEpoch;
DateTime? _dt(Object? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);
double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

const _keep = Object();

class Profile {
  final int? id;
  final String name;
  final int color;
  final DateTime createdAt;

  const Profile({this.id, required this.name, required this.color, required this.createdAt});

  Profile copyWith({int? id, String? name, int? color}) =>
      Profile(id: id ?? this.id, name: name ?? this.name, color: color ?? this.color, createdAt: createdAt);

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'color': color,
    'created_at': _ms(createdAt),
  };

  factory Profile.fromMap(Map<String, Object?> m) => Profile(
    id: m['id'] as int?,
    name: m['name'] as String,
    color: (m['color'] as int?) ?? 0xFF2F6F5E,
    createdAt: _dt(m['created_at']) ?? DateTime.now(),
  );
}

const productForms = ['tableta', 'cápsula', 'jarabe', 'gotas', 'suspensión', 'otro'];

class Product {
  final int? id;
  final String? gtin;
  final String name;
  final String? activeIngredient;
  final String? strength;
  final String form;
  final String unit; // 'pza' | 'ml'
  final double unitsPerBox;

  const Product({
    this.id,
    this.gtin,
    required this.name,
    this.activeIngredient,
    this.strength,
    this.form = 'tableta',
    this.unit = 'pza',
    this.unitsPerBox = 0,
  });

  String get unitLabel => unit == 'ml' ? 'ml' : 'pza';

  Product copyWith({
    int? id,
    Object? gtin = _keep,
    String? name,
    Object? activeIngredient = _keep,
    Object? strength = _keep,
    String? form,
    String? unit,
    double? unitsPerBox,
  }) => Product(
    id: id ?? this.id,
    gtin: identical(gtin, _keep) ? this.gtin : gtin as String?,
    name: name ?? this.name,
    activeIngredient: identical(activeIngredient, _keep) ? this.activeIngredient : activeIngredient as String?,
    strength: identical(strength, _keep) ? this.strength : strength as String?,
    form: form ?? this.form,
    unit: unit ?? this.unit,
    unitsPerBox: unitsPerBox ?? this.unitsPerBox,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'gtin': gtin,
    'name': name,
    'active_ingredient': activeIngredient,
    'strength': strength,
    'form': form,
    'unit': unit,
    'units_per_box': unitsPerBox,
  };

  factory Product.fromMap(Map<String, Object?> m) => Product(
    id: m['id'] as int?,
    gtin: m['gtin'] as String?,
    name: m['name'] as String,
    activeIngredient: m['active_ingredient'] as String?,
    strength: m['strength'] as String?,
    form: (m['form'] as String?) ?? 'otro',
    unit: (m['unit'] as String?) ?? 'pza',
    unitsPerBox: _d(m['units_per_box']),
  );
}

class Box {
  final int? id;
  final int productId;
  final int? profileId; // null = compartida
  final double unitsInitial;
  final double unitsLeft;
  final DateTime expiresOn;
  final String? lot;
  final DateTime addedAt;
  final bool archived;

  const Box({
    this.id,
    required this.productId,
    this.profileId,
    required this.unitsInitial,
    required this.unitsLeft,
    required this.expiresOn,
    this.lot,
    required this.addedAt,
    this.archived = false,
  });

  Box copyWith({int? id, double? unitsLeft, bool? archived, Object? profileId = _keep}) => Box(
    id: id ?? this.id,
    productId: productId,
    profileId: identical(profileId, _keep) ? this.profileId : profileId as int?,
    unitsInitial: unitsInitial,
    unitsLeft: unitsLeft ?? this.unitsLeft,
    expiresOn: expiresOn,
    lot: lot,
    addedAt: addedAt,
    archived: archived ?? this.archived,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'product_id': productId,
    'profile_id': profileId,
    'units_initial': unitsInitial,
    'units_left': unitsLeft,
    'expires_on': _ms(expiresOn),
    'lot': lot,
    'added_at': _ms(addedAt),
    'archived': archived ? 1 : 0,
  };

  factory Box.fromMap(Map<String, Object?> m) => Box(
    id: m['id'] as int?,
    productId: m['product_id'] as int,
    profileId: m['profile_id'] as int?,
    unitsInitial: _d(m['units_initial']),
    unitsLeft: _d(m['units_left']),
    expiresOn: _dt(m['expires_on'])!,
    lot: m['lot'] as String?,
    addedAt: _dt(m['added_at']) ?? DateTime.now(),
    archived: (m['archived'] as int? ?? 0) == 1,
  );
}

class Treatment {
  final int? id;
  final int profileId;
  final int productId;
  final double dose;
  final ScheduleType scheduleType;
  final int? intervalHours;
  final String? fixedTimes; // "08:00,20:00"
  final DateTime startsAt;
  final DateTime? endsAt;
  final int toleranceMin;
  final int missAfterMin;
  final String? notes;
  final bool active;

  const Treatment({
    this.id,
    required this.profileId,
    required this.productId,
    required this.dose,
    required this.scheduleType,
    this.intervalHours,
    this.fixedTimes,
    required this.startsAt,
    this.endsAt,
    this.toleranceMin = 10,
    this.missAfterMin = 60,
    this.notes,
    this.active = true,
  });

  Treatment copyWith({
    int? id,
    double? dose,
    bool? active,
    Object? endsAt = _keep,
    int? toleranceMin,
    int? missAfterMin,
  }) => Treatment(
    id: id ?? this.id,
    profileId: profileId,
    productId: productId,
    dose: dose ?? this.dose,
    scheduleType: scheduleType,
    intervalHours: intervalHours,
    fixedTimes: fixedTimes,
    startsAt: startsAt,
    endsAt: identical(endsAt, _keep) ? this.endsAt : endsAt as DateTime?,
    toleranceMin: toleranceMin ?? this.toleranceMin,
    missAfterMin: missAfterMin ?? this.missAfterMin,
    notes: notes,
    active: active ?? this.active,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'profile_id': profileId,
    'product_id': productId,
    'dose': dose,
    'schedule_type': scheduleType.name,
    'interval_hours': intervalHours,
    'fixed_times': fixedTimes,
    'starts_at': _ms(startsAt),
    'ends_at': _ms(endsAt),
    'tolerance_min': toleranceMin,
    'miss_after_min': missAfterMin,
    'notes': notes,
    'active': active ? 1 : 0,
  };

  factory Treatment.fromMap(Map<String, Object?> m) => Treatment(
    id: m['id'] as int?,
    profileId: m['profile_id'] as int,
    productId: m['product_id'] as int,
    dose: _d(m['dose']),
    scheduleType: ScheduleType.values.byName(m['schedule_type'] as String),
    intervalHours: m['interval_hours'] as int?,
    fixedTimes: m['fixed_times'] as String?,
    startsAt: _dt(m['starts_at'])!,
    endsAt: _dt(m['ends_at']),
    toleranceMin: (m['tolerance_min'] as int?) ?? 10,
    missAfterMin: (m['miss_after_min'] as int?) ?? 60,
    notes: m['notes'] as String?,
    active: (m['active'] as int? ?? 1) == 1,
  );
}

class Dose {
  final int? id;
  final int treatmentId;
  final DateTime scheduledAt;
  final DateTime? confirmedAt;
  final DoseStatus status;
  final ConfirmMethod? method;
  final int? boxId;

  const Dose({
    this.id,
    required this.treatmentId,
    required this.scheduledAt,
    this.confirmedAt,
    this.status = DoseStatus.pending,
    this.method,
    this.boxId,
  });

  bool get isConfirmed => status == DoseStatus.onTime || status == DoseStatus.late;

  Dose copyWith({int? id, DateTime? confirmedAt, DoseStatus? status, ConfirmMethod? method, int? boxId}) => Dose(
    id: id ?? this.id,
    treatmentId: treatmentId,
    scheduledAt: scheduledAt,
    confirmedAt: confirmedAt ?? this.confirmedAt,
    status: status ?? this.status,
    method: method ?? this.method,
    boxId: boxId ?? this.boxId,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'treatment_id': treatmentId,
    'scheduled_at': _ms(scheduledAt),
    'confirmed_at': _ms(confirmedAt),
    'status': status.db,
    'method': method?.name,
    'box_id': boxId,
  };

  factory Dose.fromMap(Map<String, Object?> m) => Dose(
    id: m['id'] as int?,
    treatmentId: m['treatment_id'] as int,
    scheduledAt: _dt(m['scheduled_at'])!,
    confirmedAt: _dt(m['confirmed_at']),
    status: DoseStatusDb.parse(m['status'] as String),
    method: m['method'] == null ? null : ConfirmMethod.values.byName(m['method'] as String),
    boxId: m['box_id'] as int?,
  );
}
