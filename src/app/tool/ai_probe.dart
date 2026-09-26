import 'dart:convert';
import 'dart:io';

import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/features/ai_ingest/data/ai_config.dart';
import 'package:snap_split/src/features/ai_ingest/data/ai_recognition_service.dart';
import 'package:snap_split/src/features/ai_ingest/domain/ai_ingest_service.dart';
import 'package:snap_split/src/features/ai_ingest/domain/ai_receipt_dto.dart';

/// AI 识别人工冒烟探针（不进 flutter test，CI 不跑）。
///
/// 用法（src/app 下，需先填好 .env 的 api_key）：
///   dart run tool/ai_probe.dart <图片路径> [--index N]
///
/// 输出：AI 原始 JSON → 草稿明细与合计。退出码：0 成功 / 2 缺配置 / 3 失败。
/// 图片只读，不入库不落库。
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _fail(2, '用法：dart run tool/ai_probe.dart <图片路径> [--index N]');
  }
  final String imagePath = args.first;
  int index = 0;
  final int flag = args.indexOf('--index');
  if (flag >= 0 && flag + 1 < args.length) {
    index = int.tryParse(args[flag + 1]) ?? 0;
  }
  final File image = File(imagePath);
  if (!image.existsSync()) {
    _fail(2, '图片不存在：$imagePath');
  }

  // 探针为纯 Dart CLI（flutter_dotenv 依赖 dart:ui，此处手写解析；
  // App 正式路径仍走 flutter_dotenv）。
  final AiConfig config = AiConfig.fromMap(_readEnvFile('.env'));
  if (!config.isConfigured) {
    _fail(2, '未配置 api_key：请复制 .env.example 为 .env 并填写');
  }

  final AiRecognitionService service = AiRecognitionService(config: config);
  try {
    final AiReceiptDto dto = await service.parseImageFile(
      image,
      sourceImageIndex: index,
    );
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

/// 手写 .env 解析（平键 KEY=VALUE，跳空行/#，去首尾空格去引号）。
Map<String, String> _readEnvFile(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    return <String, String>{};
  }
  final Map<String, String> env = <String, String>{};
  for (final String line in file.readAsLinesSync()) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final int sep = trimmed.indexOf('=');
    if (sep <= 0) {
      continue;
    }
    String value = trimmed.substring(sep + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    env[trimmed.substring(0, sep).trim()] = value;
  }
  return env;
}
