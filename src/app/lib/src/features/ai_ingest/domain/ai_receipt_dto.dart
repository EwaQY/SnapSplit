import '../../../core/errors/app_exception.dart';

/// AI 识别商品行（原始信息，不持久化）。
class AiReceiptItem {
  const AiReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    this.tag,
  });

  final String name;
  final num quantity;
  final num unitPrice;
  final num amount;
  final String? tag;

  factory AiReceiptItem.fromJson(Map<String, dynamic> json) {
    final String? name = json['name'] as String?;
    final num? amount = json['amount'] as num?;
    if (name == null || name.trim().isEmpty || amount == null) {
      throw ValidationException('AI 商品行缺字段：$json');
    }
    return AiReceiptItem(
      name: name,
      quantity: json['quantity'] as num? ?? 1,
      unitPrice: json['unit_price'] as num? ?? amount,
      amount: amount,
      tag: json['tag'] as String?,
    );
  }
}

/// AI 识别附加费/折扣行（仅用于计算，不持久化）。
class AiAdjustment {
  const AiAdjustment({required this.name, required this.amount});

  /// 附加费为正，折扣为负。
  final String name;
  final num amount;

  factory AiAdjustment.fromJson(Map<String, dynamic> json) {
    final String? name = json['name'] as String?;
    final num? amount = json['amount'] as num?;
    if (name == null || amount == null) {
      throw ValidationException('AI 调整行缺字段：$json');
    }
    return AiAdjustment(name: name, amount: amount);
  }
}

/// AI 单图识别结果（一张图默认一个购物单）。
class AiReceiptDto {
  const AiReceiptDto({
    required this.sourceImageIndex,
    this.merchant,
    this.date,
    required this.items,
    this.surcharges = const <AiAdjustment>[],
    this.discounts = const <AiAdjustment>[],
  });

  final int sourceImageIndex;
  final String? merchant;
  final String? date;
  final List<AiReceiptItem> items;
  final List<AiAdjustment> surcharges;
  final List<AiAdjustment> discounts;

  /// 附加费总额（分，四舍五入）。
  int get surchargeCents => surcharges.fold(
    0,
    (int sum, AiAdjustment e) => sum + (e.amount * 100).round(),
  );

  /// 折扣总额（分，负数，四舍五入）。
  int get discountCents => discounts.fold(
    0,
    (int sum, AiAdjustment e) => sum + (e.amount * 100).round(),
  );

  factory AiReceiptDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? items = json['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      throw ValidationException('AI 识别结果无商品：$json');
    }
    List<AiAdjustment> adjustments(String key) => <AiAdjustment>[
      for (final dynamic raw in (json[key] as List<dynamic>? ?? <dynamic>[]))
        AiAdjustment.fromJson(raw as Map<String, dynamic>),
    ];
    return AiReceiptDto(
      sourceImageIndex: (json['source_image_index'] as num? ?? 0).toInt(),
      merchant: json['merchant'] as String?,
      date: json['date'] as String?,
      items: <AiReceiptItem>[
        for (final dynamic raw in items)
          AiReceiptItem.fromJson(raw as Map<String, dynamic>),
      ],
      surcharges: adjustments('surcharges'),
      discounts: adjustments('discounts'),
    );
  }
}
