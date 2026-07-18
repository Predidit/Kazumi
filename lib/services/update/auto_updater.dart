import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/request/clients/download_http_client.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/update/update_asset_policy.dart';
import 'package:kazumi/services/update/update_release_metadata_loader.dart';
import 'package:kazumi/services/update/windows_update_artifact_verifier.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/date_time.dart';
import 'package:kazumi/utils/crypto.dart';
import 'package:kazumi/utils/version.dart';
import 'package:kazumi/services/platform/application_lifecycle_service.dart';

export 'package:kazumi/services/update/update_asset_policy.dart'
    show InstallationType;

/// 安装类型枚举
/// 更新信息类
class UpdateInfo {
  final String version;
  final String description;
  final String downloadUrl;
  final List<String> downloadUrls;
  final int? expectedSizeBytes;
  final String releaseNotes;
  final String publishedAt;
  final InstallationType? installationType;
  final List<InstallationType> availableInstallationTypes;
  final List<dynamic> assets;

  UpdateInfo({
    required this.version,
    required this.description,
    required this.downloadUrl,
    this.downloadUrls = const [],
    this.expectedSizeBytes,
    required this.releaseNotes,
    required this.publishedAt,
    this.installationType,
    this.availableInstallationTypes = const [],
    this.assets = const [],
  });

  /// 获取默认的安装类型（第一个可用类型）
  InstallationType get recommendedInstallationType {
    if (availableInstallationTypes.isNotEmpty) {
      return availableInstallationTypes.first;
    }
    return installationType ?? InstallationType.unknown;
  }
}

Map<String, dynamic>? getUpdateAssetForType(
    List<dynamic> assets, InstallationType type) {
  for (final candidate in assets) {
    if (candidate is! Map) {
      continue;
    }
    final asset = Map<String, dynamic>.from(candidate);
    try {
      validateUpdateAsset(asset, type);
      return asset;
    } on UpdateAssetPolicyException {
      continue;
    }
  }
  return null;
}

ValidatedUpdateAsset? getValidatedUpdateAssetForType(
    List<dynamic> assets, InstallationType type) {
  for (final candidate in assets) {
    if (candidate is! Map) {
      continue;
    }
    try {
      return validateUpdateAsset(Map<String, dynamic>.from(candidate), type);
    } on UpdateAssetPolicyException {
      continue;
    }
  }
  return null;
}

String getUpdateDownloadUrlFromAsset(Map<String, dynamic>? asset) {
  if (asset == null) {
    return '';
  }
  final name = (asset['name'] as String?)?.toLowerCase() ?? '';
  final type = switch (name) {
    final value when value.endsWith('.msix') => InstallationType.windowsMsix,
    final value when value.endsWith('.zip') => InstallationType.windowsPortable,
    final value when value.endsWith('.dmg') => InstallationType.macosDmg,
    final value when value.endsWith('.apk') => InstallationType.androidApk,
    final value when value.endsWith('.tar.gz') => InstallationType.linuxTar,
    final value when value.endsWith('.deb') => InstallationType.linuxDeb,
    _ => null,
  };
  if (type == null) {
    return '';
  }
  try {
    return validateUpdateAsset(asset, type).downloadUri.toString();
  } on UpdateAssetPolicyException {
    return '';
  }
}

String getUpdateFileHashFromAsset(Map<String, dynamic> asset) {
  final digest = asset['digest'] as String? ?? '';
  try {
    return normalizeSha256Digest(digest);
  } on UpdateAssetPolicyException {
    return '';
  }
}

List<String> getUpdateFilePatterns(InstallationType installationType) {
  switch (installationType) {
    case InstallationType.windowsMsix:
      return ['windows', '.msix'];
    case InstallationType.windowsPortable:
      return ['windows', '.zip'];
    case InstallationType.macosDmg:
      return ['macos', '.dmg'];
    case InstallationType.androidApk:
      return ['android', '.apk'];
    case InstallationType.linuxDeb:
    case InstallationType.linuxTar:
    case InstallationType.ios:
    case InstallationType.unknown:
      return [];
  }
}

