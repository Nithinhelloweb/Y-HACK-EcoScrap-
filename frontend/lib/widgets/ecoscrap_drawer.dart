import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/offline_store.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../i18n/translations.dart';
import 'ecoscrap_logo.dart';

class EcoScrapDrawer extends StatelessWidget {
  final UserModel user;
  final String role;
  final Color roleColor;
  final int selectedNavIndex;
  final Function(int) onDestinationSelected;
  final OfflineStore offlineStore;
  final ApiService apiService;
  final AuthService authService;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final String currentLang;
  final Function(String) onLangChanged;

  const EcoScrapDrawer({
    super.key,
    required this.user,
    required this.role,
    required this.roleColor,
    required this.selectedNavIndex,
    required this.onDestinationSelected,
    required this.offlineStore,
    required this.apiService,
    required this.authService,
    required this.isDark,
    required this.onToggleTheme,
    required this.currentLang,
    required this.onLangChanged,
  });

  String t(String key) => AppTranslations.get(key, currentLang);

  @override
  Widget build(BuildContext context) {
    final destinations = _getRoleDestinations(role);

    return Drawer(
      backgroundColor: AppTheme.getCardBg(context),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header Profile Area ──────────────────────────────────────────
            _buildDrawerHeader(context),

            // ── Scrollable Body: Sync & Navigation Items ──────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  // Offline Sync Card
                  _buildOfflineSyncCard(context),
                  const SizedBox(height: 12),

                  // Destination Group Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'WORKSPACE NAVIGATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppTheme.getTextSecondary(context).withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Destination Items
                  ...destinations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = selectedNavIndex == index;
                    return _buildNavItem(
                      context: context,
                      index: index,
                      title: item.title,
                      subtitle: item.subtitle,
                      icon: item.icon,
                      isSelected: isSelected,
                      badgeCount: item.badgeCount,
                    );
                  }),

                  const Divider(height: 24, thickness: 0.8),

                  // Switch Demo Role (Hackathon quick access)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'DEMO ROLE SWITCHER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppTheme.getTextSecondary(context).withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildDemoRoleSwitcher(context),

                  const SizedBox(height: 14),

                  // Appearance & Settings
                  _buildAppearanceTile(context),

                  const SizedBox(height: 10),

