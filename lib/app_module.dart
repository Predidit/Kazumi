import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/core_module.dart';
import 'package:kazumi/pages/index_module.dart';

final appModule = createModule(
  register: (c) {
    c
      ..module(coreModule)
      ..module(indexModule);
  },
);
