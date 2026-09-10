import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../voice_state.dart';

class VoiceWaveform extends StatefulWidget {
  final VoiceStatus status;
  final double audioLevel;

  const VoiceWaveform({
    super.key,
    required this.status,
    required this.audioLevel,
  });

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.status == VoiceStatus.listening;
    final isSpeaking = widget.status == VoiceStatus.speaking;
    final isActive = isListening || isSpeaking;

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(24, (index) {
              double height = 6.0;
              if (isActive) {
                // Vocal frequency spectrum distribution across 24 bins (100 Hz to 6400 Hz)
                final freqFactor = 0.45 + 0.55 * math.sin((index / 23.0) * math.pi);
                final wavePhase = _waveController.value * 2 * math.pi;
                final barPhase = (index / 24.0) * 3 * math.pi;
                final sineVal = (math.sin(wavePhase + barPhase) + 1) / 2.0;
                final energy = isListening
                    ? math.max(0.25, widget.audioLevel)
                    : 0.65;
                height = 6.0 + 44.0 * sineVal * energy * freqFactor;
              }

              final color = isListening
                  ? AppTheme.collectorColor
                  : (isSpeaking ? Colors.teal : Colors.grey.withValues(alpha: 0.3));

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 3.5,
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
