import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../shopping/domain/surcharge_allocator.dart';
import 'ai_receipt_dto.dart';

/// 待确认账目：AI/本地OCR/手动的商品草稿（未落库，无标签/分摊归属）。
class DraftItem {
  const DraftItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.finalAmount,
  });

  final String name;

  /// 计费数量（按件为整数值，称重为小数，如 0.32）。
  final double quantity;
  final int unitPrice;
  final int finalAmount;
}

/// 待确认购物单：一张图一个，未落库。
class DraftShopping {
  const DraftShopping({
    required this.sourceImageIndex,
    this.merchant,
    required this.items,
  });

  final int sourceImageIndex;
  final String? merchant;
  final List<DraftItem> items;
}

/// AI 确认服务：DTO → 待确认单（纯函数，无 DB 依赖）。
///
/// - 数量×单价与总价冲突以总价为准（`amount` 即原始金额）；
/// - `surcharges` + `discounts` 按商品原始金额比例摊入最终金额；
/// - 只产出增量结果，不持久化中间字段。
DraftShopping toDraftShopping(AiReceiptDto dto) {
  if (dto.items.isEmpty) {
    throw ValidationException('AI 识别结果无商品');
  }
  final List<int> baseAmounts = <int>[
    for (final AiReceiptItem item in dto.items) (item.amount * 100).round(),
  ];
  final int adjustment = dto.surchargeCents + dto.discountCents;
  final List<int> deltas = allocateAdjustment(
    adjustment: adjustment,
    baseAmounts: baseAmounts,
  );
  final int baseTotal = baseAmounts.fold(0, (int a, int b) => a + b);
  AppLogger.info(
    'ai.adjust items=${dto.items.length} base=$baseTotal分 '
    'disc=${dto.discountCents}分 sur=${dto.surchargeCents}分 '
    'final=${baseTotal + adjustment}分',
  );
  return DraftShopping(
    sourceImageIndex: dto.sourceImageIndex,
    merchant: dto.merchant,
    items: <DraftItem>[
      for (int i = 0; i < dto.items.length; i++)
        DraftItem(
          name: dto.items[i].name,
          quantity: dto.items[i].quantity.toDouble(),
          unitPrice: (dto.items[i].unitPrice * 100).round(),
          finalAmount: baseAmounts[i] + deltas[i],
        ),
    ],
  );
}
