import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/lot_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'ecoscrap_logo.dart';

// Web camera imports — only used on web (guarded by kIsWeb at runtime,
// and by conditional import at compile time via the stub pattern below).
// We use a direct import here because this file itself is only meaningful
// in a web build when the live-camera path is taken.
// ignore: avoid_web_libraries_in_flutter
import 'web_camera_view.dart'
    if (dart.library.io) 'camera_stub.dart';

class CameraScannerModal extends StatefulWidget {
  final ApiService apiService;
  final Function(AIClassifyResult result, Uint8List? imageBytes) onScanned;

  const CameraScannerModal({
    super.key,
    required this.apiService,
    required this.onScanned,
  });

  @override
  State<CameraScannerModal> createState() => _CameraScannerModalState();
}

class _CameraScannerModalState extends State<CameraScannerModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;

  bool _isScanning = false;
  bool _webCameraActive = false;
  bool _webCameraReady = false;
  Uint8List? _previewBytes;
  String _statusMessage = 'Point camera directly at e-waste item';

  // Web camera controller — only instantiated on web
  WebCameraViewController? _webCamCtrl;

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(
        parent: _scanAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // On web: auto-start camera immediately when modal opens
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startWebCamera());
    }
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _webCamCtrl?.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // WEB CAMERA METHODS
  // ──────────────────────────────────────────────

  void _startWebCamera() {
    if (!kIsWeb) return;
    final ctrl = WebCameraViewController();
    ctrl.addListener(() {
      if (!mounted) return;
      setState(() {
        _webCameraReady = ctrl.isReady;
        if (ctrl.errorMessage != null) {
          _statusMessage = ctrl.errorMessage!;
        } else if (ctrl.isReady) {
          _statusMessage = 'Live camera active — tap 📸 Capture & Analyse';
        }
      });
    });
    setState(() {
      _webCamCtrl = ctrl;
      _webCameraActive = true;
      _previewBytes = null;
      _statusMessage = 'Starting webcam...';
    });
  }

  void _stopWebCamera() {
    _webCamCtrl?.stopCamera();
    setState(() {
      _webCameraActive = false;
      _webCameraReady = false;
      _statusMessage = 'Camera stopped. Tap "Open Live Camera" to restart.';
    });
  }

  Future<void> _captureWebFrame() async {
    if (_webCamCtrl == null || !_webCameraReady) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning image with Local YOLOv8 & EasyOCR...';
    });

    try {
      final bytes = await _webCamCtrl!.captureFrame();
      if (bytes == null) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Frame capture failed — ensure camera is active.';
        });
        return;
      }

      // Show frozen frame preview while backend analyses it
      final base64Str = base64Encode(bytes);
      setState(() {
        _previewBytes = bytes;
        _webCameraActive = false; // pause live feed to show still
      });

      final result = await widget.apiService.classifyImageBase64(
        base64Data: base64Str,
        hintText: '',
      );

      if (!mounted) return;
      widget.onScanned(result, bytes);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _webCameraActive = true;
        _statusMessage = 'AI analysis failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRed,
          content: Text('Vision analysis failed: $e'),
        ),
      );
    }
  }

  // ──────────────────────────────────────────────
  // NON-WEB (MOBILE / DESKTOP) METHODS
  // ──────────────────────────────────────────────

  Future<void> _openCamera() async {
    final picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _previewBytes = bytes;
          _isScanning = true;
          _statusMessage = 'Analysing visual spectrum & safety hazards...';
        });
        await _analyzeCapturedBytes(bytes, photo.name);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertAmber,
          content: Text('Camera notice: $e. Try "Upload Photo" instead.'),
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _previewBytes = bytes;
          _isScanning = true;
          _statusMessage = 'Analysing e-waste image features...';
        });
        await _analyzeCapturedBytes(bytes, image.name);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRed,
          content: Text('Failed to load image: $e'),
        ),
      );
    }
  }

  Future<void> _analyzeCapturedBytes(Uint8List bytes, String filename) async {
    try {
      final result = await widget.apiService.classifyImageBytes(
        bytes: bytes,
        filename: filename,
        hintText: '',
      );
      if (!mounted) return;
      widget.onScanned(result, bytes);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRed,
          content: Text('AI Vision Analysis failed: $e'),
        ),
      );
    }
  }

  // ──────────────────────────────────────────────
  // DEMO PRESETS
  // ──────────────────────────────────────────────

  Future<void> _triggerPreset(String query, String label) async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning $label signature...';
    });
    try {
      final result = await widget.apiService.classifyMaterial(query);
      if (!mounted) return;
      widget.onScanned(result, null);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRed,
          content: Text('Scan error: $e'),
        ),
      );
    }
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Dialog(
      backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? AppTheme.borderSubtle : AppTheme.borderLight),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildViewfinder(),
            const SizedBox(height: 16),
            _buildActionButtons(isDark),
            const SizedBox(height: 16),
            _buildDivider(),
            const SizedBox(height: 10),
            _buildPresetChips(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        const EcoScrapLogo(size: 38, borderRadius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Lens: Live Camera Scrap Scanner',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              Text(
                kIsWeb
                    ? 'Live Webcam • Object Recognition • CPCB Categorization'
                    : 'Camera Capture • Hazard Detection • CPCB Categorization',
                style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context)),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          onPressed: () {
            _webCamCtrl?.stopCamera();
            Navigator.of(context).pop();
          },
          tooltip: 'Close',
        ),
      ],
    );
  }

  // ── Viewfinder ────────────────────────────────
  Widget _buildViewfinder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 260,
        color: const Color(0xFF0F172A),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Web: live camera feed or frozen frame preview ──
            if (kIsWeb) ...[
              if (_webCameraActive && _webCamCtrl != null)
                Positioned.fill(
                  child: WebCameraView(controller: _webCamCtrl!),
                )
              else if (_previewBytes != null)
                Positioned.fill(
                  child: Image.memory(_previewBytes!, fit: BoxFit.cover),
                )
              else
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 40),
                      SizedBox(height: 8),
                      Text(
                        'Camera not started',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              // ── Non-web: still image preview or placeholder ──
              if (_previewBytes != null)
                Positioned.fill(
                  child: Image.memory(_previewBytes!, fit: BoxFit.cover),
                )
              else
                const Center(
                  child: Icon(Icons.camera_enhance_rounded, color: Colors.white24, size: 48),
                ),
            ],

            // ── Viewfinder HUD overlay (always shown) ──
            Positioned.fill(
              child: CustomPaint(
                painter: _ViewfinderOverlayPainter(
                  linePosition: _scanAnimation.value,
                  isScanning: _isScanning,
                  showGrid: !_webCameraActive,
                ),
              ),
            ),

            // ── Corner reticle box (only when no live feed) ──
            if (!_webCameraActive || !_webCameraReady)
              Container(
                width: 140,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isScanning
                        ? AppTheme.alertAmber
                        : AppTheme.collectorColor.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    _isScanning
                        ? Icons.hourglass_top_rounded
                        : Icons.filter_center_focus_rounded,
                    color: _isScanning
                        ? AppTheme.alertAmber
                        : Colors.white.withValues(alpha: 0.6),
                    size: 32,
                  ),
                ),
              ),

            // ── Scanning laser bar ──
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Positioned(
                  top: _scanAnimation.value * 260,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          _isScanning ? AppTheme.alertAmber : AppTheme.collectorColor,
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isScanning
                                  ? AppTheme.alertAmber
                                  : AppTheme.collectorColor)
                              .withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── Live badge (top-right when camera is active on web) ──
            if (kIsWeb && _webCameraActive && _webCameraReady)
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 7),
                      SizedBox(width: 5),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Status pill (bottom) ──
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isScanning
                        ? AppTheme.alertAmber.withValues(alpha: 0.5)
                        : AppTheme.collectorColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isScanning) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.alertAmber,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      const Icon(Icons.videocam_rounded, color: AppTheme.collectorColor, size: 14),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action Buttons ────────────────────────────
  Widget _buildActionButtons(bool isDark) {
    if (kIsWeb) {
      // Web: Capture frame (primary) + Stop/Restart camera toggle
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                backgroundColor: _webCameraReady
                    ? AppTheme.collectorColor
                    : (isDark ? Colors.grey[700] : Colors.grey[300]),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: _webCameraReady ? 2 : 0,
              ),
              icon: const Icon(Icons.photo_camera_rounded, size: 18),
              label: Text(
                _isScanning ? 'Analysing...' : '📸 Capture & Analyse',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              onPressed: (_isScanning || !_webCameraReady) ? null : _captureWebFrame,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(color: AppTheme.getBorder(context)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(
                _webCameraActive ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                size: 18,
                color: AppTheme.getTextPrimary(context),
              ),
              label: Text(
                _webCameraActive ? 'Stop Cam' : 'Start Cam',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              onPressed: _isScanning
                  ? null
                  : () {
                      if (_webCameraActive) {
                        _stopWebCamera();
                      } else {
                        _startWebCamera();
                      }
                    },
            ),
          ),
        ],
      );
    } else {
      // Non-web: standard camera open + gallery upload
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                backgroundColor: AppTheme.collectorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text(
                'Open Live Camera',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              onPressed: _isScanning ? null : _openCamera,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(color: AppTheme.getBorder(context)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(Icons.photo_library_rounded, size: 18, color: AppTheme.getTextPrimary(context)),
              label: Text(
                'Upload Photo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              onPressed: _isScanning ? null : _pickFromGallery,
            ),
          ),
        ],
      );
    }
  }

  // ── Divider ───────────────────────────────────
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppTheme.getBorder(context))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'Instant Hackathon Test Scenarios',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.getTextMuted(context),
            ),
          ),
        ),
        Expanded(child: Divider(color: AppTheme.getBorder(context))),
      ],
    );
  }

  // ── Preset Chips ──────────────────────────────
  Widget _buildPresetChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildPresetChip(
          icon: Icons.memory_rounded,
          label: 'Laptop Motherboard (PCB)',
          color: AppTheme.collectorColor,
          query: 'high grade laptop motherboard with intel cpu',
        ),
        _buildPresetChip(
          icon: Icons.battery_alert_rounded,
          label: 'Swollen Li-Ion Battery (Hazard)',
          color: AppTheme.alertRed,
          query: 'swollen lithium ion battery 18650 thermal risk',
        ),
        _buildPresetChip(
          icon: Icons.electrical_services_rounded,
          label: 'Copper Cables',
          color: AppTheme.infoBlue,
          query: 'insulated copper wire cable bundle',
        ),
        _buildPresetChip(
          icon: Icons.tv_rounded,
          label: 'CRT Monitor (Leaded Glass)',
          color: Colors.deepOrange,
          query: 'cathode ray tube crt monitor display',
        ),
        _buildPresetChip(
          icon: Icons.power_rounded,
          label: 'Single-Sided SMPS Board',
          color: Colors.teal,
          query: 'smps power supply circuit board',
        ),
      ],
    );
  }

  Widget _buildPresetChip({
    required IconData icon,
    required String label,
    required Color color,
    required String query,
  }) {
    final isDark = AppTheme.isDark(context);
    return InkWell(
      onTap: _isScanning ? null : () => _triggerPreset(query, label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.14 : 0.09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppTheme.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Viewfinder Painter ────────────────────
class _ViewfinderOverlayPainter extends CustomPainter {
  final double linePosition;
  final bool isScanning;
  final bool showGrid;

  _ViewfinderOverlayPainter({
    required this.linePosition,
    required this.isScanning,
    this.showGrid = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isScanning ? AppTheme.alertAmber : AppTheme.collectorColor)
          .withValues(alpha: 0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const cornerLength = 22.0;
    const padding = 16.0;

    // Top-Left Corner
    canvas.drawLine(const Offset(padding, padding), const Offset(padding + cornerLength, padding), paint);
    canvas.drawLine(const Offset(padding, padding), const Offset(padding, padding + cornerLength), paint);

    // Top-Right Corner
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding - cornerLength, padding), paint);
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding, padding + cornerLength), paint);

    // Bottom-Left Corner
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding + cornerLength, size.height - padding), paint);
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding, size.height - padding - cornerLength), paint);

    // Bottom-Right Corner
    canvas.drawLine(Offset(size.width - padding, size.height - padding), Offset(size.width - padding - cornerLength, size.height - padding), paint);
    canvas.drawLine(Offset(size.width - padding, size.height - padding), Offset(size.width - padding, size.height - padding - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderOverlayPainter oldDelegate) {
    return oldDelegate.linePosition != linePosition ||
        oldDelegate.isScanning != isScanning;
  }
}
