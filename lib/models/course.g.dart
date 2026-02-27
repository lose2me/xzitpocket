import 'package:hive/hive.dart';
import 'course.dart';

class CourseAdapter extends TypeAdapter<Course> {
  @override
  final int typeId = 0;

  @override
  Course read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Course(
      title: fields[0] as String,
      teacher: fields[1] as String,
      weekday: fields[2] as int,
      sessions: (fields[3] as List).cast<int>(),
      weeks: (fields[4] as List).cast<int>(),
      campus: fields[5] as String,
      place: fields[6] as String,
      colorIndex: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Course obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.teacher)
      ..writeByte(2)
      ..write(obj.weekday)
      ..writeByte(3)
      ..write(obj.sessions)
      ..writeByte(4)
      ..write(obj.weeks)
      ..writeByte(5)
      ..write(obj.campus)
      ..writeByte(6)
      ..write(obj.place)
      ..writeByte(7)
      ..write(obj.colorIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
