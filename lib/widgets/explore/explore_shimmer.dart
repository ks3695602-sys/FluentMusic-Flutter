/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'package:flutter/cupertino.dart';

/// A sweep highlight painted over every skeleton block in [child].
///
/// All blocks share one controller so the light travels across the whole page
/// instead of each card pulsing on its own.
class ExploreShimmer extends StatefulWidget {
  const ExploreShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<ExploreShimmer> createState() => _ExploreShimmerState();
}

class _ExploreShimmerState extends State<ExploreShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final base = (isDark ? CupertinoColors.white : CupertinoColors.black)
        .withValues(alpha: isDark ? 0.10 : 0.06);
    final highlight = (isDark ? CupertinoColors.white : CupertinoColors.black)
        .withValues(alpha: isDark ? 0.26 : 0.14);

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final slide = _controller.value * 3 - 1.5;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.0 + slide, 0),
            end: Alignment(1.0 + slide, 0),
            colors: [base, highlight, base],
            stops: const [0.1, 0.5, 0.9],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// A single rounded skeleton block.
class ExploreShimmerBox extends StatelessWidget {
  const ExploreShimmerBox({
    this.width,
    this.height,
    this.borderRadius = 14,
    this.margin,
    super.key,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: (isDark ? CupertinoColors.white : CupertinoColors.black)
            .withValues(alpha: isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// The Explore page while its first feed is loading.
class ExploreFeedSkeleton extends StatelessWidget {
  const ExploreFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ExploreShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + 14,
          20,
          40,
        ),
        children: [
          const ExploreShimmerBox(width: 150, height: 34, borderRadius: 10),
          const SizedBox(height: 10),
          const ExploreShimmerBox(width: 250, height: 14, borderRadius: 7),
          const SizedBox(height: 26),
          const ExploreShimmerBox(width: 110, height: 18, borderRadius: 8),
          const SizedBox(height: 12),
          SizedBox(
            height: 246,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const ExploreShimmerBox(
                width: 138,
                height: 246,
                borderRadius: 22,
              ),
            ),
          ),
          const SizedBox(height: 26),
          const ExploreShimmerBox(
            width: double.infinity,
            height: 170,
            borderRadius: 26,
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              for (var index = 0; index < 3; index++) ...[
                const ExploreShimmerBox(
                  width: 92,
                  height: 34,
                  borderRadius: 17,
                ),
                const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 28),
          for (var index = 0; index < 4; index++) ...[
            Row(
              children: [
                const ExploreShimmerBox(
                  width: 52,
                  height: 52,
                  borderRadius: 14,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ExploreShimmerBox(
                        width: double.infinity,
                        height: 14,
                        borderRadius: 7,
                      ),
                      const SizedBox(height: 8),
                      ExploreShimmerBox(
                        width: index.isEven ? 150 : 110,
                        height: 12,
                        borderRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
