import 'package:flutter/material.dart';
import 'package:negoo_super_admin/theme/app_theme.dart';

class RealtimeStatusBadge extends StatefulWidget {
  final String label;
  final bool isLive;
  final VoidCallback? onRefresh;

  const RealtimeStatusBadge({
    super.key,
    this.label = "LIVE STREAM",
    this.isLive = true,
    this.onRefresh,
  });

  @override
  State<RealtimeStatusBadge> createState() => _RealtimeStatusBadgeState();
}

class _RealtimeStatusBadgeState extends State<RealtimeStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onRefresh,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: widget.isLive
              ? AppColors.emerald.withValues(alpha: 0.12)
              : AppColors.rose.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.isLive
                ? AppColors.emerald.withValues(alpha: 0.3)
                : AppColors.rose.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isLive
                        ? AppColors.emerald.withValues(
                            alpha: _pulseAnimation.value,
                          )
                        : AppColors.rose.withValues(
                            alpha: _pulseAnimation.value,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isLive
                            ? AppColors.emerald.withValues(
                                alpha: _pulseAnimation.value * 0.7,
                              )
                            : AppColors.rose.withValues(
                                alpha: _pulseAnimation.value * 0.7,
                              ),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.isLive ? AppColors.emeraldLight : AppColors.roseLight,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            if (widget.onRefresh != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.refresh_rounded,
                size: 13,
                color: widget.isLive
                    ? AppColors.emeraldLight.withValues(alpha: 0.8)
                    : AppColors.roseLight.withValues(alpha: 0.8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
