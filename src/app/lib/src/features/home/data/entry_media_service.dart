import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// 录入媒体来源：拍照走相机，截图录入走相册选图。
enum EntryMediaSource {
  /// 拍照录入。
  camera,

  /// 截图录入（相册选图）。
  gallery,
}

/// 选图结果：成功带文件，其余只带提示文案（调用方弹 SnackBar）。
typedef EntryMediaResult = ({XFile? file, String? notice});

/// 录入选图服务：先申请运行时权限，再调系统相机/相册。
///
/// 先查状态后申请：已授权（含部分授权）直接进，不再弹框；
/// AI 识别链路下期再接，本期只负责拿到图片并回执（调用方提示即可）。
/// 权限与选图均可注入，便于单测替换，不碰真系统弹窗。
class EntryMediaService {
  /// 创建选图服务。
  EntryMediaService({
    Future<PermissionStatus> Function(Permission permission)? statusOf,
    Future<PermissionStatus> Function(Permission permission)? request,
    Future<XFile?> Function({required ImageSource source})? pickImage,
    Future<bool> Function()? openSettings,
    Future<int?> Function()? androidSdkInt,
  }) : _statusOf = statusOf ?? _defaultStatusOf,
       _request = request ?? _defaultRequest,
       _pickImage =
           pickImage ??
           (( {required ImageSource source}) =>
               ImagePicker().pickImage(source: source)),
       _openSettings = openSettings ?? openAppSettings,
       _androidSdkInt = androidSdkInt ?? _defaultAndroidSdkInt;

  final Future<PermissionStatus> Function(Permission permission) _statusOf;
  final Future<PermissionStatus> Function(Permission permission) _request;
  final Future<XFile?> Function({required ImageSource source}) _pickImage;
  final Future<bool> Function() _openSettings;
  final Future<int?> Function() _androidSdkInt;

  /// 相册权限：Android 13+ 用 photos（READ_MEDIA_IMAGES），
  /// 12- 用 storage（READ_EXTERNAL_STORAGE）——photos 在 33 以下
  /// 插件直接不处理，永远 denied。
  Future<Permission> _galleryPermission() async {
    final int? sdk = await _androidSdkInt();
    if (sdk != null && sdk < 33) {
      return Permission.storage;
    }
    return Permission.photos;
  }

  /// 选图：成功返回文件；失败/取消返回提示文案。
  Future<EntryMediaResult> pick(EntryMediaSource source) async {
    final Permission permission = source == EntryMediaSource.camera
        ? Permission.camera
        : await _galleryPermission();
    final String failNotice = source == EntryMediaSource.camera
        ? '相机权限请求失败，无法拍照录入'
        : '相册权限请求失败，无法截图录入';
    PermissionStatus status;
    try {
      // 先查：已授权（含选择部分）直接进，不打扰用户。
      status = await _statusOf(permission);
    } on Exception {
      return (file: null, notice: failNotice);
    }
    if (!status.isGranted && !status.isLimited) {
      try {
        // 未授权才申请（弹系统框）。
        status = await _request(permission);
      } on Exception {
        return (file: null, notice: failNotice);
      }
    }
    if (status.isGranted || status.isLimited) {
      try {
        final XFile? file = await _pickImage(
          source: source == EntryMediaSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
        );
        if (file == null) {
          return (file: null, notice: '未选择图片');
        }
        return (file: file, notice: '已选择图片，AI 识别下期再接');
      } on Exception {
        return (file: null, notice: '打开相机/相册失败，请重试');
      }
    }
    if (status.isPermanentlyDenied) {
      try {
        await _openSettings();
      } on Exception {
        // 忽略设置页打开失败，提示文案已足够指引。
      }
      return (file: null, notice: '权限被拒绝，已打开系统设置，请开启后重试');
    }
    return (
      file: null,
      notice: source == EntryMediaSource.camera
          ? '需要相机权限才能拍照录入'
          : '需要相册权限才能截图录入',
    );
  }
}

/// 默认权限查询：只读状态，不弹框。
Future<PermissionStatus> _defaultStatusOf(Permission permission) =>
    permission.status;

/// 默认权限申请：单次请求，由系统决定是否弹框。
Future<PermissionStatus> _defaultRequest(Permission permission) =>
    permission.request();

/// 默认 Android SDK 查询：非 Android 返回 null（调用方按 photos 走）。
Future<int?> _defaultAndroidSdkInt() async {
  if (!Platform.isAndroid) {
    return null;
  }
  try {
    return (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  } on Exception {
    return null;
  }
}
