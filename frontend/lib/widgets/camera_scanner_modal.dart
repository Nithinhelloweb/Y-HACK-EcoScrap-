import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/lot_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'ecoscrap_logo.dart';

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

  WebCameraViewController? _webCamCtrl;

  // Review & Edit Mode State
  bool _reviewMode = false;
  AIClassifyResult? _scannedResult;
  String? _originalItemName;
  String? _originalCategory;
  String? _originalSubcategory;

  String _editedItemName = '';
  String _editedCategory = 'ITEW';
  String _editedSubcategory = 'SMARTPHONE_HANDSET';
  double _editedWeightKg = 1.0;
  double _editedQuantity = 1.0;
  String _editedCondition = 'mixed';
  bool _wasEdited = false;

  final List<Map<String, String>> _categories = const [
    {'code': 'ITEW', 'label': 'ITEW — IT & Telecom (Phones, Laptops, Peripherals)'},
    {'code': 'PCB', 'label': 'PCB — Printed Circuit Boards & Motherboards'},
    {'code': 'BATTERY', 'label': 'BATTERY — Li-Ion, Lead-Acid, UPS Cells (Hazardous)'},
    {'code': 'CABLE', 'label': 'CABLE — Insulated Copper & Wiring'},
    {'code': 'IT_EQUIPMENT', 'label': 'IT_EQUIPMENT — Printers, Servers, Appliances'},
    {'code': 'DISPLAY', 'label': 'DISPLAY — Flat Panels & CRT Monitors'},
    {'code': 'MIXED_SCRAP', 'label': 'MIXED_SCRAP — General Recyclables'},
  ];

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

  // WEB CAMERA METHODS
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
      _statusMessage = 'Camera stopped. Tap "Start Cam" to restart.';
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

      final base64Str = base64Encode(bytes);
      setState(() {
        _previewBytes = bytes;
        _webCameraActive = false;
      });

      final result = await widget.apiService.classifyImageBase64(
        base64Data: base64Str,
        hintText: '',
      );

      if (!mounted) return;
      _setupReviewMode(result, bytes);
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

  // NON-WEB METHODS
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
      _setupReviewMode(result, bytes);
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

  Future<void> _triggerPreset(String query, String label) async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning $label signature...';
    });
    try {
      final result = await widget.apiService.classifyMaterial(query);
      if (!mounted) return;
      _setupReviewMode(result, null);
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

  // REVIEW & EDIT LOGIC
  void _setupReviewMode(AIClassifyResult result, Uint8List? bytes) {
    setState(() {
      _isScanning = false;
      _reviewMode = true;
      _scannedResult = result;
      _previewBytes = bytes;
      _originalItemName = result.itemName;
      _originalCategory = result.category;
      _originalSubcategory = result.subcategory;

      _editedItemName = result.itemName;
      _editedCategory = result.category;
      _editedSubcategory = result.subcategory;
      _editedWeightKg = result.estimatedWeightKg;
      _editedQuantity = result.quantity;
      _editedCondition = 'mixed';
      _wasEdited = false;
      _statusMessage = 'Identified: ${result.itemName} (${(result.confidence * 100).toStringAsFixed(0)}% confidence)';
    });
  }

  void _retakeScan() {
    setState(() {
      _reviewMode = false;
      _scannedResult = null;
      _previewBytes = null;
      _wasEdited = false;
      _statusMessage = 'Point camera directly at e-waste item';
    });
    if (kIsWeb) {
      _startWebCamera();
    }
  }

  Future<void> _confirmAndAddToLot() async {
    if (_scannedResult == null) return;

    if (_wasEdited) {
      String? b64;
      if (_previewBytes != null) {
        b64 = base64Encode(_previewBytes!);
      }
      List<double>? bBox;
      if (_scannedResult!.detectedComponents != null && _scannedResult!.detectedComponents!.isNotEmpty) {
        final first = _scannedResult!.detectedComponents!.first;
        if (first is Map<String, dynamic> && first['normalized_box'] is List) {
          bBox = (first['normalized_box'] as List).map((e) => (e as num).toDouble()).toList();
        }
      }

      widget.apiService.submitDetectionFeedback(
        imageBase64: b64,
        originalItemName: _originalItemName,
        originalCategory: _originalCategory,
        originalSubcategory: _originalSubcategory,
        correctedItemName: _editedItemName,
        correctedCategory: _editedCategory,
        correctedSubcategory: _editedSubcategory,
        correctedWeightKg: _editedWeightKg,
        correctedQuantity: _editedQuantity,
        correctedCondition: _editedCondition,
        boundingBox: bBox,
        collectorId: 'COL-001',
      ).then((val) {
        debugPrint('Self-training feedback submitted: ${val['sample_id']}');
      }).catchError((err) {
        debugPrint('Feedback notice: $err');
      });
    }

    final finalResult = _scannedResult!.copyWith(
      itemName: _editedItemName,
      category: _editedCategory,
      subcategory: _editedSubcategory,
      estimatedWeightKg: _editedWeightKg,
      quantity: _editedQuantity,
    );

    widget.onScanned(finalResult, _previewBytes);
    Navigator.of(context).pop();
  }

  void _showEditDetectionDialog(bool isDark) {
    final nameCtrl = TextEditingController(text: _editedItemName);
    final subcatCtrl = TextEditingController(text: _editedSubcategory);
    final weightCtrl = TextEditingController(text: _editedWeightKg.toStringAsFixed(1));
    final qtyCtrl = TextEditingController(text: _editedQuantity.toInt().toString());
    String selectedCat = _editedCategory;
    String selectedCond = _editedCondition;

    final validCatCodes = _categories.map((c) => c['code']).toSet();
    if (!validCatCodes.contains(selectedCat)) {
      selectedCat = 'ITEW';
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? AppTheme.borderSubtle : AppTheme.borderLight),
          ),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppTheme.collectorColor, size: 24),
              const SizedBox(width: 8),
              Text(
                'Edit Detected Object',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.collectorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.collectorColor.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.model_training_rounded, size: 16, color: AppTheme.collectorColor),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Corrections update this lot and automatically self-train the local YOLO model.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.collectorColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Item Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g., Optical USB Mouse, Samsung Galaxy A50',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Category (CPCB)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context))),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCat,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: _categories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['code'],
                        child: Text(
                          c['label']!,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCat = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text('Subcategory Tag', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: subcatCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. MOUSE_PERIPHERAL, SMARTPHONE_HANDSET',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Weight (kg)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context))),
                            const SizedBox(height: 4),
                            TextField(
                              controller: weightCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: '1.0',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Quantity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context))),
                            const SizedBox(height: 4),
                            TextField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '1',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Physical Condition', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['scrap', 'repairable', 'working', 'mixed'].map((cond) {
                      final isSelected = selectedCond == cond;
                      return ChoiceChip(
                        label: Text(cond.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppTheme.getTextPrimary(context))),
                        selected: isSelected,
                        selectedColor: AppTheme.collectorColor,
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedCond = cond);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: AppTheme.getTextSecondary(context))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.collectorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                final w = double.tryParse(weightCtrl.text.trim()) ?? _editedWeightKg;
                final q = double.tryParse(qtyCtrl.text.trim()) ?? _editedQuantity;
                setState(() {
                  _editedItemName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : _editedItemName;
                  _editedCategory = selectedCat;
                  _editedSubcategory = subcatCtrl.text.trim().isNotEmpty ? subcatCtrl.text.trim() : _editedSubcategory;
                  _editedWeightKg = w;
                  _editedQuantity = q;
                  _editedCondition = selectedCond;
                  _wasEdited = true;
                });
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.collectorColor,
                    content: Text('Object details updated! Changes will self-train model on lot confirmation.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Dialog(
      backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? AppTheme.borderSubtle : AppTheme.borderLight),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                _buildViewfinder(),
                const SizedBox(height: 14),
                if (_reviewMode)
                  _buildReviewAndEditPanel(isDark)
                else ...[
                  _buildActionButtons(isDark),
                  const SizedBox(height: 14),
                  _buildDivider(),
                  const SizedBox(height: 10),
                  _buildPresetChips(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

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
                _reviewMode ? 'AI Object Inspector & Edit' : 'AI Lens: Live Camera Scrap Scanner',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              Text(
                _reviewMode
                    ? 'Review detected boxes • Edit classifications • Continuous self-training'
                    : (kIsWeb
                        ? 'Live Webcam • Multi-Object YOLOv8 • CPCB Classification'
                        : 'Camera Capture • Hazard Detection • CPCB Classification'),
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

  Widget _buildViewfinder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 260,
        color: const Color(0xFF0F172A),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_reviewMode && _previewBytes != null) ...[
              Positioned.fill(
                child: Image.memory(_previewBytes!, fit: BoxFit.contain),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: BoundingBoxOverlayPainter(
                    components: _scannedResult?.detectedComponents,
                    primaryLabel: _editedItemName,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.collectorColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: AppTheme.collectorColor, size: 13),
                      const SizedBox(width: 6),
                      Text(
                        'DETECTED: $_editedItemName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (kIsWeb) ...[
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
              if (_previewBytes != null)
                Positioned.fill(
                  child: Image.memory(_previewBytes!, fit: BoxFit.cover),
                )
              else
                const Center(
                  child: Icon(Icons.camera_enhance_rounded, color: Colors.white24, size: 48),
                ),
            ],

            if (!_reviewMode) ...[
              Positioned.fill(
                child: CustomPaint(
                  painter: _ViewfinderOverlayPainter(
                    linePosition: _scanAnimation.value,
                    isScanning: _isScanning,
                    showGrid: !_webCameraActive,
                  ),
                ),
              ),
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
            ],

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

  Widget _buildReviewAndEditPanel(bool isDark) {
    final ai = _scannedResult;
    final comps = ai?.detectedComponents ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.getBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editedItemName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_editedCategory • $_editedSubcategory',
                          style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context)),
                        ),
                      ],
                    ),
                  ),
                  if (_wasEdited)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 11, color: Colors.purpleAccent),
                          SizedBox(width: 4),
                          Text(
                            'User Edited',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.collectorColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${((ai?.confidence ?? 0.9) * 100).toStringAsFixed(0)}% Conf',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.collectorColor),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildMetaBadge('Weight', '${_editedWeightKg.toStringAsFixed(1)} kg', Icons.scale_rounded),
                  _buildMetaBadge('Quantity', '${_editedQuantity.toInt()} units', Icons.inventory_2_rounded),
                  _buildMetaBadge('Condition', _editedCondition.toUpperCase(), Icons.fact_check_rounded),
                  if (ai?.estimatedBaseRatePerKg != null)
                    _buildMetaBadge('CPCB Benchmark', '₹${ai!.estimatedBaseRatePerKg.toStringAsFixed(0)}/kg', Icons.currency_rupee_rounded),
                ],
              ),

              if (comps.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Detected Components (${comps.length}):',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.getTextSecondary(context)),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: comps.map((c) {
                    final comp = c as Map<String, dynamic>;
                    final lbl = comp['label'] ?? comp['raw_class'] ?? 'Object';
                    final conf = ((comp['confidence'] as num?)?.toDouble() ?? 0.85) * 100;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.collectorColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppTheme.collectorColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '$lbl (${conf.toStringAsFixed(0)}%)',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.collectorColor),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppTheme.collectorColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.collectorColor),
                label: const Text(
                  '✏️ Edit Object',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.collectorColor),
                ),
                onPressed: () => _showEditDetectionDialog(isDark),
              ),
            ),
            const SizedBox(width: 10),
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
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'Confirm & Add to Lot',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                onPressed: _confirmAndAddToLot,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Retake / Rescan',
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: AppTheme.getBorder(context)),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _retakeScan,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetaBadge(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context) ? Colors.black45 : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.getTextSecondary(context)),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 10, color: AppTheme.getTextSecondary(context)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    if (kIsWeb) {
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

  Widget _buildPresetChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildPresetChip(
          icon: Icons.mouse_rounded,
          label: 'Optical Mouse',
          color: const Color(0xFF06B6D4),
          query: 'optical usb computer mouse peripheral plastic scrap',
        ),
        _buildPresetChip(
          icon: Icons.phone_android_rounded,
          label: 'Smartphone Handset',
          color: const Color(0xFF3B82F6),
          query: 'smartphone mobile phone touchscreen handset',
        ),
        _buildPresetChip(
          icon: Icons.memory_rounded,
          label: 'Motherboard (PCB)',
          color: AppTheme.collectorColor,
          query: 'high grade laptop motherboard with intel cpu',
        ),
        _buildPresetChip(
          icon: Icons.battery_alert_rounded,
          label: 'Swollen Li-Ion Battery',
          color: AppTheme.alertRed,
          query: 'swollen lithium ion battery 18650 thermal risk',
        ),
        _buildPresetChip(
          icon: Icons.electrical_services_rounded,
          label: 'Copper Cables',
          color: AppTheme.infoBlue,
          query: 'insulated copper wire cable bundle',
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

// ── Bounding Box Overlay Painter ─────────────────
class BoundingBoxOverlayPainter extends CustomPainter {
  final List<dynamic>? components;
  final String? primaryLabel;

  BoundingBoxOverlayPainter({
    this.components,
    this.primaryLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (components == null || components!.isEmpty) return;

    for (final comp in components!) {
      if (comp is! Map<String, dynamic>) continue;

      double? x1, y1, x2, y2;
      final normBox = comp['normalized_box'];
      if (normBox is List && normBox.length == 4) {
        x1 = (normBox[0] as num).toDouble();
        y1 = (normBox[1] as num).toDouble();
        x2 = (normBox[2] as num).toDouble();
        y2 = (normBox[3] as num).toDouble();
      } else {
        final box = comp['box'];
        if (box is List && box.length == 4) {
          final bx1 = (box[0] as num).toDouble();
          final by1 = (box[1] as num).toDouble();
          final bx2 = (box[2] as num).toDouble();
          final by2 = (box[3] as num).toDouble();
          if (bx2 <= 1.0 && by2 <= 1.0) {
            x1 = bx1;
            y1 = by1;
            x2 = bx2;
            y2 = by2;
          }
        }
      }

      if (x1 == null || y1 == null || x2 == null || y2 == null) continue;

      final rect = Rect.fromLTRB(
        (x1 * size.width).clamp(2.0, size.width - 4.0),
        (y1 * size.height).clamp(2.0, size.height - 4.0),
        (x2 * size.width).clamp(4.0, size.width - 2.0),
        (y2 * size.height).clamp(4.0, size.height - 2.0),
      );

      final label = (comp['label'] ?? comp['raw_class'] ?? 'E-Waste').toString();
      final conf = ((comp['confidence'] as num?)?.toDouble() ?? 0.85) * 100;
      final isHazard = label.toUpperCase().contains('BATTERY') ||
          label.toUpperCase().contains('HAZARD') ||
          label.toUpperCase().contains('MEDICAL');

      final baseColor = isHazard
          ? AppTheme.alertRed
          : (label.toUpperCase().contains('PCB')
              ? AppTheme.collectorColor
              : (label.toUpperCase().contains('MOUSE') || label.toUpperCase().contains('KEYBOARD')
                  ? const Color(0xFF06B6D4)
                  : const Color(0xFFF59E0B)));

      // 1. Translucent fill
      final fillPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), fillPaint);

      // 2. Border
      final borderPaint = Paint()
        ..color = baseColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), borderPaint);

      // 3. Corner notches
      final cornerPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      const cLen = 10.0;
      canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cLen, rect.top), cornerPaint);
      canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left, rect.top + cLen), cornerPaint);
      canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right - cLen, rect.top), cornerPaint);
      canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cLen), cornerPaint);

      // 4. Pill tag
      final tagText = '$label ${conf.toStringAsFixed(0)}%';
      final textSpan = TextSpan(
        text: tagText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final tagW = textPainter.width + 12;
      final tagH = textPainter.height + 6;
      final tagLeft = rect.left.clamp(2.0, size.width - tagW - 2.0);
      final tagTop = (rect.top - tagH - 3).clamp(2.0, size.height - tagH - 2.0);

      final tagRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tagLeft, tagTop, tagW, tagH),
        const Radius.circular(4),
      );

      final tagBgPaint = Paint()..color = baseColor.withValues(alpha: 0.9);
      canvas.drawRRect(tagRect, tagBgPaint);
      textPainter.paint(canvas, Offset(tagLeft + 6, tagTop + 3));
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxOverlayPainter oldDelegate) {
    return oldDelegate.components != components || oldDelegate.primaryLabel != primaryLabel;
  }
}

// ── Custom Viewfinder HUD Painter ────────────────
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
    canvas.drawLine(Offset(size.width - padding, size.height - padding), Offset(size.width - padding, padding + cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderOverlayPainter oldDelegate) {
    return oldDelegate.linePosition != linePosition ||
        oldDelegate.isScanning != isScanning;
  }
}
