import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/bangumi_avatar.dart';

void main() {
  testWidgets('uses the proxy-aware cached image widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BangumiAvatar(imageUrl: 'https://lain.bgm.tv/avatar.jpg'),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://lain.bgm.tv/avatar.jpg');
    expect(image.errorListener, isNotNull);
    expect(image.errorWidget, isNotNull);
    expect(image.placeholder, isNotNull);
    expect(image.fadeInDuration, const Duration(milliseconds: 120));
    expect(image.fadeOutDuration, const Duration(milliseconds: 120));
  });

  testWidgets('falls back for empty image URLs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BangumiAvatar(imageUrl: '')),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    final provider = avatar.backgroundImage! as AssetImage;
    expect(provider.assetName, 'assets/images/noface.jpeg');
  });

  testWidgets('uses the local fallback after an image error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BangumiAvatar(imageUrl: 'https://lain.bgm.tv/broken.jpg'),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    final context = tester.element(find.byType(CachedNetworkImage));
    final fallback = image.errorWidget!(
      context,
      image.imageUrl,
      Exception('image failed'),
    ) as CircleAvatar;
    final provider = fallback.backgroundImage! as AssetImage;
    expect(provider.assetName, 'assets/images/noface.jpeg');
  });
}
