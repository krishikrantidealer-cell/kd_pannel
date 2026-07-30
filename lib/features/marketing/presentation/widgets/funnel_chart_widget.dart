import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';

class FunnelStepData {
  final String stepName;
  final int userCount;
  final int eventCount;
  final double conversionRate; // % from initial step
  final Color stepColor;

  const FunnelStepData({
    required this.stepName,
    required this.userCount,
    this.eventCount = 0,
    required this.conversionRate,
    required this.stepColor,
  });
}

class FunnelChartWidget extends StatefulWidget {
  final List<FunnelStepData> steps;
  final bool isLoading;
  final ValueChanged<String>? onStepSelected;

  const FunnelChartWidget({
    super.key,
    required this.steps,
    this.isLoading = false,
    this.onStepSelected,
  });

  @override
  State<FunnelChartWidget> createState() => _FunnelChartWidgetState();
}

class _FunnelChartWidgetState extends State<FunnelChartWidget> {
  int? _hoveredIndex;
  int? _selectedIndex;
  String _selectedViewMode = 'Flow'; // 'Flow', 'Bars', 'Metrics'

  IconData _getStepIcon(int index, String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('visit') || nameLower.contains('app') || nameLower.contains('launch') || index == 0) {
      return Icons.touch_app_rounded;
    } else if (nameLower.contains('search') || nameLower.contains('view') || nameLower.contains('product')) {
      return Icons.search_rounded;
    } else if (nameLower.contains('cart') || nameLower.contains('add')) {
      return Icons.shopping_cart_rounded;
    } else if (nameLower.contains('checkout') || nameLower.contains('pay')) {
      return Icons.credit_card_rounded;
    } else {
      return Icons.check_circle_rounded;
    }
  }

  String _getStepRecommendation(int index, double dropOffPercent) {
    if (index == 0) return 'Top of funnel audience. Focus on high-converting landing pages.';
    if (dropOffPercent > 50) {
      return 'Critical Drop-off (${dropOffPercent.toStringAsFixed(1)}%)! High churn step requiring immediate campaign/UX optimization.';
    } else if (dropOffPercent > 25) {
      return 'Moderate Drop-off (${dropOffPercent.toStringAsFixed(1)}%). Consider retargeting push notifications or discount triggers.';
    } else {
      return 'Healthy Conversion (${(100 - dropOffPercent).toStringAsFixed(1)}% retained). Step is performing within optimal benchmarks.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingState();
    }

    if (widget.steps.isEmpty) {
      return _buildEmptyState();
    }

    final maxCount = widget.steps.first.userCount > 0 ? widget.steps.first.userCount : 1;
    final finalStep = widget.steps.last;
    final overallConversion = finalStep.conversionRate;

    // Find highest dropoff step
    int maxDropIndex = -1;
    double maxDropPercent = -1.0;
    for (int i = 1; i < widget.steps.length; i++) {
      final prev = widget.steps[i - 1].userCount;
      final curr = widget.steps[i].userCount;
      if (prev > 0) {
        final drop = ((1 - (curr / prev)) * 100).clamp(0.0, 100.0);
        if (drop > maxDropPercent) {
          maxDropPercent = drop;
          maxDropIndex = i;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          _buildHeader(overallConversion),

          const SizedBox(height: 20),

          // KPI Metric Summary Grid
          _buildKpiSummary(maxCount, finalStep.userCount, overallConversion, maxDropIndex, maxDropPercent),

          const SizedBox(height: 24),

          // View Mode Selector
          _buildViewModeSelector(),

          const SizedBox(height: 20),

          // Render Active View Mode
          if (_selectedViewMode == 'Flow')
            _buildFlowView(maxCount)
          else if (_selectedViewMode == 'Bars')
            _buildBarsView(maxCount)
          else
            _buildMetricsView(maxCount),

          // Detailed Selected Step Inspector Card
          if (_selectedIndex != null && _selectedIndex! < widget.steps.length) ...[
            const SizedBox(height: 20),
            _buildStepDetailCard(widget.steps[_selectedIndex!], _selectedIndex!),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(double overallConversion) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00897B), Color(0xFF004D40)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00897B).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.filter_alt_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Sales & Conversion Funnel',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: overallConversion > 15
                            ? Colors.green.shade50
                            : (overallConversion > 5 ? Colors.amber.shade50 : Colors.red.shade50),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: overallConversion > 15
                              ? Colors.green.shade300
                              : (overallConversion > 5 ? Colors.amber.shade300 : Colors.red.shade300),
                        ),
                      ),
                      child: Text(
                        overallConversion > 15 ? 'HIGH CONVERSION' : (overallConversion > 5 ? 'HEALTHY' : 'NEEDS ATTENTION'),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: overallConversion > 15
                              ? Colors.green.shade800
                              : (overallConversion > 5 ? Colors.amber.shade900 : Colors.red.shade800),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'End-to-end dealer purchasing journey drop-off and conversion analytics',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiSummary(int initialAudience, int convertedBuyers, double overallRate, int maxDropIndex, double maxDropPercent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        return Flex(
          direction: isCompact ? Axis.vertical : Axis.horizontal,
          children: [
            Expanded(
              flex: isCompact ? 0 : 1,
              child: _buildKpiCard(
                title: 'OVERALL CONVERSION RATE',
                value: '${overallRate.toStringAsFixed(1)}%',
                subtitle: '$convertedBuyers converted out of $initialAudience dealers',
                icon: Icons.auto_graph_rounded,
                color: const Color(0xFF00897B),
                gradientColors: [const Color(0xFF00897B), const Color(0xFF004D40)],
              ),
            ),
            SizedBox(width: isCompact ? 0 : 12, height: isCompact ? 10 : 0),
            Expanded(
              flex: isCompact ? 0 : 1,
              child: _buildKpiCard(
                title: 'TOTAL CONVERTED BUYERS',
                value: '$convertedBuyers',
                subtitle: 'Placed ≥1 completed non-cancelled order',
                icon: Icons.verified_user_rounded,
                color: const Color(0xFF1E88E5),
                gradientColors: [const Color(0xFF1E88E5), const Color(0xFF1565C0)],
              ),
            ),
            SizedBox(width: isCompact ? 0 : 12, height: isCompact ? 10 : 0),
            Expanded(
              flex: isCompact ? 0 : 1,
              child: _buildKpiCard(
                title: 'HIGHEST CHURN STEP',
                value: maxDropIndex > 0 ? widget.steps[maxDropIndex].stepName : 'None',
                subtitle: maxDropIndex > 0 ? '${maxDropPercent.toStringAsFixed(1)}% lost at this milestone' : 'Smooth conversion flow',
                icon: Icons.trending_down_rounded,
                color: const Color(0xFFE53935),
                gradientColors: [const Color(0xFFE53935), const Color(0xFFC62828)],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeSelector() {
    final modes = [
      {'id': 'Flow', 'label': 'Funnel Flow', 'icon': Icons.account_tree_rounded},
      {'id': 'Bars', 'label': 'Progress Bars', 'icon': Icons.bar_chart_rounded},
      {'id': 'Metrics', 'label': 'Drop-off Matrix', 'icon': Icons.grid_view_rounded},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'STAGE BREAKDOWN',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: modes.map((m) {
              final isSelected = _selectedViewMode == m['id'];
              return InkWell(
                onTap: () => setState(() => _selectedViewMode = m['id'] as String),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        m['icon'] as IconData,
                        size: 14,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        m['label'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFlowView(int maxCount) {
    return Column(
      children: List.generate(widget.steps.length, (index) {
        final step = widget.steps[index];
        final isHovered = _hoveredIndex == index;
        final isSelected = _selectedIndex == index;

        final double widthRatio = maxCount > 0 ? (step.userCount / maxCount).clamp(0.12, 1.0) : 0.12;

        final double dropOffPercent = index > 0 && widget.steps[index - 1].userCount > 0
            ? ((1 - (step.userCount / widget.steps[index - 1].userCount)) * 100).clamp(0.0, 100.0)
            : 0.0;

        final double stepToStepRetained = index > 0 && widget.steps[index - 1].userCount > 0
            ? ((step.userCount / widget.steps[index - 1].userCount) * 100).clamp(0.0, 100.0)
            : 100.0;

        return Column(
          children: [
            // Connector indicator between steps
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 44),
                    Container(
                      width: 2,
                      height: 24,
                      color: step.stepColor.withOpacity(0.4),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: dropOffPercent > 40 ? Colors.red.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: dropOffPercent > 40 ? Colors.red.shade200 : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            dropOffPercent > 40 ? Icons.warning_amber_rounded : Icons.south_rounded,
                            size: 12,
                            color: dropOffPercent > 40 ? Colors.red.shade700 : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '-${dropOffPercent.toStringAsFixed(1)}% Churn (${stepToStepRetained.toStringAsFixed(1)}% Retained)',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: dropOffPercent > 40 ? Colors.red.shade800 : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Step Card
            MouseRegion(
              onEnter: (_) => setState(() => _hoveredIndex = index),
              onExit: (_) => setState(() => _hoveredIndex = null),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = isSelected ? null : index;
                  });
                  widget.onStepSelected?.call(step.stepName);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? step.stepColor.withOpacity(0.08)
                        : (isHovered ? step.stepColor.withOpacity(0.03) : AppTheme.cardColor),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? step.stepColor
                          : (isHovered ? step.stepColor.withOpacity(0.5) : AppTheme.borderColor),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isHovered || isSelected
                        ? [
                            BoxShadow(
                              color: step.stepColor.withOpacity(0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Step Badge Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: step.stepColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: step.stepColor.withOpacity(0.3)),
                        ),
                        child: Center(
                          child: Icon(
                            _getStepIcon(index, step.stepName),
                            color: step.stepColor,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Step Title & Sequence
                      SizedBox(
                        width: 150,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STEP ${index + 1}',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: step.stepColor,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              step.stepName,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Trapezoid Funnel Bar
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                Container(
                                  height: 36,
                                  width: constraints.maxWidth,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeOutCubic,
                                  height: 36,
                                  width: constraints.maxWidth * widthRatio,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        step.stepColor.withOpacity(0.8),
                                        step.stepColor,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: step.stepColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  alignment: Alignment.centerLeft,
                                  child: ClipRect(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '${step.userCount} Dealers • ${step.eventCount >= 1000 ? (step.eventCount / 1000).toStringAsFixed(1) + 'k' : step.eventCount} Actions',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        if (constraints.maxWidth * widthRatio > 240) ...[
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              '${step.conversionRate.toStringAsFixed(1)}% of Total',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white.withOpacity(0.9),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Conversion Badge
                      Container(
                        width: 80,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: step.stepColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: step.stepColor.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${step.conversionRate.toStringAsFixed(1)}%',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: step.stepColor,
                              ),
                            ),
                            Text(
                              'Conversion',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBarsView(int maxCount) {
    return Column(
      children: List.generate(widget.steps.length, (index) {
        final step = widget.steps[index];
        final isSelected = _selectedIndex == index;
        final double widthRatio = maxCount > 0 ? (step.userCount / maxCount).clamp(0.05, 1.0) : 0.05;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoveredIndex = index),
            onExit: (_) => setState(() => _hoveredIndex = null),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIndex = isSelected ? null : index;
                });
                widget.onStepSelected?.call(step.stepName);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? step.stepColor.withOpacity(0.08)
                      : (_hoveredIndex == index ? step.stepColor.withOpacity(0.03) : AppTheme.cardColor),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? step.stepColor
                        : (_hoveredIndex == index ? step.stepColor.withOpacity(0.5) : AppTheme.borderColor),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        step.stepName,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? step.stepColor : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: 24,
                            width: MediaQuery.of(context).size.width * widthRatio * 0.4,
                            decoration: BoxDecoration(
                              color: step.stepColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${step.userCount} Dealers (${step.conversionRate.toStringAsFixed(1)}%)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: step.stepColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMetricsView(int maxCount) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widget.steps.length,
      itemBuilder: (context, index) {
        final step = widget.steps[index];
        final isSelected = _selectedIndex == index;
        final dropOffPercent = index > 0 && widget.steps[index - 1].userCount > 0
            ? ((1 - (step.userCount / widget.steps[index - 1].userCount)) * 100).clamp(0.0, 100.0)
            : 0.0;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = isSelected ? null : index;
              });
              widget.onStepSelected?.call(step.stepName);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? step.stepColor.withOpacity(0.08)
                    : (_hoveredIndex == index ? step.stepColor.withOpacity(0.03) : step.stepColor.withOpacity(0.04)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? step.stepColor
                      : (_hoveredIndex == index ? step.stepColor.withOpacity(0.5) : step.stepColor.withOpacity(0.2)),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STEP ${index + 1}: ${step.stepName.toUpperCase()}',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: step.stepColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Icon(_getStepIcon(index, step.stepName), size: 16, color: step.stepColor),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${step.userCount} Users',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '${step.eventCount} Actions',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${step.conversionRate.toStringAsFixed(1)}%',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: step.stepColor,
                        ),
                      ),
                    ],
                  ),
                  if (index > 0)
                    Text(
                      '${dropOffPercent.toStringAsFixed(1)}% churn from step ${index}',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    )
                  else
                    Text(
                      '100% Initial Baseline Audience',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepDetailCard(FunnelStepData step, int index) {
    final dropOffPercent = index > 0 && widget.steps[index - 1].userCount > 0
        ? ((1 - (step.userCount / widget.steps[index - 1].userCount)) * 100).clamp(0.0, 100.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: step.stepColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: step.stepColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: step.stepColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Step ${index + 1} Analysis: ${step.stepName}',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: step.stepColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _getStepRecommendation(index, dropOffPercent),
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Conversion Funnel Analysis',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Aggregating database milestones...',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...List.generate(4, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.filter_alt_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No Conversion Funnel Records Found',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'No order or milestone data matches the selected time range filter.',
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
