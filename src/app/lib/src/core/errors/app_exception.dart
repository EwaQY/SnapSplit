/// 应用异常基类，以密封类显式表达失败，不返回魔术值。
sealed class AppException implements Exception {
  const AppException(this.message);

  /// 人类可读的错误描述。
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// 数据库打开、执行、事务失败。
final class DbException extends AppException {
  const DbException(super.message);
}

/// 按主键/条件查无数据。
final class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// 参数校验失败（如参与人为空、金额非法）。
final class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// 历史周期数据只读，禁止写入。
final class ArchivedReadOnlyException extends AppException {
  const ArchivedReadOnlyException(super.message);
}
