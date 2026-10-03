import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snap_split/src/features/home/data/entry_media_service.dart';

/// 录入选图服务单测：权限与选图全注入 fake，不碰系统弹窗。
void main() {
  EntryMediaService service({
    PermissionStatus status = PermissionStatus.granted,
    PermissionStatus? afterRequest,
    XFile? file,
    bool failRequest = false,
    bool failStatus = false,
    void Function()? onSettings,
    void Function()? onPick,
    void Function()? onRequest,
  }) {
    return EntryMediaService(
      statusOf: (_) async {
        if (failStatus) {
          throw Exception('status');
        }
        return status;
      },
      request: (_) async {
        onRequest?.call();
        if (failRequest) {
          throw Exception('auth');
        }
        return afterRequest ?? status;
      },
      pickImage: ({required ImageSource source}) async {
        onPick?.call();
        return file;
      },
      openSettings: () async {
        onSettings?.call();
        return true;
      },
    );
  }

  test('授权且选到图回文件', () async {
    bool picked = false;
    final EntryMediaService sut = service(
      file: XFile('/tmp/shot.jpg'),
      onPick: () => picked = true,
    );
    final EntryMediaResult result = await sut.pick(EntryMediaSource.camera);
    expect(picked, isTrue);
    expect(result.file?.path, '/tmp/shot.jpg');
    expect(result.notice, contains('AI'));
  });

  test('授权但取消选择提示未选', () async {
    final EntryMediaService sut = service();
    final EntryMediaResult result = await sut.pick(EntryMediaSource.gallery);
    expect(result.file, isNull);
    expect(result.notice, '未选择图片');
  });

  test('拒绝权限不调选图', () async {
    bool picked = false;
    int requests = 0;
    final EntryMediaService sut = service(
      status: PermissionStatus.denied,
      onPick: () => picked = true,
      onRequest: () => requests++,
    );
    final EntryMediaResult result = await sut.pick(EntryMediaSource.camera);
    expect(requests, 1);
    expect(picked, isFalse);
    expect(result.file, isNull);
    expect(result.notice, contains('相机权限'));
  });

  /// 选择部分后重进：已部分授权直接进，不再弹框。
  test('部分授权不再申请直接选图', () async {
    bool picked = false;
    int requests = 0;
    final EntryMediaService sut = service(
      status: PermissionStatus.limited,
      file: XFile('/tmp/part.jpg'),
      onPick: () => picked = true,
      onRequest: () => requests++,
    );
    final EntryMediaResult result = await sut.pick(EntryMediaSource.gallery);
    expect(requests, 0);
    expect(picked, isTrue);
    expect(result.file?.path, '/tmp/part.jpg');
  });

  test('永久拒绝开设置页', () async {
    bool opened = false;
    final EntryMediaService sut = service(
      status: PermissionStatus.permanentlyDenied,
      onSettings: () => opened = true,
    );
    final EntryMediaResult result = await sut.pick(EntryMediaSource.gallery);
    expect(opened, isTrue);
    expect(result.notice, contains('系统设置'));
  });

  test('权限请求抛错给失败提示', () async {
    final EntryMediaService sut = service(
      status: PermissionStatus.denied,
      failRequest: true,
    );
    final EntryMediaResult result = await sut.pick(EntryMediaSource.camera);
    expect(result.file, isNull);
    expect(result.notice, contains('失败'));
  });

  test('权限查询抛错给失败提示', () async {
    final EntryMediaService sut = service(failStatus: true);
    final EntryMediaResult result = await sut.pick(EntryMediaSource.gallery);
    expect(result.file, isNull);
    expect(result.notice, contains('失败'));
  });

  /// Android 12- 相册走 storage（photos 在 33 以下插件不处理）。
  test('相册 SDK32 要 storage', () async {
    final List<Permission> asked = <Permission>[];
    final EntryMediaService sut = EntryMediaService(
      androidSdkInt: () async => 32,
      statusOf: (_) async => PermissionStatus.denied,
      request: (Permission p) async {
        asked.add(p);
        return PermissionStatus.granted;
      },
      pickImage: ({required ImageSource source}) async => XFile('/tmp/a.jpg'),
    );
    await sut.pick(EntryMediaSource.gallery);
    expect(asked, <Permission>[Permission.storage]);
  });

  /// Android 13+ 相册走 photos。
  test('相册 SDK33 要 photos', () async {
    final List<Permission> asked = <Permission>[];
    final EntryMediaService sut = EntryMediaService(
      androidSdkInt: () async => 33,
      statusOf: (_) async => PermissionStatus.denied,
      request: (Permission p) async {
        asked.add(p);
        return PermissionStatus.granted;
      },
      pickImage: ({required ImageSource source}) async => XFile('/tmp/a.jpg'),
    );
    await sut.pick(EntryMediaSource.gallery);
    expect(asked, <Permission>[Permission.photos]);
  });
}
