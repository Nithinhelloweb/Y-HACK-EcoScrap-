import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ServerConfigDialog extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback? onServerChanged;

  const ServerConfigDialog({
    super.key,
    required this.apiService,
    this.onServerChanged,
  });

  static Future<void> show(BuildContext context, {
    required ApiService apiService,
    VoidCallback? onServerChanged,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ServerConfigDialog(
        apiService: apiService,
        onServerChanged: onServerChanged,
      ),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late TextEditingController _urlController;
  bool _isTesting = false;
  Map<String, dynamic>? _testResult;
  String? _detectedTunnelUrl;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.apiService.baseUrl);
    _checkLocalTunnelFile();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _checkLocalTunnelFile() async {
    try {
      if (!kIsWeb) {
        final f = File('tunnel_url.txt');
        if (await f.exists()) {
          final content = (await f.readAsString()).trim();
          if (content.startsWith('http')) {
            if (mounted) {
              setState(() {
                _detectedTunnelUrl = content.endsWith('/api') ? content : '$content/api';
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final res = await widget.apiService.testConnection(_urlController.text.trim());
    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = res;
      });
    }
  }

  Future<void> _saveAndApply() async {
    final newUrl = _urlController.text.trim();
    if (newUrl.isEmpty) return;

    await widget.apiService.updateBaseUrl(newUrl);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Connected to ${widget.apiService.baseUrl}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.collectorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onServerChanged?.call();
    }
  }

  void _applyPreset(String preset) {
    setState(() {
      _urlController.text = preset;
      _testResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: AppTheme.getCardBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.getBorder(context)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6821F).withValues(alpha: 0.15), // Cloudflare Orange
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cloud_queue_rounded, color: Color(0xFFF6821F), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server & Cloudflare Tunnel',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Configure static IP or Cloudflare public tunnel',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppTheme.getTextSecondary(context)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Active URL indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.getSurface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.getBorder(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Active: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.apiService.baseUrl,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          color: AppTheme.getTextPrimary(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Target URL Input
              Text(
                'API Base URL / Endpoint',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: AppTheme.getTextPrimary(context),
                ),
                decoration: InputDecoration(
                  hintText: 'https://xxx.trycloudflare.com/api',
                  prefixIcon: const Icon(Icons.link_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => _urlController.clear(),
                  ),
                  filled: true,
                  fillColor: AppTheme.getSurface(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.getBorder(context)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Presets
              Text(
                'Quick Presets:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.laptop_rounded, size: 14, color: Color(0xFF0D9488)),
                    label: const Text('Localhost (8000)', style: TextStyle(fontSize: 11)),
                    onPressed: () => _applyPreset('http://127.0.0.1:8000/api'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.phone_android_rounded, size: 14, color: Color(0xFF6366F1)),
                    label: const Text('Android 10.0.2.2', style: TextStyle(fontSize: 11)),
                    onPressed: () => _applyPreset('http://10.0.2.2:8000/api'),
                  ),
                  if (_detectedTunnelUrl != null)
                    ActionChip(
                      avatar: const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFF6821F)),
                      label: const Text('Active Cloudflare Tunnel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: const Color(0xFFF6821F).withValues(alpha: 0.15),
                      onPressed: () => _applyPreset(_detectedTunnelUrl!),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.wifi_rounded, size: 14, color: Color(0xFF10B981)),
                    label: const Text('LAN (Port 8000)', style: TextStyle(fontSize: 11)),
                    onPressed: () => _applyPreset('http://192.168.1.100:8000/api'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Test Connection Result
              if (_testResult != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testResult!['success'] == true
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _testResult!['success'] == true
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : const Color(0xFFEF4444).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testResult!['success'] == true
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        color: _testResult!['success'] == true
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _testResult!['success'] == true
                                  ? 'Connected Successfully (${_testResult!['latency_ms']}ms)'
                                  : 'Connection Failed (${_testResult!['latency_ms']}ms)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _testResult!['success'] == true
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                            if (_testResult!['error'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _testResult!['error'].toString(),
                                style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Actions: Ping & Save
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_ping_rounded, size: 18),
                    label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                    onPressed: _isTesting ? null : _testConnection,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF6821F), // Cloudflare Orange
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Save & Apply',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: _saveAndApply,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Instructions / Guide
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'How to start Cloudflare Tunnel:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Run in terminal:  powershell ./start_cloudflare_tunnel.ps1\n'
                      '• Or with python:   python backend/start_tunnel.py\n'
                      '• Copy the public https://*.trycloudflare.com/api URL above.\n'
                      '• Supports static custom domains via Cloudflare Named Tunnels.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        fontFamily: 'monospace',
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
