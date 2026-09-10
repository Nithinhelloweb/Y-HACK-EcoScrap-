import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../i18n/translations.dart';
import '../theme/app_theme.dart';
import '../widgets/ecoscrap_logo.dart';

class PassportScreen extends StatefulWidget {
  final ApiService apiService;
  final String currentLang;

  const PassportScreen({
    super.key,
    required this.apiService,
    required this.currentLang,
  });

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  final _searchController = TextEditingController(text: 'EW-TN-2026-000184');
  Map<String, dynamic>? _passportData;
  bool _isLoading = false;
  String? _errorMessage;

  String t(String key) => AppTranslations.get(key, widget.currentLang);

  @override
  void initState() {
    super.initState();
    _fetchPassport();
  }

  Future<void> _fetchPassport() async {
    final code = _searchController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await widget.apiService.fetchPassport(code);
      if (!mounted) return;
      setState(() {
        _passportData = res;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load passport: $e';
        _passportData = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRed,
          content: Text('Could not load passport: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _passportData;

    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      backgroundColor: AppTheme.getCardBg(context),
      onRefresh: _fetchPassport,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        children: [
          // Search & Trace Header Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardBoxDecoration(color: AppTheme.getCardBg(context), context: context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryGreen, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text('Digital E-Waste Passport Lookup',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.getTextPrimary(context))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: AppTheme.getTextPrimary(context)),
                        decoration: const InputDecoration(
                          hintText: 'Enter Lot Code (e.g. EW-TN-2026-000184)',
                          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
                        ),
                        onSubmitted: (_) => _fetchPassport(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(84, 48),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _fetchPassport,
                      child: const Text('Trace', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Quick preset chip for demo
                Row(
                  children: [
                    Text('Sample Lot:', style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context), fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        _searchController.text = 'EW-TN-2026-000184';
                        _fetchPassport();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'EW-TN-2026-000184',
                          style: TextStyle(fontSize: 11, color: AppTheme.primaryGreen, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
            )
          else if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.alertRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.alertRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.alertRed, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            )
          else if (data != null) ...[
            // Main Passport Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardBoxDecoration(
                color: AppTheme.getCardBg(context),
                borderColor: AppTheme.primaryGreen.withValues(alpha: 0.35),
                glow: true,
                glowColor: AppTheme.primaryGreen,
                context: context,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const EcoScrapLogo(size: 26, borderRadius: 6),
                          const SizedBox(width: 8),
                          const Text(
                            'DIGITAL E-WASTE PASSPORT',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.2,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: AppTheme.pillBadgeDecoration(AppTheme.primaryGreen, context: context),
                        child: const Text('CPCB Traceable',
                            style: TextStyle(color: AppTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data['lot_code'] ?? '',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.getTextPrimary(context), letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.isDark(context) ? AppTheme.surfaceDark : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${data['category']} • ${data['subcategory']}',
                            style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Collector: ${data['collector_code']} • Recycler: ${data['verified_recycler_name']}',
                      style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    'Weight: ${data['verified_weight_kg'] ?? data['estimated_weight_kg']} kg (${data['verified_weight_kg'] != null ? "Dual-Weight Scale Verified" : "Collector Declared"})',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryGreen, fontSize: 13),
                  ),
                  const Divider(height: 24),

                  // Ledger Hash Integrity Status
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (data['ledger_integrity_valid'] == true)
                          ? AppTheme.primaryGreen.withValues(alpha: 0.12)
                          : AppTheme.alertRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (data['ledger_integrity_valid'] == true)
                            ? AppTheme.primaryGreen.withValues(alpha: 0.5)
                            : AppTheme.alertRed.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (data['ledger_integrity_valid'] == true) ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                          color: (data['ledger_integrity_valid'] == true) ? AppTheme.primaryGreen : AppTheme.alertRed,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (data['ledger_integrity_valid'] == true)
                                    ? t('chain_valid')
                                    : '🚨 WARNING: Tampered Hash Detected!',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: (data['ledger_integrity_valid'] == true) ? AppTheme.primaryGreen : AppTheme.alertRed,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (data['ledger_integrity_valid'] == true)
                                    ? 'All blocks in the chain match expected SHA-256 cryptographic signatures.'
                                    : 'State verification failed: Block hash does not match previous block hash.',
                                style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Circular Material Recovery Breakdown
            _buildCircularityCard(context, data),
            const SizedBox(height: 14),

            // Environmental Impact Metrics
            _buildImpactCard(context, data),
            const SizedBox(height: 16),

            // Tamper-Evident SHA-256 Ledger Timeline
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.link_rounded, color: AppTheme.primaryGreen, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tamper-Evident Cryptographic Ledger',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.getTextPrimary(context)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...((data['events_timeline'] as List? ?? []).map((ev) => _buildLedgerBlock(context, ev))),
          ],
        ],
      ),
    );
  }

  Widget _buildCircularityCard(BuildContext context, Map<String, dynamic> data) {
    final fractions = data['recovered_fractions_estimate'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardBoxDecoration(color: AppTheme.getCardBg(context), context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const EcoScrapLogo(size: 24, borderRadius: 6),
              const SizedBox(width: 10),
              Text('Circular Material Recovery Potential',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.getTextPrimary(context))),
            ],
          ),
          const SizedBox(height: 12),
          ...fractions.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('• ${e.key.replaceAll('_', ' ').toUpperCase()}',
                        style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${e.value} kg',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryGreen, fontSize: 12)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildImpactCard(BuildContext context, Map<String, dynamic> data) {
    final env = data['environmental_savings'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.isDark(context) ? const Color(0xFF042F2E) : const Color(0xFFECFDF5),
        borderColor: AppTheme.primaryGreen.withValues(alpha: 0.4),
        context: context,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.eco_rounded, color: AppTheme.primaryGreen, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Environmental Impact & Carbon Offset',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.getTextPrimary(context))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricCol(context, 'CO2e Avoided', '${env['co2e_avoided_kg'] ?? 0} kg', Icons.cloud_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricCol(context, 'Toxics Contained', '${env['toxic_heavy_metals_contained_g'] ?? 0} g', Icons.security_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricCol(context, 'Trees Offset', '${env['trees_offset_equivalent'] ?? 0}', Icons.park_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 24),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.getTextPrimary(context)),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context), fontWeight: FontWeight.w600, height: 1.2),
        ),
      ],
    );
  }

  Widget _buildLedgerBlock(BuildContext context, dynamic ev) {
    final prev = (ev['previous_hash'] as String? ?? '').length >= 16
        ? (ev['previous_hash'] as String).substring(0, 16)
        : (ev['previous_hash'] ?? '');
    final curr = (ev['current_hash'] as String? ?? '').length >= 16
        ? (ev['current_hash'] as String).substring(0, 16)
        : (ev['current_hash'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardBoxDecoration(color: AppTheme.getCardBg(context), context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Block: ${ev['event_type']}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primaryGreen)),
              const Icon(Icons.link_rounded, size: 18, color: AppTheme.primaryGreen),
            ],
          ),
          const SizedBox(height: 6),
          Text('Prev Hash: $prev...', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.getTextSecondary(context))),
          Text('Block Hash: $curr...', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.primaryGreen)),
        ],
      ),
    );
  }
}
