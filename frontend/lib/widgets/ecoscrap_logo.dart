import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EcoScrapLogo extends StatelessWidget {
  final double size;
  final double? borderRadius;
  final bool showBorder;
  final bool isCircle;
  final String? heroTag;

  const EcoScrapLogo({
    super.key,
    this.size = 36,
    this.borderRadius,
    this.showBorder = true,
    this.isCircle = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = isCircle
        ? size / 2
        : (borderRadius ?? (size > 60 ? 18.0 : (size > 36 ? 12.0 : 8.0)));

    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(effectiveRadius),
      child: Image.asset(
        'assets/EcoScrap_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'EcoScrap Logo',
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(effectiveRadius),
            ),
            child: Icon(
              Icons.recycling_rounded,
              color: AppTheme.primaryGreen,
              size: size * 0.6,
            ),
          );
        },
      ),
    );

    if (showBorder) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      imageWidget = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(effectiveRadius),
          border: Border.all(
            color: isDark ? const Color(0xFF2E2C28) : const Color(0xFFE5E2DA),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: size > 48 ? 10 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: imageWidget,
      );
    }

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: imageWidget);
    }
    return imageWidget;
  }
}

class EcoScrapBrandHeader extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  final String? subtitle;
  final CrossAxisAlignment crossAxisAlignment;

  const EcoScrapBrandHeader({
    super.key,
    this.logoSize = 32,
    this.fontSize = 20,
    this.subtitle,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        EcoScrapLogo(size: logoSize),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'EcoScrap',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: fontSize,
                color: AppTheme.getTextPrimary(context),
                letterSpacing: -0.5,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: fontSize * 0.55,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
