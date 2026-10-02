import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../ledger/data/ledger_repository.dart';
import '../providers/home_filter.dart';
import '../providers/home_providers.dart';
import '../widgets/tag_capsule.dart';
import '../widgets/wheel_sheets.dart';

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
                          _FormCard(
                            child: Column(
                              spacing: 10,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _SelectRow(
                                  label: '账本',
                                  value: ledgerName,
                                  onTap: () => _pickLedger(ledgers),
                                ),
                                const _SheetDivider(),
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
                          _FormCard(
                            child: Column(
                              spacing: 10,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _SelectRow(
                                  label: '支付人',
                                  value: payerName,
                                  onTap: _pickPayer,
                                ),
                                const _SheetDivider(),
                                _SelectRow(
                                  label: '参与人',
                                  value: participantName,
                                  onTap: _pickParticipants,
                                ),
                              ],
                            ),
                          ),
                          _FormCard(
                            child: Column(
                              spacing: 10,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _AmountRow(
                                  minController: _minController,
                                  maxController: _maxController,
                                ),
                                const _SheetDivider(),
                                _DateRow(
                                  startDate: _startDate,
                                  endDate: _endDate,
                                  onPickStart: () => _pickDate(isStart: true),
                                  onPickEnd: () => _pickDate(isStart: false),
                                ),
                              ],
                            ),
                          ),
                          _FormCard(
                            child: _SearchRow(
                              controller: _keywordController,
                            ),
                          ),
                        ],
                      ),
                      _ConfirmButton(onTap: _confirm),
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

/// 表单白卡：白底圆角 12，内边距 `12/20/12/20`（横向 20 使行宽 318）。
class _FormCard extends StatelessWidget {
  /// 创建表单白卡。
  const _FormCard({required this.child});

  /// 卡内行列。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(
          Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: child,
    );
  }
}

/// 卡片内分割线：1px 轨道灰，紧凑高度（内容宽，不出卡片内边距）。
class _SheetDivider extends StatelessWidget {
  /// 创建分割线。
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.trackGray,
    );
  }
}

/// 选择行：左标签 + 右值 + ^v，整行可点。
class _SelectRow extends StatelessWidget {
  /// 创建选择行。
  const _SelectRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  /// 左标签。
  final String label;

  /// 右值摘要。
  final String value;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: AppTheme.formLabel),
          Row(
            spacing: 4,
            children: <Widget>[
              Text(value, style: AppTheme.formValue),
              const Icon(
                Icons.unfold_more_outlined,
                size: 16,
                color: AppTheme.secondaryGray,
              ),
            ],
          ),
        ],
      ),
    );
  }
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

/// 金额行：左标签 + 右区间输入（66×26 灰药丸）+ 元。
class _AmountRow extends StatelessWidget {
  /// 创建金额行。
  const _AmountRow({
    required this.minController,
    required this.maxController,
  });

  /// 最小金额（元）控制器。
  final TextEditingController minController;

  /// 最大金额（元）控制器。
  final TextEditingController maxController;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('金额', style: AppTheme.formLabel),
        Row(
          spacing: 6,
          children: <Widget>[
            _AmountField(controller: minController),
            Text('~', style: AppTheme.rowSubtitle),
            _AmountField(controller: maxController),
            Text('元', style: AppTheme.rowSubtitle),
          ],
        ),
      ],
    );
  }
}

/// 金额输入框：66×26，圆角 8，底 `#E5E5EA`，数字键盘。
class _AmountField extends StatelessWidget {
  /// 创建金额输入框。
  const _AmountField({required this.controller});

  /// 输入控制器。
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 26,
      decoration: const BoxDecoration(
        color: AppTheme.trackGray,
        borderRadius: BorderRadius.all(
          Radius.circular(AppTheme.radiusField),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        // 撑满 66×26 盒子再双居中：isCollapsed 只收内容高，换 expands 才稳。
        expands: true,
        maxLines: null,
        minLines: null,
        style: AppTheme.rowTitle,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

/// 日期行：左标签 + 日历图标 + 区间药丸（未选为空药丸，已选 MM-dd）。
class _DateRow extends StatelessWidget {
  /// 创建日期行。
  const _DateRow({
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
  });

  /// 开始日期。
  final DateTime? startDate;

  /// 结束日期。
  final DateTime? endDate;

  /// 选开始日期回调。
  final VoidCallback onPickStart;

  /// 选结束日期回调。
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('日期', style: AppTheme.formLabel),
        Row(
          spacing: 6,
          children: <Widget>[
            const Icon(
              Icons.date_range_outlined,
              size: 20,
              color: AppTheme.secondaryGray,
            ),
            _DatePill(date: startDate, onTap: onPickStart),
            Text('~', style: AppTheme.rowSubtitle),
            _DatePill(date: endDate, onTap: onPickEnd),
          ],
        ),
      ],
    );
  }
}

/// 日期药丸：66×26，圆角 8，底 `#E5E5EA`；已选显示 MM-dd。
class _DatePill extends StatelessWidget {
  /// 创建日期药丸。
  const _DatePill({required this.date, required this.onTap});

  /// 已选日期（null = 未选）。
  final DateTime? date;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DateTime? date = this.date;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(
        Radius.circular(AppTheme.radiusField),
      ),
      child: Container(
        width: 66,
        height: 26,
        decoration: const BoxDecoration(
          color: AppTheme.trackGray,
          borderRadius: BorderRadius.all(
            Radius.circular(AppTheme.radiusField),
          ),
        ),
        child: Center(
          child: Text(
            date == null
                ? ''
                : '${date.month.toString().padLeft(2, '0')}-'
                      '${date.day.toString().padLeft(2, '0')}',
            style: AppTheme.rowTitle,
          ),
        ),
      ),
    );
  }
}

/// 搜索行：左标签 + 搜索框（高 26，圆角 8，底 `#E5E5EA`）。
class _SearchRow extends StatelessWidget {
  /// 创建搜索行。
  const _SearchRow({required this.controller});

  /// 输入控制器。
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: <Widget>[
        Text('账目标题', style: AppTheme.formLabel),
        Expanded(
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              color: AppTheme.trackGray,
              borderRadius: BorderRadius.all(
                Radius.circular(AppTheme.radiusField),
              ),
            ),
            child: Row(
              spacing: 4,
              children: <Widget>[
                const Icon(
                  Icons.search_outlined,
                  size: 16,
                  color: AppTheme.secondaryGray,
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: AppTheme.rowTitle,
                    textAlignVertical: TextAlignVertical.center,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 确定键：全宽高 50，主蓝圆角 12，白字 17/700。
class _ConfirmButton extends StatelessWidget {
  /// 创建确定键。
  const _ConfirmButton({required this.onTap});

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppTheme.radiusLarge),
            ),
          ),
        ),
        child: Text('确定', style: AppTheme.entryLabel(Colors.white)),
      ),
    );
  }
}
