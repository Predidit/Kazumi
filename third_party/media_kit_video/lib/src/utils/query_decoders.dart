// This file is a part of media_kit (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the LICENSE file.
// ignore_for_file: implementation_imports

import 'dart:collection';
import 'dart:ffi';

import 'package:synchronized/synchronized.dart';
import 'package:media_kit/ffi/ffi.dart';
import 'package:media_kit/generated/libmpv/bindings.dart';
import 'package:media_kit/src/player/native/core/native_library.dart';
import 'package:media_kit/src/player/native/core/native_property.dart';

Future<HashSet<String>> queryDecoders(int handle) {
  return _lock.synchronized(() {
    if (_decoders.isNotEmpty) {
      return _decoders;
    }

    NativeLibrary.ensureInitialized();
    final mpv = MPV(DynamicLibrary.open(NativeLibrary.path));

    final decoders = readNativeNode(
      mpv,
      Pointer.fromAddress(handle),
      'decoder-list',
      (data) {
        final result = HashSet<String>();
        if (data.format != mpv_format.MPV_FORMAT_NODE_ARRAY) return result;
        final list = data.u.list.ref;
        for (var i = 0; i < list.num; i++) {
          final decoder = list.values[i];
          if (decoder.format != mpv_format.MPV_FORMAT_NODE_MAP) continue;
          final fields = decoder.u.list.ref;
          for (var j = 0; j < fields.num; j++) {
            final value = fields.values[j];
            if (value.format != mpv_format.MPV_FORMAT_STRING) continue;
            final key = fields.keys[j].cast<Utf8>().toDartString();
            if (key == 'codec' || key == 'driver') {
              result.add(value.u.string.cast<Utf8>().toDartString());
              break;
            }
          }
        }
        return result;
      },
    );
    if (decoders != null) _decoders.addAll(decoders);

    return _decoders;
  });
}

final Lock _lock = Lock();
final HashSet<String> _decoders = HashSet<String>();
