import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class DownloadPlayerPage extends StatefulWidget {
  final String videoPath;
  final String title;

  const DownloadPlayerPage({
    super.key,
    required this.videoPath,
    required this.title,
  });

  @override
  State<DownloadPlayerPage> createState() => _DownloadPlayerPageState();
}

class _DownloadPlayerPageState extends State<DownloadPlayerPage> {
  late final Player _player;
  late final VideoController _videoController;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _player.open(Media(widget.videoPath));
  }

  @override
  void dispose() {
    _player.dispose();
    if (_isFullscreen) {
      _exitFullscreen();
    }
    super.dispose();
  }

  void _enterFullscreen() {
    setState(() => _isFullscreen = true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _exitFullscreen() {
    setState(() => _isFullscreen = false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: Video(
                controller: _videoController,
                controls: AdaptiveVideoControls,
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 4,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                onPressed: _exitFullscreen,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: SysAppBar(title: Text(widget.title)),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Video(
              controller: _videoController,
              controls: AdaptiveVideoControls,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: _enterFullscreen,
                  tooltip: '全屏',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