class AutoUpdater {
  static final AutoUpdater _instance = AutoUpdater._internal();

  factory AutoUpdater() => _instance;

  AutoUpdater._internal();

  final DownloadHttpClient _downloadClient = DownloadHttpClient.instance;
  final UpdateArtifactVerifier _artifactVerifier =
      const WindowsUpdateArtifactVerifier();

  /// 检测所有可能的安装类型
  Future<List<InstallationType>> _detectAvailableInstallationTypes() async {
    List<InstallationType> availableTypes = [];

    try {
      if (Platform.isWindows) {
        // Windows 平台支持 MSIX 和 ZIP 便携版
        if (_artifactVerifier.supports(InstallationType.windowsMsix)) {
          availableTypes.add(InstallationType.windowsMsix);
        }
        if (_artifactVerifier.supports(InstallationType.windowsPortable)) {
          availableTypes.add(InstallationType.windowsPortable);
        }
      } else if (Platform.isLinux) {
        // Linux 平台支持 DEB 和 TAR.GZ
        availableTypes.add(InstallationType.linuxDeb);
        availableTypes.add(InstallationType.linuxTar);
      } else if (Platform.isMacOS) {
        // macOS 平台支持 DMG
        availableTypes.add(InstallationType.macosDmg);
      } else if (Platform.isIOS) {
        // iOS 平台通过 Github
        availableTypes.add(InstallationType.ios);
      } else if (Platform.isAndroid) {
        // Android 平台支持 APK
        availableTypes.add(InstallationType.androidApk);
      }
    } catch (e) {
      KazumiLogger().w('Update: detect installation types failed', error: e);
    }

    if (availableTypes.isEmpty) {
      availableTypes.add(InstallationType.unknown);
    }

    return availableTypes;
  }

  /// 检查是否有新版本可用
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final data = await _latestRelease();

      if (!data.containsKey('tag_name')) {
        throw Exception('无效的响应数据');
      }

      final remoteVersion = data['tag_name'] as String;
      final currentVersion = ApiEndpoints.version;

      if (needUpdate(currentVersion, remoteVersion)) {
        final availableTypes = await _detectAvailableInstallationTypes();

        return UpdateInfo(
          version: remoteVersion,
          description: data['body'] ?? '发现新版本',
          downloadUrl: '',
          // 将在用户选择安装类型后填充
          releaseNotes: validateUpdateReleaseNotesUrl(data['html_url']),
          publishedAt: data['published_at'] ?? '',
          installationType: availableTypes.first,
          // 保持兼容性
          availableInstallationTypes: availableTypes,
          assets: data['assets'] ?? [],
        );
      }

