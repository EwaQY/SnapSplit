import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../ledger/data/ledger_repository.dart';
import '../providers/home_filter.dart';
import '../providers/home_providers.dart';
import '../../../common_widgets/amount_field.dart';
import '../../../common_widgets/date_pill.dart';
import '../../../common_widgets/form_card.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../common_widgets/search_field.dart';
import '../../../common_widgets/select_row.dart';
import '../../../common_widgets/sheet_divider.dart';
import '../../../common_widgets/tag_capsule.dart';
import '../../../common_widgets/wheel_sheets.dart';

/// 打开账目筛选弹窗（底部 Sheet，全宽，顶圆角 14，底 `#F2F2F7`）。
///
/// 确定后把 [HomeFilter] 写进 [homeFilterProvider]（最近列表自动重刷）；
/// 取消/下滑关闭则不改条件。fire-and-forget，调用方无需 await。
void showHomeFilterSheet(BuildContext context) {
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.rowBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusSheet),
        ),
      ),
      builder: (BuildContext context) => const _FilterSheetBody(),
    ),
  );
}

/// 筛选弹窗体：标题栏 + 内容操作区（表单区 + 确定键），垂直 gap 10。
class _FilterSheetBody extends ConsumerStatefulWidget {
  /// 创建弹窗体。
  const _FilterSheetBody();

  @override
  ConsumerState<_FilterSheetBody> createState() => _FilterSheetBodyState();
}

class _FilterSheetBodyState extends ConsumerState<_FilterSheetBody> {
  String? _ledgerId;
  Set<String> _tagIds = <String>{};
  String? _payerId;
  Set<String> _participantIds = <String>{};
  DateTime? _startDate;
  DateTime? _endDate;
  List<Tag>? _tags;
  List<_MemberOption>? _members;
  String? _memberLedgerId;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late final TextEditingController _keywordController;

  @override
  void initState() {
    super.initState();
    final HomeFilter current = ref.read(homeFilterProvider);
    _ledgerId = current.ledgerId;
    _memberLedgerId = current.ledgerId;
    _tagIds = Set<String>.of(current.tagIds);
    _payerId = current.payerId;
    _participantIds = Set<String>.of(current.participantIds);
    _startDate = current.startDate;
    _endDate = current.endDate;
    _minController = TextEditingController(
      text: current.minAmountCents == null
          ? ''
          : (current.minAmountCents! / 100).toString(),
    );
    _maxController = TextEditingController(
      text: current.maxAmountCents == null
          ? ''
          : (current.maxAmountCents! / 100).toString(),
    );
    _keywordController = TextEditingController(text: current.keyword);
    unawaited(_loadTags());
    unawaited(_loadMembers());
  }

  Future<void> _loadTags() async {
    final List<Tag> tags = await ref.read(
      tagRepositoryProvider,
    ).listActiveTags();
    if (!mounted) {
      return;
    }
    setState(() {
      _tags = tags;
    });
  }

