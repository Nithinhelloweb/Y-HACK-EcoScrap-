import 'package:flutter/material.dart';
import '../models/lot_model.dart';
import '../services/api_service.dart';
import '../services/offline_store.dart';
import '../i18n/translations.dart';

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

  Future<void> _runAILensSimulation(String query) async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiService.classifyMaterial(query);
      setState(() {
        _aiResult = res;
        _selectedCategory = res.category;
        _selectedSubcategory = res.subcategory;
      });
      await _fetchFairValue();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI Lens Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          backgroundColor: (parsed['is_hazard'] == true) ? Colors.red.shade900 : Colors.teal.shade800,
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
            title: Row(
              children: [
                const Icon(Icons.shield_rounded, color: Colors.orangeAccent),
                const SizedBox(width: 8),
                Text(t('safety_protocols_btn'), style: const TextStyle(fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: protocols.entries.map<Widget>((entry) {
                  final data = entry.value as Map<String, dynamic>;
                  final title = lang == 'ta'
                      ? (data['title_ta'] ?? data['title'])
                      : (lang == 'hi' ? (data['title_hi'] ?? data['title']) : data['title']);
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
                      color: isCritical ? const Color(0xFF450A0A) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isCritical ? Colors.redAccent : Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCritical ? Icons.warning_amber_rounded : Icons.info_outline,
                              color: isCritical ? Colors.redAccent : Colors.tealAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCritical ? Colors.red : Colors.teal,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(data['hazard_level'] ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...sops.map((s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text('• $s', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            )),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            created.isOfflinePending
                ? '⚡ Saved to Offline Outbox! (${created.lotCode})'
                : '✅ Lot Created Online: ${created.lotCode}',
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.offlineStore;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(t('app_title')),
            actions: [
              // Language Switcher Dropdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: DropdownButton<String>(
                  value: widget.currentLang,
                  underline: const SizedBox(),
                  dropdownColor: const Color(0xFF1E293B),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English 🌐', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'ta', child: Text('தமிழ் 🌐', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'hi', child: Text('हिंदी 🌐', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (val) {
                    if (val != null) widget.onLangChanged(val);
                  },
                ),
              ),
              // Simulated Offline Mode Toggle
              IconButton(
                tooltip: store.isOfflineMode ? t('offline_mode') : t('online_mode'),
                icon: Icon(
                  store.isOfflineMode ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                  color: store.isOfflineMode ? Colors.orangeAccent : Colors.lightGreenAccent,
                ),
                onPressed: store.toggleOfflineMode,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadLots,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Connectivity & Outbox Banner
                _buildConnectivityBanner(store),
                const SizedBox(height: 12),

                // Collector Trust Card
                _buildCollectorTrustCard(),
                const SizedBox(height: 16),

                // Voice & AI Action Hub
                _buildActionHub(),
                const SizedBox(height: 16),

                // AI Lens Result & Safety Hazard Warning (if triggered)
                if (_aiResult != null) _buildAIResultCard(),

                // Fair Value Range Card
                if (_fairValueData != null) _buildFairValueCard(),

                const SizedBox(height: 16),
                // Create Lot Form
                _buildLotFormCard(),

                const SizedBox(height: 24),
                // Collector's Active Lots Feed
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '📦 ${t('completed_lots')} (${store.lots.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadLots,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...store.lots.map((lot) => _buildLotItem(lot)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectivityBanner(OfflineStore store) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: store.isOfflineMode ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.teal.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: store.isOfflineMode ? Colors.amber : Colors.tealAccent,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            store.isOfflineMode ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
            color: store.isOfflineMode ? Colors.amber : Colors.tealAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.isOfflineMode ? t('offline_mode') : t('online_mode'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (store.pendingCount > 0)
                  Text(
                    '${store.pendingCount} ${t('pending_sync')}',
                    style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
                  ),
              ],
            ),
          ),
          if (store.pendingCount > 0 && !store.isOfflineMode)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                final count = await store.syncPendingQueue(widget.apiService);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Synced $count lots to central EcoScrap!')),
                  );
                }
              },
              icon: const Icon(Icons.sync, size: 16),
              label: Text(t('sync_now')),
            ),
        ],
      ),
    );
  }

  Widget _buildCollectorTrustCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.green.shade800,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.badge_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Murugan K. (COL-TN-019284)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('CPCB Verified Collection Partner • Coimbatore', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade900,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('⭐ 94.5 / 100 Trust Score', style: TextStyle(color: Colors.lightGreenAccent, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      const Text('182 Lots Formalized', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.indigo.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.mic_rounded, color: Colors.white),
                label: Text(t('voice_button'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: _showVoicePromptDialog,
              ),
            ),
            const SizedBox(width: 12),
            // AI Camera Lens Button
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                label: Text(t('ai_lens_btn'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: _showAICameraDialog,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: const BorderSide(color: Colors.amberAccent, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.shield_rounded, color: Colors.amberAccent, size: 20),
            label: Text(
              t('safety_protocols_btn'),
              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: _showSafetyProtocolsDialog,
          ),
        ),
      ],
    );
  }

  void _showVoicePromptDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Row(
                children: [
                  Icon(Icons.record_voice_over, color: Colors.indigoAccent),
                  SizedBox(width: 10),
                  Text('Voice Assistant (தமிழ் / हिंदी / English)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(t('voice_hint'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),

              // Tamil Prompts
              ListTile(
                tileColor: Colors.grey.shade900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.cable, color: Colors.amberAccent),
                title: const Text('தமிழ்: "10 கிலோ தாமிர கம்பி"'),
                subtitle: const Text('Extracts 10 kg • Categorizes as CABLE'),
                onTap: () {
                  Navigator.pop(context);
                  _runVoiceSimulation("10 கிலோ தாமிர கம்பி");
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                tileColor: Colors.grey.shade900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.battery_alert, color: Colors.redAccent),
                title: const Text('தமிழ்: "வீங்கிய லித்தியம் பேட்டரி"'),
                subtitle: const Text('Triggers Swollen Battery Hazard Alert'),
                onTap: () {
                  Navigator.pop(context);
                  _runVoiceSimulation("வீங்கிய லித்தியம் பேட்டரி");
                },
              ),
              const SizedBox(height: 6),

              // Hindi Prompts
              ListTile(
                tileColor: Colors.grey.shade900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.memory, color: Colors.tealAccent),
                title: const Text('हिंदी: "5 किलो पुराना लैपटॉप मदरबोर्ड"'),
                subtitle: const Text('Extracts 5 kg • Categorizes as High-Grade PCB'),
                onTap: () {
                  Navigator.pop(context);
                  _runVoiceSimulation("5 किलो पुराना लैपटॉप मदरबोर्ड");
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                tileColor: Colors.grey.shade900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.deepOrangeAccent),
                title: const Text('हिंदी: "इनवर्टर लेड एसिड बैटरी"'),
                subtitle: const Text('Categorizes as Lead-Acid • Corrosive Hazard'),
                onTap: () {
                  Navigator.pop(context);
                  _runVoiceSimulation("इनवर्टर लेड एसिड बैटरी");
                },
              ),
              const SizedBox(height: 6),

              // English Prompts
              ListTile(
                tileColor: Colors.grey.shade900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.laptop_chromebook, color: Colors.lightBlueAccent),
                title: const Text('English: "8.4 kg server circuit boards"'),
                subtitle: const Text('Extracts 8.4 kg • IT_HIGH_GRADE_PCB'),
                onTap: () {
                  Navigator.pop(context);
                  _runVoiceSimulation("8.4 kg server circuit boards");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAICameraDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('AI Lens: Select E-Waste Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.memory, color: Colors.greenAccent),
                title: const Text('Laptop Motherboard (PCB)'),
                subtitle: const Text('Simulate image scan of high-grade PCB'),
                onTap: () {
                  Navigator.pop(context);
                  _runAILensSimulation("motherboard");
                },
              ),
              ListTile(
                leading: const Icon(Icons.battery_charging_full, color: Colors.amberAccent),
                title: const Text('Lithium-Ion Battery Cell'),
                subtitle: const Text('Simulate image scan of battery pack'),
                onTap: () {
                  Navigator.pop(context);
                  _runAILensSimulation("lithium battery");
                },
              ),
              ListTile(
                leading: const Icon(Icons.electrical_services, color: Colors.lightBlueAccent),
                title: const Text('Copper Wire Bundle'),
                subtitle: const Text('Simulate image scan of insulated cable'),
                onTap: () {
                  Navigator.pop(context);
                  _runAILensSimulation("copper cable");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAIResultCard() {
    final ai = _aiResult!;
    final hasHazard = ai.safetyFlags.contains('THERMAL_RUNAWAY_RISK') ||
        ai.safetyFlags.contains('DO_NOT_PUNCTURE') ||
        ai.safetyFlags.contains('CORROSIVE_SULFURIC_ACID');

    return Card(
      color: hasHazard ? const Color(0xFF450A0A) : const Color(0xFF042F2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: hasHazard ? Colors.redAccent : Colors.tealAccent, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(hasHazard ? Icons.warning_amber_rounded : Icons.auto_awesome,
                        color: hasHazard ? Colors.redAccent : Colors.tealAccent),
                    const SizedBox(width: 8),
                    Text(ai.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${(ai.confidence * 100).toStringAsFixed(0)}% Confidence',
                      style: const TextStyle(fontSize: 12, color: Colors.lightGreenAccent)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Classification: ${ai.category} • ${ai.grade}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            if (hasHazard)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('⚠️ ${ai.safetyGuidance}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            else
              Text('💡 Safety Guidance: ${ai.safetyGuidance}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildFairValueCard() {
    final fv = _fairValueData!;
    final min = fv['fair_value_min'];
    final max = fv['fair_value_max'];
    final breakdown = (fv['breakdown'] as List? ?? []);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t('fair_value_title'), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const Text('🛡️ Anti-Exploitation Band', style: TextStyle(fontSize: 12, color: Colors.lightGreenAccent)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '₹$min – ₹$max',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.lightGreenAccent),
            ),
            const Divider(height: 20),
            const Text('Why this price? (Explainability breakdown):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...breakdown.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('• ${item['name']}', style: const TextStyle(fontSize: 12)),
                      Text(
                        '${(item['adjustment_inr'] as num) >= 0 ? '+' : ''}₹${item['adjustment_inr']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: (item['adjustment_inr'] as num) >= 0 ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildLotFormCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create New Lot Draft', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      border: OutlineInputBorder(),
                      suffixText: 'kg',
                    ),
                    onChanged: (_) => _fetchFairValue(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'PCB', child: Text('PCB Board')),
                      DropdownMenuItem(value: 'BATTERY', child: Text('Battery')),
                      DropdownMenuItem(value: 'CABLE', child: Text('Cables')),
                      DropdownMenuItem(value: 'IT_EQUIPMENT', child: Text('IT Scrap')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                        _fetchFairValue();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _createLot,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(t('create_lot_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLotItem(LotModel lot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: lot.isOfflinePending ? Colors.amber.shade900 : Colors.teal.shade900,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            lot.isOfflinePending ? Icons.offline_bolt : Icons.qr_code_2_rounded,
            color: Colors.white,
          ),
        ),
        title: Text('${lot.lotCode} • ${lot.category}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${lot.estimatedWeightKg} kg • Fair: ₹${lot.fairValueMin.toStringAsFixed(0)}–₹${lot.fairValueMax.toStringAsFixed(0)}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: lot.status == 'OPEN_FOR_BIDS' ? Colors.blue.shade900 : Colors.green.shade900,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(lot.status, style: const TextStyle(fontSize: 11, color: Colors.white)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subcategory: ${lot.subcategory}'),
                Text('Condition: ${lot.condition}'),
                if (lot.verifiedWeightKg != null)
                  Text('Scale Verified Weight: ${lot.verifiedWeightKg} kg', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                const Divider(),
                Text('Bids (${lot.bids.length}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (lot.bids.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Waiting for verified recyclers to submit offers...'),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bid.isAnomaly ? const Color(0xFF450A0A) : Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bid.isAnomaly ? Colors.redAccent : Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(bid.recyclerName, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Net: ₹${bid.netCollectorPayable.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: bid.isAnomaly ? Colors.redAccent : Colors.lightGreenAccent,
                  )),
            ],
          ),
          Text('Offer: ₹${bid.offerPrice.toStringAsFixed(0)} (Match Score: ${bid.matchScore.toStringAsFixed(0)}/100)'),
          if (bid.isAnomaly) ...[
            const SizedBox(height: 4),
            Text(bid.anomalyReason ?? 'Predatory low offer!',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
          if (bid.status == 'SUBMITTED')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Accept Offer'),
                onPressed: () async {
                  await widget.apiService.acceptBid(bid.id);
                  _loadLots();
                },
              ),
            )
          else if (bid.status == 'ACCEPTED')
            const Align(
              alignment: Alignment.centerRight,
              child: Text('✅ ACCEPTED', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
