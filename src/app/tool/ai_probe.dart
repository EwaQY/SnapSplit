import 'dart:convert';
import 'dart:io';

import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/features/ai_ingest/data/ai_config.dart';
import 'package:snap_split/src/features/ai_ingest/data/ai_recognition_service.dart';
import 'package:snap_split/src/features/ai_ingest/domain/ai_ingest_service.dart';
import 'package:snap_split/src/features/ai_ingest/domain/ai_receipt_dto.dart';

/// AI 识别人工冒烟探针（不进 flutter test，CI 不跑）。
///
/// 用法（src/app 下，真站联调只在本机内存临时填 key，不落盘）：
///   dart run tool/ai_probe.dart <图片路径> [--index N] [--out <目录>]
///
/// 控制台输出草稿摘要；加 --out 则另存 UTF-8 结果文件
/// `<目录>/<图名>.result.json`（AI 原文 + 映射后草稿 + 元信息）。
/// 退出码：0 成功 / 2 缺配置 / 3 失败。图片只读，不入库不落库。
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _fail(2, '用法：dart run tool/ai_probe.dart <图片路径> [--index N] [--out <目录>]');
  }
  final String imagePath = args.first;
  int index = 0;
  final int flag = args.indexOf('--index');
  if (flag >= 0 && flag + 1 < args.length) {
    index = int.tryParse(args[flag + 1]) ?? 0;
  }
  String? outDir;
  final int outFlag = args.indexOf('--out');
  if (outFlag >= 0 && outFlag + 1 < args.length) {
    outDir = args[outFlag + 1];
  }
  final File image = File(imagePath);
  if (!image.existsSync()) {
    _fail(2, '图片不存在：$imagePath');
  }

  // 探针默认占位；打真站时调 loadAiConfig 传参（key/模型/头），不读文件不落盘。
  // 默认站是 Cline 私有接口，随默认带上 x-client-type；切标准站传空即可。
  final AiConfig config = loadAiConfig(extraHeaders: kClineClientHeaders);
  if (!config.isConfigured) {
    _fail(2, '未配置 api_key：调 loadAiConfig 传参覆盖后重跑（不落盘不提交）');
  }

  final AiRecognitionService service = AiRecognitionService(config: config);
  try {
    final ({AiReceiptDto dto, String rawContent}) result =
        await service.parseImageBytesWithRaw(
          image.readAsBytesSync(),
          mime: _mimeOf(imagePath),
          sourceImageIndex: index,
        );
    final AiReceiptDto dto = result.dto;
    final DraftShopping draft = toDraftShopping(dto);
    int total = 0;
    for (final DraftItem item in draft.items) {
      total += item.finalAmount;
      // ignore: avoid_print
      print(
        '- ${item.name} x${item.quantity} '
        '单价${item.unitPrice}分 实付${item.finalAmount}分',
      );
    }
    // ignore: avoid_print
    print('merchant=${dto.merchant} 合计=$total分 共${draft.items.length}件');
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'merchant': dto.merchant,
      'date': dto.date,
      'items': <Map<String, dynamic>>[
        for (final DraftItem item in draft.items)
          <String, dynamic>{
            'name': item.name,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'final_amount': item.finalAmount,
          },
      ],
    }));
    if (outDir != null) {
      _writeResult(
        outDir: outDir,
        imagePath: imagePath,
        rawContent: result.rawContent,
        dto: dto,
        draft: draft,
        total: total,
      );
    }
  } on AiException catch (e) {
    _fail(3, 'AI 解析失败 [${e.kind.name}]：${e.message}');
  } finally {
    service.close();
  }
}

Never _fail(int code, String message) {
  // ignore: avoid_print
  print(message);
  exit(code);
}

/// 写 UTF-8 结果文件（AI 原文 + 映射后草稿 + 元信息）。
void _writeResult({
  required String outDir,
  required String imagePath,
  required String rawContent,
  required AiReceiptDto dto,
  required DraftShopping draft,
  required int total,
}) {
  final String base = imagePath.split(RegExp(r'[\\/]')).last;
  final String stem = base.contains('.')
      ? base.substring(0, base.lastIndexOf('.'))
      : base;
  Directory(outDir).createSync(recursive: true);
  final File file = File('$outDir/$stem.result.json');
  final Map<String, dynamic> payload = <String, dynamic>{
    'image': imagePath,
    'merchant': dto.merchant,
    'date': dto.date,
    'total_cents': total,
    // AI 原 JSON（解析成对象，字段直接可读；去围栏失败则存原文）。
    'ai_raw': _tryParseJson(rawContent) ?? rawContent,
    // 入库字段（expense_item 行字段；payer/参与人/标签在确认页挂载）。
    'db_rows': <Map<String, dynamic>>[
      for (final DraftItem item in draft.items)
        <String, dynamic>{
          'name': item.name,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'final_amount': item.finalAmount,
        },
    ],
    'pending_at_confirm': <String>[
      'payer_id',
      'participant_ids',
      'tag_ids',
    ],
  };
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(payload),
    encoding: utf8,
  );
  // ignore: avoid_print
  print('结果已存：${file.path}');
}

String _mimeOf(String path) {
  final String lower = path.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

/// 原文转 JSON 对象（去围栏；失败返回 null 由调用方存原文）。
Map<String, dynamic>? _tryParseJson(String rawContent) {
  String stripped = rawContent;
  if (stripped.contains('```json')) {
    stripped = stripped.split('```json')[1].split('```')[0];
  } else if (stripped.contains('```')) {
    stripped = stripped.split('```')[1].split('```')[0];
  }
  try {
    return jsonDecode(stripped) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
