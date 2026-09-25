import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// 生成新主键（UUID v4）。
String newId() => _uuid.v4();
