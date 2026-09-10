import 'package:flutter/material.dart';
import '../models/lot_model.dart';
import '../services/api_service.dart';
import '../i18n/translations.dart';
import '../theme/app_theme.dart';
import '../widgets/ecoscrap_logo.dart';

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

  @override
  Widget build(BuildContext context) {
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
                Container(
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
                ),
                const SizedBox(height: 14),

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
                const SizedBox(height: 16),

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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.getTextPrimary(context))),
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
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppTheme.collectorColor, size: 16),
                    SizedBox(width: 6),
                    Text('Received & Scale Verified',
                        style: TextStyle(color: AppTheme.collectorColor, fontWeight: FontWeight.w800, fontSize: 12)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
