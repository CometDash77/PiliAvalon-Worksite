import 'package:hive_ce/hive.dart';

class ExposureRecord {
  const ExposureRecord({
    required this.bvid,
    required this.exposureCount,
    required this.firstExposedAt,
    required this.lastExposedAt,
    this.coolingStartAt,
  });

  final String bvid;
  final int exposureCount;
  final DateTime firstExposedAt;
  final DateTime lastExposedAt;
  final DateTime? coolingStartAt;

  bool get isCooling => coolingStartAt != null;

  ExposureRecord copyWith({
    String? bvid,
    int? exposureCount,
    DateTime? firstExposedAt,
    DateTime? lastExposedAt,
    DateTime? coolingStartAt,
    bool clearCoolingStartAt = false,
  }) {
    return ExposureRecord(
      bvid: bvid ?? this.bvid,
      exposureCount: exposureCount ?? this.exposureCount,
      firstExposedAt: firstExposedAt ?? this.firstExposedAt,
      lastExposedAt: lastExposedAt ?? this.lastExposedAt,
      coolingStartAt: clearCoolingStartAt
          ? null
          : coolingStartAt ?? this.coolingStartAt,
    );
  }
}

class ExposureTrackerConfig {
  const ExposureTrackerConfig({
    this.enabled = false,
    this.windowDays = 7,
    this.threshold = 10,
    this.coolingDays = 30,
    this.maxCacheSize = 5000,
  });

  final bool enabled;
  final int windowDays;
  final int threshold;
  final int coolingDays;
  final int maxCacheSize;

  ExposureTrackerConfig normalized() => ExposureTrackerConfig(
    enabled: enabled,
    windowDays: windowDays.clamp(1, 30),
    threshold: threshold.clamp(2, 50),
    coolingDays: coolingDays.clamp(1, 90),
    maxCacheSize: maxCacheSize.clamp(1, 50000),
  );
}

class ExposureRecordAdapter extends TypeAdapter<ExposureRecord> {
  @override
  final int typeId = 30;

  @override
  ExposureRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExposureRecord(
      bvid: fields[0] as String,
      exposureCount: fields[1] as int,
      firstExposedAt: DateTime.fromMillisecondsSinceEpoch(fields[2] as int),
      lastExposedAt: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      coolingStartAt: fields[4] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fields[4] as int),
    );
  }

  @override
  void write(BinaryWriter writer, ExposureRecord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.bvid)
      ..writeByte(1)
      ..write(obj.exposureCount)
      ..writeByte(2)
      ..write(obj.firstExposedAt.millisecondsSinceEpoch)
      ..writeByte(3)
      ..write(obj.lastExposedAt.millisecondsSinceEpoch)
      ..writeByte(4)
      ..write(obj.coolingStartAt?.millisecondsSinceEpoch);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExposureRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
