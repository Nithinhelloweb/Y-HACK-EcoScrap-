import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/lot_model.dart';
import '../services/api_service.dart';
import '../services/offline_store.dart';
import '../i18n/translations.dart';
import '../theme/app_theme.dart';
import '../widgets/camera_scanner_modal.dart';
import '../widgets/ecoscrap_logo.dart';
import '../voice/voice_screen.dart';

class CollectorScreen extends StatefulWidget {
  final ApiService apiService;
  final OfflineStore offlineStore;
  final String currentLang;
  final Function(String) onLangChanged;

  const CollectorScreen({
    super.key,
    required this.apiService,
    required this.offlineStore,
    required this.currentLang,
    required this.onLangChanged,
  });

  @override
  State<CollectorScreen> createState() => _CollectorScreenState();
}

class _CollectorScreenState extends State<CollectorScreen> {
  final _weightController = TextEditingController(text: '8.4');
  String _selectedCategory = 'PCB';
  String _selectedSubcategory = 'IT_HIGH_GRADE_PCB';
  final String _selectedCondition = 'mixed';

  AIClassifyResult? _aiResult;
  Uint8List? _scannedImageBytes;
  Map<String, dynamic>? _fairValueData;
  bool _isLoading = false;

  String t(String key) => AppTranslations.get(key, widget.currentLang);

  @override
  void initState() {
    super.initState();
    _loadLots();
  }

  Future<void> _loadLots() async {
    try {
      final serverLots = await widget.apiService.fetchLots();
      widget.offlineStore.setLots(serverLots);
    } catch (e) {
      debugPrint('Could not fetch server lots, relying on local cache');
    }
  }

