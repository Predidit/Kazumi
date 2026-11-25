import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/download/download_manager.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final payload = List.generate(3500, (i) => i % 251);
  const block = 1024;
  late Directory root;
  late Directory directory;
  late HttpServer server;
  late PathProviderPlatform originalPaths;
  late HttpOverrides? originalOverrides;
  late Level originalLogLevel;
  late DownloadEpisode episode;
  late void Function(HttpResponse response, String? range) serve;
  final ranges = <String?>[];
  final validators = <String?>[];

  File getFile(String name) => File('${directory.path}/$name');

  void partial(
    HttpResponse response,
    int start,
    int end, {
    String? contentRange,
    List<int>? body,
  }) {
    response.statusCode = HttpStatus.partialContent;
    response.headers.set(
      HttpHeaders.contentRangeHeader,
      contentRange ?? 'bytes $start-$end/${payload.length}',
    );
    response.add(body ?? payload.sublist(start, end + 1));
  }

  setUpAll(() async {
    originalLogLevel = Logger.level;
    Logger.level = Level.off;
    DioFactory.reset();
    originalOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    originalPaths = PathProviderPlatform.instance;
    root = await Directory.systemTemp.createTemp('kazumi-direct-ranges-');
    PathProviderPlatform.instance = _Paths(root.path);
    Hive.init(root.path);
    await GStorage.init();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType('video', 'mp4');
      if (ranges.isEmpty) {
        // The manager first probes the URL for an M3U8 playlist.
        request.response.add(payload.sublist(0, block));
      } else {
        serve(request.response, request.headers.value(HttpHeaders.rangeHeader));
      }
      ranges.add(request.headers.value(HttpHeaders.rangeHeader));
      validators.add(request.headers.value(HttpHeaders.ifRangeHeader));
      try {
        await request.response.close();
      } on IOException {
        // A rejected response may already have been closed by the downloader.
      }
    });
  });

  setUp(() async {
    ranges.clear();
    validators.clear();
    directory = await root.createTemp('episode-');
    episode = DownloadEpisode(
      1,
      'episode',
      0,
      DownloadStatus.pending,
      0,
      0,
      0,
      '',
      directory.path,
      '',
      null,
      '',
      0,
      '',
    );
  });

  tearDownAll(() async {
    DioFactory.reset();
    await server.close(force: true);
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    HttpOverrides.global = originalOverrides;
    await root.delete(recursive: true);
    Logger.level = originalLogLevel;
  });

  Future<void> download({
    bool resume = false,
    int? pauseAt,
    DownloadManager? downloader,
  }) async {
    final request = DownloadRequest(
      recordKey: 'record',
      bangumiId: 1,
      pluginName: 'test',
      episodeNumber: 1,
      m3u8Url: 'http://127.0.0.1:${server.port}/video.mp4',
      httpHeaders: {},
      adBlockerEnabled: false,
      episode: episode,
    );
    final manager = downloader ?? DownloadManager();
    final done = Completer<void>();
    manager.onProgress = (_, _, current, _) {
      if (current.status == DownloadStatus.downloading &&
          current.totalBytes == pauseAt) {
        manager.pause('record', 1);
      }
      if (!done.isCompleted &&
          (current.status == DownloadStatus.completed ||
              current.status == DownloadStatus.paused ||
              current.status == DownloadStatus.failed)) {
        done.complete();
      }
    };
    if (resume) {
      if (!await getFile('video.mp4.tmp').exists()) {
        await getFile('video.mp4.tmp').writeAsBytes(payload.sublist(0, block));
      }
      await manager.resume(request);
    } else {
      await manager.enqueue(request);
    }
    await done.future.timeout(const Duration(seconds: 15));
  }

  Future<void> expectComplete() async {
    expect(
      episode.status,
      DownloadStatus.completed,
      reason: episode.errorMessage,
    );
    final file = File(episode.localM3u8Path);
    expect(await file.length(), payload.length);
    expect(await file.readAsBytes(), orderedEquals(payload));
    expect(episode.totalBytes, payload.length);
    expect(episode.progressPercent, 1.0);
    expect(await getFile('video.mp4.tmp').exists(), isFalse);
  }

  test(
    'continues a capped first GET until the whole file is present',
    () async {
      int? statusAfterFirst;
      double? progressAfterFirst;
      bool? publishedAfterFirst;
      serve = (response, range) {
        response.headers.set(HttpHeaders.etagHeader, '"episode-v1"');
        final start = range == null
            ? 0
            : int.parse(range.substring(6, range.length - 1));
        if (start == block) {
          statusAfterFirst = episode.status;
          progressAfterFirst = episode.progressPercent;
          publishedAfterFirst = getFile('video.mp4').existsSync();
        }
        partial(response, start, min(start + block, payload.length) - 1);
      };
      await download();
      await expectComplete();
      expect(statusAfterFirst, DownloadStatus.downloading);
      expect(progressAfterFirst, block / payload.length);
      expect(publishedAfterFirst, isFalse);
      expect(ranges, [null, null, 'bytes=1024-', 'bytes=2048-', 'bytes=3072-']);
      expect(validators, [
        null,
        null,
        '"episode-v1"',
        '"episode-v1"',
        '"episode-v1"',
      ]);
    },
  );

  test('downloads a full 200 without Content-Length', () async {
    serve = (response, _) => response.add(payload);
    await download();
    await expectComplete();
    expect(ranges, [null, null]);
  });

  for (final tags in [
    <String>[],
    ['"v1"', '"v2"'],
  ]) {
    test('rejects a tagged resume with continuation ETags $tags', () async {
      serve = (response, _) {
        response.headers.set(HttpHeaders.etagHeader, '"v1"');
        partial(response, 0, block - 1);
      };
      await download(pauseAt: block);
      expect(episode.status, DownloadStatus.paused);
      ranges.clear();
      validators.clear();

      serve = (response, _) {
        response.headers.noFolding(HttpHeaders.etagHeader);
        for (final tag in tags) {
          response.headers.add(HttpHeaders.etagHeader, tag);
        }
        partial(response, block, payload.length - 1);
      };
      await download(resume: true);
      expect(ranges, [null, 'bytes=1024-']);
      expect(validators, [null, '"v1"']);
      expect(episode.status, DownloadStatus.failed);
      expect(episode.totalBytes, 0);
      expect(await getFile('video.mp4').exists(), isFalse);
      expect(await getFile('video.mp4.tmp').exists(), isFalse);
      expect(await getFile('video.mp4.tmp.etag').exists(), isFalse);
    });
  }

  test('does not adopt a validator first seen after byte zero', () async {
    serve = (response, range) {
      final start = range == null
          ? 0
          : int.parse(range.substring(6, range.length - 1));
      if (start == block) response.headers.set(HttpHeaders.etagHeader, '"v2"');
      partial(response, start, min(start + block, payload.length) - 1);
    };
    await download();
    await expectComplete();
    expect(ranges, [null, null, 'bytes=1024-', 'bytes=2048-', 'bytes=3072-']);
    expect(validators, everyElement(isNull));
  });

  test('resumes from an existing prefix', () async {
    serve = (response, _) => partial(response, block, payload.length - 1);
    await download(resume: true);
    await expectComplete();
    expect(ranges, [null, 'bytes=1024-']);
  });

  test('pauses after the first block and resumes from disk', () async {
    serve = (response, range) {
      if (range == null) {
        partial(response, 0, block - 1);
      } else {
        partial(response, block, payload.length - 1);
      }
    };
    await download(pauseAt: block);
    expect(episode.status, DownloadStatus.paused);
    expect(ranges, [null, null]);
    expect(await getFile('video.mp4').exists(), isFalse);
    expect(
      await getFile('video.mp4.tmp').readAsBytes(),
      payload.sublist(0, block),
    );
    ranges.clear();
    await download(resume: true);
    await expectComplete();
    expect(ranges, [null, 'bytes=1024-']);
  });

  test('replaces the prefix when the range request returns 200', () async {
    serve = (response, _) {
      response.contentLength = payload.length;
      response.add(payload);
    };
    await download(resume: true);
    await expectComplete();
    expect(ranges, [null, 'bytes=1024-']);
  });

  test('restarts when the saved range is unsatisfiable', () async {
    serve = (response, range) {
      if (range == null) {
        response.add(payload);
      } else {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes */${payload.length}',
        );
      }
    };
    await download(resume: true);
    await expectComplete();
    expect(ranges, [null, 'bytes=1024-', null]);
  });

  for (final declareLength in [true, false]) {
    test(
      'keeps the prefix on empty 200 (length declared: $declareLength)',
      () async {
        episode.totalBytes = block;
        episode.progressPercent = block / payload.length;
        serve = (response, _) {
          if (declareLength) response.contentLength = 0;
        };
        await download(resume: true);
        expect(episode.status, DownloadStatus.failed);
        expect(ranges, [null, 'bytes=1024-']);
        expect(
          await getFile('video.mp4.tmp').readAsBytes(),
          payload.sublist(0, block),
        );
        expect(episode.totalBytes, block);
        expect(episode.progressPercent, block / payload.length);
      },
    );
  }

  test(
    'drops an unsatisfiable prefix even when the replacement GET fails',
    () async {
      serve = (response, range) {
        response.statusCode = range == null ? 503 : 416;
        if (range != null) {
          response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */50');
        }
      };
      await download(resume: true);
      expect(ranges, [null, 'bytes=1024-', null]);
      expect(episode.status, DownloadStatus.failed);
      expect(await getFile('video.mp4.tmp').exists(), isFalse);
      expect(episode.totalBytes, 0);
    },
  );

  test('drops a prefix when the file shrinks between ranges', () async {
    serve = (response, range) {
      if (range == null) {
        partial(response, 0, block - 1);
      } else {
        response.statusCode = 416;
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */50');
      }
    };
    await download();
    expect(ranges, [null, null, 'bytes=1024-']);
    expect(episode.status, DownloadStatus.failed);
    expect(await getFile('video.mp4.tmp').exists(), isFalse);
    expect(episode.totalBytes, 0);
  });

  for (final sameVersion in [true, false]) {
    test(
      'resumes a full temp file after 416 (same ETag: $sameVersion)',
      () async {
        serve = (response, _) {
          response.headers.set(HttpHeaders.etagHeader, '"v1"');
          partial(response, 0, payload.length - 1);
        };
        await download(pauseAt: payload.length);
        expect(episode.status, DownloadStatus.paused);
        expect(await getFile('video.mp4.tmp').readAsBytes(), payload);
        ranges.clear();
        validators.clear();
        final replacement = sameVersion ? payload : payload.reversed.toList();
        serve = (response, range) {
          response.headers.set(
            HttpHeaders.etagHeader,
            sameVersion ? '"v1"' : '"v2"',
          );
          if (range != null) {
            response.statusCode = 416;
            response.headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes */${payload.length}',
            );
          } else {
            response.add(replacement);
          }
        };
        await download(resume: true);
        expect(ranges, [
          null,
          'bytes=${payload.length}-',
          if (!sameVersion) null,
        ]);
        expect(validators[1], '"v1"');
        expect(
          episode.status,
          DownloadStatus.completed,
          reason: episode.errorMessage,
        );
        expect(await getFile('video.mp4').readAsBytes(), replacement);
        expect(await getFile('video.mp4.tmp.etag').exists(), isFalse);
      },
    );
  }

  test('does not publish an unverified same-length file after 416', () async {
    await getFile('video.mp4.tmp').writeAsBytes(payload.reversed.toList());
    serve = (response, range) {
      response.headers.set(HttpHeaders.etagHeader, '"v1"');
      if (range == null) {
        response.add(payload);
      } else {
        response.statusCode = 416;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes */${payload.length}',
        );
      }
    };
    await download(resume: true);
    expect(ranges, [null, 'bytes=${payload.length}-', null]);
    await expectComplete();
  });

  for (final encoding in ['', 'identity, IDENTITY']) {
    test('accepts identity-only 206 coding "$encoding"', () async {
      serve = (response, _) {
        response.headers.set(HttpHeaders.contentEncodingHeader, encoding);
        partial(response, 0, payload.length - 1);
      };
      await download();
      await expectComplete();
    });
  }

  test(
    'accepts multiple identity encoding values from the HTTP adapter',
    () async {
      final dio = DioFactory.downloadDio;
      final interceptor = InterceptorsWrapper(
        onResponse: (response, handler) {
          if (response.statusCode == HttpStatus.partialContent) {
            response.headers.set(HttpHeaders.contentEncodingHeader, [
              '',
              'identity',
            ]);
          }
          handler.next(response);
        },
      );
      dio.interceptors.add(interceptor);
      addTearDown(() => dio.interceptors.remove(interceptor));
      serve = (response, _) => partial(response, 0, payload.length - 1);
      await download();
      await expectComplete();
    },
  );

  test('keeps the prefix on an undecoded deflate 200', () async {
    serve = (response, _) {
      response.headers.set(HttpHeaders.contentEncodingHeader, 'deflate');
      response.add(zlib.encode(payload));
    };
    await download(resume: true);
    expect(episode.status, DownloadStatus.failed);
    expect(await getFile('video.mp4').exists(), isFalse);
    expect(
      await getFile('video.mp4.tmp').readAsBytes(),
      payload.sublist(0, block),
    );
  });

  test('accepts an automatically decoded gzip 200', () async {
    serve = (response, _) {
      response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      response.add(gzip.encode(payload));
    };
    await download(resume: true);
    await expectComplete();
  });

  test('rejects a gzip range before appending any bytes', () async {
    serve = (response, _) {
      response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      partial(
        response,
        block,
        payload.length - 1,
        body: gzip.encode(payload.sublist(block)),
      );
    };
    await download(resume: true);
    expect(episode.status, DownloadStatus.failed);
    expect(
      await getFile('video.mp4.tmp').readAsBytes(),
      payload.sublist(0, block),
    );
  });

  for (final pause in [true, false]) {
    test('handles a mid-stream error (paused: $pause)', () async {
      final manager = DownloadManager();
      final interceptor = InterceptorsWrapper(
        onResponse: (response, handler) {
          if (response.data case final ResponseBody body) {
            body.stream = body.stream.map((chunk) {
              if (pause) {
                manager.pause('record', 1);
                throw const SocketException('connection closed');
              }
              throw DioException.receiveTimeout(
                timeout: const Duration(seconds: 1),
                requestOptions: response.requestOptions,
              );
            });
          }
          handler.next(response);
        },
      );
      final dio = DioFactory.downloadDio;
      dio.interceptors.add(interceptor);
      addTearDown(() => dio.interceptors.remove(interceptor));
      serve = (response, _) => response.add(payload);
      await download(resume: true, downloader: manager);
      expect(ranges, [null, 'bytes=1024-']);
      expect(
        episode.status,
        pause ? DownloadStatus.paused : DownloadStatus.failed,
      );
      if (!pause) expect(episode.errorMessage, '响应超时，请稍后重试！');
      expect(
        await getFile('video.mp4.tmp').readAsBytes(),
        payload.sublist(0, block),
      );
    });
  }

  for (final header in [
    'bytes 0-1023/3500',
    'bytes 1024-3500/3500',
    'invalid',
  ]) {
    test('rejects inconsistent continuation $header', () async {
      serve = (response, range) {
        if (range == null) {
          partial(response, 0, block - 1);
        } else {
          partial(response, block, 2 * block - 1, contentRange: header);
        }
      };
      await download();
      expect(episode.status, DownloadStatus.failed);
      expect(await getFile('video.mp4').exists(), isFalse);
      expect(
        await getFile('video.mp4.tmp').readAsBytes(),
        payload.sublist(0, block),
      );
      expect(ranges, [null, null, 'bytes=1024-']);
    });
  }

  for (final changeETag in [true, false]) {
    test(
      'discards a stale prefix when the ${changeETag ? "ETag" : "total size"} changes',
      () async {
        serve = (response, range) {
          final first = range == null;
          response.headers.set(
            HttpHeaders.etagHeader,
            first || !changeETag ? '"v1"' : '"v2"',
          );
          partial(
            response,
            first ? 0 : block,
            first ? block - 1 : payload.length - 1,
            contentRange: first || changeETag ? null : 'bytes 1024-3499/3600',
          );
        };
        await download();
        expect(episode.status, DownloadStatus.failed);
        expect(ranges, [null, null, 'bytes=1024-']);
        expect(episode.totalBytes, 0);
        expect(await getFile('video.mp4').exists(), isFalse);
        expect(await getFile('video.mp4.tmp').exists(), isFalse);
      },
    );
  }

  for (final length in [block - 1, block + 1]) {
    test('rejects a $length-byte body for a $block-byte range', () async {
      serve = (response, _) => partial(
        response,
        block,
        2 * block - 1,
        body: payload.sublist(block, block + length),
      );
      await download(resume: true);
      expect(episode.status, DownloadStatus.failed);
      expect(await getFile('video.mp4').exists(), isFalse);
      final prefix = await getFile('video.mp4.tmp').readAsBytes();
      expect(prefix.length, inInclusiveRange(block, 2 * block));
      expect(prefix, payload.sublist(0, prefix.length));
      expect(ranges, [null, 'bytes=1024-']);
    });
  }
}
