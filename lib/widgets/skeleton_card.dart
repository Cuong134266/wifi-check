import 'package:flutter/material.dart';

/// Skeleton shimmer card matching the layout of history/ranking cards.
class SkeletonCard extends StatefulWidget {
  final int index;
  final bool isRanking;

  const SkeletonCard({
    super.key,
    this.index = 0,
    this.isRanking = false,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _shimmerBox({double width = 80, double height = 14, double radius = 6}) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _shimmerController.value, 0),
              end: Alignment(-1.0 + 2.0 * _shimmerController.value + 1.0, 0),
              colors: const [
                Color(0xFFE5E7EB),
                Color(0xFFF3F4F6),
                Color(0xFFE5E7EB),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final delay = widget.index * 60;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(widget.isRanking ? 14 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: widget.isRanking ? _buildRankingSkeleton() : _buildHistorySkeleton(),
      ),
    );
  }

  Widget _buildHistorySkeleton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBox(width: 100, height: 14),
            const SizedBox(height: 8),
            _shimmerBox(width: 70, height: 12),
          ],
        ),
        _shimmerBox(width: 50, height: 22, radius: 4),
      ],
    );
  }

  Widget _buildRankingSkeleton() {
    return Row(
      children: [
        _shimmerBox(width: 28, height: 28, radius: 14),
        const SizedBox(width: 10),
        _shimmerBox(width: 36, height: 36, radius: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(width: 100, height: 14),
              const SizedBox(height: 6),
              _shimmerBox(width: 80, height: 10),
            ],
          ),
        ),
        _shimmerBox(width: 50, height: 24, radius: 12),
      ],
    );
  }
}

/// Skeleton list that shows multiple shimmer cards
class SkeletonList extends StatelessWidget {
  final int count;
  final bool isRanking;

  const SkeletonList({
    super.key,
    this.count = 6,
    this.isRanking = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isRanking ? 16 : 24,
        vertical: 8,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => SkeletonCard(
        index: index,
        isRanking: isRanking,
      ),
    );
  }
}
