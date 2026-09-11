import 'package:flutter/material.dart';
import '../models/lot_model.dart';
import '../services/api_service.dart';
import '../i18n/translations.dart';
import '../theme/app_theme.dart';
import '../widgets/ecoscrap_logo.dart';

class RecyclerScreen extends StatefulWidget {
  final ApiService apiService;
  final String currentLang;
  final int initialTab;

  const RecyclerScreen({
    super.key,
    required this.apiService,
    required this.currentLang,
    this.initialTab = 0,
  });

  @override
  State<RecyclerScreen> createState() => _RecyclerScreenState();
}

class _RecyclerScreenState extends State<RecyclerScreen> {
  List<LotModel> _lots = [];
  bool _isLoading = false;
  String _selectedCategoryFilter = 'ALL';
  bool _showMyBids = true;

  // Performance stats & bid history
  Map<String, dynamic>? _recyclerStats;
  List<Map<String, dynamic>> _myBids = [];

  late int _currentSubTab;

  final _otpController = TextEditingController();
  final _scaleWeightController = TextEditingController();

  String t(String key) => AppTranslations.get(key, widget.currentLang);

  @override
  void initState() {
    super.initState();
    _currentSubTab = widget.initialTab;
    _fetchLots();
    _loadRecyclerStats();
  }

