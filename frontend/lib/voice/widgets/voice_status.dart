import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../voice_state.dart';

class VoiceStatusPill extends StatelessWidget {
  final VoiceStatus status;

  const VoiceStatusPill({super.key, required this.status});

  Color _getStatusColor() {
    switch (status) {
      case VoiceStatus.idle:
        return AppTheme.collectorColor;
      case VoiceStatus.listening:
        return AppTheme.alertAmber;
      case VoiceStatus.processing:
        return AppTheme.infoBlue;
      case VoiceStatus.executing:
        return Colors.purple;
      case VoiceStatus.speaking:
        return Colors.teal;
      case VoiceStatus.error:
        return AppTheme.alertRed;
      case VoiceStatus.offline:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case VoiceStatus.idle:
        return Icons.mic_rounded;
      case VoiceStatus.listening:
        return Icons.hearing_rounded;
      case VoiceStatus.processing:
        return Icons.hourglass_top_rounded;
      case VoiceStatus.executing:
        return Icons.bolt_rounded;
      case VoiceStatus.speaking:
        return Icons.volume_up_rounded;
      case VoiceStatus.error:
        return Icons.error_outline_rounded;
      case VoiceStatus.offline:
        return Icons.cloud_off_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(), size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            status.displayName,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
