// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_service.dart';

// ignore_for_file: type=lint
class $FoodsTable extends Foods with TableInfo<$FoodsTable, Food> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _caloriesMeta =
      const VerificationMeta('calories');
  @override
  late final GeneratedColumn<double> calories = GeneratedColumn<double>(
      'calories', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _proteinMeta =
      const VerificationMeta('protein');
  @override
  late final GeneratedColumn<double> protein = GeneratedColumn<double>(
      'protein', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _carbsMeta = const VerificationMeta('carbs');
  @override
  late final GeneratedColumn<double> carbs = GeneratedColumn<double>(
      'carbs', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _fatMeta = const VerificationMeta('fat');
  @override
  late final GeneratedColumn<double> fat = GeneratedColumn<double>(
      'fat', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _mealMeta = const VerificationMeta('meal');
  @override
  late final GeneratedColumn<String> meal = GeneratedColumn<String>(
      'meal', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, calories, protein, carbs, fat, timestamp, meal];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'foods';
  @override
  VerificationContext validateIntegrity(Insertable<Food> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('calories')) {
      context.handle(_caloriesMeta,
          calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta));
    } else if (isInserting) {
      context.missing(_caloriesMeta);
    }
    if (data.containsKey('protein')) {
      context.handle(_proteinMeta,
          protein.isAcceptableOrUnknown(data['protein']!, _proteinMeta));
    } else if (isInserting) {
      context.missing(_proteinMeta);
    }
    if (data.containsKey('carbs')) {
      context.handle(
          _carbsMeta, carbs.isAcceptableOrUnknown(data['carbs']!, _carbsMeta));
    } else if (isInserting) {
      context.missing(_carbsMeta);
    }
    if (data.containsKey('fat')) {
      context.handle(
          _fatMeta, fat.isAcceptableOrUnknown(data['fat']!, _fatMeta));
    } else if (isInserting) {
      context.missing(_fatMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('meal')) {
      context.handle(
          _mealMeta, meal.isAcceptableOrUnknown(data['meal']!, _mealMeta));
    } else if (isInserting) {
      context.missing(_mealMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Food map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Food(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      calories: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}calories'])!,
      protein: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}protein'])!,
      carbs: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}carbs'])!,
      fat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fat'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      meal: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}meal'])!,
    );
  }

  @override
  $FoodsTable createAlias(String alias) {
    return $FoodsTable(attachedDatabase, alias);
  }
}

