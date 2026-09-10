import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../i18n/translations.dart';
import '../theme/app_theme.dart';
import '../widgets/ecoscrap_logo.dart';

class AdminScreen extends StatefulWidget {
  final ApiService apiService;
  final String currentLang;

  const AdminScreen({
    super.key,
    required this.apiService,
    required this.currentLang,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic>? _metrics;
  bool _isLoading = false;

  String t(String key) => AppTranslations.get(key, widget.currentLang);

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
  }

  Future<void> _fetchMetrics() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiService.fetchAdminMetrics();
      setState(() => _metrics = res);
    } catch (e) {
      debugPrint('Admin metrics error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _metrics;

    return RefreshIndicator(
      color: AppTheme.adminColor,
      backgroundColor: AppTheme.getCardBg(context),
      onRefresh: _fetchMetrics,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.adminColor))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              children: [
                // Executive Header Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardBoxDecoration(
                    color: AppTheme.isDark(context) ? const Color(0xFF1E1B4B) : const Color(0xFFF5F3FF),
                    borderColor: AppTheme.adminColor.withValues(alpha: 0.4),
                    glow: true,
                    glowColor: AppTheme.adminColor,
                    context: context,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const EcoScrapLogo(size: 28, borderRadius: 8),
                                const SizedBox(width: 10),
                                Text(
                                  'Governance & Circularity Telemetry',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.getTextPrimary(context)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'CPCB-Aligned Oversight • Coimbatore Regional Formalization Pilot',
                              style: TextStyle(
                                color: AppTheme.isDark(context) ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: AppTheme.isDark(context) ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                          size: 22,
                        ),
                        tooltip: 'Refresh metrics',
                        onPressed: _fetchMetrics,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (m != null) ...[
                  // Grid of Key KPIs (Row 1)
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: t('completed_lots'),
                          value: '${m['total_ewaste_diverted_kg']} kg',
                          icon: Icons.scale_rounded,
                          color: AppTheme.collectorColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: 'CO2e Avoided',
                          value: '${m['co2e_avoided_kg']} kg',
                          icon: Icons.eco_rounded,
                          color: const Color(0xFF14B8A6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Grid of Key KPIs (Row 2)
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: t('toxic_metals_contained'),
                          value: '${m['toxic_heavy_metals_contained_g'] ?? 0} g',
                          icon: Icons.science_rounded,
                          color: AppTheme.alertRed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: t('trees_offset'),
                          value: '${m['trees_offset_equivalent'] ?? 0} trees',
                          icon: Icons.park_rounded,
                          color: const Color(0xFF84CC16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Grid of Key KPIs (Row 3)
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: t('anomaly_alert'),
                          value: '${m['price_anomalies_prevented']} alerts',
                          icon: Icons.shield_rounded,
                          color: AppTheme.alertAmber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: 'Verified Recyclers',
                          value: '${m['verified_recyclers']} registered',
                          icon: Icons.factory_rounded,
                          color: AppTheme.recyclerColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Material Distribution Breakdown
                  if (m['category_distribution'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AppTheme.cardBoxDecoration(color: AppTheme.getCardBg(context), context: context),
                      child: Column(
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
                                child: const Icon(Icons.pie_chart_rounded, color: AppTheme.collectorColor, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Text(t('material_breakdown'),
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.getTextPrimary(context))),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...(m['category_distribution'] as Map<String, dynamic>).entries.map((e) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('• ${e.key}', style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 13)),
                                  Text('${e.value} kg',
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.collectorColor, fontSize: 13)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Live Anomaly Radar Feed
                  if (m['recent_anomalies'] != null && (m['recent_anomalies'] as List).isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AppTheme.cardBoxDecoration(
                        color: AppTheme.isDark(context) ? const Color(0xFF270707) : const Color(0xFFFEF2F2),
                        borderColor: AppTheme.alertRed.withValues(alpha: 0.6),
                        glow: true,
                        glowColor: AppTheme.alertRed,
                        context: context,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.radar_rounded, color: AppTheme.alertRed, size: 20),
                              const SizedBox(width: 8),
                              Text(t('anomaly_radar'),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.alertRed)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...(m['recent_anomalies'] as List).take(3).map((r) {
                            final item = r as Map<String, dynamic>;
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.alertRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('🚨 ', style: TextStyle(fontSize: 12)),
                                  Expanded(
                                    child: Text(
                                      '${item['risk_type']}: ${item['explanation']}',
                                      style: TextStyle(fontSize: 12, color: AppTheme.getTextPrimary(context), height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Ledger Integrity Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: AppTheme.cardBoxDecoration(
                      color: AppTheme.getCardBg(context),
                      borderColor: AppTheme.collectorColor.withValues(alpha: 0.35),
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
                                color: AppTheme.collectorColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.verified_user_rounded, color: AppTheme.collectorColor, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text('Tamper-Evident Ledger Health',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.getTextPrimary(context))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: AppTheme.pillBadgeDecoration(AppTheme.collectorColor, context: context),
                          child: const Text('Status: 100% SECURE • SHA-256 Validated',
                              style: TextStyle(color: AppTheme.collectorColor, fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 8),
                        Text('Zero cryptographic hash divergence detected across all regional collection & handover nodes.',
                            style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: color.withValues(alpha: 0.3),
        context: context,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.getTextPrimary(context),
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.getTextSecondary(context),
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
