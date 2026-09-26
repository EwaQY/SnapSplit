import '../../../core/errors/app_exception.dart';
import '../../shopping/domain/surcharge_allocator.dart';
import 'ai_receipt_dto.dart';

/// 待确认账目：AI/确认页的可编辑中间态（未落库）。
class DraftItem {
  const DraftItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.finalAmount,
    this.tagNames = const <String>[],
  });

  final String name;
  final int quantity;
  final int unitPrice;
  final int finalAmount;
  final List<String> tagNames;
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
  return DraftShopping(
    sourceImageIndex: dto.sourceImageIndex,
    merchant: dto.merchant,
    items: <DraftItem>[
      for (int i = 0; i < dto.items.length; i++)
        DraftItem(
          name: dto.items[i].name,
          quantity: dto.items[i].quantity.toInt(),
          unitPrice: (dto.items[i].unitPrice * 100).round(),
          finalAmount: baseAmounts[i] + deltas[i],
          tagNames: <String>[
            if (dto.items[i].tag != null && dto.items[i].tag!.trim().isNotEmpty)
              dto.items[i].tag!.trim(),
          ],
        ),
    ],
  );
}
