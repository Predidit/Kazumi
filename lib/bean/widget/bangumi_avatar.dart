import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/services/logging/logger.dart';

class BangumiAvatar extends StatelessWidget {
  const BangumiAvatar({
    super.key,
    required this.imageUrl,
    this.radius,
  });

  final String imageUrl;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return _fallback();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: const Duration(milliseconds: 120),
      imageBuilder: (context, provider) => _avatar(provider),
      placeholder: (context, url) => _fallback(),
      errorWidget: (context, url, error) => _fallback(),
      errorListener: (error) {
        KazumiLogger().w(
          'BangumiAvatar: image load failed',
          error: error,
        );
      },
    );
  }

  Widget _avatar(ImageProvider<Object> provider) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: provider,
    );
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: radius,
      backgroundImage: const AssetImage('assets/images/noface.jpeg'),
    );
  }
}
