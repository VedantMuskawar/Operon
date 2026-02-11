/// Utility for calculating trend (percent change) between current and previous values.
library;

enum TrendDirection { up, down, neutral }

/// Result of trend calculation for display in stat cards.
class TrendResult {
  const TrendResult({
    required this.percentChange,
    required this.direction,
  });

  final double percentChange;
  final TrendDirection direction;

  String get badgeText {
    final symbol = direction == TrendDirection.up
        ? '↑'
        : direction == TrendDirection.down
            ? '↓'
            : '—';
    return '$symbol ${percentChange.abs().toStringAsFixed(1)}% vs last month';
  }
}

/// Computes the percentage change and direction between current and previous values.
/// Returns neutral with 0% when previous is zero.
TrendResult calculateTrend(num currentValue, num previousValue) {
  final curr = currentValue.toDouble();
  final prev = previousValue.toDouble();
  if (prev == 0) {
    return const TrendResult(
      percentChange: 0,
      direction: TrendDirection.neutral,
    );
  }
  final percentChange = (curr - prev) / prev * 100;
  final direction = percentChange > 0
      ? TrendDirection.up
      : percentChange < 0
          ? TrendDirection.down
          : TrendDirection.neutral;
  return TrendResult(
    percentChange: percentChange,
    direction: direction,
  );
}
