import 'package:auto_injector/auto_injector.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/routing/media_resolver.dart';
import 'package:kazumi/services/collection/collection_service.dart';
import 'package:kazumi/services/download/download_manager.dart';
import 'package:kazumi/services/player/audio_controller.dart';
import 'package:kazumi/services/player/history_playback_service.dart';
import 'package:kazumi/services/shaders/shader_asset_service.dart';

final appInjector = createAppInjector();

AutoInjector createAppInjector() {
  final injector = AutoInjector();
  injector
    ..addLazySingleton<ICollectRepository>(CollectRepository.new)
    ..addLazySingleton<ISearchHistoryRepository>(SearchHistoryRepository.new)
    ..addLazySingleton<IHistoryRepository>(() => HistoryRepository())
    ..addLazySingleton<IDownloadRepository>(DownloadRepository.new)
    ..addLazySingleton<IDownloadManager>(DownloadManager.new)
    ..addLazySingleton<AudioController>(AudioController.new)
    ..addLazySingleton<MediaResolver>(() => MediaResolver(
          injector.get<ICollectRepository>(),
          injector.get<IHistoryRepository>(),
          injector.get<PluginsController>(),
          injector.get<DownloadController>(),
        ))
    ..addLazySingleton<HistoryPlaybackService>(HistoryPlaybackService.new)
    ..addLazySingleton<ShaderAssetService>(ShaderAssetService.new)
    ..addLazySingleton<PluginsController>(PluginsController.new)
    ..addLazySingleton<CollectionService>(CollectionService.new,
        config: BindConfig(onDispose: (service) => service.dispose()))
    ..addLazySingleton<CollectController>(CollectController.new,
        config: BindConfig(onDispose: (controller) => controller.dispose()))
    ..addLazySingleton<HistoryController>(HistoryController.new,
        config: BindConfig(onDispose: (controller) => controller.dispose()))
    ..addLazySingleton<MyController>(MyController.new)
    ..addLazySingleton<DownloadController>(DownloadController.new)
    ..addLazySingleton<ThemeProvider>(ThemeProvider.new,
        config: BindConfig(onDispose: (theme) => theme.dispose()))
    ..add<InfoController>(InfoController.new)
    ..add<SearchPageController>(SearchPageController.new)
    ..add<VideoPageController>(VideoPageController.new)
    ..add<PlayerController>(PlayerController.new)
    ..add<PopularController>(PopularController.new)
    ..add<TimelineController>(TimelineController.new);
  injector.commit();
  return injector;
}
