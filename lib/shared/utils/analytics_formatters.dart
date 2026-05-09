/// Formatting helpers for the Analytics tab — token counts and USD
/// costs. Pure functions, no widget dependencies.
library;

String formatTokens(int n) {
  if (n <= 0) return '0';
  if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(2)}B';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

String formatCostUsd(double usd) {
  if (usd <= 0) return r'$0';
  if (usd < 0.01) return r'<$0.01';
  if (usd < 1) return '\$${usd.toStringAsFixed(3)}';
  if (usd < 100) return '\$${usd.toStringAsFixed(2)}';
  return '\$${usd.round()}';
}
