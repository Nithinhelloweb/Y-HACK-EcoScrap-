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
  List<Map<String, dynamic>> _disputes = [];
  String _disputeFilter = 'ALL';
  Map<String, dynamic>? _geoData;
  Map<String, dynamic>? _integrationsData;
  List<Map<String, dynamic>> _auditLogs = [];

  // Duplicate lot check state
  final _dupCategoryCtrl = TextEditingController(text: 'ITEW');
  final _dupWeightCtrl = TextEditingController(text: '12.5');
  final _dupPriceCtrl = TextEditingController(text: '1200.0');
  final _dupCollectorCtrl = TextEditingController(text: 'COL-DEMO-01');
  bool _isCheckingDuplicate = false;
  Map<String, dynamic>? _dupCheckResult;
  bool _isLoading = false;

  String t(String key) => AppTranslations.get(key, widget.currentLang);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 5),
    );
    _loadAll();
  }

  @override
  void didUpdateWidget(AdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab && widget.initialTab < 6) {
      _tabController.animateTo(widget.initialTab.clamp(0, 5));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dupCategoryCtrl.dispose();
    _dupWeightCtrl.dispose();
    _dupPriceCtrl.dispose();
    _dupCollectorCtrl.dispose();
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
        widget.apiService.fetchDisputes().catchError((_) => <Map<String, dynamic>>[]),
        widget.apiService.fetchGeographicIntelligence().catchError((_) => <String, dynamic>{}),
        widget.apiService.fetchIntegrations().catchError((_) => <String, dynamic>{}),
        widget.apiService.fetchAuditLogs().catchError((_) => <String, dynamic>{}),
      ]);
      if (mounted) {
        setState(() {
          _metrics = results[0] as Map<String, dynamic>?;
          _collectors = (results[1] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _recyclers = (results[2] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _marketTrends = results[3] as Map<String, dynamic>?;
          _envSummary = results[4] as Map<String, dynamic>?;
          _fraudAlerts = results[5] as Map<String, dynamic>?;
          _disputes = (results[6] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _geoData = results[7] as Map<String, dynamic>?;
          _integrationsData = results[8] as Map<String, dynamic>?;
          _auditLogs = ((results[9] as Map<String, dynamic>?)?['logs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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
              Tab(text: 'Disputes', icon: Icon(Icons.gavel_rounded, size: 16)),
              Tab(text: 'Geo Hub', icon: Icon(Icons.hub_rounded, size: 16)),
              Tab(text: 'Market', icon: Icon(Icons.trending_up_rounded, size: 16)),
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
                    _buildDisputesTab(),
                    _buildGeoIntegrationsTab(),
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

  // ─── TAB 3: Disputes Queue ──────────────────────────────────────────────────

  Widget _buildDisputesTab() {
    final filtered = _disputes.where((d) {
      if (_disputeFilter == 'ALL') return true;
      return (d['dispute_status'] as String? ?? '') == _disputeFilter;
    }).toList();

    return RefreshIndicator(
      color: AppTheme.adminColor,
      backgroundColor: AppTheme.getCardBg(context),
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        children: [
          _buildSectionHeader('⚖️ Disputes & Arbitration Triage', '${filtered.length} of ${_disputes.length} records', AppTheme.adminColor),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDisputeFilterChip('ALL', 'All Disputes (${_disputes.length})'),
                const SizedBox(width: 8),
                _buildDisputeFilterChip('OPEN', 'Open (${_disputes.where((d) => d['dispute_status'] == 'OPEN').length})'),
                const SizedBox(width: 8),
                _buildDisputeFilterChip('RESOLVED', 'Resolved (${_disputes.where((d) => d['dispute_status'] == 'RESOLVED').length})'),
                const SizedBox(width: 8),
                _buildDisputeFilterChip('ESCALATED_CPCB', 'Escalated CPCB'),
                const SizedBox(width: 8),
                _buildDisputeFilterChip('REJECTED', 'Dismissed'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            _buildEmptyState('No disputes found matching filter "$_disputeFilter".', Icons.gavel_rounded)
          else
            ...filtered.map((d) => _buildDisputeCard(d)),
        ],
      ),
    );
  }

  Widget _buildDisputeFilterChip(String key, String label) {
    final isSelected = _disputeFilter == key;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: AppTheme.adminColor.withValues(alpha: 0.2),
      backgroundColor: AppTheme.isDark(context) ? AppTheme.surfaceDark : const Color(0xFFF1F5F9),
      side: BorderSide(color: isSelected ? AppTheme.adminColor : AppTheme.getBorder(context)),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.adminColor : AppTheme.getTextSecondary(context),
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _disputeFilter = key),
    );
  }

  Widget _buildDisputeCard(Map<String, dynamic> d) {
    final status = d['dispute_status'] as String? ?? 'OPEN';
    final type = d['dispute_type'] as String? ?? 'OTHER';
    final disputeId = d['id'] as String? ?? '';
    final lotId = d['lot_id'] as String? ?? '—';
    final reason = d['reason'] as String? ?? '—';
    final raisedBy = d['raised_by_id'] as String? ?? '—';
    final against = d['against_party_id'] as String? ?? '—';
    final resolution = d['resolution_decision'] as String?;
    final notes = d['resolution_notes'] as String?;
    final adjustment = (d['settlement_adjustment_inr'] as num?)?.toDouble() ?? 0.0;

    final Color statusColor = status == 'RESOLVED'
        ? const Color(0xFF059669)
        : status == 'OPEN'
            ? AppTheme.alertAmber
            : (status == 'ESCALATED_CPCB' ? AppTheme.alertRed : Colors.grey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: statusColor.withValues(alpha: 0.35),
        context: context,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.gavel_rounded, color: statusColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dispute #${disputeId.substring(0, disputeId.length > 8 ? 8 : disputeId.length)}',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.getTextPrimary(context))),
                    Text('Lot: $lotId • Type: $type',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: AppTheme.pillBadgeDecoration(statusColor, context: context),
                child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.getSurface(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reason: $reason',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                const SizedBox(height: 4),
                Text('Raised by: $raisedBy • Against: $against',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (status == 'RESOLVED' && resolution != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                      const SizedBox(width: 6),
                      Text('Ruling: $resolution',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF059669))),
                      const Spacer(),
                      if (adjustment > 0)
                        Text('Adjustment: ₹${adjustment.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF059669))),
                    ],
                  ),
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Notes: $notes', style: const TextStyle(fontSize: 11, color: Color(0xFF065F46))),
                  ],
                ],
              ),
            ),
          ],
          if (status == 'OPEN') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.adminColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.balance_rounded, size: 16),
                label: const Text('Arbitrate Dispute', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                onPressed: () => _showResolveDisputeDialog(d),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showResolveDisputeDialog(Map<String, dynamic> dispute) {
    String selectedDecision = 'PARTIAL_SETTLEMENT';
    final notesCtrl = TextEditingController();
    final adjustmentCtrl = TextEditingController(text: '250.0');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppTheme.getCardBg(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.balance_rounded, color: AppTheme.adminColor),
                  const SizedBox(width: 8),
                  Text('Arbitrate Dispute',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.getTextPrimary(context))),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lot: ${dispute['lot_id']} • Reason: ${dispute['reason']}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 14),
                    const Text('Select Ruling Decision:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDecision,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                          value: 'PARTIAL_SETTLEMENT',
                          child: Text('Partial Settlement (Fair adjustment)'),
                        ),
                        DropdownMenuItem(
                          value: 'APPROVED_FOR_COLLECTOR',
                          child: Text('Rule in Collector Favor (Full Payout)'),
                        ),
                        DropdownMenuItem(
                          value: 'APPROVED_FOR_RECYCLER',
                          child: Text('Rule in Recycler Favor (Deduction valid)'),
                        ),
                        DropdownMenuItem(
                          value: 'DISMISSED',
                          child: Text('Dismiss Dispute (No grounds)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedDecision = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: adjustmentCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Settlement Adjustment (₹)',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Arbitration Notes & Ruling Basis',
                        prefixIcon: Icon(Icons.description_rounded),
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
                    backgroundColor: AppTheme.adminColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Confirm Ruling', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final adj = double.tryParse(adjustmentCtrl.text.trim()) ?? 0.0;
                    final notes = notesCtrl.text.trim();
                    Navigator.pop(ctx);
                    try {
                      await widget.apiService.resolveDispute(
                        disputeId: dispute['id'] as String? ?? '',
                        resolutionDecision: selectedDecision,
                        resolutionNotes: notes.isEmpty ? null : notes,
                        settlementAdjustmentInr: adj,
                      );
                      await _loadAll();
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF065F46),
                          content: Text('✅ Dispute ruled: $selectedDecision. Settlement ₹$adj logged.'),
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
      },
    );
  }

  // ─── TAB 4: Geo Hub & Ecosystem Integrations ────────────────────────────────

  Widget _buildGeoIntegrationsTab() {
    final hubs = (_geoData?['regional_clusters'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final integrations = (_integrationsData?['integrations'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return RefreshIndicator(
      color: AppTheme.adminColor,
      backgroundColor: AppTheme.getCardBg(context),
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        children: [
          // Section 1: Regional Hubs
          _buildSectionHeader('🗺 Regional Hub Geographic Intelligence', 'Tamil Nadu Western E-Waste Corridor', AppTheme.adminColor),
          const SizedBox(height: 12),
          if (hubs.isEmpty)
            _buildEmptyState('Loading regional telemetry clusters...', Icons.map_rounded)
          else
            ...hubs.map((h) => _buildHubCard(h)),
          const SizedBox(height: 20),

          // Section 2: Duplicate Lot Engine
          _buildSectionHeader('🔍 Duplicate Lot Risk Scanner', 'Metadata similarity & weight tolerance analyzer', Colors.deepOrange),
          const SizedBox(height: 12),
          _buildDuplicateCheckerCard(),
          const SizedBox(height: 20),

          // Section 3: Ecosystem Integrations
          _buildSectionHeader('🌐 Regulatory & Ecosystem Integration Readiness', 'CPCB • TN-SPCB • PRO/EPR • Escrow', const Color(0xFF059669)),
          const SizedBox(height: 12),
          if (integrations.isEmpty)
            _buildEmptyState('Checking integration readiness endpoints...', Icons.sync_alt_rounded)
          else
            ...integrations.map((i) => _buildIntegrationTile(i)),
          const SizedBox(height: 20),

          // Section 4: Audit Logs
          _buildSectionHeader('📜 High-Consequence Immutable Audit Logs', '${_auditLogs.length} events recorded', const Color(0xFF6366F1)),
          const SizedBox(height: 12),
          if (_auditLogs.isEmpty)
            _buildEmptyState('No administrative audit entries yet.', Icons.history_edu_rounded)
          else
            ..._auditLogs.map((a) => _buildAuditLogTile(a)),
        ],
      ),
    );
  }

  Widget _buildHubCard(Map<String, dynamic> h) {
    final hubName = h['hub_name'] as String? ?? 'Hub';
    final district = h['district'] as String? ?? 'TN';
    final vol = (h['collection_volume_kg'] as num?)?.toDouble() ?? 0.0;
    final recyclers = (h['active_recyclers'] as num?)?.toInt() ?? 0;
    final capUtil = (h['capacity_utilization_pct'] as num?)?.toDouble() ?? 0.0;
    final status = h['status'] as String? ?? 'ACTIVE';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: AppTheme.adminColor.withValues(alpha: 0.25),
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
                  color: AppTheme.adminColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_city_rounded, color: AppTheme.adminColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hubName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.getTextPrimary(context))),
                    Text('District: $district • Corridor Node', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: AppTheme.pillBadgeDecoration(const Color(0xFF059669), context: context),
                child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.getSurface(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('${vol.toStringAsFixed(0)} kg',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.collectorColor)),
                      const Text('Collected Volume', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.getSurface(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('$recyclers Recyclers',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.recyclerColor)),
                      const Text('Active Formal Partners', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.getSurface(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('${capUtil.toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF6366F1))),
                      const Text('Cap Utilization', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateCheckerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: Colors.deepOrange.withValues(alpha: 0.3),
        context: context,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint_rounded, color: Colors.deepOrange, size: 20),
              const SizedBox(width: 8),
              Text('Live Intake Duplicate Verifier',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.getTextPrimary(context))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Test a candidate lot before auction dispatch to ensure no double-counting or re-submitted lots within regional radius.',
            style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dupCategoryCtrl,
                  decoration: const InputDecoration(labelText: 'Category (ITEW, PCB, etc.)', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _dupWeightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg)', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dupPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price (₹)', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _dupCollectorCtrl,
                  decoration: const InputDecoration(labelText: 'Collector ID', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isCheckingDuplicate
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded, size: 16),
              label: Text(_isCheckingDuplicate ? 'Scanning Database...' : 'Run Duplicate Lot Check',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onPressed: _isCheckingDuplicate
                  ? null
                  : () async {
                      setState(() => _isCheckingDuplicate = true);
                      try {
                        final wt = double.tryParse(_dupWeightCtrl.text.trim()) ?? 10.0;
                        final res = await widget.apiService.checkDuplicateLot(
                          category: _dupCategoryCtrl.text.trim(),
                          subcategory: 'General',
                          estimatedWeightKg: wt,
                          collectorId: _dupCollectorCtrl.text.trim().isEmpty ? null : _dupCollectorCtrl.text.trim(),
                        );
                        if (mounted) {
                          setState(() {
                            _dupCheckResult = res;
                          });
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        if (mounted) setState(() => _isCheckingDuplicate = false);
                      }
                    },
            ),
          ),
          if (_dupCheckResult != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _dupCheckResult!['duplicate_suspected'] == true
                    ? AppTheme.alertRed.withValues(alpha: 0.12)
                    : const Color(0xFF059669).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _dupCheckResult!['duplicate_suspected'] == true ? AppTheme.alertRed : const Color(0xFF059669),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _dupCheckResult!['duplicate_suspected'] == true
                            ? Icons.warning_rounded
                            : Icons.check_circle_rounded,
                        color: _dupCheckResult!['duplicate_suspected'] == true ? AppTheme.alertRed : const Color(0xFF059669),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _dupCheckResult!['duplicate_suspected'] == true
                              ? 'POTENTIAL DUPLICATE DETECTED'
                              : 'NO DUPLICATE FOUND (CLEAN LOT)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: _dupCheckResult!['duplicate_suspected'] == true ? AppTheme.alertRed : const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_dupCheckResult!['recommendation'] as String? ?? '',
                      style: TextStyle(fontSize: 11, color: AppTheme.getTextPrimary(context))),
                  if ((_dupCheckResult!['matching_candidates'] as List?)?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    const Text('Matching Candidates:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                    ...((_dupCheckResult!['matching_candidates'] as List).cast<Map<String, dynamic>>()).map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '• ${c['lot_code']} (${c['category']}) - Sim: ${(((c['similarity_score'] as num?)?.toDouble() ?? 0.0) * 100).toStringAsFixed(0)}% • ΔWeight: ${c['weight_delta_kg']} kg',
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntegrationTile(Map<String, dynamic> i) {
    final name = i['name'] as String? ?? 'Integration';
    final type = i['partner_type'] as String? ?? 'REGULATORY';
    final status = i['status'] as String? ?? 'ACTIVE';
    final latency = (i['latency_ms'] as num?)?.toInt() ?? 120;
    final protocol = i['protocol'] as String? ?? 'REST';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardBoxDecoration(
        color: AppTheme.getCardBg(context),
        borderColor: const Color(0xFF059669).withValues(alpha: 0.25),
        context: context,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF059669), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.getTextPrimary(context))),
                Text('$type • Protocol: $protocol • Latency: ${latency}ms',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: AppTheme.pillBadgeDecoration(const Color(0xFF059669), context: context),
            child: Text(status, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogTile(Map<String, dynamic> a) {
    final action = a['action'] as String? ?? 'AUDIT';
    final target = '${a['target_type'] ?? ''} ${a['target_id'] ?? ''}';
    final performedBy = a['performed_by_id'] as String? ?? 'SYSTEM';
    final timestamp = a['created_at'] as String? ?? '';
    final details = (a['details'] as Map<String, dynamic>?)?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.getSurface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(action, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF6366F1))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(target,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.getTextPrimary(context)),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                timestamp.length > 10 ? timestamp.substring(0, 10) : timestamp,
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('By: $performedBy • $details',
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
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
