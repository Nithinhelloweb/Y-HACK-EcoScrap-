import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../voice_state.dart';

class MicrophoneButton extends StatefulWidget {
  final VoiceStatus status;
  final bool isHandsFree;
  final VoidCallback onPressDown;
  final VoidCallback onPressUp;
  final VoidCallback onTapHandsFree;

  const MicrophoneButton({
    super.key,
    required this.status,
    required this.isHandsFree,
    required this.onPressDown,
    required this.onPressUp,
    required this.onTapHandsFree,
  });

  @override
  State<MicrophoneButton> createState() => _MicrophoneButtonState();
}

class _MicrophoneButtonState extends State<MicrophoneButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.status == VoiceStatus.listening;
    final isProcessing = widget.status == VoiceStatus.processing;
    final isSpeaking = widget.status == VoiceStatus.speaking;

    Color btnColor = AppTheme.collectorColor;
    if (isListening) {
      btnColor = AppTheme.alertAmber;
    } else if (isProcessing) {
      btnColor = AppTheme.infoBlue;
    } else if (isSpeaking) {
      btnColor = Colors.teal;
    }

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.isHandsFree ? null : (_) => widget.onPressDown(),
        onTapUp: widget.isHandsFree ? null : (_) => widget.onPressUp(),
        onTapCancel: widget.isHandsFree ? null : () => widget.onPressUp(),
        onTap: widget.isHandsFree ? widget.onTapHandsFree : null,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final scale = isListening ? _pulseAnimation.value : 1.0;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Radar Ring 1
                if (isListening)
                  Container(
                    width: 90 * scale,
                    height: 90 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: btnColor.withValues(alpha: 0.2),
                    ),
                  ),
                // Main Button
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        btnColor,
                        btnColor.withValues(alpha: 0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: btnColor.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: isListening ? 4 : 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isProcessing
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Icon(
                            isSpeaking
                                ? Icons.volume_up_rounded
                                : (isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                            color: Colors.white,
                            size: 34,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
