// Stub file for non-web platforms.
// On non-web builds, dart:html is unavailable, so this stub satisfies
// the conditional import in camera_scanner_modal.dart without pulling in
// any web-only APIs.

import 'dart:typed_data';
import 'package:flutter/material.dart';

/// No-op controller stub for non-web platforms.
class WebCameraViewController extends ChangeNotifier {
  bool get isReady => false;
  String? get errorMessage => 'Live camera view is only available on web.';

  Future<Uint8List?> captureFrame() async => null;
  Future<String?> captureFrameBase64() async => null;
  void stopCamera() {}
}

/// No-op view stub for non-web platforms.
class WebCameraView extends StatelessWidget {
  final WebCameraViewController controller;

  const WebCameraView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Live camera view not supported on this platform.',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}