  @override
  void didUpdateWidget(RecyclerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      setState(() => _currentSubTab = widget.initialTab);
    }
  }

  Future<void> _loadRecyclerStats() async {
    try {
      final stats = await widget.apiService.fetchRecyclerStats('default');
      if (mounted) setState(() => _recyclerStats = stats);
    } catch (_) {}
    try {
      final bidsData = await widget.apiService.fetchRecyclerBids('default');
      final bids = (bidsData['bids'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() => _myBids = bids);
    } catch (_) {}
  }

  Future<void> _fetchLots() async {
    setState(() => _isLoading = true);
    try {
      final lots = await widget.apiService.fetchLots();
      if (!mounted) return;
      setState(() => _lots = lots);
    } catch (e) {
      debugPrint('Error fetching lots for recycler: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<LotModel> get _filteredLots {
    if (_selectedCategoryFilter == 'ALL') return _lots;
    final target = _selectedCategoryFilter.toUpperCase();
    return _lots.where((l) {
      final cat = l.category.toUpperCase();
      if (target == 'ITEW') {
        return cat == 'ITEW' || cat.contains('PHONE') || cat.contains('MOBILE') || cat.contains('HANDSET') || cat.contains('TABLET');
      }
      return cat == target;
    }).toList();
  }

  void _showBidDialog(LotModel lot) {
    final offerController = TextEditingController(text: lot.fairValueMin.toStringAsFixed(0));
    final deductionController = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final offer = double.tryParse(offerController.text) ?? 0.0;
            final ded = double.tryParse(deductionController.text) ?? 0.0;
            final netPayable = (offer - ded).clamp(0.0, 1000000.0);
            final isBelowFloor = lot.fairValueMin > 0 && offer < (lot.fairValueMin * 0.75);

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
                      color: AppTheme.recyclerColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.gavel_rounded, color: AppTheme.recyclerColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Submit Bid: ${lot.lotCode}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.getTextPrimary(context))),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Material: ${lot.category} • ${lot.estimatedWeightKg} kg',
                      style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Fair Range: ₹${lot.fairValueMin.toStringAsFixed(0)} – ₹${lot.fairValueMax.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.collectorColor, fontSize: 13)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: offerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Offer Price (INR)', prefixText: '₹ '),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: deductionController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Logistics Deduction (INR)', prefixText: '₹ '),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Net Collector Payable:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('₹${netPayable.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.recyclerColor)),
                      ],
                    ),
                  ),
                  if (isBelowFloor) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.alertRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppTheme.alertRed, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'WARNING: Offer is 25%+ below fair value. It will be flagged by the Anomaly Shield.',
                              style: TextStyle(color: AppTheme.alertRed, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.recyclerColor,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);

                    try {
                      final bid = await widget.apiService.submitBid(
                        lotId: lot.id,
                        recyclerId: 'REC-DEMO',
                        offerPrice: offer,
                        deduction: ded,
                      );

                      if (!mounted) return;
                      if (bid.isAnomaly) {
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.alertRed,
                            content: Text('⚠️ ANOMALY ALERT: ${bid.anomalyReason}'),
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF065F46),
                            content: Text('✅ Bid of ₹$offer submitted! Match score: ${bid.matchScore}/100'),
                          ),
                        );
                      }
                      _fetchLots();
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  child: const Text('Submit Bid', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showHandoverModal(LotModel lot) {
    _otpController.clear();
    _scaleWeightController.text = lot.estimatedWeightKg.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardBg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.collectorColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.scale_rounded, color: AppTheme.collectorColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text('${t('handover_title')}: ${lot.lotCode}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.getTextPrimary(context))),
                ],
              ),
              const SizedBox(height: 6),
              Text('Collector declared weight: ${lot.estimatedWeightKg} kg • ±5% tolerance band',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: t('enter_otp'),
                  prefixIcon: const Icon(Icons.pin_rounded, color: AppTheme.recyclerColor),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _scaleWeightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: t('verified_scale'),
                  prefixIcon: const Icon(Icons.scale_rounded, color: AppTheme.collectorColor),
                  suffixText: 'kg',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.collectorColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: Text(t('confirm_handover'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  onPressed: () async {
                    final scaleWt = double.tryParse(_scaleWeightController.text) ?? lot.estimatedWeightKg;
                    final otp = _otpController.text.trim();
                    Navigator.pop(ctx);

                    try {
                      final res = await widget.apiService.verifyHandover(
                        lotId: lot.id,
                        otpCode: otp,
                        scaleWeightKg: scaleWt,
                      );

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: res['flagged_anomaly'] == true ? AppTheme.alertAmber : const Color(0xFF065F46),
                          content: Text(res['message'] ?? 'Handover complete!'),
                        ),
                      );
                      _fetchLots();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: AppTheme.alertRed, content: Text('Handover verification failed: $e')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRecordRecoveryDialog(LotModel lot) {
    final copperCtrl = TextEditingController(text: '0.0');
    final plasticCtrl = TextEditingController(text: '0.0');
    final ferrousCtrl = TextEditingController(text: '0.0');
    final preciousCtrl = TextEditingController(text: '0.0');
    final aluCtrl = TextEditingController(text: '0.0');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.getCardBg(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.recycling_rounded, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Record Recovery: ${lot.lotCode}',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.getTextPrimary(context)),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Log actual recovered material fractions separated from this ${lot.estimatedWeightKg} kg lot for EPR compliance & ledger attestation.',
                  style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: copperCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Copper Extracted (kg)',
                    prefixIcon: Icon(Icons.cable_rounded, color: Colors.deepOrange),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: plasticCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Engineering Plastics (kg)',
                    prefixIcon: Icon(Icons.category_rounded, color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ferrousCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Ferrous / Steel (kg)',
                    prefixIcon: Icon(Icons.hardware_rounded, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: preciousCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precious Metals / Gold / Silver (g)',
                    prefixIcon: Icon(Icons.diamond_rounded, color: Colors.amber),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: aluCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Aluminium Extracted (kg)',
                    prefixIcon: Icon(Icons.layers_rounded, color: Colors.teal),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Smelter / Shredder Batch Ref & Notes',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AppTheme.getTextSecondary(context))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Record & Finalize', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final copper = double.tryParse(copperCtrl.text.trim()) ?? 0.0;
                final plastic = double.tryParse(plasticCtrl.text.trim()) ?? 0.0;
                final ferrous = double.tryParse(ferrousCtrl.text.trim()) ?? 0.0;
                final precious = double.tryParse(preciousCtrl.text.trim()) ?? 0.0;
                final alu = double.tryParse(aluCtrl.text.trim()) ?? 0.0;
                final notes = notesCtrl.text.trim();

                final Map<String, double> fractions = {};
                if (copper > 0) fractions['Copper_kg'] = copper;
                if (plastic > 0) fractions['Plastics_kg'] = plastic;
                if (ferrous > 0) fractions['Ferrous_kg'] = ferrous;
                if (precious > 0) fractions['Precious_Gold_Silver_g'] = precious;
                if (alu > 0) fractions['Aluminium_kg'] = alu;

                Navigator.pop(ctx);
                try {
                  await widget.apiService.recordLotRecovery(
                    lotId: lot.id,
                    recoveredFractions: fractions,
                    recyclerId: 'REC-DEMO',
                    notes: notes.isEmpty ? null : notes,
                  );
                  await _fetchLots();
                  messenger.showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF065F46),
                      content: Text('✅ Recovery fractions sealed onto digital chain ledger!'),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(backgroundColor: AppTheme.alertRed, content: Text('Error: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final handoverLots = _lots.where((l) => l.status == 'BID_SELECTED' || l.status == 'HANDOVER_SCHEDULED').toList();
    final pipelineLots = _lots.where((l) =>
        l.status == 'RECEIVED' ||
        l.status == 'PROCESSING' ||
        l.status == 'MATERIAL_RECOVERED' ||
        l.status == 'CLOSED'
    ).toList();

    return RefreshIndicator(
      color: AppTheme.recyclerColor,
      backgroundColor: AppTheme.getCardBg(context),
      onRefresh: _fetchLots,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.recyclerColor))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              children: [
                // Recycler Profile Header Card
                _buildRecyclerHeaderCard(context),
                const SizedBox(height: 12),

                // Modular Sub-Tab Bar
                _buildSubTabBar(context, handoverLots.length, pipelineLots.length),
                const SizedBox(height: 14),

                // Sub-Tab 0: Marketplace Lots
                if (_currentSubTab == 0) ...[
                  // Material Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(context, 'ALL', 'All Materials'),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, 'ITEW', 'Smartphones & Mobiles'),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, 'PCB', 'Circuit Boards (PCB)'),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, 'BATTERY', 'Batteries (Haz)'),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, 'CABLE', 'Copper Cables'),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, 'IT_EQUIPMENT', 'IT Scrap & Laptops'),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, 'DISPLAY', 'Displays & Screens'),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, 'MIXED_SCRAP', 'Mixed Scrap'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Marketplace Lots Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.recyclerColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.storefront_rounded, color: AppTheme.recyclerColor, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text('Active E-Waste Lots (${_filteredLots.length})',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.getTextPrimary(context))),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: AppTheme.recyclerColor, size: 20),
                        tooltip: 'Refresh marketplace',
                        onPressed: _fetchLots,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_filteredLots.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: AppTheme.cardBoxDecoration(color: AppTheme.getCardBg(context), context: context),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_rounded, size: 40, color: AppTheme.getTextSecondary(context)),
                          const SizedBox(height: 10),
                          Text('No active lots matching this filter.',
                              style: TextStyle(color: AppTheme.getTextSecondary(context), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  else
                    ..._filteredLots.map((lot) => _buildRecyclerLotCard(context, lot)),
                  const SizedBox(height: 20),
                ],

                // Sub-Tab 1: My Bids & Handover
                if (_currentSubTab == 1) ...[
                  _buildMyBidsSection(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4338CA).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.scale_rounded, color: Color(0xFF6366F1), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text('Pending Handover & Scale Verification (${handoverLots.length})',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.getTextPrimary(context))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (handoverLots.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.cardBoxDecoration(color: AppTheme.getCardBg(context), context: context),
                      child: Center(
                        child: Text('No lots currently awaiting handover or scale verification.',
                            style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12)),
                      ),
                    )
                  else
                    ...handoverLots.map((lot) => _buildRecyclerLotCard(context, lot)),
                  const SizedBox(height: 20),
                ],

                // Sub-Tab 2: Processing Pipeline
                if (_currentSubTab == 2) ...[
                  _buildPipelineInfoBanner(context),
                  const SizedBox(height: 12),
                  if (pipelineLots.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: AppTheme.cardBoxDecoration(color: AppTheme.getCardBg(context), context: context),
                      child: Column(
                        children: [
                          Icon(Icons.precision_manufacturing_rounded, size: 40, color: AppTheme.getTextSecondary(context)),
                          const SizedBox(height: 10),
                          Text('No lots currently in the recovery pipeline.',
                              style: TextStyle(color: AppTheme.getTextSecondary(context), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Once physical handover is verified, received lots appear here to start dismantling.',
                              style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  else
                    ...pipelineLots.map((lot) => _buildRecyclerLotCard(context, lot)),
                  const SizedBox(height: 20),
                ],

                // Sub-Tab 3: Performance & Stats
                if (_currentSubTab == 3) ...[
                  _buildPerformanceCard(),
                  const SizedBox(height: 14),
                  _buildRecyclerRosterCard(context),
                  const SizedBox(height: 20),
                ],
              ],
            ),
    );
  }

  Widget _buildRecyclerHeaderCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: AppTheme.recyclerColor.withValues(alpha: 0.35),
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
                Text('GreenTech Circular Solutions',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.getTextPrimary(context))),
                const SizedBox(height: 2),
                Text('CPCB Reg: CPCB-TN-REC-2024-8812 • SIDCO Estate',
                    style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: AppTheme.pillBadgeDecoration(AppTheme.recyclerColor, context: context),
                      child: const Text('⭐ 96% Reliability Rating',
                          style: TextStyle(color: AppTheme.recyclerColor, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    Text('Cap: 2,500 kg/day', style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context), fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabBar(BuildContext context, int handoverCount, int pipelineCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _subTabChip(0, '🏪 Marketplace', _filteredLots.length),
          const SizedBox(width: 8),
          _subTabChip(1, '💼 My Bids & Handover', _myBids.isNotEmpty ? _myBids.length : null),
          const SizedBox(width: 8),
          _subTabChip(2, '⚙️ Pipeline', pipelineCount > 0 ? pipelineCount : null),
          const SizedBox(width: 8),
          _subTabChip(3, '📊 Performance', null),
        ],
      ),
    );
  }

  Widget _subTabChip(int index, String label, int? badgeCount) {
    final isSelected = _currentSubTab == index;
    return InkWell(
      onTap: () => setState(() => _currentSubTab = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.recyclerColor.withValues(alpha: 0.18)
              : AppTheme.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.recyclerColor : AppTheme.getBorder(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppTheme.recyclerColor : AppTheme.getTextPrimary(context),
              ),
            ),
            if (badgeCount != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.recyclerColor : AppTheme.getTextSecondary(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppTheme.getTextPrimary(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineInfoBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree_rounded, color: Color(0xFF059669), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Material Recovery Lifecycle Stepper',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF059669)),
                ),
                Text(
                  'RECEIVED ➔ 🔧 START PROCESSING ➔ ✅ RECOVERED ➔ 🔒 CLOSE LOT',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.getTextSecondary(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecyclerRosterCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: AppTheme.recyclerColor.withValues(alpha: 0.25),
        context: context,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: AppTheme.recyclerColor, size: 20),
              const SizedBox(width: 8),
              Text('CPCB Formal Authorization Roster',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.getTextPrimary(context))),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Authorized for Dismantling & Segregation: ITEW1 (Cellphones, Tablets), PCB High-Grade, Battery Waste, CRT / Flat Panel Displays.',
            style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context), height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('State Auth: TN-PCB-COIMBATORE-HUB-01', style: TextStyle(fontSize: 11, color: AppTheme.recyclerColor, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String filterKey, String label) {
    final isSelected = _selectedCategoryFilter == filterKey;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: AppTheme.recyclerColor.withValues(alpha: 0.2),
      backgroundColor: AppTheme.isDark(context) ? AppTheme.surfaceDark : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected ? AppTheme.recyclerColor : AppTheme.getBorder(context),
        width: 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.recyclerColor : AppTheme.getTextSecondary(context),
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() => _selectedCategoryFilter = filterKey);
      },
    );
  }

  Widget _buildRecyclerLotCard(BuildContext context, LotModel lot) {
    final statusColor = lot.status == 'OPEN_FOR_BIDS'
        ? AppTheme.recyclerColor
        : (lot.status == 'BID_SELECTED' ? AppTheme.alertAmber : AppTheme.collectorColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardBoxDecoration(color: AppTheme.getCardBg(context), context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lot.lotCode, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.recyclerColor)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: AppTheme.pillBadgeDecoration(statusColor, context: context),
                child: Text(lot.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.isDark(context) ? AppTheme.surfaceDark : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${lot.category} • ${lot.subcategory}',
                    style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context), fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.isDark(context) ? AppTheme.surfaceDark : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${lot.estimatedWeightKg} kg (${lot.condition})',
                    style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Fair Valuation: ₹${lot.fairValueMin.toStringAsFixed(0)} – ₹${lot.fairValueMax.toStringAsFixed(0)}',
              style: const TextStyle(color: AppTheme.collectorColor, fontWeight: FontWeight.w800, fontSize: 13)),
          if (lot.recoveredMaterials != null && lot.recoveredMaterials!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🌿 Recovered Fractions (Recorded):',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF059669))),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: lot.recoveredMaterials!.entries.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${e.key}: ${e.value}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (lot.status == 'OPEN_FOR_BIDS')
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.recyclerColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(130, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.gavel_rounded, size: 16),
                  label: const Text('Place Reverse Bid', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  onPressed: () => _showBidDialog(lot),
                )
              else if (lot.status == 'BID_SELECTED' || lot.status == 'HANDOVER_SCHEDULED')
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4338CA),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.scale_rounded, size: 16),
                  label: const Text('Verify Scale & OTP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  onPressed: () => _showHandoverModal(lot),
                )
              else if (lot.status == 'RECEIVED')
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(150, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.construction_rounded, size: 16),
                  label: const Text('🔧 Start Processing', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await widget.apiService.markLotProcessing(lot.id);
                      await _fetchLots();
                      messenger.showSnackBar(
                        const SnackBar(backgroundColor: Color(0xFF065F46), content: Text('✅ Lot is now in PROCESSING.')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                )
              else if (lot.status == 'PROCESSING')
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(160, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.recycling_rounded, size: 16),
                  label: const Text('✅ Record Fractions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  onPressed: () => _showRecordRecoveryDialog(lot),
                )
              else if (lot.status == 'MATERIAL_RECOVERED')
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(130, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.lock_rounded, size: 16),
                  label: const Text('🔒 Close Lot', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await widget.apiService.closeLot(lot.id);
                      await _fetchLots();
                      messenger.showSnackBar(
                        const SnackBar(backgroundColor: Color(0xFF065F46), content: Text('🎉 Lot closed. Digital chain sealed.')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                )
              else if (lot.status == 'CLOSED')
                const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: AppTheme.collectorColor, size: 16),
                    SizedBox(width: 6),
                    Text('Fully Closed', style: TextStyle(color: AppTheme.collectorColor, fontWeight: FontWeight.w800, fontSize: 12)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Performance Reputation Card ────────────────────────────────────────────

  Widget _buildPerformanceCard() {
    final stats = _recyclerStats;
    final totalBids = (stats?['total_bids_submitted'] as num?)?.toInt() ?? 0;
    final wonLots = (stats?['won_lots'] as num?)?.toInt() ?? 0;
    final completionRate = (stats?['completion_rate_pct'] as num?)?.toDouble() ?? 0.0;
    final kgProcessed = (stats?['total_kg_processed'] as num?)?.toDouble() ?? 0.0;
    final reliability = (stats?['reliability_score'] as num?)?.toDouble() ?? 96.0;
    final settleDays = (stats?['avg_settlement_days'] as num?)?.toDouble() ?? 2.3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: AppTheme.recyclerColor.withValues(alpha: 0.3),
        context: context,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.recyclerColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.leaderboard_rounded, color: AppTheme.recyclerColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text('📊 Performance Reputation',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.getTextPrimary(context))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: AppTheme.pillBadgeDecoration(AppTheme.recyclerColor, context: context),
                child: Text('${reliability.toStringAsFixed(0)}% Reliable',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.recyclerColor)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _recyclerStat('Bids', '$totalBids', AppTheme.recyclerColor),
              const SizedBox(width: 8),
              _recyclerStat('Won Lots', '$wonLots', AppTheme.collectorColor),
              const SizedBox(width: 8),
              _recyclerStat('Completion', '${completionRate.toStringAsFixed(0)}%', const Color(0xFF059669)),
              const SizedBox(width: 8),
              _recyclerStat('Processed', '${kgProcessed.toStringAsFixed(0)} kg', Colors.amber.shade700),
              const SizedBox(width: 8),
              _recyclerStat('Settle Days', '${settleDays.toStringAsFixed(1)}d', const Color(0xFF6366F1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recyclerStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ─── My Bids Section ────────────────────────────────────────────────────────

  Widget _buildMyBidsSection() {
    return Container(
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: Colors.amber.withValues(alpha: 0.3),
        context: context,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showMyBids = !_showMyBids),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.gavel_rounded, color: Colors.amber, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Bids & Active Lots',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.getTextPrimary(context))),
                        Text('${_myBids.length} bids submitted',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(_showMyBids ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          if (_showMyBids) ...[
            if (_myBids.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text('No bids submitted yet. Browse the marketplace to bid on lots.',
                    style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12)),
              )
            else
              ..._myBids.map((bid) => _buildMyBidTile(bid)),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildMyBidTile(Map<String, dynamic> bid) {
    final status = bid['bid_status'] as String? ?? 'SUBMITTED';
    final statusColor = status == 'ACCEPTED'
        ? AppTheme.collectorColor
        : status == 'REJECTED'
            ? AppTheme.alertRed
            : Colors.amber.shade700;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bid['lot_code'] as String? ?? '—',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.getTextPrimary(context))),
                Text('${bid['lot_category'] ?? ''} • ${bid['lot_weight_kg'] ?? 0} kg',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${((bid['offer_price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: statusColor)),
              Text('Match: ${(bid['match_score'] as num?)?.toStringAsFixed(0) ?? '—'}/100',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(status,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

