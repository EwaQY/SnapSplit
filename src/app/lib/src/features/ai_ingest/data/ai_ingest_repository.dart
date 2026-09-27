import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../shopping/data/shopping_repository.dart';
import '../domain/ai_ingest_service.dart';

/// 确认页单件决策：每件独立设付款人/参与人/分摊/标签。
///
/// - 付款人默认=提交账单的人，由调用方（确认页）填入，可逐件改；
/// - 标签由用户从提前建好的活跃标签里多选传入；
/// - 草稿 [draft] 只提供商品名/数量/单价/最终金额初值与商家名，
///   允许确认页增删改后以 [items] 为准落库。
typedef ConfirmedItem = ({
  String name,
  double quantity,
  int unitPrice,
  int finalAmount,
  String payerId,
  List<String> participantIds,
  Map<String, int>? shares,
  String? note,
  List<String> tagIds,
});

/// AI 确认 Repository：待确认单 → 落库（复用购物单链路，`source = ai`）。
class AiIngestRepository {
  AiIngestRepository(this._shopping);

  final ShoppingRepository _shopping;

  /// 确认保存待确认单（用户已在确认页逐件设好分摊与标签）。
  Future<ShoppingDetail> confirmDraftShopping({
    required String ledgerId,
    required DraftShopping draft,
    required List<ConfirmedItem> items,
    String? title,
    int? occurredAt,
  }) => AppLogger.audit(
    action: 'ai.confirmDraftShopping',
    entity: 'shopping_list',
    run: () {
      if (items.isEmpty) {
        throw ValidationException('待确认单至少包含一个账目');
      }
      return _shopping.createShoppingList(
        ledgerId: ledgerId,
        title: title ?? draft.merchant ?? 'AI 识别购物单',
        merchant: draft.merchant,
        source: 'ai',
        occurredAt: occurredAt,
        items: <NewExpenseItem>[
          for (final ConfirmedItem item in items)
            (
              name: item.name,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              finalAmount: item.finalAmount,
              payerId: item.payerId,
              participantIds: item.participantIds,
              shares: item.shares,
              note: item.note,
              tagIds: item.tagIds,
            ),
        ],
      );
    },
  );
}
