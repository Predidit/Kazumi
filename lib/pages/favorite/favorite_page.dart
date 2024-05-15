import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/constans.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/pages/favorite/favorite_controller.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final FavoriteController favoriteController =
      Modular.get<FavoriteController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('追番')),
      body: favoriteController.favorites.isEmpty ? 
      const Center(
        child: Text('啊咧（⊙.⊙） 没有追番的说'),
      )
      : CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(StyleString.cardSpace),
            sliver: contentGrid(favoriteController.favorites),
          ),
        ],
      ),
    );
  }

  Widget contentGrid(List bangumiList) {
    int crossCount = Platform.isWindows || Platform.isLinux ? 6 : 3;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        mainAxisSpacing: StyleString.cardSpace - 2,
        crossAxisSpacing: StyleString.cardSpace,
        crossAxisCount: crossCount,
        mainAxisExtent: MediaQuery.of(context).size.width / crossCount / 0.65 +
            MediaQuery.textScalerOf(context).scale(32.0),
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          if (bangumiList.isNotEmpty) {
            return BangumiCardV(bangumiItem: bangumiList[index]);
          } else {
            return Container(); // 返回一个空容器以避免返回 null
          }
        },
        childCount: bangumiList.isNotEmpty ? bangumiList.length : 10,
      ),
    );
  }
}
