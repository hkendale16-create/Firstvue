/// Deterministic VUE discovery mosaic: a 2x2 featured tile plus 1x1 tiles.
///
/// Tile size comes from the grid pattern, never from the source video or
/// photo dimensions. Media is cropped with a cover fit at paint time.
class VueMosaicCell {
  const VueMosaicCell({
    required this.index,
    required this.column,
    required this.row,
    this.columnSpan = 1,
    this.rowSpan = 1,
    this.featured = false,
  });

  final int index;
  final int column;
  final int row;
  final int columnSpan;
  final int rowSpan;
  final bool featured;

  @override
  bool operator ==(Object other) {
    return other is VueMosaicCell &&
        other.index == index &&
        other.column == column &&
        other.row == row &&
        other.columnSpan == columnSpan &&
        other.rowSpan == rowSpan &&
        other.featured == featured;
  }

  @override
  int get hashCode =>
      Object.hash(index, column, row, columnSpan, rowSpan, featured);
}

/// Builds a quilted three-column (or wider) mosaic.
///
/// Pattern, repeating:
/// 1. Featured 2x2 on the left, with 1x1 tiles stacked in the remaining columns.
/// 2. A full row of 1x1 tiles.
/// 3. Featured 2x2 on the right, with 1x1 tiles stacked beside it.
/// 4. A full row of 1x1 tiles.
List<VueMosaicCell> buildVueMosaic({
  required int itemCount,
  required int columns,
}) {
  if (itemCount <= 0) return const [];
  if (columns < 3) {
    return [
      for (var i = 0; i < itemCount; i++)
        VueMosaicCell(index: i, column: i % columns, row: i ~/ columns),
    ];
  }

  final occupied = <List<bool>>[];

  bool isFree(int row, int column) {
    if (column < 0 || column >= columns || row < 0) return false;
    if (row >= occupied.length) return true;
    return !occupied[row][column];
  }

  void ensureRow(int row) {
    while (occupied.length <= row) {
      occupied.add(List<bool>.filled(columns, false));
    }
  }

  bool regionFree(int row, int column, int rowSpan, int columnSpan) {
    for (var y = 0; y < rowSpan; y++) {
      for (var x = 0; x < columnSpan; x++) {
        if (!isFree(row + y, column + x)) return false;
      }
    }
    return true;
  }

  void mark(int row, int column, int rowSpan, int columnSpan) {
    for (var y = 0; y < rowSpan; y++) {
      ensureRow(row + y);
      for (var x = 0; x < columnSpan; x++) {
        occupied[row + y][column + x] = true;
      }
    }
  }

  (int, int) firstFree({required int rowSpan, required int columnSpan}) {
    var row = 0;
    while (true) {
      ensureRow(row);
      for (var column = 0; column <= columns - columnSpan; column++) {
        if (regionFree(row, column, rowSpan, columnSpan)) {
          return (row, column);
        }
      }
      row++;
    }
  }

  // One featured 2x2, two stacked 1x1s per leftover column, then a 1x1 row.
  final cycleLength = 1 + (2 * (columns - 2)) + columns;
  final cells = <VueMosaicCell>[];
  var featuredOnLeft = true;
  var sinceFeatured = 0;
  var wantFeatured = true;

  for (var i = 0; i < itemCount; i++) {
    if (wantFeatured) {
      final featuredColumn = featuredOnLeft ? 0 : columns - 2;
      var row = 0;
      while (!regionFree(row, featuredColumn, 2, 2)) {
        row++;
      }
      cells.add(
        VueMosaicCell(
          index: i,
          column: featuredColumn,
          row: row,
          columnSpan: 2,
          rowSpan: 2,
          featured: true,
        ),
      );
      mark(row, featuredColumn, 2, 2);
      featuredOnLeft = !featuredOnLeft;
      wantFeatured = false;
      sinceFeatured = 1;
      continue;
    }

    final slot = firstFree(rowSpan: 1, columnSpan: 1);
    cells.add(VueMosaicCell(index: i, column: slot.$2, row: slot.$1));
    mark(slot.$1, slot.$2, 1, 1);
    sinceFeatured++;
    if (sinceFeatured >= cycleLength) {
      wantFeatured = true;
      sinceFeatured = 0;
    }
  }

  return cells;
}