class Food extends DataClass implements Insertable<Food> {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime timestamp;
  final String meal;
  const Food(
      {required this.id,
      required this.name,
      required this.calories,
      required this.protein,
      required this.carbs,
      required this.fat,
      required this.timestamp,
      required this.meal});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['calories'] = Variable<double>(calories);
    map['protein'] = Variable<double>(protein);
    map['carbs'] = Variable<double>(carbs);
    map['fat'] = Variable<double>(fat);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['meal'] = Variable<String>(meal);
    return map;
  }

  FoodsCompanion toCompanion(bool nullToAbsent) {
    return FoodsCompanion(
      id: Value(id),
      name: Value(name),
      calories: Value(calories),
      protein: Value(protein),
      carbs: Value(carbs),
      fat: Value(fat),
      timestamp: Value(timestamp),
      meal: Value(meal),
    );
  }

  factory Food.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Food(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      calories: serializer.fromJson<double>(json['calories']),
      protein: serializer.fromJson<double>(json['protein']),
      carbs: serializer.fromJson<double>(json['carbs']),
      fat: serializer.fromJson<double>(json['fat']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      meal: serializer.fromJson<String>(json['meal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'calories': serializer.toJson<double>(calories),
      'protein': serializer.toJson<double>(protein),
      'carbs': serializer.toJson<double>(carbs),
      'fat': serializer.toJson<double>(fat),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'meal': serializer.toJson<String>(meal),
    };
  }

  Food copyWith(
          {String? id,
          String? name,
          double? calories,
          double? protein,
          double? carbs,
          double? fat,
          DateTime? timestamp,
          String? meal}) =>
      Food(
        id: id ?? this.id,
        name: name ?? this.name,
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        timestamp: timestamp ?? this.timestamp,
        meal: meal ?? this.meal,
      );
  Food copyWithCompanion(FoodsCompanion data) {
    return Food(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      calories: data.calories.present ? data.calories.value : this.calories,
      protein: data.protein.present ? data.protein.value : this.protein,
      carbs: data.carbs.present ? data.carbs.value : this.carbs,
      fat: data.fat.present ? data.fat.value : this.fat,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      meal: data.meal.present ? data.meal.value : this.meal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Food(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fat: $fat, ')
          ..write('timestamp: $timestamp, ')
          ..write('meal: $meal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, calories, protein, carbs, fat, timestamp, meal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Food &&
          other.id == this.id &&
          other.name == this.name &&
          other.calories == this.calories &&
          other.protein == this.protein &&
          other.carbs == this.carbs &&
          other.fat == this.fat &&
          other.timestamp == this.timestamp &&
          other.meal == this.meal);
}

class FoodsCompanion extends UpdateCompanion<Food> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> calories;
  final Value<double> protein;
  final Value<double> carbs;
  final Value<double> fat;
  final Value<DateTime> timestamp;
  final Value<String> meal;
  final Value<int> rowid;
  const FoodsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.calories = const Value.absent(),
    this.protein = const Value.absent(),
    this.carbs = const Value.absent(),
    this.fat = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.meal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoodsCompanion.insert({
    required String id,
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required DateTime timestamp,
    required String meal,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        calories = Value(calories),
        protein = Value(protein),
        carbs = Value(carbs),
        fat = Value(fat),
        timestamp = Value(timestamp),
        meal = Value(meal);
  static Insertable<Food> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? calories,
    Expression<double>? protein,
    Expression<double>? carbs,
    Expression<double>? fat,
    Expression<DateTime>? timestamp,
    Expression<String>? meal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fat != null) 'fat': fat,
      if (timestamp != null) 'timestamp': timestamp,
      if (meal != null) 'meal': meal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoodsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<double>? calories,
      Value<double>? protein,
      Value<double>? carbs,
      Value<double>? fat,
      Value<DateTime>? timestamp,
      Value<String>? meal,
      Value<int>? rowid}) {
    return FoodsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      timestamp: timestamp ?? this.timestamp,
      meal: meal ?? this.meal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (calories.present) {
      map['calories'] = Variable<double>(calories.value);
    }
    if (protein.present) {
      map['protein'] = Variable<double>(protein.value);
    }
    if (carbs.present) {
      map['carbs'] = Variable<double>(carbs.value);
    }
    if (fat.present) {
      map['fat'] = Variable<double>(fat.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (meal.present) {
      map['meal'] = Variable<String>(meal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fat: $fat, ')
          ..write('timestamp: $timestamp, ')
          ..write('meal: $meal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WaterLogsTable extends WaterLogs
    with TableInfo<$WaterLogsTable, WaterLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WaterLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMlMeta =
      const VerificationMeta('amountMl');
  @override
  late final GeneratedColumn<double> amountMl = GeneratedColumn<double>(
      'amount_ml', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, amountMl, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'water_logs';
  @override
  VerificationContext validateIntegrity(Insertable<WaterLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('amount_ml')) {
      context.handle(_amountMlMeta,
          amountMl.isAcceptableOrUnknown(data['amount_ml']!, _amountMlMeta));
    } else if (isInserting) {
      context.missing(_amountMlMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WaterLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WaterLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      amountMl: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_ml'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $WaterLogsTable createAlias(String alias) {
    return $WaterLogsTable(attachedDatabase, alias);
  }
}

class WaterLog extends DataClass implements Insertable<WaterLog> {
  final String id;
  final double amountMl;
  final DateTime timestamp;
  const WaterLog(
      {required this.id, required this.amountMl, required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['amount_ml'] = Variable<double>(amountMl);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  WaterLogsCompanion toCompanion(bool nullToAbsent) {
    return WaterLogsCompanion(
      id: Value(id),
      amountMl: Value(amountMl),
      timestamp: Value(timestamp),
    );
  }

  factory WaterLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WaterLog(
      id: serializer.fromJson<String>(json['id']),
      amountMl: serializer.fromJson<double>(json['amountMl']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'amountMl': serializer.toJson<double>(amountMl),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  WaterLog copyWith({String? id, double? amountMl, DateTime? timestamp}) =>
      WaterLog(
        id: id ?? this.id,
        amountMl: amountMl ?? this.amountMl,
        timestamp: timestamp ?? this.timestamp,
      );
  WaterLog copyWithCompanion(WaterLogsCompanion data) {
    return WaterLog(
      id: data.id.present ? data.id.value : this.id,
      amountMl: data.amountMl.present ? data.amountMl.value : this.amountMl,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WaterLog(')
          ..write('id: $id, ')
          ..write('amountMl: $amountMl, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, amountMl, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WaterLog &&
          other.id == this.id &&
          other.amountMl == this.amountMl &&
          other.timestamp == this.timestamp);
}

class WaterLogsCompanion extends UpdateCompanion<WaterLog> {
  final Value<String> id;
  final Value<double> amountMl;
  final Value<DateTime> timestamp;
  final Value<int> rowid;
  const WaterLogsCompanion({
    this.id = const Value.absent(),
    this.amountMl = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WaterLogsCompanion.insert({
    required String id,
    required double amountMl,
    required DateTime timestamp,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        amountMl = Value(amountMl),
        timestamp = Value(timestamp);
  static Insertable<WaterLog> custom({
    Expression<String>? id,
    Expression<double>? amountMl,
    Expression<DateTime>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (amountMl != null) 'amount_ml': amountMl,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WaterLogsCompanion copyWith(
      {Value<String>? id,
      Value<double>? amountMl,
      Value<DateTime>? timestamp,
      Value<int>? rowid}) {
    return WaterLogsCompanion(
      id: id ?? this.id,
      amountMl: amountMl ?? this.amountMl,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (amountMl.present) {
      map['amount_ml'] = Variable<double>(amountMl.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WaterLogsCompanion(')
          ..write('id: $id, ')
          ..write('amountMl: $amountMl, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeightLogsTable extends WeightLogs
    with TableInfo<$WeightLogsTable, WeightLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeightLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _weightKgMeta =
      const VerificationMeta('weightKg');
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
      'weight_kg', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual'));
  @override
  List<GeneratedColumn> get $columns => [id, weightKg, timestamp, note, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weight_logs';
  @override
  VerificationContext validateIntegrity(Insertable<WeightLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('weight_kg')) {
      context.handle(_weightKgMeta,
          weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta));
    } else if (isInserting) {
      context.missing(_weightKgMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WeightLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeightLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      weightKg: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}weight_kg'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
    );
  }

  @override
  $WeightLogsTable createAlias(String alias) {
    return $WeightLogsTable(attachedDatabase, alias);
  }
}

class WeightLog extends DataClass implements Insertable<WeightLog> {
  final String id;
  final double weightKg;
  final DateTime timestamp;
  final String? note;
  final String source;
  const WeightLog(
      {required this.id,
      required this.weightKg,
      required this.timestamp,
      this.note,
      required this.source});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['weight_kg'] = Variable<double>(weightKg);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['source'] = Variable<String>(source);
    return map;
  }

  WeightLogsCompanion toCompanion(bool nullToAbsent) {
    return WeightLogsCompanion(
      id: Value(id),
      weightKg: Value(weightKg),
      timestamp: Value(timestamp),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      source: Value(source),
    );
  }

  factory WeightLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeightLog(
      id: serializer.fromJson<String>(json['id']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      note: serializer.fromJson<String?>(json['note']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'weightKg': serializer.toJson<double>(weightKg),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'note': serializer.toJson<String?>(note),
      'source': serializer.toJson<String>(source),
    };
  }

  WeightLog copyWith(
          {String? id,
          double? weightKg,
          DateTime? timestamp,
          Value<String?> note = const Value.absent(),
          String? source}) =>
      WeightLog(
        id: id ?? this.id,
        weightKg: weightKg ?? this.weightKg,
        timestamp: timestamp ?? this.timestamp,
        note: note.present ? note.value : this.note,
        source: source ?? this.source,
      );
  WeightLog copyWithCompanion(WeightLogsCompanion data) {
    return WeightLog(
      id: data.id.present ? data.id.value : this.id,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      note: data.note.present ? data.note.value : this.note,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeightLog(')
          ..write('id: $id, ')
          ..write('weightKg: $weightKg, ')
          ..write('timestamp: $timestamp, ')
          ..write('note: $note, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, weightKg, timestamp, note, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeightLog &&
          other.id == this.id &&
          other.weightKg == this.weightKg &&
          other.timestamp == this.timestamp &&
          other.note == this.note &&
          other.source == this.source);
}

class WeightLogsCompanion extends UpdateCompanion<WeightLog> {
  final Value<String> id;
  final Value<double> weightKg;
  final Value<DateTime> timestamp;
  final Value<String?> note;
  final Value<String> source;
  final Value<int> rowid;
  const WeightLogsCompanion({
    this.id = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.note = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeightLogsCompanion.insert({
    required String id,
    required double weightKg,
    required DateTime timestamp,
    this.note = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        weightKg = Value(weightKg),
        timestamp = Value(timestamp);
  static Insertable<WeightLog> custom({
    Expression<String>? id,
    Expression<double>? weightKg,
    Expression<DateTime>? timestamp,
    Expression<String>? note,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (weightKg != null) 'weight_kg': weightKg,
      if (timestamp != null) 'timestamp': timestamp,
      if (note != null) 'note': note,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeightLogsCompanion copyWith(
      {Value<String>? id,
      Value<double>? weightKg,
      Value<DateTime>? timestamp,
      Value<String?>? note,
      Value<String>? source,
      Value<int>? rowid}) {
    return WeightLogsCompanion(
      id: id ?? this.id,
      weightKg: weightKg ?? this.weightKg,
      timestamp: timestamp ?? this.timestamp,
      note: note ?? this.note,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeightLogsCompanion(')
          ..write('id: $id, ')
          ..write('weightKg: $weightKg, ')
          ..write('timestamp: $timestamp, ')
          ..write('note: $note, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutLogsTable extends WorkoutLogs
    with TableInfo<$WorkoutLogsTable, WorkoutLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _caloriesBurnedMeta =
      const VerificationMeta('caloriesBurned');
  @override
  late final GeneratedColumn<double> caloriesBurned = GeneratedColumn<double>(
      'calories_burned', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, caloriesBurned, timestamp, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_logs';
  @override
  VerificationContext validateIntegrity(Insertable<WorkoutLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('calories_burned')) {
      context.handle(
          _caloriesBurnedMeta,
          caloriesBurned.isAcceptableOrUnknown(
              data['calories_burned']!, _caloriesBurnedMeta));
    } else if (isInserting) {
      context.missing(_caloriesBurnedMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      caloriesBurned: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}calories_burned'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
    );
  }

  @override
  $WorkoutLogsTable createAlias(String alias) {
    return $WorkoutLogsTable(attachedDatabase, alias);
  }
}

class WorkoutLog extends DataClass implements Insertable<WorkoutLog> {
  final String id;
  final double caloriesBurned;
  final DateTime timestamp;
  final String? note;
  const WorkoutLog(
      {required this.id,
      required this.caloriesBurned,
      required this.timestamp,
      this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['calories_burned'] = Variable<double>(caloriesBurned);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  WorkoutLogsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutLogsCompanion(
      id: Value(id),
      caloriesBurned: Value(caloriesBurned),
      timestamp: Value(timestamp),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory WorkoutLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutLog(
      id: serializer.fromJson<String>(json['id']),
      caloriesBurned: serializer.fromJson<double>(json['caloriesBurned']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'caloriesBurned': serializer.toJson<double>(caloriesBurned),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'note': serializer.toJson<String?>(note),
    };
  }

  WorkoutLog copyWith(
          {String? id,
          double? caloriesBurned,
          DateTime? timestamp,
          Value<String?> note = const Value.absent()}) =>
      WorkoutLog(
        id: id ?? this.id,
        caloriesBurned: caloriesBurned ?? this.caloriesBurned,
        timestamp: timestamp ?? this.timestamp,
        note: note.present ? note.value : this.note,
      );
  WorkoutLog copyWithCompanion(WorkoutLogsCompanion data) {
    return WorkoutLog(
      id: data.id.present ? data.id.value : this.id,
      caloriesBurned: data.caloriesBurned.present
          ? data.caloriesBurned.value
          : this.caloriesBurned,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutLog(')
          ..write('id: $id, ')
          ..write('caloriesBurned: $caloriesBurned, ')
          ..write('timestamp: $timestamp, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, caloriesBurned, timestamp, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutLog &&
          other.id == this.id &&
          other.caloriesBurned == this.caloriesBurned &&
          other.timestamp == this.timestamp &&
          other.note == this.note);
}

class WorkoutLogsCompanion extends UpdateCompanion<WorkoutLog> {
  final Value<String> id;
  final Value<double> caloriesBurned;
  final Value<DateTime> timestamp;
  final Value<String?> note;
  final Value<int> rowid;
  const WorkoutLogsCompanion({
    this.id = const Value.absent(),
    this.caloriesBurned = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutLogsCompanion.insert({
    required String id,
    required double caloriesBurned,
    required DateTime timestamp,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        caloriesBurned = Value(caloriesBurned),
        timestamp = Value(timestamp);
  static Insertable<WorkoutLog> custom({
    Expression<String>? id,
    Expression<double>? caloriesBurned,
    Expression<DateTime>? timestamp,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (caloriesBurned != null) 'calories_burned': caloriesBurned,
      if (timestamp != null) 'timestamp': timestamp,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutLogsCompanion copyWith(
      {Value<String>? id,
      Value<double>? caloriesBurned,
      Value<DateTime>? timestamp,
      Value<String?>? note,
      Value<int>? rowid}) {
    return WorkoutLogsCompanion(
      id: id ?? this.id,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      timestamp: timestamp ?? this.timestamp,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (caloriesBurned.present) {
      map['calories_burned'] = Variable<double>(caloriesBurned.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutLogsCompanion(')
          ..write('id: $id, ')
          ..write('caloriesBurned: $caloriesBurned, ')
          ..write('timestamp: $timestamp, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SupplementDefinitionsTable extends SupplementDefinitions
    with TableInfo<$SupplementDefinitionsTable, SupplementDefinition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SupplementDefinitionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reminderTimeMeta =
      const VerificationMeta('reminderTime');
  @override
  late final GeneratedColumn<String> reminderTime = GeneratedColumn<String>(
      'reminder_time', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, reminderTime, enabled, sortOrder, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'supplement_definitions';
  @override
  VerificationContext validateIntegrity(
      Insertable<SupplementDefinition> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('reminder_time')) {
      context.handle(
          _reminderTimeMeta,
          reminderTime.isAcceptableOrUnknown(
              data['reminder_time']!, _reminderTimeMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SupplementDefinition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SupplementDefinition(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      reminderTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reminder_time']),
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SupplementDefinitionsTable createAlias(String alias) {
    return $SupplementDefinitionsTable(attachedDatabase, alias);
  }
}

class SupplementDefinition extends DataClass
    implements Insertable<SupplementDefinition> {
  final String id;
  final String name;
  final String? reminderTime;
  final bool enabled;
  final int sortOrder;
  final DateTime createdAt;
  const SupplementDefinition(
      {required this.id,
      required this.name,
      this.reminderTime,
      required this.enabled,
      required this.sortOrder,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || reminderTime != null) {
      map['reminder_time'] = Variable<String>(reminderTime);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SupplementDefinitionsCompanion toCompanion(bool nullToAbsent) {
    return SupplementDefinitionsCompanion(
      id: Value(id),
      name: Value(name),
      reminderTime: reminderTime == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderTime),
      enabled: Value(enabled),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory SupplementDefinition.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SupplementDefinition(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      reminderTime: serializer.fromJson<String?>(json['reminderTime']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'reminderTime': serializer.toJson<String?>(reminderTime),
      'enabled': serializer.toJson<bool>(enabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SupplementDefinition copyWith(
          {String? id,
          String? name,
          Value<String?> reminderTime = const Value.absent(),
          bool? enabled,
          int? sortOrder,
          DateTime? createdAt}) =>
      SupplementDefinition(
        id: id ?? this.id,
        name: name ?? this.name,
        reminderTime:
            reminderTime.present ? reminderTime.value : this.reminderTime,
        enabled: enabled ?? this.enabled,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
      );
  SupplementDefinition copyWithCompanion(SupplementDefinitionsCompanion data) {
    return SupplementDefinition(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      reminderTime: data.reminderTime.present
          ? data.reminderTime.value
          : this.reminderTime,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SupplementDefinition(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, reminderTime, enabled, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SupplementDefinition &&
          other.id == this.id &&
          other.name == this.name &&
          other.reminderTime == this.reminderTime &&
          other.enabled == this.enabled &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class SupplementDefinitionsCompanion
    extends UpdateCompanion<SupplementDefinition> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> reminderTime;
  final Value<bool> enabled;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SupplementDefinitionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.reminderTime = const Value.absent(),
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SupplementDefinitionsCompanion.insert({
    required String id,
    required String name,
    this.reminderTime = const Value.absent(),
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAt = Value(createdAt);
  static Insertable<SupplementDefinition> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? reminderTime,
    Expression<bool>? enabled,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (reminderTime != null) 'reminder_time': reminderTime,
      if (enabled != null) 'enabled': enabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SupplementDefinitionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? reminderTime,
      Value<bool>? enabled,
      Value<int>? sortOrder,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return SupplementDefinitionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      reminderTime: reminderTime ?? this.reminderTime,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (reminderTime.present) {
      map['reminder_time'] = Variable<String>(reminderTime.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SupplementDefinitionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SupplementLogsTable extends SupplementLogs
    with TableInfo<$SupplementLogsTable, SupplementLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SupplementLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _supplementIdMeta =
      const VerificationMeta('supplementId');
  @override
  late final GeneratedColumn<String> supplementId = GeneratedColumn<String>(
      'supplement_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, supplementId, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'supplement_logs';
  @override
  VerificationContext validateIntegrity(Insertable<SupplementLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('supplement_id')) {
      context.handle(
          _supplementIdMeta,
          supplementId.isAcceptableOrUnknown(
              data['supplement_id']!, _supplementIdMeta));
    } else if (isInserting) {
      context.missing(_supplementIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SupplementLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SupplementLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      supplementId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}supplement_id'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $SupplementLogsTable createAlias(String alias) {
    return $SupplementLogsTable(attachedDatabase, alias);
  }
}

class SupplementLog extends DataClass implements Insertable<SupplementLog> {
  final String id;
  final String supplementId;
  final DateTime timestamp;
  const SupplementLog(
      {required this.id, required this.supplementId, required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['supplement_id'] = Variable<String>(supplementId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  SupplementLogsCompanion toCompanion(bool nullToAbsent) {
    return SupplementLogsCompanion(
      id: Value(id),
      supplementId: Value(supplementId),
      timestamp: Value(timestamp),
    );
  }

  factory SupplementLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SupplementLog(
      id: serializer.fromJson<String>(json['id']),
      supplementId: serializer.fromJson<String>(json['supplementId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'supplementId': serializer.toJson<String>(supplementId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  SupplementLog copyWith(
          {String? id, String? supplementId, DateTime? timestamp}) =>
      SupplementLog(
        id: id ?? this.id,
        supplementId: supplementId ?? this.supplementId,
        timestamp: timestamp ?? this.timestamp,
      );
  SupplementLog copyWithCompanion(SupplementLogsCompanion data) {
    return SupplementLog(
      id: data.id.present ? data.id.value : this.id,
      supplementId: data.supplementId.present
          ? data.supplementId.value
          : this.supplementId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SupplementLog(')
          ..write('id: $id, ')
          ..write('supplementId: $supplementId, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, supplementId, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SupplementLog &&
          other.id == this.id &&
          other.supplementId == this.supplementId &&
          other.timestamp == this.timestamp);
}

class SupplementLogsCompanion extends UpdateCompanion<SupplementLog> {
  final Value<String> id;
  final Value<String> supplementId;
  final Value<DateTime> timestamp;
  final Value<int> rowid;
  const SupplementLogsCompanion({
    this.id = const Value.absent(),
    this.supplementId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SupplementLogsCompanion.insert({
    required String id,
    required String supplementId,
    required DateTime timestamp,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        supplementId = Value(supplementId),
        timestamp = Value(timestamp);
  static Insertable<SupplementLog> custom({
    Expression<String>? id,
    Expression<String>? supplementId,
    Expression<DateTime>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supplementId != null) 'supplement_id': supplementId,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SupplementLogsCompanion copyWith(
      {Value<String>? id,
      Value<String>? supplementId,
      Value<DateTime>? timestamp,
      Value<int>? rowid}) {
    return SupplementLogsCompanion(
      id: id ?? this.id,
      supplementId: supplementId ?? this.supplementId,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (supplementId.present) {
      map['supplement_id'] = Variable<String>(supplementId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SupplementLogsCompanion(')
          ..write('id: $id, ')
          ..write('supplementId: $supplementId, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BarcodeProductsTable extends BarcodeProducts
    with TableInfo<$BarcodeProductsTable, BarcodeProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BarcodeProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _barcodeMeta =
      const VerificationMeta('barcode');
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
      'barcode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
      'brand', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _caloriesPer100gMeta =
      const VerificationMeta('caloriesPer100g');
  @override
  late final GeneratedColumn<double> caloriesPer100g = GeneratedColumn<double>(
      'calories_per100g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _proteinPer100gMeta =
      const VerificationMeta('proteinPer100g');
  @override
  late final GeneratedColumn<double> proteinPer100g = GeneratedColumn<double>(
      'protein_per100g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _carbsPer100gMeta =
      const VerificationMeta('carbsPer100g');
  @override
  late final GeneratedColumn<double> carbsPer100g = GeneratedColumn<double>(
      'carbs_per100g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _fatPer100gMeta =
      const VerificationMeta('fatPer100g');
  @override
  late final GeneratedColumn<double> fatPer100g = GeneratedColumn<double>(
      'fat_per100g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _servingsJsonMeta =
      const VerificationMeta('servingsJson');
  @override
  late final GeneratedColumn<String> servingsJson = GeneratedColumn<String>(
      'servings_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isUserCorrectedMeta =
      const VerificationMeta('isUserCorrected');
  @override
  late final GeneratedColumn<bool> isUserCorrected = GeneratedColumn<bool>(
      'is_user_corrected', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_user_corrected" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('api'));
  @override
  List<GeneratedColumn> get $columns => [
        barcode,
        name,
        brand,
        category,
        caloriesPer100g,
        proteinPer100g,
        carbsPer100g,
        fatPer100g,
        imageUrl,
        servingsJson,
        isUserCorrected,
        cachedAt,
        source
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'barcode_products';
  @override
  VerificationContext validateIntegrity(Insertable<BarcodeProduct> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('barcode')) {
      context.handle(_barcodeMeta,
          barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta));
    } else if (isInserting) {
      context.missing(_barcodeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(
          _brandMeta, brand.isAcceptableOrUnknown(data['brand']!, _brandMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('calories_per100g')) {
      context.handle(
          _caloriesPer100gMeta,
          caloriesPer100g.isAcceptableOrUnknown(
              data['calories_per100g']!, _caloriesPer100gMeta));
    } else if (isInserting) {
      context.missing(_caloriesPer100gMeta);
    }
    if (data.containsKey('protein_per100g')) {
      context.handle(
          _proteinPer100gMeta,
          proteinPer100g.isAcceptableOrUnknown(
              data['protein_per100g']!, _proteinPer100gMeta));
    } else if (isInserting) {
      context.missing(_proteinPer100gMeta);
    }
    if (data.containsKey('carbs_per100g')) {
      context.handle(
          _carbsPer100gMeta,
          carbsPer100g.isAcceptableOrUnknown(
              data['carbs_per100g']!, _carbsPer100gMeta));
    } else if (isInserting) {
      context.missing(_carbsPer100gMeta);
    }
    if (data.containsKey('fat_per100g')) {
      context.handle(
          _fatPer100gMeta,
          fatPer100g.isAcceptableOrUnknown(
              data['fat_per100g']!, _fatPer100gMeta));
    } else if (isInserting) {
      context.missing(_fatPer100gMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('servings_json')) {
      context.handle(
          _servingsJsonMeta,
          servingsJson.isAcceptableOrUnknown(
              data['servings_json']!, _servingsJsonMeta));
    }
    if (data.containsKey('is_user_corrected')) {
      context.handle(
          _isUserCorrectedMeta,
          isUserCorrected.isAcceptableOrUnknown(
              data['is_user_corrected']!, _isUserCorrectedMeta));
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {barcode};
  @override
  BarcodeProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BarcodeProduct(
      barcode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}barcode'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      brand: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brand']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      caloriesPer100g: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}calories_per100g'])!,
      proteinPer100g: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}protein_per100g'])!,
      carbsPer100g: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}carbs_per100g'])!,
      fatPer100g: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fat_per100g'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      servingsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}servings_json']),
      isUserCorrected: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_user_corrected'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
    );
  }

  @override
  $BarcodeProductsTable createAlias(String alias) {
    return $BarcodeProductsTable(attachedDatabase, alias);
  }
}

class BarcodeProduct extends DataClass implements Insertable<BarcodeProduct> {
  final String barcode;
  final String name;
  final String? brand;
  final String? category;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final String? imageUrl;
  final String? servingsJson;
  final bool isUserCorrected;
  final DateTime cachedAt;
  final String source;
  const BarcodeProduct(
      {required this.barcode,
      required this.name,
      this.brand,
      this.category,
      required this.caloriesPer100g,
      required this.proteinPer100g,
      required this.carbsPer100g,
      required this.fatPer100g,
      this.imageUrl,
      this.servingsJson,
      required this.isUserCorrected,
      required this.cachedAt,
      required this.source});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['barcode'] = Variable<String>(barcode);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['calories_per100g'] = Variable<double>(caloriesPer100g);
    map['protein_per100g'] = Variable<double>(proteinPer100g);
    map['carbs_per100g'] = Variable<double>(carbsPer100g);
    map['fat_per100g'] = Variable<double>(fatPer100g);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || servingsJson != null) {
      map['servings_json'] = Variable<String>(servingsJson);
    }
    map['is_user_corrected'] = Variable<bool>(isUserCorrected);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    map['source'] = Variable<String>(source);
    return map;
  }

  BarcodeProductsCompanion toCompanion(bool nullToAbsent) {
    return BarcodeProductsCompanion(
      barcode: Value(barcode),
      name: Value(name),
      brand:
          brand == null && nullToAbsent ? const Value.absent() : Value(brand),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      caloriesPer100g: Value(caloriesPer100g),
      proteinPer100g: Value(proteinPer100g),
      carbsPer100g: Value(carbsPer100g),
      fatPer100g: Value(fatPer100g),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      servingsJson: servingsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(servingsJson),
      isUserCorrected: Value(isUserCorrected),
      cachedAt: Value(cachedAt),
      source: Value(source),
    );
  }

  factory BarcodeProduct.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BarcodeProduct(
      barcode: serializer.fromJson<String>(json['barcode']),
      name: serializer.fromJson<String>(json['name']),
      brand: serializer.fromJson<String?>(json['brand']),
      category: serializer.fromJson<String?>(json['category']),
      caloriesPer100g: serializer.fromJson<double>(json['caloriesPer100g']),
      proteinPer100g: serializer.fromJson<double>(json['proteinPer100g']),
      carbsPer100g: serializer.fromJson<double>(json['carbsPer100g']),
      fatPer100g: serializer.fromJson<double>(json['fatPer100g']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      servingsJson: serializer.fromJson<String?>(json['servingsJson']),
      isUserCorrected: serializer.fromJson<bool>(json['isUserCorrected']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'barcode': serializer.toJson<String>(barcode),
      'name': serializer.toJson<String>(name),
      'brand': serializer.toJson<String?>(brand),
      'category': serializer.toJson<String?>(category),
      'caloriesPer100g': serializer.toJson<double>(caloriesPer100g),
      'proteinPer100g': serializer.toJson<double>(proteinPer100g),
      'carbsPer100g': serializer.toJson<double>(carbsPer100g),
      'fatPer100g': serializer.toJson<double>(fatPer100g),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'servingsJson': serializer.toJson<String?>(servingsJson),
      'isUserCorrected': serializer.toJson<bool>(isUserCorrected),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'source': serializer.toJson<String>(source),
    };
  }

  BarcodeProduct copyWith(
          {String? barcode,
          String? name,
          Value<String?> brand = const Value.absent(),
          Value<String?> category = const Value.absent(),
          double? caloriesPer100g,
          double? proteinPer100g,
          double? carbsPer100g,
          double? fatPer100g,
          Value<String?> imageUrl = const Value.absent(),
          Value<String?> servingsJson = const Value.absent(),
          bool? isUserCorrected,
          DateTime? cachedAt,
          String? source}) =>
      BarcodeProduct(
        barcode: barcode ?? this.barcode,
        name: name ?? this.name,
        brand: brand.present ? brand.value : this.brand,
        category: category.present ? category.value : this.category,
        caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
        proteinPer100g: proteinPer100g ?? this.proteinPer100g,
        carbsPer100g: carbsPer100g ?? this.carbsPer100g,
        fatPer100g: fatPer100g ?? this.fatPer100g,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        servingsJson:
            servingsJson.present ? servingsJson.value : this.servingsJson,
        isUserCorrected: isUserCorrected ?? this.isUserCorrected,
        cachedAt: cachedAt ?? this.cachedAt,
        source: source ?? this.source,
      );
  BarcodeProduct copyWithCompanion(BarcodeProductsCompanion data) {
    return BarcodeProduct(
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      name: data.name.present ? data.name.value : this.name,
      brand: data.brand.present ? data.brand.value : this.brand,
      category: data.category.present ? data.category.value : this.category,
      caloriesPer100g: data.caloriesPer100g.present
          ? data.caloriesPer100g.value
          : this.caloriesPer100g,
      proteinPer100g: data.proteinPer100g.present
          ? data.proteinPer100g.value
          : this.proteinPer100g,
      carbsPer100g: data.carbsPer100g.present
          ? data.carbsPer100g.value
          : this.carbsPer100g,
      fatPer100g:
          data.fatPer100g.present ? data.fatPer100g.value : this.fatPer100g,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      servingsJson: data.servingsJson.present
          ? data.servingsJson.value
          : this.servingsJson,
      isUserCorrected: data.isUserCorrected.present
          ? data.isUserCorrected.value
          : this.isUserCorrected,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BarcodeProduct(')
          ..write('barcode: $barcode, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('category: $category, ')
          ..write('caloriesPer100g: $caloriesPer100g, ')
          ..write('proteinPer100g: $proteinPer100g, ')
          ..write('carbsPer100g: $carbsPer100g, ')
          ..write('fatPer100g: $fatPer100g, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('servingsJson: $servingsJson, ')
          ..write('isUserCorrected: $isUserCorrected, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      barcode,
      name,
      brand,
      category,
      caloriesPer100g,
      proteinPer100g,
      carbsPer100g,
      fatPer100g,
      imageUrl,
      servingsJson,
      isUserCorrected,
      cachedAt,
      source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BarcodeProduct &&
          other.barcode == this.barcode &&
          other.name == this.name &&
          other.brand == this.brand &&
          other.category == this.category &&
          other.caloriesPer100g == this.caloriesPer100g &&
          other.proteinPer100g == this.proteinPer100g &&
          other.carbsPer100g == this.carbsPer100g &&
          other.fatPer100g == this.fatPer100g &&
          other.imageUrl == this.imageUrl &&
          other.servingsJson == this.servingsJson &&
          other.isUserCorrected == this.isUserCorrected &&
          other.cachedAt == this.cachedAt &&
          other.source == this.source);
}

class BarcodeProductsCompanion extends UpdateCompanion<BarcodeProduct> {
  final Value<String> barcode;
  final Value<String> name;
  final Value<String?> brand;
  final Value<String?> category;
  final Value<double> caloriesPer100g;
  final Value<double> proteinPer100g;
  final Value<double> carbsPer100g;
  final Value<double> fatPer100g;
  final Value<String?> imageUrl;
  final Value<String?> servingsJson;
  final Value<bool> isUserCorrected;
  final Value<DateTime> cachedAt;
  final Value<String> source;
  final Value<int> rowid;
  const BarcodeProductsCompanion({
    this.barcode = const Value.absent(),
    this.name = const Value.absent(),
    this.brand = const Value.absent(),
    this.category = const Value.absent(),
    this.caloriesPer100g = const Value.absent(),
    this.proteinPer100g = const Value.absent(),
    this.carbsPer100g = const Value.absent(),
    this.fatPer100g = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.servingsJson = const Value.absent(),
    this.isUserCorrected = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BarcodeProductsCompanion.insert({
    required String barcode,
    required String name,
    this.brand = const Value.absent(),
    this.category = const Value.absent(),
    required double caloriesPer100g,
    required double proteinPer100g,
    required double carbsPer100g,
    required double fatPer100g,
    this.imageUrl = const Value.absent(),
    this.servingsJson = const Value.absent(),
    this.isUserCorrected = const Value.absent(),
    required DateTime cachedAt,
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : barcode = Value(barcode),
        name = Value(name),
        caloriesPer100g = Value(caloriesPer100g),
        proteinPer100g = Value(proteinPer100g),
        carbsPer100g = Value(carbsPer100g),
        fatPer100g = Value(fatPer100g),
        cachedAt = Value(cachedAt);
  static Insertable<BarcodeProduct> custom({
    Expression<String>? barcode,
    Expression<String>? name,
    Expression<String>? brand,
    Expression<String>? category,
    Expression<double>? caloriesPer100g,
    Expression<double>? proteinPer100g,
    Expression<double>? carbsPer100g,
    Expression<double>? fatPer100g,
    Expression<String>? imageUrl,
    Expression<String>? servingsJson,
    Expression<bool>? isUserCorrected,
    Expression<DateTime>? cachedAt,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (barcode != null) 'barcode': barcode,
      if (name != null) 'name': name,
      if (brand != null) 'brand': brand,
      if (category != null) 'category': category,
      if (caloriesPer100g != null) 'calories_per100g': caloriesPer100g,
      if (proteinPer100g != null) 'protein_per100g': proteinPer100g,
      if (carbsPer100g != null) 'carbs_per100g': carbsPer100g,
      if (fatPer100g != null) 'fat_per100g': fatPer100g,
      if (imageUrl != null) 'image_url': imageUrl,
      if (servingsJson != null) 'servings_json': servingsJson,
      if (isUserCorrected != null) 'is_user_corrected': isUserCorrected,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BarcodeProductsCompanion copyWith(
      {Value<String>? barcode,
      Value<String>? name,
      Value<String?>? brand,
      Value<String?>? category,
      Value<double>? caloriesPer100g,
      Value<double>? proteinPer100g,
      Value<double>? carbsPer100g,
      Value<double>? fatPer100g,
      Value<String?>? imageUrl,
      Value<String?>? servingsJson,
      Value<bool>? isUserCorrected,
      Value<DateTime>? cachedAt,
      Value<String>? source,
      Value<int>? rowid}) {
    return BarcodeProductsCompanion(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      imageUrl: imageUrl ?? this.imageUrl,
      servingsJson: servingsJson ?? this.servingsJson,
      isUserCorrected: isUserCorrected ?? this.isUserCorrected,
      cachedAt: cachedAt ?? this.cachedAt,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (caloriesPer100g.present) {
      map['calories_per100g'] = Variable<double>(caloriesPer100g.value);
    }
    if (proteinPer100g.present) {
      map['protein_per100g'] = Variable<double>(proteinPer100g.value);
    }
    if (carbsPer100g.present) {
      map['carbs_per100g'] = Variable<double>(carbsPer100g.value);
    }
    if (fatPer100g.present) {
      map['fat_per100g'] = Variable<double>(fatPer100g.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (servingsJson.present) {
      map['servings_json'] = Variable<String>(servingsJson.value);
    }
    if (isUserCorrected.present) {
      map['is_user_corrected'] = Variable<bool>(isUserCorrected.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BarcodeProductsCompanion(')
          ..write('barcode: $barcode, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('category: $category, ')
          ..write('caloriesPer100g: $caloriesPer100g, ')
          ..write('proteinPer100g: $proteinPer100g, ')
          ..write('carbsPer100g: $carbsPer100g, ')
          ..write('fatPer100g: $fatPer100g, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('servingsJson: $servingsJson, ')
          ..write('isUserCorrected: $isUserCorrected, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DatabaseService extends GeneratedDatabase {
  _$DatabaseService(QueryExecutor e) : super(e);
  $DatabaseServiceManager get managers => $DatabaseServiceManager(this);
  late final $FoodsTable foods = $FoodsTable(this);
  late final $WaterLogsTable waterLogs = $WaterLogsTable(this);
  late final $WeightLogsTable weightLogs = $WeightLogsTable(this);
  late final $WorkoutLogsTable workoutLogs = $WorkoutLogsTable(this);
  late final $SupplementDefinitionsTable supplementDefinitions =
      $SupplementDefinitionsTable(this);
  late final $SupplementLogsTable supplementLogs = $SupplementLogsTable(this);
  late final $BarcodeProductsTable barcodeProducts =
      $BarcodeProductsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        foods,
        waterLogs,
        weightLogs,
        workoutLogs,
        supplementDefinitions,
        supplementLogs,
        barcodeProducts
      ];
}

typedef $$FoodsTableCreateCompanionBuilder = FoodsCompanion Function({
  required String id,
  required String name,
  required double calories,
  required double protein,
  required double carbs,
  required double fat,
  required DateTime timestamp,
  required String meal,
  Value<int> rowid,
});
typedef $$FoodsTableUpdateCompanionBuilder = FoodsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<double> calories,
  Value<double> protein,
  Value<double> carbs,
  Value<double> fat,
  Value<DateTime> timestamp,
  Value<String> meal,
  Value<int> rowid,
});

class $$FoodsTableFilterComposer
    extends Composer<_$DatabaseService, $FoodsTable> {
  $$FoodsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get calories => $composableBuilder(
      column: $table.calories, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get protein => $composableBuilder(
      column: $table.protein, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get carbs => $composableBuilder(
      column: $table.carbs, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get fat => $composableBuilder(
      column: $table.fat, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get meal => $composableBuilder(
      column: $table.meal, builder: (column) => ColumnFilters(column));
}

class $$FoodsTableOrderingComposer
    extends Composer<_$DatabaseService, $FoodsTable> {
  $$FoodsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get calories => $composableBuilder(
      column: $table.calories, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get protein => $composableBuilder(
      column: $table.protein, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get carbs => $composableBuilder(
      column: $table.carbs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get fat => $composableBuilder(
      column: $table.fat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get meal => $composableBuilder(
      column: $table.meal, builder: (column) => ColumnOrderings(column));
}

class $$FoodsTableAnnotationComposer
    extends Composer<_$DatabaseService, $FoodsTable> {
  $$FoodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  GeneratedColumn<double> get protein =>
      $composableBuilder(column: $table.protein, builder: (column) => column);

  GeneratedColumn<double> get carbs =>
      $composableBuilder(column: $table.carbs, builder: (column) => column);

  GeneratedColumn<double> get fat =>
      $composableBuilder(column: $table.fat, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get meal =>
      $composableBuilder(column: $table.meal, builder: (column) => column);
}

class $$FoodsTableTableManager extends RootTableManager<
    _$DatabaseService,
    $FoodsTable,
    Food,
    $$FoodsTableFilterComposer,
    $$FoodsTableOrderingComposer,
    $$FoodsTableAnnotationComposer,
    $$FoodsTableCreateCompanionBuilder,
    $$FoodsTableUpdateCompanionBuilder,
    (Food, BaseReferences<_$DatabaseService, $FoodsTable, Food>),
    Food,
    PrefetchHooks Function()> {
  $$FoodsTableTableManager(_$DatabaseService db, $FoodsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> calories = const Value.absent(),
            Value<double> protein = const Value.absent(),
            Value<double> carbs = const Value.absent(),
            Value<double> fat = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String> meal = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FoodsCompanion(
            id: id,
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            timestamp: timestamp,
            meal: meal,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required double calories,
            required double protein,
            required double carbs,
            required double fat,
            required DateTime timestamp,
            required String meal,
            Value<int> rowid = const Value.absent(),
          }) =>
              FoodsCompanion.insert(
            id: id,
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            timestamp: timestamp,
            meal: meal,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FoodsTableProcessedTableManager = ProcessedTableManager<
    _$DatabaseService,
    $FoodsTable,
    Food,
    $$FoodsTableFilterComposer,
    $$FoodsTableOrderingComposer,
    $$FoodsTableAnnotationComposer,
    $$FoodsTableCreateCompanionBuilder,
    $$FoodsTableUpdateCompanionBuilder,
    (Food, BaseReferences<_$DatabaseService, $FoodsTable, Food>),
    Food,
    PrefetchHooks Function()>;
typedef $$WaterLogsTableCreateCompanionBuilder = WaterLogsCompanion Function({
  required String id,
  required double amountMl,
  required DateTime timestamp,
  Value<int> rowid,
});
typedef $$WaterLogsTableUpdateCompanionBuilder = WaterLogsCompanion Function({
  Value<String> id,
  Value<double> amountMl,
  Value<DateTime> timestamp,
  Value<int> rowid,
});

class $$WaterLogsTableFilterComposer
    extends Composer<_$DatabaseService, $WaterLogsTable> {
  $$WaterLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountMl => $composableBuilder(
      column: $table.amountMl, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$WaterLogsTableOrderingComposer
    extends Composer<_$DatabaseService, $WaterLogsTable> {
  $$WaterLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountMl => $composableBuilder(
      column: $table.amountMl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$WaterLogsTableAnnotationComposer
    extends Composer<_$DatabaseService, $WaterLogsTable> {
  $$WaterLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get amountMl =>
      $composableBuilder(column: $table.amountMl, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$WaterLogsTableTableManager extends RootTableManager<
    _$DatabaseService,
    $WaterLogsTable,
    WaterLog,
    $$WaterLogsTableFilterComposer,
    $$WaterLogsTableOrderingComposer,
    $$WaterLogsTableAnnotationComposer,
    $$WaterLogsTableCreateCompanionBuilder,
    $$WaterLogsTableUpdateCompanionBuilder,
    (WaterLog, BaseReferences<_$DatabaseService, $WaterLogsTable, WaterLog>),
    WaterLog,
    PrefetchHooks Function()> {
  $$WaterLogsTableTableManager(_$DatabaseService db, $WaterLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WaterLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WaterLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WaterLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<double> amountMl = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WaterLogsCompanion(
            id: id,
            amountMl: amountMl,
            timestamp: timestamp,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required double amountMl,
            required DateTime timestamp,
            Value<int> rowid = const Value.absent(),
          }) =>
              WaterLogsCompanion.insert(
            id: id,
            amountMl: amountMl,
            timestamp: timestamp,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WaterLogsTableProcessedTableManager = ProcessedTableManager<
    _$DatabaseService,
    $WaterLogsTable,
    WaterLog,
    $$WaterLogsTableFilterComposer,
    $$WaterLogsTableOrderingComposer,
    $$WaterLogsTableAnnotationComposer,
    $$WaterLogsTableCreateCompanionBuilder,
    $$WaterLogsTableUpdateCompanionBuilder,
    (WaterLog, BaseReferences<_$DatabaseService, $WaterLogsTable, WaterLog>),
    WaterLog,
    PrefetchHooks Function()>;
typedef $$WeightLogsTableCreateCompanionBuilder = WeightLogsCompanion Function({
  required String id,
  required double weightKg,
  required DateTime timestamp,
  Value<String?> note,
  Value<String> source,
  Value<int> rowid,
});
typedef $$WeightLogsTableUpdateCompanionBuilder = WeightLogsCompanion Function({
  Value<String> id,
  Value<double> weightKg,
  Value<DateTime> timestamp,
  Value<String?> note,
  Value<String> source,
  Value<int> rowid,
});

class $$WeightLogsTableFilterComposer
    extends Composer<_$DatabaseService, $WeightLogsTable> {
  $$WeightLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get weightKg => $composableBuilder(
      column: $table.weightKg, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));
}

class $$WeightLogsTableOrderingComposer
    extends Composer<_$DatabaseService, $WeightLogsTable> {
  $$WeightLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get weightKg => $composableBuilder(
      column: $table.weightKg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));
}

class $$WeightLogsTableAnnotationComposer
    extends Composer<_$DatabaseService, $WeightLogsTable> {
  $$WeightLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$WeightLogsTableTableManager extends RootTableManager<
    _$DatabaseService,
    $WeightLogsTable,
    WeightLog,
    $$WeightLogsTableFilterComposer,
    $$WeightLogsTableOrderingComposer,
    $$WeightLogsTableAnnotationComposer,
    $$WeightLogsTableCreateCompanionBuilder,
    $$WeightLogsTableUpdateCompanionBuilder,
    (WeightLog, BaseReferences<_$DatabaseService, $WeightLogsTable, WeightLog>),
    WeightLog,
    PrefetchHooks Function()> {
  $$WeightLogsTableTableManager(_$DatabaseService db, $WeightLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeightLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeightLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeightLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<double> weightKg = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WeightLogsCompanion(
            id: id,
            weightKg: weightKg,
            timestamp: timestamp,
            note: note,
            source: source,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required double weightKg,
            required DateTime timestamp,
            Value<String?> note = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WeightLogsCompanion.insert(
            id: id,
            weightKg: weightKg,
            timestamp: timestamp,
            note: note,
            source: source,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WeightLogsTableProcessedTableManager = ProcessedTableManager<
    _$DatabaseService,
    $WeightLogsTable,
    WeightLog,
    $$WeightLogsTableFilterComposer,
    $$WeightLogsTableOrderingComposer,
    $$WeightLogsTableAnnotationComposer,
    $$WeightLogsTableCreateCompanionBuilder,
    $$WeightLogsTableUpdateCompanionBuilder,
    (WeightLog, BaseReferences<_$DatabaseService, $WeightLogsTable, WeightLog>),
    WeightLog,
    PrefetchHooks Function()>;
typedef $$WorkoutLogsTableCreateCompanionBuilder = WorkoutLogsCompanion
    Function({
  required String id,
  required double caloriesBurned,
  required DateTime timestamp,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$WorkoutLogsTableUpdateCompanionBuilder = WorkoutLogsCompanion
    Function({
  Value<String> id,
  Value<double> caloriesBurned,
  Value<DateTime> timestamp,
  Value<String?> note,
  Value<int> rowid,
});

class $$WorkoutLogsTableFilterComposer
    extends Composer<_$DatabaseService, $WorkoutLogsTable> {
  $$WorkoutLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get caloriesBurned => $composableBuilder(
      column: $table.caloriesBurned,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));
}

class $$WorkoutLogsTableOrderingComposer
    extends Composer<_$DatabaseService, $WorkoutLogsTable> {
  $$WorkoutLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get caloriesBurned => $composableBuilder(
      column: $table.caloriesBurned,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));
}

class $$WorkoutLogsTableAnnotationComposer
    extends Composer<_$DatabaseService, $WorkoutLogsTable> {
  $$WorkoutLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get caloriesBurned => $composableBuilder(
      column: $table.caloriesBurned, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$WorkoutLogsTableTableManager extends RootTableManager<
    _$DatabaseService,
    $WorkoutLogsTable,
    WorkoutLog,
    $$WorkoutLogsTableFilterComposer,
    $$WorkoutLogsTableOrderingComposer,
    $$WorkoutLogsTableAnnotationComposer,
    $$WorkoutLogsTableCreateCompanionBuilder,
    $$WorkoutLogsTableUpdateCompanionBuilder,
    (
      WorkoutLog,
      BaseReferences<_$DatabaseService, $WorkoutLogsTable, WorkoutLog>
    ),
    WorkoutLog,
    PrefetchHooks Function()> {
  $$WorkoutLogsTableTableManager(_$DatabaseService db, $WorkoutLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<double> caloriesBurned = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkoutLogsCompanion(
            id: id,
            caloriesBurned: caloriesBurned,
            timestamp: timestamp,
            note: note,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required double caloriesBurned,
            required DateTime timestamp,
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkoutLogsCompanion.insert(
            id: id,
            caloriesBurned: caloriesBurned,
            timestamp: timestamp,
            note: note,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WorkoutLogsTableProcessedTableManager = ProcessedTableManager<
    _$DatabaseService,
    $WorkoutLogsTable,
    WorkoutLog,
    $$WorkoutLogsTableFilterComposer,
    $$WorkoutLogsTableOrderingComposer,
    $$WorkoutLogsTableAnnotationComposer,
    $$WorkoutLogsTableCreateCompanionBuilder,
    $$WorkoutLogsTableUpdateCompanionBuilder,
    (
      WorkoutLog,
      BaseReferences<_$DatabaseService, $WorkoutLogsTable, WorkoutLog>
    ),
    WorkoutLog,
    PrefetchHooks Function()>;
typedef $$SupplementDefinitionsTableCreateCompanionBuilder
    = SupplementDefinitionsCompanion Function({
  required String id,
  required String name,
  Value<String?> reminderTime,
  Value<bool> enabled,
  Value<int> sortOrder,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$SupplementDefinitionsTableUpdateCompanionBuilder
    = SupplementDefinitionsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> reminderTime,
  Value<bool> enabled,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$SupplementDefinitionsTableFilterComposer
    extends Composer<_$DatabaseService, $SupplementDefinitionsTable> {
  $$SupplementDefinitionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reminderTime => $composableBuilder(
      column: $table.reminderTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SupplementDefinitionsTableOrderingComposer
    extends Composer<_$DatabaseService, $SupplementDefinitionsTable> {
  $$SupplementDefinitionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reminderTime => $composableBuilder(
      column: $table.reminderTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SupplementDefinitionsTableAnnotationComposer
    extends Composer<_$DatabaseService, $SupplementDefinitionsTable> {
  $$SupplementDefinitionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get reminderTime => $composableBuilder(
      column: $table.reminderTime, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SupplementDefinitionsTableTableManager extends RootTableManager<
    _$DatabaseService,
    $SupplementDefinitionsTable,
    SupplementDefinition,
    $$SupplementDefinitionsTableFilterComposer,
    $$SupplementDefinitionsTableOrderingComposer,
    $$SupplementDefinitionsTableAnnotationComposer,
    $$SupplementDefinitionsTableCreateCompanionBuilder,
    $$SupplementDefinitionsTableUpdateCompanionBuilder,
    (
      SupplementDefinition,
      BaseReferences<_$DatabaseService, $SupplementDefinitionsTable,
          SupplementDefinition>
    ),
    SupplementDefinition,
    PrefetchHooks Function()> {
  $$SupplementDefinitionsTableTableManager(
      _$DatabaseService db, $SupplementDefinitionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SupplementDefinitionsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$SupplementDefinitionsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SupplementDefinitionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> reminderTime = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SupplementDefinitionsCompanion(
            id: id,
            name: name,
            reminderTime: reminderTime,
            enabled: enabled,
            sortOrder: sortOrder,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> reminderTime = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SupplementDefinitionsCompanion.insert(
            id: id,
            name: name,
            reminderTime: reminderTime,
            enabled: enabled,
            sortOrder: sortOrder,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SupplementDefinitionsTableProcessedTableManager
    = ProcessedTableManager<
        _$DatabaseService,
        $SupplementDefinitionsTable,
        SupplementDefinition,
        $$SupplementDefinitionsTableFilterComposer,
        $$SupplementDefinitionsTableOrderingComposer,
        $$SupplementDefinitionsTableAnnotationComposer,
        $$SupplementDefinitionsTableCreateCompanionBuilder,
        $$SupplementDefinitionsTableUpdateCompanionBuilder,
        (
          SupplementDefinition,
          BaseReferences<_$DatabaseService, $SupplementDefinitionsTable,
              SupplementDefinition>
        ),
        SupplementDefinition,
        PrefetchHooks Function()>;
typedef $$SupplementLogsTableCreateCompanionBuilder = SupplementLogsCompanion
    Function({
  required String id,
  required String supplementId,
  required DateTime timestamp,
  Value<int> rowid,
});
typedef $$SupplementLogsTableUpdateCompanionBuilder = SupplementLogsCompanion
    Function({
  Value<String> id,
  Value<String> supplementId,
  Value<DateTime> timestamp,
  Value<int> rowid,
});

class $$SupplementLogsTableFilterComposer
    extends Composer<_$DatabaseService, $SupplementLogsTable> {
  $$SupplementLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get supplementId => $composableBuilder(
      column: $table.supplementId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$SupplementLogsTableOrderingComposer
    extends Composer<_$DatabaseService, $SupplementLogsTable> {
  $$SupplementLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get supplementId => $composableBuilder(
      column: $table.supplementId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$SupplementLogsTableAnnotationComposer
    extends Composer<_$DatabaseService, $SupplementLogsTable> {
  $$SupplementLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supplementId => $composableBuilder(
      column: $table.supplementId, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$SupplementLogsTableTableManager extends RootTableManager<
    _$DatabaseService,
    $SupplementLogsTable,
    SupplementLog,
    $$SupplementLogsTableFilterComposer,
    $$SupplementLogsTableOrderingComposer,
    $$SupplementLogsTableAnnotationComposer,
    $$SupplementLogsTableCreateCompanionBuilder,
    $$SupplementLogsTableUpdateCompanionBuilder,
    (
      SupplementLog,
      BaseReferences<_$DatabaseService, $SupplementLogsTable, SupplementLog>
    ),
    SupplementLog,
    PrefetchHooks Function()> {
  $$SupplementLogsTableTableManager(
      _$DatabaseService db, $SupplementLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SupplementLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SupplementLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SupplementLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> supplementId = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SupplementLogsCompanion(
            id: id,
            supplementId: supplementId,
            timestamp: timestamp,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String supplementId,
            required DateTime timestamp,
            Value<int> rowid = const Value.absent(),
          }) =>
              SupplementLogsCompanion.insert(
            id: id,
            supplementId: supplementId,
            timestamp: timestamp,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SupplementLogsTableProcessedTableManager = ProcessedTableManager<
    _$DatabaseService,
    $SupplementLogsTable,
    SupplementLog,
    $$SupplementLogsTableFilterComposer,
    $$SupplementLogsTableOrderingComposer,
    $$SupplementLogsTableAnnotationComposer,
    $$SupplementLogsTableCreateCompanionBuilder,
    $$SupplementLogsTableUpdateCompanionBuilder,
    (
      SupplementLog,
      BaseReferences<_$DatabaseService, $SupplementLogsTable, SupplementLog>
    ),
    SupplementLog,
    PrefetchHooks Function()>;
typedef $$BarcodeProductsTableCreateCompanionBuilder = BarcodeProductsCompanion
    Function({
  required String barcode,
  required String name,
  Value<String?> brand,
  Value<String?> category,
  required double caloriesPer100g,
  required double proteinPer100g,
  required double carbsPer100g,
  required double fatPer100g,
  Value<String?> imageUrl,
  Value<String?> servingsJson,
  Value<bool> isUserCorrected,
  required DateTime cachedAt,
  Value<String> source,
  Value<int> rowid,
});
typedef $$BarcodeProductsTableUpdateCompanionBuilder = BarcodeProductsCompanion
    Function({
  Value<String> barcode,
  Value<String> name,
  Value<String?> brand,
  Value<String?> category,
  Value<double> caloriesPer100g,
  Value<double> proteinPer100g,
  Value<double> carbsPer100g,
  Value<double> fatPer100g,
  Value<String?> imageUrl,
  Value<String?> servingsJson,
  Value<bool> isUserCorrected,
  Value<DateTime> cachedAt,
  Value<String> source,
  Value<int> rowid,
});

class $$BarcodeProductsTableFilterComposer
    extends Composer<_$DatabaseService, $BarcodeProductsTable> {
  $$BarcodeProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get brand => $composableBuilder(
      column: $table.brand, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get caloriesPer100g => $composableBuilder(
      column: $table.caloriesPer100g,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get proteinPer100g => $composableBuilder(
      column: $table.proteinPer100g,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get carbsPer100g => $composableBuilder(
      column: $table.carbsPer100g, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get fatPer100g => $composableBuilder(
      column: $table.fatPer100g, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get servingsJson => $composableBuilder(
      column: $table.servingsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isUserCorrected => $composableBuilder(
      column: $table.isUserCorrected,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));
}

class $$BarcodeProductsTableOrderingComposer
    extends Composer<_$DatabaseService, $BarcodeProductsTable> {
  $$BarcodeProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get brand => $composableBuilder(
      column: $table.brand, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get caloriesPer100g => $composableBuilder(
      column: $table.caloriesPer100g,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get proteinPer100g => $composableBuilder(
      column: $table.proteinPer100g,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get carbsPer100g => $composableBuilder(
      column: $table.carbsPer100g,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get fatPer100g => $composableBuilder(
      column: $table.fatPer100g, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get servingsJson => $composableBuilder(
      column: $table.servingsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isUserCorrected => $composableBuilder(
      column: $table.isUserCorrected,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));
}

class $$BarcodeProductsTableAnnotationComposer
    extends Composer<_$DatabaseService, $BarcodeProductsTable> {
  $$BarcodeProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get caloriesPer100g => $composableBuilder(
      column: $table.caloriesPer100g, builder: (column) => column);

  GeneratedColumn<double> get proteinPer100g => $composableBuilder(
      column: $table.proteinPer100g, builder: (column) => column);

  GeneratedColumn<double> get carbsPer100g => $composableBuilder(
      column: $table.carbsPer100g, builder: (column) => column);

  GeneratedColumn<double> get fatPer100g => $composableBuilder(
      column: $table.fatPer100g, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get servingsJson => $composableBuilder(
      column: $table.servingsJson, builder: (column) => column);

  GeneratedColumn<bool> get isUserCorrected => $composableBuilder(
      column: $table.isUserCorrected, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$BarcodeProductsTableTableManager extends RootTableManager<
    _$DatabaseService,
    $BarcodeProductsTable,
    BarcodeProduct,
    $$BarcodeProductsTableFilterComposer,
    $$BarcodeProductsTableOrderingComposer,
    $$BarcodeProductsTableAnnotationComposer,
    $$BarcodeProductsTableCreateCompanionBuilder,
    $$BarcodeProductsTableUpdateCompanionBuilder,
    (
      BarcodeProduct,
      BaseReferences<_$DatabaseService, $BarcodeProductsTable, BarcodeProduct>
    ),
    BarcodeProduct,
    PrefetchHooks Function()> {
  $$BarcodeProductsTableTableManager(
      _$DatabaseService db, $BarcodeProductsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BarcodeProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BarcodeProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BarcodeProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> barcode = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> brand = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<double> caloriesPer100g = const Value.absent(),
            Value<double> proteinPer100g = const Value.absent(),
            Value<double> carbsPer100g = const Value.absent(),
            Value<double> fatPer100g = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> servingsJson = const Value.absent(),
            Value<bool> isUserCorrected = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BarcodeProductsCompanion(
            barcode: barcode,
            name: name,
            brand: brand,
            category: category,
            caloriesPer100g: caloriesPer100g,
            proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g,
            imageUrl: imageUrl,
            servingsJson: servingsJson,
            isUserCorrected: isUserCorrected,
            cachedAt: cachedAt,
            source: source,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String barcode,
            required String name,
            Value<String?> brand = const Value.absent(),
            Value<String?> category = const Value.absent(),
            required double caloriesPer100g,
            required double proteinPer100g,
            required double carbsPer100g,
            required double fatPer100g,
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> servingsJson = const Value.absent(),
            Value<bool> isUserCorrected = const Value.absent(),
            required DateTime cachedAt,
            Value<String> source = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BarcodeProductsCompanion.insert(
            barcode: barcode,
            name: name,
            brand: brand,
            category: category,
            caloriesPer100g: caloriesPer100g,
            proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g,
            imageUrl: imageUrl,
            servingsJson: servingsJson,
            isUserCorrected: isUserCorrected,
            cachedAt: cachedAt,
            source: source,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BarcodeProductsTableProcessedTableManager = ProcessedTableManager<
    _$DatabaseService,
    $BarcodeProductsTable,
    BarcodeProduct,
    $$BarcodeProductsTableFilterComposer,
    $$BarcodeProductsTableOrderingComposer,
    $$BarcodeProductsTableAnnotationComposer,
    $$BarcodeProductsTableCreateCompanionBuilder,
    $$BarcodeProductsTableUpdateCompanionBuilder,
    (
      BarcodeProduct,
      BaseReferences<_$DatabaseService, $BarcodeProductsTable, BarcodeProduct>
    ),
    BarcodeProduct,
    PrefetchHooks Function()>;

class $DatabaseServiceManager {
  final _$DatabaseService _db;
  $DatabaseServiceManager(this._db);
  $$FoodsTableTableManager get foods =>
      $$FoodsTableTableManager(_db, _db.foods);
  $$WaterLogsTableTableManager get waterLogs =>
      $$WaterLogsTableTableManager(_db, _db.waterLogs);
  $$WeightLogsTableTableManager get weightLogs =>
      $$WeightLogsTableTableManager(_db, _db.weightLogs);
  $$WorkoutLogsTableTableManager get workoutLogs =>
      $$WorkoutLogsTableTableManager(_db, _db.workoutLogs);
  $$SupplementDefinitionsTableTableManager get supplementDefinitions =>
      $$SupplementDefinitionsTableTableManager(_db, _db.supplementDefinitions);
  $$SupplementLogsTableTableManager get supplementLogs =>
      $$SupplementLogsTableTableManager(_db, _db.supplementLogs);
  $$BarcodeProductsTableTableManager get barcodeProducts =>
      $$BarcodeProductsTableTableManager(_db, _db.barcodeProducts);
}
