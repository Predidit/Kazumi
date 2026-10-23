import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:kazumi/services/network/image_file_service.dart';

class ProxyAwareImageCacheManager extends CacheManager with ImageCacheManager {
  static final ProxyAwareImageCacheManager instance =
      ProxyAwareImageCacheManager._(ImageFileService());

  ProxyAwareImageCacheManager._(this._fileService)
    : super(Config(DefaultCacheManager.key, fileService: _fileService));

  final ImageFileService _fileService;

  @override
  Future<void> dispose() async {
    _fileService.close();
    await super.dispose();
  }
}