/// Same mosaic, then [trailingCount] extra 1x1 cells on the next row
/// (used for the pagination spinner so it never becomes a 2x2 featured tile).
List<VueMosaicCell> buildVueMosaicWithTrailing({
  required int itemCount,
  required int columns,
  int trailingCount = 0,
}) {
  final cells = [...buildVueMosaic(itemCount: itemCount, columns: columns)];
  if (trailingCount <= 0) return cells;
  var nextRow = 0;
  for (final cell in cells) {
    final bottom = cell.row + cell.rowSpan;
    if (bottom > nextRow) nextRow = bottom;
  }
  for (var i = 0; i < trailingCount; i++) {
    cells.add(
      VueMosaicCell(
        index: itemCount + i,
        column: i % columns,
        row: nextRow + i ~/ columns,
      ),
    );
  }
  return cells;
}

/// One 2-row featured quilt or one uniform 1x1 row.
sealed class VueMosaicBand {
  const VueMosaicBand();
}

class VueFeaturedBand extends VueMosaicBand {
  const VueFeaturedBand({required this.featured, required this.stacked});

  final VueMosaicCell featured;
  final List<VueMosaicCell> stacked;
}

class VueUniformBand extends VueMosaicBand {
  const VueUniformBand({required this.tiles});

  final List<VueMosaicCell> tiles;
}

List<VueMosaicBand> groupVueMosaicBands(List<VueMosaicCell> cells) {
  if (cells.isEmpty) return const [];
  final byRow = <int, List<VueMosaicCell>>{};
  var maxRow = 0;
  for (final cell in cells) {
    byRow.putIfAbsent(cell.row, () => []).add(cell);
    final bottom = cell.row + cell.rowSpan - 1;
    if (bottom > maxRow) maxRow = bottom;
  }

  final bands = <VueMosaicBand>[];
  var row = 0;
  while (row <= maxRow) {
    final here = byRow[row] ?? const <VueMosaicCell>[];
    VueMosaicCell? featured;
    for (final cell in here) {
      if (cell.featured) {
        featured = cell;
        break;
      }
    }
    if (featured != null) {
      final stacked =
          <VueMosaicCell>[
            ...here.where((cell) => !cell.featured),
            ...(byRow[row + 1] ?? const <VueMosaicCell>[]).where(
              (cell) => !cell.featured,
            ),
          ]..sort((a, b) {
            final byColumn = a.column.compareTo(b.column);
            return byColumn != 0 ? byColumn : a.row.compareTo(b.row);
          });
      bands.add(VueFeaturedBand(featured: featured, stacked: stacked));
      row += 2;
      continue;
    }
    final tiles = [...here]..sort((a, b) => a.column.compareTo(b.column));
    if (tiles.isNotEmpty) {
      bands.add(VueUniformBand(tiles: tiles));
    }
    row += 1;
  }
  return bands;
}

/// Highest-ranked items fill featured 2x2 slots first, skipping the creator
/// who was featured last so the same person is not repeatedly favored.
List<T> assignVueMosaicItems<T>({
  required List<T> ranked,
  required List<VueMosaicCell> cells,
  required String Function(T) creatorId,
  String? lastFeaturedCreatorId,
}) {
  if (ranked.isEmpty || cells.isEmpty) return ranked;

  final used = List<bool>.filled(ranked.length, false);
  final assigned = List<T?>.filled(cells.length, null);
  var previousFeatured = lastFeaturedCreatorId;

  T? takeNext({String? avoidCreator}) {
    int? fallback;
    for (var i = 0; i < ranked.length; i++) {
      if (used[i]) continue;
      fallback ??= i;
      if (avoidCreator == null ||
          avoidCreator.isEmpty ||
          creatorId(ranked[i]) != avoidCreator) {
        used[i] = true;
        return ranked[i];
      }
    }
    if (fallback == null) return null;
    used[fallback] = true;
    return ranked[fallback];
  }

  for (final cell in cells) {
    if (!cell.featured) continue;
    final item = takeNext(avoidCreator: previousFeatured);
    if (item == null) break;
    assigned[cell.index] = item;
    previousFeatured = creatorId(item);
  }

  for (final cell in cells) {
    if (assigned[cell.index] != null) continue;
    assigned[cell.index] = takeNext();
  }

  return assigned.whereType<T>().toList();
}

String? leadingFeaturedCreatorId<T>({
  required List<T> items,
  required List<VueMosaicCell> cells,
  required String Function(T) creatorId,
}) {
  for (final cell in cells) {
    if (!cell.featured || cell.index >= items.length) continue;
    return creatorId(items[cell.index]);
  }
  return null;
}

String? formatVueDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return null;
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

String? vueLocationLabel({String? city, String? state}) {
  final parts = [city, state]
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty);
  if (parts.isEmpty) return null;
  return parts.join(', ');
}
