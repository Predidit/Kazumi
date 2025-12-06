import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:skeletonizer/skeletonizer.dart';

class BangumiInfoCardV extends StatefulWidget {
  const BangumiInfoCardV({
    super.key,
    required this.bangumiItem,
    required this.isLoading,
  });

  final BangumiItem bangumiItem;
  final bool isLoading;

  @override
  State<BangumiInfoCardV> createState() => _BangumiInfoCardVState();
}

class _BangumiInfoCardVState extends State<BangumiInfoCardV> {
  int touchedIndex = -1;
  int lastTouchedIndex = 0;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Widget get voteBarChart {
    double maxY = 0;
    if (widget.bangumiItem.votesCount.isNotEmpty) {
      maxY = widget.bangumiItem.votesCount.reduce(math.max).toDouble();
    }
    if (maxY == 0) maxY = 1.0;

    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '  评分透视:',
          ),
          SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 2,
            child: LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final chartDrawHeight = height - 30;

              final targetIndex =
              touchedIndex == -1 ? lastTouchedIndex : touchedIndex;
              final dataValue = widget.bangumiItem.votesCount.isNotEmpty
                  ? widget.bangumiItem.votesCount[targetIndex]
                  : 0;

              double barHeight = (dataValue / maxY) * chartDrawHeight;
              if (dataValue > 0 && barHeight < 4.0) {
                barHeight = 4.0;
              }

              final stepWidth = width / 10;
              final barCenterX = (targetIndex * stepWidth) + (stepWidth / 2);
              final barLeft = barCenterX - 10;

              double percentage = 0;
              int count = 0;
              if (widget.bangumiItem.votesCount.isNotEmpty) {
                count = widget.bangumiItem.votesCount[targetIndex];
                percentage = widget.bangumiItem.votes > 0
                    ? (count / widget.bangumiItem.votes * 100)
                    : 0;
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  BarChart(
                    duration: Duration.zero,
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(show: false),
                      barTouchData: BarTouchData(
                        touchCallback: (FlTouchEvent event, barTouchResponse) {
                          if (!event.isInterestedForInteractions ||
                              event is FlPanEndEvent ||
                              event is FlTapUpEvent) {
                            _debounceTimer?.cancel();
                            setState(() {
                              touchedIndex = -1;
                            });
                            return;
                          }

                          if (barTouchResponse == null ||
                              barTouchResponse.spot == null) {
                            if (_debounceTimer?.isActive != true) {
                              _debounceTimer = Timer(const Duration(milliseconds: 100), () {
                                if (mounted) {
                                  setState(() {
                                    touchedIndex = -1;
                                  });
                                }
                              });
                            }
                            return;
                          }

                          _debounceTimer?.cancel();

                          final newIndex =
                              barTouchResponse.spot!.touchedBarGroupIndex;

                          if (touchedIndex != newIndex) {
                            setState(() {
                              touchedIndex = newIndex;
                              lastTouchedIndex = newIndex;
                            });
                          }
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          null,
                        ),
                      ),
                      barGroups: List<BarChartGroupData>.generate(
                        10,
                            (i) => BarChartGroupData(
                          x: i + 1,
                          barRods: [
                            BarChartRodData(
                              toY: widget.bangumiItem.votesCount[i].toDouble(),
                              color: Theme.of(context).disabledColor,
                              width: 20,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(5)),
                            )
                          ],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) => SideTitleWidget(
                              meta: meta,
                              space: 10,
                              child: Text(value.toInt().toString()),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(),
                        leftTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                      ),
                    ),
                  ),

                  AnimatedPositioned(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    bottom: 30,
                    left: barLeft,
                    width: 20,
                    height: barHeight,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: touchedIndex == -1 ? 0 : 1,
                        duration: Duration(milliseconds: 200),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius:
                            BorderRadius.vertical(top: Radius.circular(5)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  AnimatedPositioned(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    bottom: 30 + barHeight,
                    left: barCenterX,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, -0.2),
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: touchedIndex == -1 ? 0 : 1,
                          duration: Duration(milliseconds: 200),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .inverseSurface
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${percentage.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onInverseSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    softWrap: false,
                                  ),
                                  Text(
                                    '$count 人',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onInverseSurface
                                          .withValues(alpha: 0.8),
                                      fontSize: 10,
                                    ),
                                    softWrap: false,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      constraints: BoxConstraints(maxWidth: 950),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.bangumiItem.nameCn == ''
                ? widget.bangumiItem.name
                : (widget.bangumiItem.nameCn),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: AspectRatio(
                    aspectRatio: 0.65,
                    child: LayoutBuilder(builder: (context, boxConstraints) {
                      final double maxWidth = boxConstraints.maxWidth;
                      final double maxHeight = boxConstraints.maxHeight;
                      return Hero(
                        transitionOnUserGestures: true,
                        tag: widget.bangumiItem.id,
                        child: NetworkImgLayer(
                          src: widget.bangumiItem.images['large'] ?? '',
                          width: maxWidth,
                          height: maxHeight,
                          fadeInDuration: const Duration(milliseconds: 0),
                          fadeOutDuration: const Duration(milliseconds: 0),
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(width: 16),
                Flexible(
                  child: Skeletonizer(
                    enabled: widget.isLoading,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '放送开始:',
                            ),
                            Text(
                              widget.bangumiItem.airDate == ''
                                  ? '2000-11-11' // Skeleton Loader 占位符
                                  : widget.bangumiItem.airDate,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${widget.bangumiItem.votes} 人评分:',
                            ),
                            if (widget.isLoading)
                            // Skeleton Loader 占位符
                              Text(
                                '10.0 ********',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            if (!widget.isLoading)
                              Row(
                                children: [
                                  Text(
                                    '${widget.bangumiItem.ratingScore}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color:
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  RatingBarIndicator(
                                    itemCount: 5,
                                    rating: widget.bangumiItem.ratingScore
                                        .toDouble() /
                                        2,
                                    itemBuilder: (context, index) => Icon(
                                      Icons.star_rounded,
                                      color:
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                    itemSize: 20.0,
                                  ),
                                ],
                              ),
                            SizedBox(height: 8),
                            Text(
                              'Bangumi Ranked:',
                            ),
                            Text(
                              '#${widget.bangumiItem.rank}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 120,
                          height: 40,
                          child: CollectButton.extend(
                            bangumiItem: widget.bangumiItem,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (MediaQuery.sizeOf(context).width >=
                    LayoutBreakpoint.compact['width']! &&
                    !widget.isLoading)
                  voteBarChart,
              ],
            ),
          ),
        ],
      ),
    );
  }
}