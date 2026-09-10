import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../i18n/translations.dart';
import '../theme/app_theme.dart';
import '../widgets/ecoscrap_logo.dart';

class AdminScreen extends StatefulWidget {
  final ApiService apiService;
  final String currentLang;
  final int initialTab;

  const AdminScreen({
    super.key,
    required this.apiService,
    required this.currentLang,
    this.initialTab = 0,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  Map<String, dynamic>? _metrics;
  List<Map<String, dynamic>> _collectors = [];
  List<Map<String, dynamic>> _recyclers = [];
  Map<String, dynamic>? _marketTrends;
  Map<String, dynamic>? _envSummary;
  Map<String, dynamic>? _fraudAlerts;
  bool _isLoading = false;

  String t(String key) => AppTranslations.get(key, widget.currentLang);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _loadAll();
  }

  @override
  void didUpdateWidget(AdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab && widget.initialTab < 4) {
      _tabController.animateTo(widget.initialTab.clamp(0, 3));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        widget.apiService.fetchAdminMetrics().catchError((_) => <String, dynamic>{}),
        widget.apiService.fetchAdminCollectors().catchError((_) => <Map<String, dynamic>>[]),
        widget.apiService.fetchAdminRecyclers().catchError((_) => <Map<String, dynamic>>[]),
        widget.apiService.fetchMarketTrends().catchError((_) => <String, dynamic>{}),
        widget.apiService.fetchEnvironmentalSummary().catchError((_) => <String, dynamic>{}),
        widget.apiService.fetchFraudAlerts().catchError((_) => <String, dynamic>{}),
      ]);
      if (mounted) {
        setState(() {
          _metrics = results[0] as Map<String, dynamic>?;
          _collectors = (results[1] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _recyclers = (results[2] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _marketTrends = results[3] as Map<String, dynamic>?;
          _envSummary = results[4] as Map<String, dynamic>?;
          _fraudAlerts = results[5] as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      debugPrint('Admin load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Executive Header Banner ────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardBoxDecoration(
            color: AppTheme.isDark(context) ? const Color(0xFF1E1B4B) : const Color(0xFFF5F3FF),
            borderColor: AppTheme.adminColor.withValues(alpha: 0.4),
            glow: true,
            glowColor: AppTheme.adminColor,
            context: context,
          ),
          child: Row(
            children: [
              const EcoScrapLogo(size: 28, borderRadius: 8),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🛡 Governance & Circularity Telemetry',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.getTextPrimary(context))),
                    const SizedBox(height: 2),
                    Text('CPCB-Aligned Oversight • Coimbatore Regional Pilot',
                        style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.adminColor, size: 22),
                tooltip: 'Refresh all',
                onPressed: _loadAll,
              ),
            ],
          ),
        ),

        // ── Tab Bar ───────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          decoration: BoxDecoration(
            color: AppTheme.getCardBg(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.getBorder(context)),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AppTheme.adminColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.adminColor.withValues(alpha: 0.5)),
            ),
            labelColor: AppTheme.adminColor,
            unselectedLabelColor: AppTheme.getTextSecondary(context),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            tabs: const [
              Tab(text: 'Overview', icon: Icon(Icons.dashboard_rounded, size: 16)),
              Tab(text: 'Users', icon: Icon(Icons.people_alt_rounded, size: 16)),
              Tab(text: 'Market Intel', icon: Icon(Icons.trending_up_rounded, size: 16)),
              Tab(text: 'Ecosystem', icon: Icon(Icons.eco_rounded, size: 16)),
            ],
          ),
        ),

        // ── Tab Views ─────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.adminColor))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildUsersTab(),
                    _buildMarketIntelTab(),
                    _buildEcosystemTab(),
                  ],
                ),
        ),
      ],
    );
  }

  // ─── TAB 1: Overview (existing KPIs + fraud alerts) ────────────────────────

  Widget _buildOverviewTab() {
    final m = _metrics;
    final alerts = (_fraudAlerts?['alerts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return RefreshIndicator(
      color: AppTheme.adminColor,
      backgroundColor: AppTheme.getCardBg(context),
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        children: [
          // KPI Cards
          if (m != null) ...[
            Row(
              children: [
                Expanded(child: _buildKpiCard('Total Lots', '${m['total_lots'] ?? 0}', Icons.inventory_2_rounded, AppTheme.collectorColor)),
                const SizedBox(width: 10),
                Expanded(child: _buildKpiCard('Active Collectors', '${m['total_collectors'] ?? 0}', Icons.person_rounded, const Color(0xFF0891B2))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildKpiCard('Total Kg Tracked', '${((m['total_kg_tracked'] as num?)?.toStringAsFixed(0) ?? 0)}', Icons.scale_rounded, AppTheme.adminColor)),
                const SizedBox(width: 10),
                Expanded(child: _buildKpiCard('Verified Recyclers', '${m['total_recyclers'] ?? 0}', Icons.verified_rounded, const Color(0xFF059669))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildKpiCard('Avg Trust Score', (m['avg_trust_score'] as num?)?.toStringAsFixed(1) ?? '—', Icons.star_rounded, Colors.amber.shade700)),
                const SizedBox(width: 10),
                Expanded(child: _buildKpiCard('Anomaly Rate', '${(m['anomaly_rate'] as num?)?.toStringAsFixed(1) ?? '0'}%', Icons.warning_rounded, AppTheme.alertRed)),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Fraud & Risk Alerts
          _buildSectionHeader('⚠️ Fraud & Risk Alerts', '${alerts.length} active', AppTheme.alertRed),
          const SizedBox(height: 8),
          if (alerts.isEmpty)
            _buildEmptyState('No active fraud alerts. All transactions within normal parameters.', Icons.shield_rounded)
          else
            ...alerts.map((alert) => _buildAlertTile(alert)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── TAB 2: Users ──────────────────────────────────────────────────────────

  Widget _buildUsersTab() {
    return RefreshIndicator(
      color: AppTheme.adminColor,
      backgroundColor: AppTheme.getCardBg(context),
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        children: [
          _buildSectionHeader('👷 Collectors (${_collectors.length})', 'Tap to verify / revoke', const Color(0xFF0891B2)),
          const SizedBox(height: 8),
          if (_collectors.isEmpty)
            _buildEmptyState('No collectors registered yet.', Icons.person_search_rounded)
          else
            ..._collectors.map((c) => _buildUserTile(c, 'COLLECTOR')),
          const SizedBox(height: 16),
          _buildSectionHeader('🏭 Recyclers (${_recyclers.length})', 'CPCB Authorized Dismantlers', const Color(0xFF059669)),
          const SizedBox(height: 8),
          if (_recyclers.isEmpty)
            _buildEmptyState('No recyclers registered yet.', Icons.factory_rounded)
          else
            ..._recyclers.map((r) => _buildUserTile(r, 'RECYCLER')),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, String role) {
    final isVerified = user['is_verified'] as bool? ?? false;
    final roleColor = role == 'COLLECTOR' ? const Color(0xFF0891B2) : const Color(0xFF059669);
    final name = user['name'] as String? ?? user['org_name'] as String? ?? '—';
    final trust = (user['trust_score'] as num?)?.toStringAsFixed(1) ??
        (user['reliability_score'] as num?)?.toStringAsFixed(1) ??
        '—';
    final lotsOrBids = '${(user['total_lots'] as num?)?.toInt() ?? (user['total_bids'] as num?)?.toInt() ?? 0}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: roleColor.withValues(alpha: 0.2),
        context: context,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              role == 'COLLECTOR' ? Icons.person_rounded : Icons.factory_rounded,
              color: roleColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.getTextPrimary(context))),
                Row(
                  children: [
                    Text('${role == 'COLLECTOR' ? 'Trust' : 'Reliability'}: $trust • ${role == 'COLLECTOR' ? 'Lots' : 'Bids'}: $lotsOrBids',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      const Text('✅', style: TextStyle(fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isVerified ? AppTheme.alertRed : const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () async {
              try {
                final userId = user['user_id'] as String? ?? user['id'] as String? ?? '';
                await widget.apiService.verifyUser(userId, !isVerified);
                await _loadAll();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF065F46),
                      content: Text('${isVerified ? 'Revoked' : 'Verified'}: $name'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(isVerified ? 'Revoke' : 'Verify',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ─── TAB 3: Market Intelligence ────────────────────────────────────────────

  Widget _buildMarketIntelTab() {
    final trends = (_marketTrends?['trends'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return RefreshIndicator(
      color: AppTheme.adminColor,
      backgroundColor: AppTheme.getCardBg(context),
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        children: [
          _buildSectionHeader('📈 Material Price Intelligence', 'Market-rate pricing insights', AppTheme.adminColor),
          const SizedBox(height: 8),
          if (trends.isEmpty)
            _buildEmptyState('No pricing trend data available yet.', Icons.trending_up_rounded)
          else
            ...trends.map((item) => _buildTrendTile(item)),
          const SizedBox(height: 16),

          // Summary stats from market trends
          if (_marketTrends != null) ...[
            _buildSectionHeader('🔖 Period Summary', 'Last 30 days', AppTheme.adminColor),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardBoxDecoration(
                color: AppTheme.getCardBg(context),
                borderColor: AppTheme.adminColor.withValues(alpha: 0.2),
                context: context,
              ),
              child: Column(
                children: [
                  _marketSummaryRow('Total Lots in Period', '${_marketTrends!['total_lots'] ?? '—'}'),
                  _marketSummaryRow('Average Offer (₹/kg)', '₹${(_marketTrends!['avg_price_per_kg'] as num?)?.toStringAsFixed(0) ?? '—'}'),
                  _marketSummaryRow('Avg Bid Match Score', '${(_marketTrends!['avg_match_score'] as num?)?.toStringAsFixed(1) ?? '—'}/100'),
                  _marketSummaryRow('Anomalous Bids', '${_marketTrends!['anomaly_count'] ?? 0}'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendTile(Map<String, dynamic> item) {
    final category = item['category'] as String? ?? '—';
    final minPrice = (item['price_min'] as num?)?.toDouble() ?? 0.0;
    final maxPrice = (item['price_max'] as num?)?.toDouble() ?? 0.0;
    final avgPrice = (item['price_avg'] as num?)?.toDouble() ?? 0.0;
    final lotCount = (item['lot_count'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: AppTheme.adminColor.withValues(alpha: 0.2),
        context: context,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.adminColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.category_rounded, color: AppTheme.adminColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.getTextPrimary(context))),
                Text('$lotCount lots • ₹${minPrice.toStringAsFixed(0)} – ₹${maxPrice.toStringAsFixed(0)} / lot',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text('₹${avgPrice.toStringAsFixed(0)}\navg',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.adminColor),
              textAlign: TextAlign.right),
        ],
      ),
    );
  }

  Widget _marketSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.getTextPrimary(context))),
        ],
      ),
    );
  }

  // ─── TAB 4: Ecosystem (Environmental Intelligence) ─────────────────────────

  Widget _buildEcosystemTab() {
    final env = _envSummary;

    return RefreshIndicator(
      color: AppTheme.adminColor,
      backgroundColor: AppTheme.getCardBg(context),
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        children: [
          _buildSectionHeader('🌿 Environmental Intelligence', 'CPCB Traceability & Impact', const Color(0xFF059669)),
          const SizedBox(height: 10),
          if (env == null)
            _buildEmptyState('No environmental summary available yet.', Icons.eco_rounded)
          else ...[
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    'Total Kg Recovered',
                    '${((env['total_kg_recovered'] as num?)?.toStringAsFixed(1) ?? 0)} kg',
                    Icons.scale_rounded,
                    const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    'CO₂ Saved',
                    '${((env['co2_equivalent_kg_saved'] as num?)?.toStringAsFixed(1) ?? 0)} kg',
                    Icons.cloud_off_rounded,
                    AppTheme.adminColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    'Lots Closed',
                    '${(env['closed_lots'] as num?)?.toInt() ?? 0}',
                    Icons.check_circle_outline_rounded,
                    AppTheme.collectorColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    'Hazardous Avg',
                    '${((env['avg_hazardous_materials_g_per_lot'] as num?)?.toStringAsFixed(1) ?? 0)} g/lot',
                    Icons.warning_amber_rounded,
                    AppTheme.alertAmber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Material breakdown
            _buildSectionHeader('🔬 Heavy Metal Recovery Estimates', 'Per-category', const Color(0xFF059669)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardBoxDecoration(
                color: AppTheme.getCardBg(context),
                borderColor: const Color(0xFF059669).withValues(alpha: 0.2),
                context: context,
              ),
              child: Column(
                children: [
                  _envMaterialRow('♻️ Materials Diverted', '${((env['total_kg_recovered'] as num?)?.toStringAsFixed(1) ?? 0)} kg', const Color(0xFF059669)),
                  _envMaterialRow('⚗️ Hazardous Managed', '${((env['avg_hazardous_materials_g_per_lot'] as num?)?.toStringAsFixed(1) ?? 0)} g/lot avg', AppTheme.alertAmber),
                  _envMaterialRow('🌍 Carbon Benefit', '${((env['co2_equivalent_kg_saved'] as num?)?.toStringAsFixed(2) ?? 0)} kg CO₂e', AppTheme.adminColor),
                ],
              ),
            ),
          ],

          // Recycler roster from _recyclers
          const SizedBox(height: 16),
          _buildSectionHeader('🏭 Active Recycler Roster', '${_recyclers.length} CPCB-authorized', const Color(0xFF059669)),
          const SizedBox(height: 8),
          if (_recyclers.isEmpty)
            _buildEmptyState('No registered recyclers yet.', Icons.factory_rounded)
          else
            ..._recyclers.map((r) => _buildRecyclerRosterTile(r)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _envMaterialRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _buildRecyclerRosterTile(Map<String, dynamic> r) {
    final name = r['org_name'] as String? ?? '—';
    final regNo = r['registration_no'] as String? ?? '—';
    final reliability = (r['reliability_score'] as num?)?.toStringAsFixed(0) ?? '—';
    final materials = (r['accepted_materials'] as List?)?.cast<String>().take(3).join(', ') ?? '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: const Color(0xFF059669).withValues(alpha: 0.2),
        context: context,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.factory_rounded, color: Color(0xFF059669), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.getTextPrimary(context))),
                Text('Reg: $regNo', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                Text('$reliability% Reliability • $materials', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared Helpers ─────────────────────────────────────────────────────────

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: color.withValues(alpha: 0.25),
        context: context,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color)),
                Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.getTextPrimary(context))),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardBoxDecoration(color: AppTheme.getCardBg(context), context: context),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppTheme.getTextSecondary(context)),
          const SizedBox(height: 10),
          Text(message,
              style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildAlertTile(Map<String, dynamic> alert) {
    final severity = alert['severity'] as String? ?? 'LOW';
    final color = severity == 'HIGH'
        ? AppTheme.alertRed
        : severity == 'MEDIUM'
            ? AppTheme.alertAmber
            : Colors.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(alert['alert_type'] as String? ?? 'ALERT',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(5)),
                      child: Text(severity, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(alert['description'] as String? ?? '—',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if ((alert['lot_code'] as String?) != null)
                  Text('Lot: ${alert['lot_code']}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
