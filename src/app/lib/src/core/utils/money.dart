import '../errors/app_exception.dart';

/// 金额换算：底层以分为单位存储，展示以元为单位。
///
/// 所有分摊、结算计算均使用分为单位的整数，避免浮点误差。

/// 元转分，四舍五入。
int yuanToCents(double yuan) => (yuan * 100).round();

/// 分转元。
double centsToYuan(int cents) => cents / 100.0;

/// 分格式化为元字符串，保留两位小数。
String formatCents(int cents) => (cents / 100).toStringAsFixed(2);

/// 解析用户输入的元字符串为分。
///
/// 允许前后空格与最多两位小数；非法输入抛 [ValidationException]。
int parseYuanToCents(String text) {
  final String normalized = text.trim();
  if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(normalized)) {
    throw ValidationException('金额格式非法：$text');
  }
  final bool negative = normalized.startsWith('-');
  final String digits = negative ? normalized.substring(1) : normalized;
  final List<String> parts = digits.split('.');
  final int cents =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return negative ? -cents : cents;
}
