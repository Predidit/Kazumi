import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/search/image_search_page.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/pages/search/search_page.dart';

void _provideSearchController(Scoped scoped) {
  scoped.add<SearchPageController>(SearchPageController.new);
}

final searchModule = createModule(
  path: '/search',
  register: (c) {
    c
      ..route(
        '/',
        provide: _provideSearchController,
        child: (context, state) => SearchPage(
          controller: context.read<SearchPageController>(),
        ),
      )
      ..route(
        '/image',
        provide: _provideSearchController,
        child: (context, state) => ImageSearchPage(
          controller: context.read<SearchPageController>(),
        ),
      )
      ..route(
        '/:tag',
        provide: _provideSearchController,
        child: (context, state) => SearchPage(
          controller: context.read<SearchPageController>(),
          inputTag: state['tag'] ?? '',
        ),
      );
  },
);