  /// 成员选项：已选账本则仅该账本成员，否则合并全账本成员（按 userId 去重）。
  Future<void> _loadMembers() async {
    final String? ledgerId = _ledgerId;
    final LedgerRepository ledgers = ref.read(ledgerRepositoryProvider);
    final Map<String, _MemberOption> merged = <String, _MemberOption>{};
    if (ledgerId != null) {
      for (final LedgerMemberView view in await ledgers.listMembers(
        ledgerId,
      )) {
        merged[view.user.id] = _MemberOption(
          userId: view.user.id,
          nickname: view.user.isSelf == 1 ? '我' : view.user.nickname,
          isSelf: view.user.isSelf == 1,
        );
      }
    } else {
      final List<Ledger> all = await ref.read(ledgerListProvider.future);
      for (final Ledger ledger in all) {
        for (final LedgerMemberView view in await ledgers.listMembers(
          ledger.id,
        )) {
          merged.putIfAbsent(
            view.user.id,
            () => _MemberOption(
              userId: view.user.id,
              nickname: view.user.isSelf == 1 ? '我' : view.user.nickname,
              isSelf: view.user.isSelf == 1,
            ),
          );
        }
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _memberLedgerId = ledgerId;
      final List<_MemberOption> options = merged.values.toList()
        ..sort(
          (_MemberOption a, _MemberOption b) =>
              a.nickname.compareTo(b.nickname),
        );
      _members = options;
    });
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_memberLedgerId != _ledgerId) {
      unawaited(_loadMembers());
    }
    final List<Ledger> ledgers = ref.watch(ledgerListProvider).value ??
        <Ledger>[];
    String ledgerName = '所有账本';
    for (final Ledger ledger in ledgers) {
      if (ledger.id == _ledgerId) {
        ledgerName = ledger.name;
      }
    }
    final Map<String, String> memberNames = <String, String>{
      for (final _MemberOption option in _members ?? <_MemberOption>[])
        option.userId: option.nickname,
    };
    final String payerName = _payerId == null
        ? '不限'
        : memberNames[_payerId] ?? '不限';
    final String participantName = _participantIds.isEmpty
        ? '不限'
        : _formatNames(
            _participantIds.map((id) => memberNames[id] ?? '未知').toList(),
          );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
            child: Column(
              spacing: 10,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Column(
                  spacing: 12,
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppTheme.trackGray,
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                    Text(
                      '账目筛选',
                      style: AppTheme.sheetTitle,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    spacing: 10,
                    children: <Widget>[
                      Column(
                        spacing: 12,
                        children: <Widget>[
                          FormCard(
                            child: Column(
                              spacing: 10,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                SelectRow(
                                  label: '账本',
                                  value: ledgerName,
                                  onTap: () => _pickLedger(ledgers),
                                ),
                                const SheetDivider(),
                                _TagBlock(
                                  tags: _tags,
                                  selectedIds: _tagIds,
                                  onToggle: (String id) {
                                    setState(() {
                                      final Set<String> next = Set<String>.of(
                                        _tagIds,
                                      );
                                      if (next.contains(id)) {
                                        next.remove(id);
                                      } else {
                                        next.add(id);
                                      }
                                      _tagIds = next;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          FormCard(
                            child: Column(
                              spacing: 10,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                SelectRow(
                                  label: '支付人',
                                  value: payerName,
                                  onTap: _pickPayer,
                                ),
                                const SheetDivider(),
                                SelectRow(
                                  label: '参与人',
                                  value: participantName,
                                  onTap: _pickParticipants,
                                ),
                              ],
                            ),
                          ),
                          FormCard(
                            child: Column(
                              spacing: 10,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                AmountRow(
                                  minController: _minController,
                                  maxController: _maxController,
                                ),
                                const SheetDivider(),
                                DateRow(
                                  startDate: _startDate,
                                  endDate: _endDate,
                                  onPickStart: () => _pickDate(isStart: true),
                                  onPickEnd: () => _pickDate(isStart: false),
                                ),
                              ],
                            ),
                          ),
                          FormCard(
                            child: SearchField(
                              controller: _keywordController,
                            ),
                          ),
                        ],
                      ),
                      PrimaryButton(label: '确定', onTap: _confirm),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 账本单选（iOS 滚轮，所有账本 + 账本列表）；取消不改值。
  Future<void> _pickLedger(List<Ledger> ledgers) async {
    final String? picked = await showWheelOptionSheet<String>(
      context,
      title: '账本',
      options: <WheelOption<String>>[
        const WheelOption<String>(value: '', label: '所有账本'),
        for (final Ledger ledger in ledgers)
          WheelOption<String>(value: ledger.id, label: ledger.name),
      ],
      initialValue: _ledgerId ?? '',
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _ledgerId = picked.isEmpty ? null : picked;
    });
  }

  /// 付款人单选（iOS 滚轮，不限 + 成员）。
  Future<void> _pickPayer() async {
    final List<_MemberOption> members = _members ?? <_MemberOption>[];
    final String? picked = await showWheelOptionSheet<String>(
      context,
      title: '支付人',
      options: <WheelOption<String>>[
        const WheelOption<String>(value: '', label: '不限'),
        for (final _MemberOption option in members)
          WheelOption<String>(
            value: option.userId,
            label: option.nickname,
          ),
      ],
      initialValue: _payerId ?? '',
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _payerId = picked.isEmpty ? null : picked;
    });
  }

  /// 参与人多选（iOS check 表，确定后落值）。
  Future<void> _pickParticipants() async {
    final List<_MemberOption> members = _members ?? <_MemberOption>[];
    final Set<String>? picked = await showCheckOptionSheet(
      context,
      title: '参与人',
      options: <WheelOption<String>>[
        for (final _MemberOption option in members)
          WheelOption<String>(
            value: option.userId,
            label: option.nickname,
          ),
      ],
      initial: _participantIds,
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _participantIds = picked;
    });
  }

  /// 日期单选（起/止）：iOS 滚轮日期，只取年月日。
  Future<void> _pickDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showWheelDateSheet(
      context,
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate ?? _startDate ?? now),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _startDate = DateTime(picked.year, picked.month, picked.day);
      } else {
        _endDate = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  /// 确定：金额起止合法才落值（起 > 止则提示不关闭）。
  void _confirm() {
    final int? min = _parseYuan(_minController.text);
    final int? max = _parseYuan(_maxController.text);
    if (min != null && max != null && min > max) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最小金额不能大于最大金额')),
      );
      return;
    }
    ref.read(homeFilterProvider.notifier).apply(
      HomeFilter(
        ledgerId: _ledgerId,
        tagIds: _tagIds,
        payerId: _payerId,
        participantIds: _participantIds,
        minAmountCents: min,
        maxAmountCents: max,
        startDate: _startDate,
        endDate: _endDate,
        keyword: _keywordController.text,
      ),
    );
    Navigator.pop(context);
  }

  /// 元转分：空串 = 不限；非法输入按不限处理。
  int? _parseYuan(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final double? yuan = double.tryParse(trimmed);
    if (yuan == null || yuan < 0) {
      return null;
    }
    return (yuan * 100).round();
  }

  /// 参与人摘要：两内直列，超出“首、次等N人”。
  String _formatNames(List<String> names) {
    if (names.length <= 2) {
      return names.join('、');
    }
    return '${names[0]}、${names[1]}等${names.length}人';
  }
}

/// 成员选项（userId 去重后的展示项）。
class _MemberOption {
  const _MemberOption({
    required this.userId,
    required this.nickname,
    required this.isSelf,
  });

  final String userId;
  final String nickname;
  final bool isSelf;
}

/// 标签块：标签文本 + 胶囊换行多选。
class _TagBlock extends StatelessWidget {
  /// 创建标签块。
  const _TagBlock({
    required this.tags,
    required this.selectedIds,
    required this.onToggle,
  });

  /// 活跃标签（null = 加载中）。
  final List<Tag>? tags;

  /// 已选 ids。
  final Set<String> selectedIds;

  /// 切换回调。
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final List<Tag>? tags = this.tags;
    return Column(
      spacing: 10,
      // Fill 语义：嵌套纵列默认 Hug（包内容），必须 stretch 才铺满卡片宽，
      // 否则会被父列按 center 摆到中间。
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('标签', style: AppTheme.formLabel),
        if (tags == null)
          const SizedBox(
            height: 33,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (tags.isEmpty)
          Text('暂无标签', style: AppTheme.rowSubtitle)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final Tag tag in tags)
                TagCapsule(
                  label: tag.name,
                  selected: selectedIds.contains(tag.id),
                  onTap: () => onToggle(tag.id),
                ),
            ],
          ),
      ],
    );
  }
}
