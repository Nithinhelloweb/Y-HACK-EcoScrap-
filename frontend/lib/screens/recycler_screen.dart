import 'package:flutter/material.dart';
import '../models/lot_model.dart';
import '../services/api_service.dart';
import '../i18n/translations.dart';

class RecyclerScreen extends StatefulWidget {
  final ApiService apiService;
  final String currentLang;

  const RecyclerScreen({
    super.key,
    required this.apiService,
    required this.currentLang,
  });

  @override
  State<RecyclerScreen> createState() => _RecyclerScreenState();
}

class _RecyclerScreenState extends State<RecyclerScreen> {
  List<LotModel> _lots = [];
  bool _isLoading = false;
  String _selectedCategoryFilter = 'ALL';

  final _otpController = TextEditingController();
  final _scaleWeightController = TextEditingController();

  String t(String key) => AppTranslations.get(key, widget.currentLang);

  @override
  void initState() {
    super.initState();
    _fetchLots();
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
    return _lots.where((l) => l.category == _selectedCategoryFilter).toList();
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
              title: Text('Submit Bid for ${lot.lotCode}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Category: ${lot.category} (${lot.estimatedWeightKg} kg)'),
                  Text('Fair Range: ₹${lot.fairValueMin.toStringAsFixed(0)} – ₹${lot.fairValueMax.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightGreenAccent)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: offerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Offer Price (INR)', border: OutlineInputBorder()),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: deductionController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Logistics Deduction (INR)', border: OutlineInputBorder()),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Net Collector Payable:', style: TextStyle(fontSize: 12)),
                        Text('₹${netPayable.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.tealAccent)),
                      ],
                    ),
                  ),
                  if (isBelowFloor) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF450A0A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '🚨 WARNING: This offer is 25%+ below the fair minimum. It will be flagged by the EcoScrap Anomaly Shield.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
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
                            backgroundColor: Colors.red.shade900,
                            content: Text('⚠️ ANOMALY ALERT: ${bid.anomalyReason}'),
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.green.shade800,
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
                  child: const Text('Submit Bid'),
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
              Text('${t('handover_title')}: ${lot.lotCode}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Collector declared weight: ${lot.estimatedWeightKg} kg', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: t('enter_otp'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.pin),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _scaleWeightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: t('verified_scale'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.scale),
                  suffixText: 'kg',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                  icon: const Icon(Icons.verified),
                  label: Text(t('confirm_handover'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          backgroundColor: res['flagged_anomaly'] == true ? Colors.orange.shade900 : Colors.green.shade800,
                          content: Text(res['message'] ?? 'Handover complete!'),
                        ),
                      );
                      _fetchLots();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: Colors.red, content: Text('Handover verification failed: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('recycler_tab')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLots,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Recycler Info Header
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.factory_rounded, color: Colors.tealAccent, size: 40),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('GreenTech Circular Solutions Pvt Ltd', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('CPCB Reg: CPCB-TN-REC-2024-8812 • SIDCO Estate', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              SizedBox(height: 4),
                              Text('⭐ 96% Reliability Rating • Daily Cap: 2,500 kg', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Material Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All Materials'),
                      const SizedBox(width: 8),
                      _buildFilterChip('PCB', 'Circuit Boards (PCB)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('BATTERY', 'Batteries (Haz)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('CABLE', 'Copper Cables'),
                      const SizedBox(width: 8),
                      _buildFilterChip('IT_EQUIPMENT', 'IT Scrap'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text('Active E-Waste Lots (${_filteredLots.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                if (_filteredLots.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('No active lots matching this filter.'))),

                ..._filteredLots.map((lot) => _buildRecyclerLotCard(lot)),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedCategoryFilter == filterKey;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: Colors.teal.shade800,
      onSelected: (_) {
        setState(() => _selectedCategoryFilter = filterKey);
      },
    );
  }

  Widget _buildRecyclerLotCard(LotModel lot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lot.lotCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.tealAccent)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade900,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(lot.status, style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Material: ${lot.category} • ${lot.subcategory}'),
            Text('Estimated Weight: ${lot.estimatedWeightKg} kg • Condition: ${lot.condition}'),
            Text('Fair Range: ₹${lot.fairValueMin.toStringAsFixed(0)} – ₹${lot.fairValueMax.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.lightGreenAccent, fontWeight: FontWeight.bold)),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (lot.status == 'OPEN_FOR_BIDS')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    icon: const Icon(Icons.gavel, size: 16),
                    label: const Text('Place Reverse Bid'),
                    onPressed: () => _showBidDialog(lot),
                  )
                else if (lot.status == 'BID_SELECTED' || lot.status == 'HANDOVER_SCHEDULED')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                    icon: const Icon(Icons.scale, size: 16),
                    label: const Text('Verify Scale & OTP'),
                    onPressed: () => _showHandoverModal(lot),
                  )
                else if (lot.status == 'RECEIVED')
                  const Text('✅ Received & Verified at Scale', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
