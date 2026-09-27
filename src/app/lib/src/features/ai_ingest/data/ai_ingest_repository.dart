import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../shopping/data/shopping_repository.dart';
import '../../tags/data/tag_repository.dart';
import '../domain/ai_ingest_service.dart';

/// AI 确认 Repository：待确认单 → 落库（复用购物单链路，`source = ai`）。
///
/// 标签名解析：已存在则复用，不存在则新建（全局共享）。
class AiIngestRepository {
  AiIngestRepository(this._shopping, this._tags);

  final ShoppingRepository _shopping;
  final TagRepository _tags;

  /// 确认保存待确认单（用户可在调用前自行增删改 [draft]）。
  Future<ShoppingDetail> confirmDraftShopping({
    required String ledgerId,
    required DraftShopping draft,
    required String payerId,
    required List<String> participantIds,
    String? title,
    int? occurredAt,
  }) => AppLogger.audit(
    action: 'ai.confirmDraftShopping',
    entity: 'shopping_list',
    run: () async {
      if (draft.items.isEmpty) {
        throw ValidationException('待确认单至少包含一个账目');
      }
      final List<NewExpenseItem> items = <NewExpenseItem>[];
      for (final DraftItem item in draft.items) {
        final List<String> tagIds = <String>[];
        for (final String name in item.tagNames.toSet()) {
          tagIds.add(await _resolveTagId(name));
        }
        items.add(
          (
            name: item.name,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            finalAmount: item.finalAmount,
            payerId: payerId,
            participantIds: participantIds,
            shares: null,
            note: null,
            tagIds: tagIds,
          ),
        );
      }
      return _shopping.createShoppingList(
        ledgerId: ledgerId,
        title: title ?? draft.merchant ?? 'AI 识别购物单',
        merchant: draft.merchant,
        source: 'ai',
        occurredAt: occurredAt,
        items: items,
      );
    },
  );

  Future<String> _resolveTagId(String name) async {
    final List<Tag> active = await _tags.listAllTags();
    for (final Tag tag in active) {
      if (tag.name == name) {
        return tag.id;
      }
    }
    return (await _tags.createTag(name: name)).id;
  }
}
