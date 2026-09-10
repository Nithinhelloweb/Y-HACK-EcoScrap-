// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// dart:html is deprecated in favour of package:web + dart:js_interop,
// but remains fully functional on Flutter SDK ^3.11.4 for web builds.
// This file is ONLY compiled on web (conditional import in camera_scanner_modal.dart).

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// A Flutter-Web-only widget that renders a live webcam feed using
/// [navigator.mediaDevices.getUserMedia] via [dart:html], displayed through
/// a registered [HtmlElementView] platform view.
class WebCameraView extends StatefulWidget {
  final WebCameraViewController controller;

  const WebCameraView({super.key, required this.controller});

  @override
  State<WebCameraView> createState() => _WebCameraViewState();
}

class _WebCameraViewState extends State<WebCameraView> {
  html.VideoElement? _videoEl;
  late final String _viewType =
      'ecoscrap-webcam-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.borderRadius = '12px'
      ..style.background = '#0F172A';

    _videoEl = video;

    // Register a fresh platform view factory unique to this modal lifecycle
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => video,
    );

    // Request webcam access
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      });
      video.srcObject = stream;
      await video.play();
      widget.controller._attach(video);
      if (mounted) setState(() {});
    } catch (e) {
      widget.controller._onError('Camera access denied or unavailable: $e');
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _stopStream() {
    final srcObj = _videoEl?.srcObject;
    if (srcObj is html.MediaStream) {
      for (final track in srcObj.getTracks()) {
        track.stop();
      }
    }
    _videoEl?.srcObject = null;
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

/// Controller for [WebCameraView] — call [captureFrame] to grab a JPEG frame.
class WebCameraViewController extends ChangeNotifier {
  html.VideoElement? _videoEl;
  String? _errorMessage;
  bool _isReady = false;

  bool get isReady => _isReady;
  String? get errorMessage => _errorMessage;

  void _attach(html.VideoElement el) {
    _videoEl = el;
    _isReady = true;
    _errorMessage = null;
    notifyListeners();
  }

  void _onError(String msg) {
    _errorMessage = msg;
    _isReady = false;
    notifyListeners();
  }

  /// Captures the current video frame as a JPEG [Uint8List].
  /// Returns null if the camera is not ready.
  Future<Uint8List?> captureFrame() async {
    final video = _videoEl;
    if (video == null || video.videoWidth == 0) return null;

    final canvas = html.CanvasElement(
      width: video.videoWidth,
      height: video.videoHeight,
    );
    canvas.context2D.drawImage(video, 0, 0);

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.88);
    final base64Str = dataUrl.split(',').last;
    return base64Decode(base64Str);
  }

  /// Returns the raw base64 JPEG string (without data-URL prefix).
  Future<String?> captureFrameBase64() async {
    final bytes = await captureFrame();
    if (bytes == null) return null;
    return base64Encode(bytes);
  }

  /// Stops the webcam stream and releases the camera hardware.
  void stopCamera() {
    final srcObj = _videoEl?.srcObject;
    if (srcObj is html.MediaStream) {
      for (final track in srcObj.getTracks()) {
        track.stop();
      }
    }
    _videoEl?.srcObject = null;
    _isReady = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopCamera();
    super.dispose();
  }
}
