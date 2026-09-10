import 'package:auto_injector/auto_injector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/app_injector.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/image_preview.dart';
import 'package:kazumi/di/route_scope.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/collect/collect_page.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/info/info_page.dart';
import 'package:kazumi/pages/init_page.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/tab_locations.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/my/my_page.dart';
import 'package:kazumi/pages/onboarding/onboarding_page.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:kazumi/pages/route_error_page.dart';
import 'package:kazumi/pages/search/image_search_page.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/pages/search/search_page.dart';
import 'package:kazumi/pages/settings/settings_routes.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/pages/timeline/timeline_page.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/video/video_page.dart';
import 'package:kazumi/pages/video/video_playback_args.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/routing/media_location.dart';
import 'package:kazumi/routing/media_resolver.dart';
import 'package:kazumi/routing/resolved_route.dart';
import 'package:kazumi/routing/startup_navigation.dart';
import 'package:kazumi/services/shaders/shader_asset_service.dart';

GoRouter createAppRouter(
    {AutoInjector? injector,
    String initialLocation = '/',
    StartupNavigation? startup}) {
  final dependencies = injector ?? appInjector;
  final initialization = startup ?? StartupNavigation();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    observers: [KazumiDialog.observer, rootRouteObserver],
    redirect: (context, state) {
      final path = state.uri.path;
      if (path.length > 1 && path.endsWith('/')) {
        return state.uri
            .replace(path: path.replaceFirst(RegExp(r'/+$'), ''))
            .toString();
      }
      return initialization.redirect(state.uri);
    },
    errorBuilder: (context, state) =>
        const RouteErrorPage(message: '页面不存在，请返回首页后重试。'),
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: InitPage(
            onReady: () =>
                context.go(initialization.complete(defaultTabLocation())),
            onNeedsOnboarding: () {
              initialization.beginOnboarding();
              context.go('/onboarding');
            },
            pluginsController: dependencies.get<PluginsController>(),
            collectController: dependencies.get<CollectController>(),
            shaderAssetService: dependencies.get<ShaderAssetService>(),
            myController: dependencies.get<MyController>(),
            downloadController: dependencies.get<DownloadController>(),
          ),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: OnboardingPage(
            onReady: () =>
                context.go(initialization.complete(defaultTabLocation())),
            pluginsController: dependencies.get<PluginsController>(),
            myController: dependencies.get<MyController>(),
          ),
        ),
      ),
      GoRoute(path: '/tab', redirect: (context, state) => defaultTabLocation()),
      ShellRoute(
        notifyRootObserver: false,
        pageBuilder: (context, state, child) => CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 70),
          reverseTransitionDuration: const Duration(milliseconds: 70),
          transitionsBuilder: _fadeTransition,
          child: RouteScope(
            // Retain tab controllers while replacing and unmounting tab pages.
            create: () => AutoInjector()
              ..addLazySingleton<PopularController>(
                  () => dependencies.get<PopularController>())
              ..addLazySingleton<TimelineController>(
                  () => dependencies.get<TimelineController>()),
            builder: (context, scope) => ScaffoldMenu(
              selectedIndex: tabLocations.indexOf(state.uri.path),
              child: child,
            ),
          ),
        ),
        routes: [
          GoRoute(
            path: tabLocations[0],
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: PopularPage(
                  controller: RouteScope.read<PopularController>(context)),
            ),
          ),
          GoRoute(
            path: tabLocations[1],
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: TimelinePage(
                  controller: RouteScope.read<TimelineController>(context)),
            ),
          ),
          GoRoute(
            path: tabLocations[2],
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: CollectPage(
                  controller: dependencies.get<CollectController>()),
            ),
          ),
          GoRoute(
            path: tabLocations[3],
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: MyPage(controller: dependencies.get<MyController>()),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/info/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) {
            return const RouteErrorPage(message: '番组详情参数无效，请返回后重新打开。');
          }
          Widget page(BangumiItem item) => _controllerScope<InfoController>(
                dependencies,
                (controller) => InfoPage(
                  inputBangumiItem: item,
                  infoController: controller,
                  pluginsController: dependencies.get<PluginsController>(),
                ),
                key: ValueKey(id),
                onDispose: (controller) => controller.dispose(),
              );
          final cached = state.extra;
          if (cached is BangumiItem && cached.id == id) return page(cached);
          return ResolvedRoute<BangumiItem>(
            key: ValueKey(id),
            load: (_) => dependencies.get<MediaResolver>().info(id),
            builder: page,
          );
        },
      ),
      GoRoute(
        path: '/video/:id',
        builder: (context, state) {
          final VideoLocation target;
          try {
            target = VideoLocation.parse(state.uri);
          } on FormatException catch (error) {
            return RouteErrorPage(message: error.message);
          }
          Widget page(VideoPlaybackArgs args) => RouteScope(
                key: ValueKey(target.location),
                create: () => AutoInjector()
                  ..addLazySingleton<VideoPageController>(
                    () => dependencies.get<VideoPageController>(),
                    config: BindConfig(
                        onDispose: (controller) => controller.dispose()),
                  )
                  ..addLazySingleton<PlayerController>(
                    () => dependencies.get<PlayerController>(),
                    config: BindConfig(
                        onDispose: (controller) => controller.dispose()),
                  ),
                builder: (context, scope) => VideoPage(
                  args: args,
                  playerController: scope.get<PlayerController>(),
                  videoPageController: scope.get<VideoPageController>(),
                  downloadController: dependencies.get<DownloadController>(),
                  collectController: dependencies.get<CollectController>(),
                  myController: dependencies.get<MyController>(),
                ),
              );
          final cached = state.extra;
          if (cached is VideoPlaybackArgs && target.matches(cached)) {
            return page(cached);
          }
          return ResolvedRoute<VideoPlaybackArgs>(
            key: ValueKey(target.location),
            load: (token) =>
                dependencies.get<MediaResolver>().video(target, token),
            builder: page,
          );
        },
      ),
      GoRoute(
        path: ImageViewer.routePath,
        pageBuilder: (context, state) {
          final args = state.extra;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 220),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            transitionsBuilder: _fadeTransition,
            child: args is ImageViewerRouteArgs
                ? ImageViewer(
                    imageUrls: args.imageUrls,
                    initialIndex: args.initialIndex,
                    heroTag: args.heroTag,
                  )
                : const RouteErrorPage(message: '图片预览参数无效，请返回后重试。'),
          );
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => _controllerScope<SearchPageController>(
          dependencies,
          (controller) => SearchPage(controller: controller),
          onDispose: (controller) => controller.dispose(),
        ),
      ),
      // A literal path must be matched before the dynamic tag route.
      GoRoute(
        path: '/search/image',
        builder: (context, state) => _controllerScope<SearchPageController>(
          dependencies,
          (controller) => ImageSearchPage(controller: controller),
          onDispose: (controller) => controller.dispose(),
        ),
      ),
      GoRoute(
        path: '/search/:tag',
        builder: (context, state) => _controllerScope<SearchPageController>(
          dependencies,
          (controller) => SearchPage(
            controller: controller,
            inputTag: state.pathParameters['tag'] ?? '',
          ),
          onDispose: (controller) => controller.dispose(),
        ),
      ),
      ...settingsRoutes(dependencies),
    ],
  );
}

Widget _controllerScope<T>(
  AutoInjector dependencies,
  Widget Function(T controller) builder, {
  Key? key,
  void Function(T)? onDispose,
}) =>
    RouteScope(
      key: key,
      create: () => AutoInjector()
        ..addLazySingleton<T>(() => dependencies.get<T>(),
            config: BindConfig(onDispose: onDispose)),
      builder: (context, scope) => builder(scope.get<T>()),
    );

Widget _fadeTransition(BuildContext context, Animation<double> animation,
        Animation<double> secondaryAnimation, Widget child) =>
    FadeTransition(opacity: animation, child: child);
