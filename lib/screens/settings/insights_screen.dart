import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group.dart';
import '../../providers/groups_provider.dart';
import '../../widgets/fade_slide_item.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final groups = Provider.of<GroupsProvider>(context).groups;

    final pageBg = isDark ? cs.surface : Colors.white;
    final cardBg = isDark ? cs.surfaceContainerHighest : Colors.white;

    final totalSpent =
        groups.fold<double>(0, (s, g) => s + g.totalExpenses);
    final youAreOwed = groups
        .where((g) => g.balance > 0)
        .fold<double>(0, (s, g) => s + g.balance);
    final youOwe = groups
        .where((g) => g.balance < 0)
        .fold<double>(0, (s, g) => s + g.balance.abs());
    final totalGroups = groups.length;
    final totalMembers = groups.fold<int>(0, (s, g) => s + g.members);

    final groupSpending = groups
        .where((g) => g.totalExpenses > 0)
        .toList()
      ..sort((a, b) => b.totalExpenses.compareTo(a.totalExpenses));
    final topGroups = groupSpending.take(5).toList();

    final settled = groups.where((g) => g.balance.abs() < 0.01).length;
    final owedGroups = groups.where((g) => g.balance > 0).length;
    final oweGroups = groups.where((g) => g.balance < 0).length;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Insights'),
        backgroundColor: isDark ? cs.surface : null,
        foregroundColor: isDark ? cs.onSurface : null,
        elevation: 0,
      ),
      body: groups.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No group data yet.\nJoin or create a group to see insights.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Summary cards row
                    FadeSlideItem(
                      index: 0,
                      child: Row(
                        children: [
                          _SummaryCard(
                            label: 'Total Spent',
                            value: 'Rs. ${totalSpent.toStringAsFixed(0)}',
                            icon: Icons.payments_outlined,
                            color: const Color(0xFF4F7D6A),
                            cardBg: cardBg,
                            cs: cs,
                          ),
                          const SizedBox(width: 10),
                          _SummaryCard(
                            label: 'You Are Owed',
                            value: 'Rs. ${youAreOwed.toStringAsFixed(0)}',
                            icon: Icons.arrow_downward_rounded,
                            color: const Color(0xFF2E7D32),
                            cardBg: cardBg,
                            cs: cs,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeSlideItem(
                      index: 1,
                      child: Row(
                        children: [
                          _SummaryCard(
                            label: 'You Owe',
                            value: 'Rs. ${youOwe.toStringAsFixed(0)}',
                            icon: Icons.arrow_upward_rounded,
                            color: const Color(0xFFCC7A29),
                            cardBg: cardBg,
                            cs: cs,
                          ),
                          const SizedBox(width: 10),
                          _SummaryCard(
                            label: 'Groups / Members',
                            value: '$totalGroups / $totalMembers',
                            icon: Icons.groups_outlined,
                            color: cs.secondary,
                            cardBg: cardBg,
                            cs: cs,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pie chart — animated sweep
                    FadeSlideItem(
                      index: 2,
                      child: _InsightCard(
                        title: 'Balance Status',
                        cardBg: cardBg,
                        cs: cs,
                        child: _BalancePieChart(
                          settled: settled,
                          owedGroups: owedGroups,
                          oweGroups: oweGroups,
                          progress: _anim.value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bar chart — animated bars
                    if (topGroups.isNotEmpty) ...[
                      FadeSlideItem(
                        index: 3,
                        child: _InsightCard(
                          title: 'Top Groups by Spending',
                          cardBg: cardBg,
                          cs: cs,
                          child: _GroupBarChart(
                            groups: topGroups,
                            progress: _anim.value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Net balance list
                    FadeSlideItem(
                      index: 4,
                      child: _InsightCard(
                        title: 'Net Balance Overview',
                        cardBg: cardBg,
                        cs: cs,
                        child: _NetBalanceList(groups: groups, cs: cs),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Avg spend
                    FadeSlideItem(
                      index: 5,
                      child: _InsightCard(
                        title: 'Average Spend per Group',
                        cardBg: cardBg,
                        cs: cs,
                        child: _AvgSpendList(
                          groups: groupSpending.take(6).toList(),
                          cs: cs,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.cardBg,
    required this.cs,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color cardBg;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.child,
    required this.cardBg,
    required this.cs,
  });

  final String title;
  final Widget child;
  final Color cardBg;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Animated Pie Chart ───────────────────────────────────────────────────────

class _BalancePieChart extends StatelessWidget {
  const _BalancePieChart({
    required this.settled,
    required this.owedGroups,
    required this.oweGroups,
    required this.progress,
  });

  final int settled;
  final int owedGroups;
  final int oweGroups;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final total = settled + owedGroups + oweGroups;
    if (total == 0) {
      return const Center(child: Text('No data'));
    }

    final slices = <_PieSlice>[
      if (owedGroups > 0)
        _PieSlice(
          value: owedGroups / total,
          color: const Color(0xFF4F7D6A),
          label: 'Owed to You',
          count: owedGroups,
        ),
      if (oweGroups > 0)
        _PieSlice(
          value: oweGroups / total,
          color: const Color(0xFFE8AC73),
          label: 'You Owe',
          count: oweGroups,
        ),
      if (settled > 0)
        _PieSlice(
          value: settled / total,
          color: Colors.blueGrey.shade300,
          label: 'Settled',
          count: settled,
        ),
    ];

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: CustomPaint(
            painter: _PieChartPainter(slices, progress),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: slices
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${s.count}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: s.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _PieSlice {
  const _PieSlice({
    required this.value,
    required this.color,
    required this.label,
    required this.count,
  });
  final double value;
  final Color color;
  final String label;
  final int count;
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter(this.slices, this.progress);
  final List<_PieSlice> slices;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = min(cx, cy) - 6;
    final paint = Paint()..style = PaintingStyle.fill;
    double startAngle = -pi / 2;

    // Draw each slice proportional to progress (sweep animation)
    double drawnFraction = 0;
    for (final slice in slices) {
      final targetFraction = slice.value;
      final available = progress - drawnFraction;
      if (available <= 0) break;
      final fraction = min(targetFraction, available);
      final sweep = fraction * 2 * pi;
      paint.color = slice.color;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      startAngle += sweep;
      drawnFraction += fraction;
    }

    // Donut hole
    paint.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(cx, cy), radius * 0.52, paint);
  }

  @override
  bool shouldRepaint(_PieChartPainter old) => old.progress != progress;
}

// ─── Animated Bar Chart ───────────────────────────────────────────────────────

class _GroupBarChart extends StatelessWidget {
  const _GroupBarChart({required this.groups, required this.progress});
  final List<Group> groups;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final maxVal = groups.map((g) => g.totalExpenses).reduce(max);
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: groups.asMap().entries.map((entry) {
        final idx = entry.key;
        final g = entry.value;
        // Stagger: each bar starts animating slightly after the previous one
        final barProgress = ((progress - idx * 0.1) / (1 - idx * 0.1))
            .clamp(0.0, 1.0);
        final ratio = maxVal > 0 ? g.totalExpenses / maxVal : 0.0;
        final animatedRatio = ratio * barProgress;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      g.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Rs. ${g.totalExpenses.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4F7D6A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (ctx, constraints) => Stack(
                  children: [
                    Container(
                      height: 10,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Container(
                      height: 10,
                      width: constraints.maxWidth * animatedRatio,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F7D6A), Color(0xFFE8AC73)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Net Balance List ─────────────────────────────────────────────────────────

class _NetBalanceList extends StatelessWidget {
  const _NetBalanceList({required this.groups, required this.cs});
  final List<Group> groups;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Text('No groups yet.');
    }
    return Column(
      children: groups.asMap().entries.map((entry) {
        final g = entry.value;
        final isPositive = g.balance > 0.01;
        final isNegative = g.balance < -0.01;
        final color = isPositive
            ? const Color(0xFF4F7D6A)
            : isNegative
                ? const Color(0xFFCC7A29)
                : Colors.grey;
        final label = isPositive
            ? 'Owed to you'
            : isNegative
                ? 'You owe'
                : 'Settled';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  g.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${g.balance.abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Avg Spend List ───────────────────────────────────────────────────────────

class _AvgSpendList extends StatelessWidget {
  const _AvgSpendList({required this.groups, required this.cs});
  final List<Group> groups;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Text('No spending data yet.');
    }
    return Column(
      children: groups.map((g) {
        final avg = g.members > 0 ? g.totalExpenses / g.members : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    const Color(0xFF4F7D6A).withValues(alpha: 0.12),
                child: Text(
                  g.name.isNotEmpty ? g.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Color(0xFF4F7D6A),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${g.members} members',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${avg.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFCC7A29),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'avg/person',
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
