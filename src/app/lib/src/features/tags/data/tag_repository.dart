import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/utils/app_time.dart';
import '../../../core/utils/ids.dart';

/// 标签 Repository：全局共享标签的唯一数据源。
///
/// - 归档（`archived_at`）后不再出现在新账目标签选择器（[listActiveTags]），
///   但历史账目标签引用保留不变，明细照常展示原名。
/// - UI 仅提供归档，不提供删除。
class TagRepository {
  TagRepository(this._db);

  final AppDatabase _db;

  /// 新建标签，名全局唯一（重复抛 [ValidationException]）。
  Future<Tag> createTag({required String name, String? icon}) =>
      AppLogger.audit(
        action: 'tag.createTag',
        entity: 'tag',
        run: () async {
          if (name.trim().isEmpty) {
            throw ValidationException('标签名不能为空');
          }
          final int now = nowUnixSeconds();
          final String id = newId();
          try {
            await _db
                .into(_db.tags)
                .insert(
                  TagsCompanion.insert(
                    id: id,
                    name: name,
                    icon: Value(icon),
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
          } on SqliteException catch (e) {
            if (e.extendedResultCode == 2067) {
              throw ValidationException('标签名已存在：$name');
            }
            rethrow;
          }
          return getById(id);
        },
      );

  /// 取标签，不存在抛 [NotFoundException]。
  Future<Tag> getById(String id) async {
    final Tag? tag =
        await (_db.select(_db.tags)
              ..where((Tags t) => t.id.equals(id))).getSingleOrNull();
    if (tag == null) {
      throw NotFoundException('标签不存在：$id');
    }
    return tag;
  }

  /// 改名/换图标（重名抛 [ValidationException]）。
  Future<Tag> renameTag(String id, {String? name, String? icon}) =>
      AppLogger.audit(
        action: 'tag.renameTag',
        entity: 'tag',
        id: id,
        run: () async {
          if (name != null && name.trim().isEmpty) {
            throw ValidationException('标签名不能为空');
          }
          await getById(id);
          try {
            await (_db.update(_db.tags)..where(
                  (t) => t.id.equals(id),
                )).write(
              TagsCompanion(
                name: name == null ? const Value.absent() : Value(name),
                icon: icon == null ? const Value.absent() : Value(icon),
                updatedAt: Value(nowUnixSeconds()),
              ),
            );
          } on SqliteException catch (e) {
            if (e.extendedResultCode == 2067) {
              throw ValidationException('标签名已存在：$name');
            }
            rethrow;
          }
          return getById(id);
        },
      );

  /// 归档标签（幂等，已归档再次调用无副作用）。
  Future<Tag> archiveTag(String id) => AppLogger.audit(
    action: 'tag.archiveTag',
    entity: 'tag',
    id: id,
    run: () async {
      await getById(id);
      final int now = nowUnixSeconds();
      await (_db.update(_db.tags)..where(
            (t) => t.id.equals(id) & t.archivedAt.isNull(),
          )).write(
        TagsCompanion(archivedAt: Value(now), updatedAt: Value(now)),
      );
      return getById(id);
    },
  );

  /// 新账目标签选择器：仅活跃（未归档、未软删）标签，按名称排序。
  Future<List<Tag>> listActiveTags() =>
      (_db.select(_db.tags)
            ..where(
              (Tags t) => t.archivedAt.isNull() & t.deletedAt.isNull(),
            )
            ..orderBy([(Tags t) => OrderingTerm.asc(t.name)]))
          .get();

  /// 全部标签（含已归档，用于管理页）。
  Future<List<Tag>> listAllTags() =>
      (_db.select(_db.tags)
            ..where((Tags t) => t.deletedAt.isNull())
            ..orderBy([(Tags t) => OrderingTerm.asc(t.name)]))
          .get();
}