                  // Language Selection
                  _buildLanguageRow(context),
                ],
              ),
            ),

            // ── Footer Logout ────────────────────────────────────────────────
            _buildDrawerFooter(context),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: roleColor.withValues(alpha: isDark ? 0.12 : 0.08),
        border: Border(
          bottom: BorderSide(
            color: roleColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const EcoScrapLogo(size: 38, borderRadius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('app_title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'CPCB-Aligned Circular Pilot v1.4',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.getTextSecondary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close Drawer',
              ),
            ],
          ),
          const SizedBox(height: 14),
          // User Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.getCardBg(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: roleColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: roleColor.withValues(alpha: 0.2),
                    border: Border.all(color: roleColor, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: roleColor,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppTheme.getTextPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${user.phone} • $role',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: AppTheme.pillBadgeDecoration(roleColor, context: context),
                  child: Text(
                    role,
                    style: TextStyle(
                      color: roleColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Offline Sync Widget ────────────────────────────────────────────────────

  Widget _buildOfflineSyncCard(BuildContext context) {
    return ListenableBuilder(
      listenable: offlineStore,
      builder: (context, _) {
        final isOffline = offlineStore.isOfflineMode;
        final pending = offlineStore.pendingCount;
        final isSyncing = offlineStore.isSyncing;
        final statusColor = isOffline ? AppTheme.alertAmber : AppTheme.collectorColor;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: isDark ? 0.12 : 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isOffline ? 'Offline Mode Active' : 'Online & Sync Ready',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: statusColor,
                      ),
                    ),
                  ),
                  // Simulation Toggle
                  Transform.scale(
                    scale: 0.75,
                    child: Switch.adaptive(
                      value: isOffline,
                      activeTrackColor: AppTheme.alertAmber,
                      onChanged: (val) {
                        offlineStore.toggleOfflineMode();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    pending > 0 ? '$pending items queued for sync' : 'All local collections synced',
                    style: TextStyle(
                      fontSize: 11,
                      color: pending > 0 ? AppTheme.alertAmber : AppTheme.getTextSecondary(context),
                      fontWeight: pending > 0 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (pending > 0 || !isOffline)
                    InkWell(
                      onTap: isSyncing
                          ? null
                          : () async {
                              final count = await offlineStore.syncPendingQueue(apiService);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF065F46),
                                    content: Text('✅ Synced $count lots to central EcoScrap ledger.'),
                                  ),
                                );
                              }
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.collectorColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSyncing)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            else
                              const Icon(Icons.sync_rounded, size: 14, color: Colors.black),
                            const SizedBox(width: 4),
                            Text(
                              isSyncing ? 'Syncing...' : 'Sync Now',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Nav Item ───────────────────────────────────────────────────────────────

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    int? badgeCount,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isSelected ? roleColor.withValues(alpha: isDark ? 0.18 : 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? roleColor.withValues(alpha: 0.4) : Colors.transparent,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isSelected ? roleColor.withValues(alpha: 0.2) : AppTheme.getSurface(context),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            color: isSelected ? roleColor : AppTheme.getTextSecondary(context),
            size: 19,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
            color: isSelected ? roleColor : AppTheme.getTextPrimary(context),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 10.5,
            color: isSelected ? roleColor.withValues(alpha: 0.8) : AppTheme.getTextSecondary(context),
          ),
        ),
        trailing: badgeCount != null && badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.alertAmber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : (isSelected ? Icon(Icons.arrow_forward_ios_rounded, size: 12, color: roleColor) : null),
        onTap: () {
          Navigator.of(context).pop(); // Close drawer
          onDestinationSelected(index);
        },
      ),
    );
  }

  // ─── Demo Role Switcher ─────────────────────────────────────────────────────

  Widget _buildDemoRoleSwitcher(BuildContext context) {
    return Row(
      children: [
        _roleChip(context, 'COLLECTOR', 'Collector', AppTheme.collectorColor),
        const SizedBox(width: 6),
        _roleChip(context, 'RECYCLER', 'Recycler', AppTheme.recyclerColor),
        const SizedBox(width: 6),
        _roleChip(context, 'ADMIN', 'Admin', AppTheme.adminColor),
      ],
    );
  }

  Widget _roleChip(BuildContext context, String targetRole, String label, Color chipColor) {
    final isCurrent = role.toUpperCase() == targetRole.toUpperCase();
    return Expanded(
      child: InkWell(
        onTap: () async {
          Navigator.of(context).pop();
          await authService.quickDemoLogin(apiService: apiService, role: targetRole);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isCurrent ? chipColor.withValues(alpha: 0.22) : AppTheme.getSurface(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrent ? chipColor : AppTheme.getBorder(context),
              width: isCurrent ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                color: isCurrent ? chipColor : AppTheme.getTextPrimary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Settings Tiles ─────────────────────────────────────────────────────────

  Widget _buildAppearanceTile(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.getSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 18,
                color: isDark ? Colors.amber : const Color(0xFF475569),
              ),
              const SizedBox(width: 10),
              Text(
                isDark ? 'Dark Theme' : 'Light Theme',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
            ],
          ),
          Switch.adaptive(
            value: isDark,
            activeTrackColor: AppTheme.primaryGreen,
            onChanged: (_) => onToggleTheme(),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageRow(BuildContext context) {
    return Row(
      children: [
        _langButton(context, 'en', 'English'),
        const SizedBox(width: 6),
        _langButton(context, 'ta', 'தமிழ்'),
        const SizedBox(width: 6),
        _langButton(context, 'hi', 'हिंदी'),
      ],
    );
  }

  Widget _langButton(BuildContext context, String code, String label) {
    final isSelected = currentLang == code;
    return Expanded(
      child: InkWell(
        onTap: () => onLangChanged(code),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.16) : AppTheme.getSurface(context),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : AppTheme.getBorder(context),
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppTheme.primaryGreen : AppTheme.getTextPrimary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildDrawerFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.getBorder(context), width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.alertRed,
            side: BorderSide(color: AppTheme.alertRed.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.logout_rounded, size: 16),
          label: Text(t('logout_btn'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          onPressed: () async {
            Navigator.of(context).pop();
            await authService.logout();
          },
        ),
      ),
    );
  }

  // ─── Destination Definitions per Role ───────────────────────────────────────

  List<_DrawerNavConfig> _getRoleDestinations(String userRole) {
    switch (userRole.toUpperCase()) {
      case 'COLLECTOR':
        return [
          _DrawerNavConfig(
            title: 'AI Intake & Scanner',
            subtitle: 'Camera AI lens, voice, fair valuation',
            icon: Icons.camera_alt_rounded,
          ),
          _DrawerNavConfig(
            title: 'My Lots & Collections',
            subtitle: 'Active lots, bids received, scale OTP',
            icon: Icons.inventory_2_rounded,
            badgeCount: offlineStore.pendingCount > 0 ? offlineStore.pendingCount : null,
          ),
          _DrawerNavConfig(
            title: 'Earnings & Payments',
            subtitle: 'UPI settlements, earnings summary',
            icon: Icons.account_balance_wallet_rounded,
          ),
          _DrawerNavConfig(
            title: 'Digital Product Passport',
            subtitle: 'QR verification, lifecycle timeline',
            icon: Icons.qr_code_scanner_rounded,
          ),
          _DrawerNavConfig(
            title: 'Trust & Safety Protocols',
            subtitle: 'Score breakdown, hazard guidelines',
            icon: Icons.health_and_safety_rounded,
          ),
        ];

      case 'RECYCLER':
        return [
          _DrawerNavConfig(
            title: 'E-Waste Marketplace',
            subtitle: 'Active lots, material filters, bids',
            icon: Icons.storefront_rounded,
          ),
          _DrawerNavConfig(
            title: 'My Bids & Handover',
            subtitle: 'Submitted bids, match score, scale OTP',
            icon: Icons.gavel_rounded,
          ),
          _DrawerNavConfig(
            title: 'Processing Pipeline',
            subtitle: 'RECEIVED → PROCESSING → CLOSED',
            icon: Icons.precision_manufacturing_rounded,
          ),
          _DrawerNavConfig(
            title: 'Performance & Stats',
            subtitle: 'Reputation score, capacity, turnaround',
            icon: Icons.leaderboard_rounded,
          ),
          _DrawerNavConfig(
            title: 'Digital Passport Audit',
            subtitle: 'Lot verification & custody audit',
            icon: Icons.qr_code_scanner_rounded,
          ),
        ];

      case 'ADMIN':
      default:
        return [
          _DrawerNavConfig(
            title: 'Governance Telemetry',
            subtitle: 'Macro KPIs, volume radar, anomalies',
            icon: Icons.analytics_rounded,
          ),
          _DrawerNavConfig(
            title: 'User Verification & KYC',
            subtitle: 'Verify / revoke collectors & recyclers',
            icon: Icons.people_alt_rounded,
          ),
          _DrawerNavConfig(
            title: 'Market Intelligence',
            subtitle: 'Pricing trends, floor rates, period data',
            icon: Icons.trending_up_rounded,
          ),
          _DrawerNavConfig(
            title: 'Environmental Impact',
            subtitle: 'CO₂ savings, toxic metal diversion',
            icon: Icons.eco_rounded,
          ),
          _DrawerNavConfig(
            title: 'Fraud & Risk Alerts',
            subtitle: 'Predatory bids, suspicious deviations',
            icon: Icons.warning_amber_rounded,
          ),
          _DrawerNavConfig(
            title: 'Universal Passport Inspector',
            subtitle: 'Inspect & trace any lot passport',
            icon: Icons.qr_code_scanner_rounded,
          ),
        ];
    }
  }
}

class _DrawerNavConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final int? badgeCount;

  _DrawerNavConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badgeCount,
  });
}