      return null;
    } catch (e) {
      KazumiLogger().e('Update: check for updates failed', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _latestRelease() async {
    return UpdateReleaseMetadataLoader(
      endpoints: const [
        ApiEndpoints.latestAppMirror,
        ApiEndpoints.latestApp,
      ],
      fetch: _downloadClient.getPlain,
      onFailure: (endpoint, error) {
        KazumiLogger().w(
          'Update: release metadata endpoint failed. '
          'host=${endpoint.host}, errorType=${error.runtimeType}',
        );
      },
    ).load();
  }

  /// 自动检查更新（仅在启用自动更新时）
  Future<void> autoCheckForUpdates() async {
    final autoUpdate = GStorage.getSetting(SettingsKeys.autoUpdate);
    if (!autoUpdate) return;

    try {
      final updateInfo = await checkForUpdates();
      if (updateInfo != null) {
        _showUpdateDialog(updateInfo, isAutoCheck: true);
      }
    } catch (e) {
      // 自动检查失败时不显示错误
      KazumiLogger().w('Update: auto check for updates failed', error: e);
    }
  }

  /// 手动检查更新
  Future<void> manualCheckForUpdates() async {
    try {
      final updateInfo = await checkForUpdates();
      if (updateInfo != null) {
        _showUpdateDialog(updateInfo, isAutoCheck: false);
      } else {
        KazumiDialog.showToast(message: '当前已经是最新版本！');
      }
    } catch (e) {
      KazumiDialog.showToast(message: '检查更新失败');
    }
  }

  /// 显示更新对话框
  void _showUpdateDialog(UpdateInfo updateInfo, {bool isAutoCheck = false}) {
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: Text('发现新版本 ${updateInfo.version}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(updateInfo.description),
                if (updateInfo.publishedAt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '发布时间: ${formatDate(updateInfo.publishedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                if (!Platform.isLinux && !Platform.isIOS) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择安装类型:',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 8),
                        ...updateInfo.availableInstallationTypes.map((type) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () {
                                  KazumiDialog.dismiss();
                                  _downloadUpdateWithType(updateInfo, type);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.download,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _getInstallationTypeDescription(type),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (isAutoCheck)
              TextButton(
                onPressed: () {
                  GStorage.putSetting(SettingsKeys.autoUpdate, false);
                  KazumiDialog.dismiss();
                  KazumiDialog.showToast(message: '已关闭自动更新');
                },
                child: Text(
                  '关闭自动更新',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            TextButton(
              onPressed: () => KazumiDialog.dismiss(),
              child: Text(
                '稍后提醒',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            if (updateInfo.releaseNotes.isNotEmpty)
              TextButton(
                onPressed: () {
                  launchUrl(Uri.parse(updateInfo.releaseNotes),
                      mode: LaunchMode.externalApplication);
                },
                child: const Text('查看详情'),
              ),
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                // 直接使用第一个可用的安装类型
                if (updateInfo.availableInstallationTypes.isNotEmpty) {
                  _downloadUpdateWithType(
                      updateInfo, updateInfo.availableInstallationTypes.first);
                }
              },
              child: const Text('立即更新'),
            ),
          ],
        );
      },
    );
  }

  /// 获取安装类型的描述
  String _getInstallationTypeDescription(InstallationType type) {
    switch (type) {
      case InstallationType.windowsMsix:
        return 'Windows MSIX 包';
      case InstallationType.windowsPortable:
        return 'Windows 便携版 (ZIP)';
      case InstallationType.linuxDeb:
        return 'Linux DEB 包';
      case InstallationType.linuxTar:
        return 'Linux TAR 包';
      case InstallationType.macosDmg:
        return 'macOS DMG 镜像';
      case InstallationType.androidApk:
        return 'Android APK';
      case InstallationType.ios:
        return 'iOS ipa';
      case InstallationType.unknown:
        return '未知安装类型';
    }
  }

  /// 根据选择的类型下载更新
  Future<void> _downloadUpdateWithType(
      UpdateInfo updateInfo, InstallationType selectedType) async {
    try {
      // iOS 和 Linux 直接跳转到 Release 页面
      if (selectedType == InstallationType.ios ||
          selectedType == InstallationType.linuxDeb ||
          selectedType == InstallationType.linuxTar) {
        String releaseUrl = updateInfo.releaseNotes;
        if (releaseUrl.isEmpty) {
          releaseUrl = ApiEndpoints.latestApp;
        }
        launchUrl(Uri.parse(releaseUrl), mode: LaunchMode.externalApplication);
        return;
      }

      final asset =
          getValidatedUpdateAssetForType(updateInfo.assets, selectedType);
      if (asset == null) {
        KazumiDialog.showToast(
            message:
                '没有找到 ${_getInstallationTypeDescription(selectedType)} 的下载链接');
        return;
      }

      // 创建一个临时的 UpdateInfo 对象用于下载
      final downloadInfo = UpdateInfo(
        version: updateInfo.version,
        description: updateInfo.description,
        downloadUrl: asset.downloadUri.toString(),
        downloadUrls: asset.downloadUris.map((uri) => uri.toString()).toList(),
        expectedSizeBytes: asset.sizeBytes,
        releaseNotes: updateInfo.releaseNotes,
        publishedAt: updateInfo.publishedAt,
        installationType: selectedType,
        availableInstallationTypes: [selectedType],
        assets: updateInfo.assets,
      );

      _downloadUpdate(downloadInfo, asset.sha256);
    } catch (e) {
      KazumiDialog.showToast(message: '下载失败: ${e.toString()}');
      KazumiLogger().e('Update: download update failed', error: e);
    }
  }

  /// 下载更新
  Future<void> _downloadUpdate(
      UpdateInfo updateInfo, String expectedHash) async {
    final downloadUrls = updateInfo.downloadUrls.isNotEmpty
        ? updateInfo.downloadUrls
        : [if (updateInfo.downloadUrl.isNotEmpty) updateInfo.downloadUrl];
    if (downloadUrls.isEmpty || updateInfo.expectedSizeBytes == null) {
      KazumiDialog.showToast(message: '没有找到合适的下载链接');
      return;
    }

    // 显示下载进度对话框
    KazumiDialog.show(
      clickMaskDismiss: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('正在下载更新'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _downloadProgress,
                builder: (context, value, child) {
                  return Column(
                    children: [
                      LinearProgressIndicator(value: value),
                      const SizedBox(height: 8),
                      Text('${(value * 100).toStringAsFixed(1)}%'),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _cancelDownload();
                KazumiDialog.dismiss();
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    try {
      final downloadPath = await _downloadFile(
        downloadUrls,
        updateInfo.version,
        expectedHash,
        updateInfo.expectedSizeBytes!,
        updateInfo.recommendedInstallationType,
      );

      // 不自动关闭对话框，而是显示下载完成状态
      _showDownloadCompleteDialog(downloadPath, updateInfo);
    } catch (e) {
      KazumiDialog.dismiss();

      // 显示详细的错误信息
      String errorMessage = '下载失败';
      if (e.toString().contains('Permission denied') ||
          e.toString().contains('Operation not permitted')) {
        errorMessage = '权限不足，文件已保存到应用临时目录';
      } else if (e.toString().contains('No space left')) {
        errorMessage = '磁盘空间不足';
      } else if (e.toString().contains('Network')) {
        errorMessage = '网络连接错误';
      } else if (e.toString().contains('文件完整性验证失败')) {
        errorMessage = '文件完整性验证失败，可能是网络传输错误';
      }

      KazumiDialog.show(
        builder: (context) {
          return AlertDialog(
            title: const Text('下载失败'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                const SizedBox(height: 8),
                Text(
                  '错误详情: ${e.toString()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => KazumiDialog.dismiss(),
                child: const Text('确定'),
              ),
              TextButton(
                onPressed: () {
                  KazumiDialog.dismiss();
                  // 重新尝试下载
                  _downloadUpdate(updateInfo, expectedHash);
                },
                child: const Text('重试'),
              ),
            ],
          );
        },
      );

      KazumiLogger().e('Update: download update failed', error: e);
    }
  }

  final ValueNotifier<double> _downloadProgress = ValueNotifier(0.0);
  CancelToken? _cancelToken;

  void _cancelDownload() {
    _cancelToken?.cancel();
  }

  /// 显示下载完成对话框
  void _showDownloadCompleteDialog(String filePath, UpdateInfo updateInfo) {
    // 替换当前的下载进度对话框内容
    KazumiDialog.dismiss();

    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('下载完成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('新版本 ${updateInfo.version} 已下载完成'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '安装过程中应用将会退出',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '文件位置:',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      filePath,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => KazumiDialog.dismiss(),
              child: Text(
                '稍后安装',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            if (isDesktop())
              TextButton(
                onPressed: () {
                  // 在文件管理器中显示文件
                  _revealInFileManager(filePath);
                },
                child: const Text('打开文件夹'),
              ),
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                _installUpdate(
                    filePath, updateInfo.recommendedInstallationType);
              },
              child: const Text('立即安装'),
            ),
          ],
        );
      },
    );
  }

  /// 下载文件
  Future<String> _downloadFile(
    List<String> urls,
    String version,
    String expectedHash,
    int expectedSizeBytes,
    InstallationType installationType,
  ) async {
    final normalizedExpectedHash = validateExpectedSha256(expectedHash);
    if (expectedSizeBytes <= 0 ||
        expectedSizeBytes > maxWindowsUpdateArtifactBytes) {
      throw const UpdateAssetPolicyException(
        'The expected update size is outside the allowed range',
      );
    }
    if (Platform.isWindows && !_artifactVerifier.supports(installationType)) {
      throw const UpdateArtifactVerificationException(
        'This Windows update type has no trusted artifact verifier',
      );
    }

    final downloadUris = <Uri>[];
    for (final url in urls) {
      final uri = validateUpdateDownloadUri(url, installationType);
      if (!downloadUris.contains(uri)) {
        downloadUris.add(uri);
      }
    }
    if (downloadUris.isEmpty) {
      throw const UpdateAssetPolicyException(
        'The update asset has no valid download URL',
      );
    }

    Object? lastError;
    StackTrace? lastStackTrace;
    for (final downloadUri in downloadUris) {
      try {
        return await _downloadFileFromUri(
          downloadUri,
          version,
          normalizedExpectedHash,
          expectedSizeBytes,
          installationType,
        );
      } catch (error, stackTrace) {
        if (error is NetworkException &&
            error.type == NetworkExceptionType.cancel) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        lastError = error;
        lastStackTrace = stackTrace;
        KazumiLogger().w(
          'Update: download candidate failed. host=${downloadUri.host}, '
          'errorType=${error.runtimeType}',
        );
      }
    }
    Error.throwWithStackTrace(
      lastError ?? const UpdateAssetPolicyException('Update download failed'),
      lastStackTrace ?? StackTrace.current,
    );
  }

  Future<String> _downloadFileFromUri(
    Uri downloadUri,
    String version,
    String normalizedExpectedHash,
    int expectedSizeBytes,
    InstallationType installationType,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final canonicalTempRoot =
        await Directory(tempDir.path).resolveSymbolicLinks();
    final fileName = buildControlledUpdateFilename(
      installationType: installationType,
      version: version,
      uniqueToken: _generateSecureUpdateToken(),
    );
    final filePath = resolveContainedUpdatePath(canonicalTempRoot, fileName);
    final partPath =
        resolveContainedUpdatePath(canonicalTempRoot, '$fileName.part');
    final partFile = File(partPath);
    var promoted = false;
    var verified = false;
    var sizeLimitExceeded = false;

    await _assertUnusedUpdatePath(filePath);
    await _assertUnusedUpdatePath(partPath);
    _cancelToken = CancelToken();

    try {
      try {
        await _downloadClient.download(
          downloadUri.toString(),
          partPath,
          cancelToken: _cancelToken,
          onReceiveProgress: (received, total) {
            if (received > maxWindowsUpdateArtifactBytes ||
                total > maxWindowsUpdateArtifactBytes) {
              sizeLimitExceeded = true;
              _cancelToken?.cancel('Update artifact exceeds size limit');
              return;
            }
            _downloadProgress.value =
                (received / expectedSizeBytes).clamp(0.0, 0.99);
          },
        );
      } catch (error, stackTrace) {
        if (sizeLimitExceeded) {
          Error.throwWithStackTrace(
            const UpdateAssetPolicyException(
              'The downloaded update exceeded the allowed size',
            ),
            stackTrace,
          );
        }
        Error.throwWithStackTrace(error, stackTrace);
      }

      final partType =
          await FileSystemEntity.type(partPath, followLinks: false);
      if (partType != FileSystemEntityType.file) {
        throw const UpdateAssetPolicyException(
          'The downloaded update is not a regular file',
        );
      }

      if (await partFile.length() != expectedSizeBytes) {
        throw const UpdateAssetPolicyException(
          'The downloaded update size does not match release metadata',
        );
      }

      final downloadedHash = (await calculateFileHash(partFile)).toLowerCase();
      if (downloadedHash != normalizedExpectedHash) {
        throw Exception(
          '文件完整性验证失败: 期望 $normalizedExpectedHash，实际 $downloadedHash',
        );
      }

      await _assertUnusedUpdatePath(filePath);
      final finalFile = await partFile.rename(filePath);
      promoted = true;

      if (Platform.isWindows) {
        await _artifactVerifier.verify(
          filePath: finalFile.path,
          installationType: installationType,
        );
      }

      verified = true;
      _downloadProgress.value = 1.0;
      KazumiLogger().i(
        'Update: artifact hash and publisher verified: $filePath',
      );
      return filePath;
    } finally {
      _cancelToken = null;
      await _deleteRegularUpdateFile(partPath);
      if (promoted && !verified) {
        await _deleteRegularUpdateFile(filePath);
      }
    }
  }

  String _generateSecureUpdateToken() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<void> _assertUnusedUpdatePath(String filePath) async {
    final entityType =
        await FileSystemEntity.type(filePath, followLinks: false);
    if (entityType != FileSystemEntityType.notFound) {
      throw const UpdateAssetPolicyException(
        'A generated update path already exists',
      );
    }
  }

  Future<void> _deleteRegularUpdateFile(String filePath) async {
    final entityType =
        await FileSystemEntity.type(filePath, followLinks: false);
    if (entityType == FileSystemEntityType.file) {
      await File(filePath).delete();
    }
  }

  /// 安装更新
  void _installUpdate(
      String filePath, InstallationType installationType) async {
    try {
      // 显示准备退出的提示
      KazumiDialog.showToast(message: '准备安装更新，应用即将退出...');

      await Future.delayed(const Duration(seconds: 2));

      if (Platform.isWindows) {
        if (installationType == InstallationType.windowsMsix) {
          final Uri fileUri = Uri.file(filePath);
          if (await canLaunchUrl(fileUri)) {
            await launchUrl(fileUri);
          } else {
            throw 'Could not launch $fileUri';
          }
        } else {
          await Process.start('explorer.exe', [filePath], runInShell: true);
        }
        await Future.delayed(const Duration(seconds: 1));
        await ApplicationLifecycleService.flushBeforeExit();
        exit(0);
      } else if (Platform.isMacOS) {
        if (filePath.endsWith('.dmg')) {
          await Process.start('open', [filePath]);
          exit(0);
        }
      } else if (Platform.isAndroid) {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          KazumiDialog.showToast(message: '无法打开安装文件: ${result.message}');
          return;
        }
      }
    } catch (e) {
      KazumiDialog.showToast(message: '启动安装程序失败: ${e.toString()}');
      KazumiLogger().e('Update: launch installer failed', error: e);
    }
  }

  /// 在文件管理器中显示文件
  void _revealInFileManager(String filePath) async {
    try {
      final type = await FileSystemEntity.type(filePath);
      String targetDirOrFile;

      // 如果传入的本来就是目录则打开这个目录
      // 如果是文件则打开包含它的目录
      if (type == FileSystemEntityType.notFound) {
        KazumiDialog.showToast(message: '文件或目录不存在');
        return;
      } else if (type == FileSystemEntityType.directory) {
        targetDirOrFile = filePath;
      } else {
        targetDirOrFile = File(filePath).parent.path;
      }

      if (Platform.isWindows) {
        if (type == FileSystemEntityType.file) {
          final arg = '/select,${filePath.replaceAll('/', r'\')}';
          await Process.start('explorer.exe', [arg], runInShell: true);
        } else {
          await Process.start(
              'explorer.exe', [targetDirOrFile.replaceAll('/', r'\')],
              runInShell: true);
        }
      } else if (Platform.isMacOS) {
        if (type == FileSystemEntityType.file) {
          await Process.start('open', ['-R', filePath]);
        } else {
          await Process.start('open', [targetDirOrFile]);
        }
      } else if (Platform.isLinux) {
        // 尝试打开包含文件的文件夹
        await Process.start('xdg-open', [targetDirOrFile]);
      } else {
        KazumiDialog.showToast(message: '此平台不支持通过此方法打开文件管理器');
      }
    } catch (e) {
      KazumiDialog.showToast(message: '无法打开文件管理器');
      KazumiLogger().w('Update: reveal in file manager failed', error: e);
    } finally {
      try {
        // 确保对话框被关闭
        KazumiDialog.dismiss();
      } catch (_) {}
    }
  }
}