  Future<void> _runVoiceSimulation(String prompt) async {
    setState(() => _isLoading = true);
    try {
      final parsed = await widget.apiService.parseVoicePrompt(prompt, lang: widget.currentLang);
      final wt = (parsed['weight_kg'] as num?)?.toDouble() ?? 5.0;
      _weightController.text = wt.toString();
      setState(() {
        _selectedCategory = parsed['category'] ?? 'PCB';
        _selectedSubcategory = parsed['subcategory'] ?? 'IT_HIGH_GRADE_PCB';
      });
      await _fetchFairValue();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: (parsed['is_hazard'] == true) ? AppTheme.alertRed : const Color(0xFF065F46),
          content: Text(parsed['confirmation_message'] ?? 'Voice command processed successfully.'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice processing error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSafetyProtocolsDialog() async {
    setState(() => _isLoading = true);
    try {
      final protocols = await widget.apiService.fetchSafetyProtocols();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) {
          final lang = widget.currentLang;
          return AlertDialog(
            backgroundColor: AppTheme.getCardBg(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppTheme.getBorder(context)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.alertAmber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shield_rounded, color: AppTheme.alertAmber, size: 20),
                ),
                const SizedBox(width: 10),
                Text(t('safety_protocols_btn'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: protocols.values.map<Widget>((p) {
                  final data = p as Map<String, dynamic>;
                  final title = (lang == 'ta' && data['title_ta'] != null)
                      ? data['title_ta']
                      : (lang == 'hi' && data['title_hi'] != null)
                          ? data['title_hi']
                          : data['title_en'] ?? data['hazard_type'];
                  final sops = (lang == 'ta' && data['handling_sop_ta'] != null)
                      ? data['handling_sop_ta'] as List
                      : (lang == 'hi' && data['handling_sop_hi'] != null)
                          ? data['handling_sop_hi'] as List
                          : data['handling_sop'] as List;
                  final isCritical = data['hazard_level'] == 'CRITICAL';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCritical ? AppTheme.alertRed.withValues(alpha: 0.12) : AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isCritical ? AppTheme.alertRed.withValues(alpha: 0.5) : AppTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCritical ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                              color: isCritical ? AppTheme.alertRed : AppTheme.collectorColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: AppTheme.pillBadgeDecoration(isCritical ? AppTheme.alertRed : AppTheme.collectorColor),
                              child: Text(
                                data['hazard_level'] ?? '',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isCritical ? AppTheme.alertRed : AppTheme.collectorColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...sops.map((s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text('• $s', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            )),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load safety protocols: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFairValue() async {
    final wt = double.tryParse(_weightController.text) ?? 8.4;
    try {
      final fv = await widget.apiService.getFairValue(
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
        weightKg: wt,
        condition: _selectedCondition,
      );
      setState(() => _fairValueData = fv);
    } catch (e) {
      debugPrint('Fair value error: $e');
    }
  }

  Future<void> _createLot() async {
    final wt = double.tryParse(_weightController.text) ?? 5.0;
    final fvMin = (_fairValueData?['fair_value_min'] as num?)?.toDouble() ?? 4700.0;
    final fvMax = (_fairValueData?['fair_value_max'] as num?)?.toDouble() ?? 5200.0;

    setState(() => _isLoading = true);
    try {
      final created = await widget.offlineStore.addLot(
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
        weightKg: wt,
        condition: _selectedCondition,
        fairMin: fvMin,
        fairMax: fvMax,
        apiService: widget.apiService,
      );

      // Refresh lots so that the new lot and generated bids immediately display on screen
      await _loadLots();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: created.isOfflinePending ? Colors.amber.shade900 : const Color(0xFF065F46),
          content: Text(
            created.isOfflinePending
                ? '⚡ Saved to Offline Outbox! (${created.lotCode})'
                : '✅ Lot Created Online: ${created.lotCode}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRed,
          content: Text('Lot creation error: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.offlineStore;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return RefreshIndicator(
          color: AppTheme.collectorColor,
          backgroundColor: AppTheme.getCardBg(context),
          onRefresh: _loadLots,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            children: [
              // Connectivity & Outbox Banner
              _buildConnectivityBanner(store),
              const SizedBox(height: 14),

              // Collector Trust Card
              _buildCollectorTrustCard(),
              const SizedBox(height: 14),

              // Voice & AI Action Hub
              _buildActionHub(),
              const SizedBox(height: 14),

              // AI Lens Result & Safety Hazard Warning (if triggered)
              if (_aiResult != null) ...[
                _buildAIResultCard(),
                const SizedBox(height: 14),
              ],

              // Fair Pricing Transparency Card
              if (_fairValueData != null) ...[
                _buildFairValueCard(),
                const SizedBox(height: 14),
              ],

              // Quick New Lot Creation Form
              _buildLotFormCard(),
              const SizedBox(height: 16),

              // Collector Lots Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.collectorColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2_rounded, color: AppTheme.collectorColor, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(t('my_lots_heading'),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.getTextPrimary(context))),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.collectorColor),
                    label: Text(t('sync_btn'), style: const TextStyle(color: AppTheme.collectorColor, fontSize: 12)),
                    onPressed: _loadLots,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (store.lots.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: AppTheme.cardBoxDecoration(color: AppTheme.getCardBg(context), context: context),
                  child: Column(
                    children: [
                      const EcoScrapLogo(size: 48, borderRadius: 14),
                      const SizedBox(height: 10),
                      Text('No lots created yet.', style: TextStyle(color: AppTheme.getTextSecondary(context), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Use AI Lens or voice input above to create your first formal lot draft.',
                          style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12), textAlign: TextAlign.center),
                    ],
                  ),
                )
              else
                ...store.lots.map((lot) => _buildLotItem(lot)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectivityBanner(OfflineStore store) {
    final isOffline = store.isOfflineMode;
    final bannerColor = isOffline ? AppTheme.alertAmber : AppTheme.collectorColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
            color: bannerColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOffline ? t('offline_mode') : t('online_mode'),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: bannerColor),
                ),
                if (store.pendingCount > 0)
                  Text(
                    '${store.pendingCount} ${t('pending_sync')}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.alertAmber, fontWeight: FontWeight.w600),
                  )
                else
                  Text(
                    isOffline ? 'Drafts stored locally in-memory' : 'Real-time sync to central EcoScrap database',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
          if (store.pendingCount > 0 && !isOffline) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.collectorColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final count = await store.syncPendingQueue(widget.apiService);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Synced $count lots to central EcoScrap!')),
                  );
                }
              },
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: Text(t('sync_now'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
          ],
          // Offline Simulation Toggle Button
          InkWell(
            onTap: store.toggleOfflineMode,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isOffline ? AppTheme.alertAmber.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isOffline ? AppTheme.alertAmber : AppTheme.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOffline ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                    color: isOffline ? AppTheme.alertAmber : AppTheme.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOffline ? 'Offline' : 'Simulate',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isOffline ? AppTheme.alertAmber : AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectorTrustCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: AppTheme.collectorColor.withValues(alpha: 0.3),
        context: context,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EcoScrapLogo(size: 48, borderRadius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      'Murugan K.',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.getTextPrimary(context)),
                    ),
                    Text(
                      '(COL-TN-019284)',
                      style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'CPCB Verified Collection Partner • Coimbatore Hub',
                  style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: AppTheme.pillBadgeDecoration(AppTheme.collectorColor, context: context),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 13, color: AppTheme.collectorColor),
                          SizedBox(width: 4),
                          Text(
                            '94.5 / 100 Trust Score',
                            style: TextStyle(color: AppTheme.collectorColor, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '182 Lots Formalized',
                      style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionHub() {
    return Column(
      children: [
        Row(
          children: [
            // Voice Assistant Button
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                  backgroundColor: const Color(0xFF4338CA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
                label: const Flexible(
                  child: Text(
                    'Voice Assistant',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => VoiceScreen(
                      apiService: widget.apiService,
                      initialLanguage: widget.currentLang,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // AI Camera Lens Button
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                label: Flexible(
                  child: Text(
                    t('ai_lens_btn'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                onPressed: _showAICameraDialog,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  side: BorderSide(color: AppTheme.alertAmber.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.shield_rounded, color: AppTheme.alertAmber, size: 17),
                label: Flexible(
                  child: Text(
                    t('safety_protocols_btn'),
                    style: const TextStyle(color: AppTheme.alertAmber, fontWeight: FontWeight.w700, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                onPressed: _showSafetyProtocolsDialog,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(120, 42),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                side: BorderSide(color: const Color(0xFF818CF8).withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF818CF8), size: 16),
              label: const Text(
                'Demo Prompts',
                style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.w600, fontSize: 12),
              ),
              onPressed: _showVoicePromptDialog,
            ),
          ],
        ),
      ],
    );
  }

  void _showVoicePromptDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardBg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4338CA).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF818CF8), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text('Voice Assistant (தமிழ் / हिंदी / English)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.getTextPrimary(context))),
                ],
              ),
              const SizedBox(height: 8),
              Text(t('voice_hint'), style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4338CA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
                label: const Text('Open Interactive Voice Screen', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => VoiceScreen(
                        apiService: widget.apiService,
                        initialLanguage: widget.currentLang,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Tamil Prompts
              _voiceTile(
                context: context,
                title: 'தமிழ்: "10 கிலோ தாமிர கம்பி"',
                sub: 'Extracts 10 kg • Categorizes as CABLE',
                icon: Icons.cable_rounded,
                color: AppTheme.alertAmber,
                prompt: "10 கிலோ தாமிர கம்பி",
              ),
              const SizedBox(height: 6),
              _voiceTile(
                context: context,
                title: 'தமிழ்: "வீங்கிய லித்தியம் பேட்டரி"',
                sub: 'Triggers Swollen Battery Hazard Alert',
                icon: Icons.battery_alert_rounded,
                color: AppTheme.alertRed,
                prompt: "வீங்கிய லித்தியம் பேட்டரி",
              ),
              const SizedBox(height: 6),

              // Hindi Prompts
              _voiceTile(
                context: context,
                title: 'हिंदी: "5 किलो पुराना लैपटॉप मदरबोर्ड"',
                sub: 'Extracts 5 kg • Categorizes as High-Grade PCB',
                icon: Icons.memory_rounded,
                color: AppTheme.collectorColor,
                prompt: "5 किलो पुराना लैपटॉप मदरबोर्ड",
              ),
              const SizedBox(height: 6),
              _voiceTile(
                context: context,
                title: 'हिंदी: "इनवर्टर लेड एसिड बैटरी"',
                sub: 'Categorizes as Lead-Acid • Corrosive Hazard',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.alertAmber,
                prompt: "इनवर्टर लेड एसिड बैटरी",
              ),
              const SizedBox(height: 6),

              // English Prompts
              _voiceTile(
                context: context,
                title: 'English: "8.4 kg server circuit boards"',
                sub: 'Extracts 8.4 kg • IT_HIGH_GRADE_PCB',
                icon: Icons.laptop_chromebook_rounded,
                color: AppTheme.infoBlue,
                prompt: "8.4 kg server circuit boards",
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _voiceTile({
    required BuildContext context,
    required String title,
    required String sub,
    required IconData icon,
    required Color color,
    required String prompt,
  }) {
    return ListTile(
      tileColor: AppTheme.isDark(context) ? AppTheme.surfaceDark : const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.getBorder(context))),
      leading: Icon(icon, color: color, size: 20),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.getTextPrimary(context))),
      subtitle: Text(sub, style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
      onTap: () {
        Navigator.pop(context);
        _runVoiceSimulation(prompt);
      },
    );
  }

  void _showAICameraDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CameraScannerModal(
        apiService: widget.apiService,
        onScanned: (result, imageBytes) async {
          setState(() {
            _aiResult = result;
            _scannedImageBytes = imageBytes;
            _selectedCategory = result.category;
            _selectedSubcategory = result.subcategory;
            if (result.estimatedWeightKg > 0) {
              _weightController.text = result.estimatedWeightKg.toStringAsFixed(1);
            }
            if (result.fairValueEstimate != null) {
              _fairValueData = result.fairValueEstimate;
            }
          });
          if (result.fairValueEstimate == null) {
            await _fetchFairValue();
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: result.safetyFlags.any((f) => f.contains('RISK') || f.contains('HAZARD') || f.contains('ACID'))
                  ? AppTheme.alertRed
                  : AppTheme.collectorColor,
              content: Text('Identified: ${result.itemName} (${(result.confidence * 100).toStringAsFixed(0)}% confidence)'),
            ),
          );
        },
      ),
    );
  }

  void _openEditAIResultDialog() {
    if (_aiResult == null) return;
    final ai = _aiResult!;
    final isDark = AppTheme.isDark(context);

    final nameCtrl = TextEditingController(text: ai.itemName);
    final subcatCtrl = TextEditingController(text: ai.subcategory);
    final weightCtrl = TextEditingController(text: ai.estimatedWeightKg.toStringAsFixed(1));
    final qtyCtrl = TextEditingController(text: ai.quantity.toInt().toString());
    String selectedCat = ai.category;

    final categories = const [
      {'code': 'ITEW', 'label': 'ITEW — IT & Telecom (Phones, Laptops, Peripherals)'},
      {'code': 'PCB', 'label': 'PCB — Printed Circuit Boards & Motherboards'},
      {'code': 'BATTERY', 'label': 'BATTERY — Li-Ion, Lead-Acid, UPS Cells (Hazardous)'},
      {'code': 'CABLE', 'label': 'CABLE — Insulated Copper & Wiring'},
      {'code': 'IT_EQUIPMENT', 'label': 'IT_EQUIPMENT — Printers, Servers, Appliances'},
      {'code': 'DISPLAY', 'label': 'DISPLAY — Flat Panels & CRT Monitors'},
      {'code': 'MIXED_SCRAP', 'label': 'MIXED_SCRAP — General Recyclables'},
    ];

    final validCatCodes = categories.map((c) => c['code']).toSet();
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
                'Edit AI Detection Result',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.getTextPrimary(context)),
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
                            'Corrections update fair value calculations and self-train the local AI model.',
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
                    items: categories.map((c) {
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
              label: const Text('Save & Update Lot', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final newName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : ai.itemName;
                final newSubcat = subcatCtrl.text.trim().isNotEmpty ? subcatCtrl.text.trim() : ai.subcategory;
                final newWeight = double.tryParse(weightCtrl.text.trim()) ?? ai.estimatedWeightKg;
                final newQty = double.tryParse(qtyCtrl.text.trim()) ?? ai.quantity;

                String? b64;
                if (_scannedImageBytes != null) {
                  b64 = base64Encode(_scannedImageBytes!);
                }
                List<double>? bBox;
                if (ai.detectedComponents != null && ai.detectedComponents!.isNotEmpty) {
                  final first = ai.detectedComponents!.first;
                  if (first is Map<String, dynamic> && first['normalized_box'] is List) {
                    bBox = (first['normalized_box'] as List).map((e) => (e as num).toDouble()).toList();
                  }
                }

                widget.apiService.submitDetectionFeedback(
                  imageBase64: b64,
                  originalItemName: ai.itemName,
                  originalCategory: ai.category,
                  originalSubcategory: ai.subcategory,
                  correctedItemName: newName,
                  correctedCategory: selectedCat,
                  correctedSubcategory: newSubcat,
                  correctedWeightKg: newWeight,
                  correctedQuantity: newQty,
                  correctedCondition: 'mixed',
                  boundingBox: bBox,
                  collectorId: 'COL-001',
                ).then((res) {
                  debugPrint('Self-training feedback submitted: ${res['sample_id']}');
                }).catchError((err) {
                  debugPrint('Feedback notice: $err');
                });

                setState(() {
                  _aiResult = ai.copyWith(
                    itemName: newName,
                    category: selectedCat,
                    subcategory: newSubcat,
                    estimatedWeightKg: newWeight,
                    quantity: newQty,
                  );
                  _selectedCategory = selectedCat;
                  _selectedSubcategory = newSubcat;
                  _weightController.text = newWeight.toStringAsFixed(1);
                });

                Navigator.of(dialogCtx).pop();
                await _fetchFairValue();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.collectorColor,
                    content: Text('AI result updated & training sample recorded for model self-training!'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIResultCard() {
    final ai = _aiResult!;
    final hasHazard = ai.safetyFlags.any((f) =>
        f.contains('RISK') || f.contains('PUNCTURE') || f.contains('ACID') || f.contains('HAZARD'));
    final composition = ai.compositionBreakdown;
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardBoxDecoration(
        color: hasHazard
            ? (isDark ? const Color(0xFF2A0A0A) : const Color(0xFFFEF2F2))
            : (isDark ? const Color(0xFF042F2E) : const Color(0xFFECFDF5)),
        borderColor: hasHazard ? AppTheme.alertRed.withValues(alpha: 0.6) : AppTheme.collectorColor.withValues(alpha: 0.6),
        context: context,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Captured Image Thumbnail or Icon
              if (_scannedImageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    _scannedImageBytes!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: (hasHazard ? AppTheme.alertRed : AppTheme.collectorColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasHazard ? Icons.warning_amber_rounded : Icons.camera_alt_rounded,
                    color: hasHazard ? AppTheme.alertRed : AppTheme.collectorColor,
                    size: 26,
                  ),
                ),
              const SizedBox(width: 12),

              // Title and Category details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            ai.itemName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.getTextPrimary(context),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black45 : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(ai.confidence * 100).toStringAsFixed(0)}% Match',
                                style: const TextStyle(fontSize: 11, color: AppTheme.collectorColor, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _openEditAIResultDialog,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.collectorColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.collectorColor.withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded, size: 12, color: AppTheme.collectorColor),
                                    SizedBox(width: 3),
                                    Text('Edit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.collectorColor)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ai.category} • ${ai.grade}',
                      style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12),
                    ),
                    Text(
                      'CPCB Benchmark: ₹${ai.estimatedBaseRatePerKg.toStringAsFixed(0)} / kg',
                      style: const TextStyle(color: AppTheme.collectorColor, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Local OCR Detected Text & Brands
          if ((ai.detectedText != null && ai.detectedText!.isNotEmpty) || ai.extractedBrands.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.document_scanner_rounded, size: 14, color: Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      const Text(
                        'Local OCR Detected Label Text:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                      ),
                      const Spacer(),
                      if (ai.ocrConfidence > 0)
                        Text(
                          '${(ai.ocrConfidence * 100).toStringAsFixed(0)}% OCR Conf',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  if (ai.extractedBrands.isNotEmpty || ai.extractedModels.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ...ai.extractedBrands.map((b) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Brand: $b',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                          ),
                        )),
                        ...ai.extractedModels.map((m) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Model: $m',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                          ),
                        )),
                      ],
                    ),
                  ],
                  if (ai.detectedText != null && ai.detectedText!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${ai.detectedText!}"',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.getTextPrimary(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Local YOLO Detected Components
          if (ai.detectedComponents != null && ai.detectedComponents!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.memory_rounded, size: 14, color: AppTheme.primaryGreen),
                const SizedBox(width: 4),
                Text(
                  'Local YOLO Detected Components (${ai.detectedComponents!.length}):',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: ai.detectedComponents!.map((c) {
                final comp = c as Map<String, dynamic>;
                final lbl = comp['label'] ?? comp['raw_class'] ?? 'Component';
                final conf = ((comp['confidence'] as num?)?.toDouble() ?? 0.8) * 100;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$lbl (${conf.toStringAsFixed(0)}%)',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                  ),
                );
              }).toList(),
            ),
          ],

          // Composition Chips (if available)
          if (composition != null && composition.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: composition.entries.take(4).map((e) {
                final keyStr = e.key.replaceAll('_pct', '%').replaceAll('_ppm', ' ppm').replaceAll('_', ' ');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black38 : Colors.white70,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? AppTheme.borderSubtle : AppTheme.borderLight),
                  ),
                  child: Text(
                    '${e.value} $keyStr',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.getTextSecondary(context)),
                  ),
                );
              }).toList(),
            ),
          ],

          // Safety Guidance Banner
          const SizedBox(height: 10),
          if (hasHazard)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.alertRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: AppTheme.alertRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ ${ai.safetyGuidance}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              '💡 Safety Guidance: ${ai.safetyGuidance}',
              style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context)),
            ),

          const SizedBox(height: 12),

          // 1-Tap Actions: Instant Add Lot or Apply to Form
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: hasHazard ? Colors.amber.shade900 : AppTheme.collectorColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                  label: const Text(
                    'Instant Add Lot',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () async {
                    setState(() {
                      _selectedCategory = ai.category;
                      _selectedSubcategory = ai.subcategory;
                    });
                    await _createLot();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: hasHazard ? AppTheme.alertRed.withValues(alpha: 0.5) : AppTheme.collectorColor.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: Text(
                    'Apply to Form',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                  onPressed: () async {
                    setState(() {
                      _selectedCategory = ai.category;
                      _selectedSubcategory = ai.subcategory;
                    });
                    await _fetchFairValue();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.collectorColor,
                        content: Text('Applied "${ai.itemName}" to Lot Creation Form below!'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF8B5CF6)),
                label: const Text(
                  '✏️ Edit AI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                onPressed: _openEditAIResultDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFairValueCard() {
    final fv = _fairValueData!;
    final min = fv['fair_value_min'];
    final max = fv['fair_value_max'];
    final breakdown = (fv['breakdown'] as List? ?? []);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: AppTheme.collectorColor.withValues(alpha: 0.4),
        context: context,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('fair_value_title'), style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context), fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: AppTheme.pillBadgeDecoration(AppTheme.collectorColor, context: context),
                child: const Text('🛡️ Anti-Exploitation Band', style: TextStyle(fontSize: 11, color: AppTheme.collectorColor, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹$min – ₹$max',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.collectorColor, letterSpacing: -0.5),
          ),
          const Divider(height: 24),
          Text('Why this price? (Explainability breakdown):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.getTextPrimary(context))),
          const SizedBox(height: 8),
          ...breakdown.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('• ${item['name']}', style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
                    Text(
                      '${(item['adjustment_inr'] as num) >= 0 ? '+' : ''}₹${item['adjustment_inr']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: (item['adjustment_inr'] as num) >= 0 ? AppTheme.collectorColor : AppTheme.alertAmber,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _getNormalizedCategory(String cat) {
    final upper = cat.toUpperCase();
    if (upper == 'ITEW' || upper.contains('PHONE') || upper.contains('MOBILE') || upper.contains('HANDSET') || upper.contains('TABLET')) {
      return 'ITEW';
    }
    if (upper == 'PCB' || upper.contains('CIRCUIT') || upper.contains('MOTHERBOARD') || upper.contains('BOARD')) {
      return 'PCB';
    }
    if (upper == 'BATTERY' || upper.contains('CELL') || upper.contains('LITHIUM') || upper.contains('LEAD')) {
      return 'BATTERY';
    }
    if (upper == 'CABLE' || upper.contains('WIRE') || upper.contains('COPPER')) {
      return 'CABLE';
    }
    if (upper == 'IT_EQUIPMENT' || upper.contains('LAPTOP') || upper.contains('SERVER') || upper.contains('COMPUTER')) {
      return 'IT_EQUIPMENT';
    }
    if (upper == 'DISPLAY' || upper.contains('MONITOR') || upper.contains('SCREEN') || upper.contains('PANEL')) {
      return 'DISPLAY';
    }
    return 'MIXED_SCRAP';
  }

  String _getDefaultSubcategory(String cat) {
    final norm = _getNormalizedCategory(cat);
    switch (norm) {
      case 'ITEW':
        return 'SMARTPHONE_HANDSET';
      case 'PCB':
        return 'IT_HIGH_GRADE_PCB';
      case 'BATTERY':
        return 'LITHIUM_ION';
      case 'CABLE':
        return 'COPPER_RICH_CABLE';
      case 'IT_EQUIPMENT':
        return 'LAPTOP_WHOLE';
      case 'DISPLAY':
        return 'LED_MONITOR';
      case 'MIXED_SCRAP':
      default:
        return 'MIXED_EWASTE';
    }
  }

  List<Map<String, String>> _getSubcategoriesForCategory(String category) {
    switch (category) {
      case 'ITEW':
        return [
          {'value': 'SMARTPHONE_HANDSET', 'label': '📱 Smartphone / Handset'},
          {'value': 'TABLET_DEVICE', 'label': '📱 Tablet / E-Reader'},
        ];
      case 'PCB':
        return [
          {'value': 'IT_HIGH_GRADE_PCB', 'label': '🟩 High-Grade Motherboard'},
          {'value': 'LOW_GRADE_PCB', 'label': '🟨 Low-Grade SMPS Board'},
        ];
      case 'BATTERY':
        return [
          {'value': 'LITHIUM_ION', 'label': '🔋 Lithium-Ion Pack'},
          {'value': 'LEAD_ACID', 'label': '⚡ Sealed Lead-Acid'},
        ];
      case 'CABLE':
        return [
          {'value': 'COPPER_RICH_CABLE', 'label': '🔌 High-Copper Cable'},
        ];
      case 'IT_EQUIPMENT':
        return [
          {'value': 'LAPTOP_WHOLE', 'label': '💻 Laptop Unit'},
        ];
      case 'DISPLAY':
        return [
          {'value': 'LED_MONITOR', 'label': '🖥️ Flat Panel LCD/LED'},
          {'value': 'CRT_MONITOR', 'label': '📺 CRT Leaded Glass'},
        ];
      case 'MIXED_SCRAP':
      default:
        return [
          {'value': 'MIXED_EWASTE', 'label': '📦 Mixed E-Scrap'},
        ];
    }
  }

  Widget _buildLotFormCard() {
    final normalizedCategory = _getNormalizedCategory(_selectedCategory);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardBoxDecoration(color: AppTheme.getCardBg(context), context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create New Lot Draft', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.getTextPrimary(context))),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    suffixText: 'kg',
                  ),
                  onChanged: (_) => _fetchFairValue(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(normalizedCategory),
                  initialValue: normalizedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  dropdownColor: AppTheme.getCardBg(context),
                  items: const [
                    DropdownMenuItem(value: 'ITEW', child: Text('Smartphones & Handsets')),
                    DropdownMenuItem(value: 'PCB', child: Text('PCB Circuit Boards')),
                    DropdownMenuItem(value: 'BATTERY', child: Text('Batteries (Li-Ion/Pb)')),
                    DropdownMenuItem(value: 'CABLE', child: Text('Cables & Wiring')),
                    DropdownMenuItem(value: 'IT_EQUIPMENT', child: Text('IT Scrap & Laptops')),
                    DropdownMenuItem(value: 'DISPLAY', child: Text('Displays & Monitors')),
                    DropdownMenuItem(value: 'MIXED_SCRAP', child: Text('Mixed E-Waste')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                        _selectedSubcategory = _getDefaultSubcategory(val);
                      });
                      _fetchFairValue();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Material Subtype / Grade:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.getTextSecondary(context)),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _getSubcategoriesForCategory(normalizedCategory).map((sub) {
                final isSelected = _selectedSubcategory == sub['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(sub['label']!),
                    selected: isSelected,
                    selectedColor: AppTheme.collectorColor.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? AppTheme.collectorColor : AppTheme.getTextSecondary(context),
                    ),
                    side: BorderSide(
                      color: isSelected ? AppTheme.collectorColor : AppTheme.getBorder(context),
                    ),
                    backgroundColor: AppTheme.getSurface(context),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedSubcategory = sub['value']!);
                        _fetchFairValue();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.collectorColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _isLoading ? null : _createLot,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: Text(t('create_lot_btn'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLotItem(LotModel lot) {
    final isPending = lot.isOfflinePending;
    final statusColor = lot.status == 'OPEN_FOR_BIDS'
        ? AppTheme.recyclerColor
        : (lot.status == 'BID_SELECTED' ? AppTheme.alertAmber : AppTheme.collectorColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardBoxDecoration(color: AppTheme.getCardBg(context), context: context),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (isPending ? AppTheme.alertAmber : AppTheme.collectorColor).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: (isPending ? AppTheme.alertAmber : AppTheme.collectorColor).withValues(alpha: 0.4)),
          ),
          child: Icon(
            isPending ? Icons.offline_bolt_rounded : Icons.qr_code_2_rounded,
            color: isPending ? AppTheme.alertAmber : AppTheme.collectorColor,
            size: 22,
          ),
        ),
        title: Text(
          '${lot.lotCode} • ${lot.category}',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.getTextPrimary(context)),
        ),
        subtitle: Text(
          '${lot.estimatedWeightKg} kg • Fair: ₹${lot.fairValueMin.toStringAsFixed(0)}–₹${lot.fairValueMax.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context)),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: AppTheme.pillBadgeDecoration(statusColor, context: context),
          child: Text(
            lot.status,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subcategory: ${lot.subcategory}', style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
                    Text('Condition: ${lot.condition}', style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
                  ],
                ),
                if (lot.verifiedWeightKg != null) ...[
                  const SizedBox(height: 6),
                  Text('Scale Verified Weight: ${lot.verifiedWeightKg} kg',
                      style: const TextStyle(color: AppTheme.collectorColor, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
                const Divider(height: 20),
                Text('Bids Received (${lot.bids.length}):',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.getTextPrimary(context))),
                const SizedBox(height: 6),
                if (lot.bids.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Text('Waiting for verified recyclers to submit offers...',
                        style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12)),
                  ),
                ...lot.bids.map((b) => _buildBidTile(lot, b)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBidTile(LotModel lot, BidModel bid) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bid.isAnomaly
            ? AppTheme.alertRed.withValues(alpha: 0.12)
            : (AppTheme.isDark(context) ? AppTheme.surfaceDark : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bid.isAnomaly ? AppTheme.alertRed.withValues(alpha: 0.5) : AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(bid.recyclerName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.getTextPrimary(context))),
              Text('Net: ₹${bid.netCollectorPayable.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: bid.isAnomaly ? AppTheme.alertRed : AppTheme.collectorColor,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Offer: ₹${bid.offerPrice.toStringAsFixed(0)} • Match Score: ${bid.matchScore.toStringAsFixed(0)}/100',
            style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context)),
          ),
          if (bid.isAnomaly) ...[
            const SizedBox(height: 4),
            Text(bid.anomalyReason ?? 'Predatory low offer!',
                style: const TextStyle(color: AppTheme.alertRed, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
          if (bid.status == 'SUBMITTED')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.collectorColor),
                label: const Text('Accept Offer', style: TextStyle(color: AppTheme.collectorColor, fontWeight: FontWeight.w700, fontSize: 12)),
                onPressed: () async {
                  await widget.apiService.acceptBid(bid.id);
                  _loadLots();
                },
              ),
            )
          else if (bid.status == 'ACCEPTED')
            const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text('✅ ACCEPTED', style: TextStyle(color: AppTheme.collectorColor, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}
