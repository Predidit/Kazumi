import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:skeletonizer/skeletonizer.dart';

// 视频卡片 - 水平布局
class BangumiInfoCardV extends StatefulWidget {
  const BangumiInfoCardV({
    super.key,
    required this.bangumiItem,
    required this.isLoading,
    required this.showRating,
  });

  final BangumiItem bangumiItem;
  final bool isLoading;
  final bool showRating;

  @override
  State<BangumiInfoCardV> createState() => _BangumiInfoCardVState();
}

class _BangumiInfoCardVState extends State<BangumiInfoCardV> {
  static const double _extendedActionHeight = 40;
  // Reserve the Material tap target and inter-widget layout beyond text paint.
  static const double _materialControlMargin = 32;
  int touchedIndex = -1;

  Widget get voteBarChart {
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
            child: BarChart(
              duration: Duration(milliseconds: 80),
              BarChartData(
                // alignment: BarChartAlignment.spaceEvenly,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barTouchData: BarTouchData(
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex =
                          barTouchResponse.spot!.touchedBarGroupIndex;
                    });
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).colorScheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      var percentage =
                          widget.bangumiItem.votesCount[groupIndex] /
                              widget.bangumiItem.votes *
                              100;
                      return BarTooltipItem(
                        '${percentage.toStringAsFixed(2)}% (${widget.bangumiItem.votesCount[groupIndex]}人)',
                        TextStyle(
                            color:
                                Theme.of(context).colorScheme.onInverseSurface),
                      );
                    },
                  ),
                ),
                barGroups: List<BarChartGroupData>.generate(
                  10,
                  (i) => BarChartGroupData(
                    x: i + 1,
                    barRods: [
                      BarChartRodData(
                        toY: widget.bangumiItem.votesCount[i].toDouble(),
                        color: touchedIndex == i
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                        width: 20,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(5)),
                      )
                    ],
                    // showingTooltipIndicators: [0],
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
          ),
        ],
      ),
    );
  }

  Widget _buildInfoDetails() {
    final ratingWidgets = <Widget>[
      Text(
        widget.showRating ? '${widget.bangumiItem.ratingScore}' : '***',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      RatingBarIndicator(
        itemCount: 5,
        rating: widget.showRating
            ? widget.bangumiItem.ratingScore.toDouble() / 2
            : 0,
        itemBuilder: (context, index) => Icon(
          Icons.star_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        itemSize: 20.0,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('放送开始:'),
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
          widget.showRating ? '${widget.bangumiItem.votes} 人评分:' : '*** 人评分:',
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
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: ratingWidgets,
          ),
        SizedBox(height: 8),
        Text('Bangumi Ranked:'),
        Text(
          widget.showRating ? '#${widget.bangumiItem.rank}' : '***',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  double _textHeight(String text, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  double _requiredInfoHeight(double maxWidth) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final valueStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
    );
    final scoreStyle = valueStyle.copyWith(fontSize: 16);
    final date = widget.bangumiItem.airDate == ''
        ? '2000-11-11'
        : widget.bangumiItem.airDate;
    final ratingLabel =
        widget.showRating ? '${widget.bangumiItem.votes} 人评分:' : '*** 人评分:';
    final rank = widget.showRating ? '#${widget.bangumiItem.rank}' : '***';
    final score = widget.showRating ? '${widget.bangumiItem.ratingScore}' : '***';

    final scorePainter = TextPainter(
      text: TextSpan(text: score, style: scoreStyle),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout();
    final ratingHeight = scorePainter.width + 8 + 100 <= maxWidth
        ? scorePainter.height.clamp(20, double.infinity)
        : scorePainter.height + 4 + 20;

    return _textHeight('放送开始:', defaultStyle, maxWidth) +
        _textHeight(date, valueStyle, maxWidth) +
        8 +
        _textHeight(ratingLabel, defaultStyle, maxWidth) +
        (widget.isLoading
            ? _textHeight('10.0 ********', valueStyle, maxWidth)
            : ratingHeight) +
        8 +
        _textHeight('Bangumi Ranked:', defaultStyle, maxWidth) +
        _textHeight(rank, valueStyle, maxWidth) +
        _extendedActionHeight +
        _materialControlMargin;
  }

  Widget _buildCompactInfo(double maxWidth, double maxHeight) {
    final date = widget.bangumiItem.airDate == ''
        ? '2000-11-11'
        : widget.bangumiItem.airDate;
    final score = widget.showRating
        ? '${widget.bangumiItem.ratingScore} 分'
        : '*** 分';
    final dateStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
    );
    final scoreStyle = dateStyle.copyWith(fontSize: 16);
    final showScore = !widget.isLoading &&
        48 +
                4 +
                _textHeight(date, dateStyle, maxWidth) +
                _textHeight(score, scoreStyle, maxWidth) <=
            maxHeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollectButton(
          bangumiItem: widget.bangumiItem,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(height: 4),
        Text(
          date,
          key: const ValueKey('bangumi-info-date'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: dateStyle,
        ),
        if (showScore)
          Text(
            score,
            key: const ValueKey('bangumi-info-score'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: scoreStyle,
          ),
      ],
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
                        flightShuttleBuilder:
                            NetworkImgLayer.heroFlightShuttleBuilder,
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final useCompactLayout =
                          _requiredInfoHeight(constraints.maxWidth) >
                              constraints.maxHeight;
                      return Skeletonizer(
                        enabled: widget.isLoading,
                        child: useCompactLayout
                            ? _buildCompactInfo(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              )
                            : Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoDetails(),
                                  SizedBox(
                                    width: 120,
                                    height: 40,
                                    child: CollectButton.extend(
                                      bangumiItem: widget.bangumiItem,
                                    ),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
                ),
                if (widget.showRating &&
                    MediaQuery.sizeOf(context).width >=
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
