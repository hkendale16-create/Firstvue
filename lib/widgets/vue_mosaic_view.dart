import 'package:flutter/material.dart';

import '../services/discovery_feed_service.dart';
import '../theme/firstvue_theme.dart';
import 'vue_mosaic_layout.dart';
import 'vue_mosaic_tile.dart';

/// Quilted VUE mosaic: a 2x2 featured tile, stacked 1x1s beside it, then
/// repeating three-column rows. Cell size is pattern-based, not media-based.
class VueMosaicView extends StatelessWidget {
  final List<DiscoveryFeedItem> items;
  final int columns;
  final bool loadingMore;
  final EdgeInsetsGeometry padding;
  final void Function(DiscoveryFeedItem item) onOpen;
  final void Function(DiscoveryFeedItem item) onOpenProfile;
  final Widget Function(VueMosaicCell cell, DiscoveryFeedItem? item)?
  tileBuilder;

  const VueMosaicView({
    super.key,
    required this.items,
    required this.columns,
    required this.onOpen,
    required this.onOpenProfile,
    this.loadingMore = false,
    this.padding = EdgeInsets.zero,
    this.tileBuilder,
  });

  static const double spacing = 3;
  static const double cellAspectRatio = 0.78;

  @override
  Widget build(BuildContext context) {
    final cells = buildVueMosaic(itemCount: items.length, columns: columns);
    final bands = groupVueMosaicBands(cells);
    return ListView.builder(
      padding: padding,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: bands.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= bands.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FirstVueColors.gold,
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: _VueMosaicBandView(
            band: bands[index],
            columns: columns,
            spacing: spacing,
            aspectRatio: cellAspectRatio,
            items: items,
            tileBuilder: tileBuilder,
            onOpen: onOpen,
            onOpenProfile: onOpenProfile,
          ),
        );
      },
    );
  }
}

class _VueMosaicBandView extends StatelessWidget {
  final VueMosaicBand band;
  final int columns;
  final double spacing;
  final double aspectRatio;
  final List<DiscoveryFeedItem> items;
  final Widget Function(VueMosaicCell cell, DiscoveryFeedItem? item)?
  tileBuilder;
  final void Function(DiscoveryFeedItem item) onOpen;
  final void Function(DiscoveryFeedItem item) onOpenProfile;

  const _VueMosaicBandView({
    required this.band,
    required this.columns,
    required this.spacing,
    required this.aspectRatio,
    required this.items,
    required this.onOpen,
    required this.onOpenProfile,
    this.tileBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cellHeight = cellWidth / aspectRatio;
        return switch (band) {
          VueFeaturedBand(:final featured, :final stacked) => SizedBox(
            height: cellHeight * 2 + spacing,
            child: _featuredRow(featured: featured, stacked: stacked),
          ),
          VueUniformBand(:final tiles) => SizedBox(
            height: cellHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) SizedBox(width: spacing),
                  Expanded(child: _tileAtColumn(tiles, column)),
                ],
              ],
            ),
          ),
        };
      },
    );
  }

  Widget _featuredRow({
    required VueMosaicCell featured,
    required List<VueMosaicCell> stacked,
  }) {
    final children = <Widget>[];
    var column = 0;
    while (column < columns) {
      if (column > 0) children.add(SizedBox(width: spacing));
      if (column == featured.column) {
        children.add(Expanded(flex: 2, child: _tile(featured)));
        column += 2;
        continue;
      }
      final top = stacked.where(
        (cell) => cell.column == column && cell.row == featured.row,
      );
      final bottom = stacked.where(
        (cell) => cell.column == column && cell.row == featured.row + 1,
      );
      children.add(
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: top.isEmpty ? const SizedBox.shrink() : _tile(top.first),
              ),
              SizedBox(height: spacing),
              Expanded(
                child: bottom.isEmpty
                    ? const SizedBox.shrink()
                    : _tile(bottom.first),
              ),
            ],
          ),
        ),
      );
      column += 1;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _tileAtColumn(List<VueMosaicCell> tiles, int column) {
    for (final cell in tiles) {
      if (cell.column == column) return _tile(cell);
    }
    return const SizedBox.shrink();
  }

  Widget _tile(VueMosaicCell cell) {
    final item = cell.index < items.length ? items[cell.index] : null;
    final child = tileBuilder != null
        ? tileBuilder!(cell, item)
        : item == null
        ? const SizedBox.shrink()
        : VueMosaicTile(
            item: item,
            featured: cell.featured,
            onOpen: () => onOpen(item),
            onOpenProfile: () => onOpenProfile(item),
          );
    return KeyedSubtree(
      key: ValueKey(
        cell.featured ? 'featured-${cell.index}' : 'tile-${cell.index}',
      ),
      child: SizedBox.expand(child: child),
    );
  }
}
