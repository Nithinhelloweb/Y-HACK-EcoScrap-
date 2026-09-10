import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'services/offline_store.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/collector_screen.dart';
import 'screens/recycler_screen.dart';
import 'screens/passport_screen.dart';
import 'screens/admin_screen.dart';
import 'i18n/translations.dart';
import 'theme/app_theme.dart';
import 'widgets/responsive_container.dart';
import 'widgets/ecoscrap_logo.dart';
import 'widgets/ecoscrap_drawer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final offlineStore = OfflineStore();
  await offlineStore.init();

  final authService = AuthService();
  await authService.init();

  runApp(EcoScrapApp(
    offlineStore: offlineStore,
    authService: authService,
  ));
}

class EcoScrapApp extends StatefulWidget {
  final OfflineStore offlineStore;
  final AuthService? authService;

  const EcoScrapApp({
    super.key,
    required this.offlineStore,
    this.authService,
  });

  @override
  State<EcoScrapApp> createState() => _EcoScrapAppState();
}

class _EcoScrapAppState extends State<EcoScrapApp> {
  final ApiService _apiService = ApiService();
  late final AuthService _authService;
  String _currentLang = 'en';

  // Navigation state
  int _drawerNavIndex = 0;
  int _collectorSubTab = 0;
  int _recyclerSubTab = 0;
  int _adminSubTab = 0;
  int _topScreenIndex = 0; // 0: Role Main Screen, 1: Passport

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  ThemeMode _themeMode = ThemeMode.light;
  static const String _themePrefKey = 'ecoscrap_theme_mode';

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _authService.addListener(_onAuthChanged);
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themePrefKey);
      if (saved == 'dark') {
        setState(() => _themeMode = ThemeMode.dark);
      } else if (saved == 'light') {
        setState(() => _themeMode = ThemeMode.light);
      }
    } catch (_) {}
  }

  Future<void> _toggleTheme() async {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    setState(() {
      _drawerNavIndex = 0;
      _collectorSubTab = 0;
      _recyclerSubTab = 0;
      _adminSubTab = 0;
      _topScreenIndex = 0;
    });
  }

  String t(String key) => AppTranslations.get(key, _currentLang);

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'COLLECTOR':
        return AppTheme.collectorColor;
      case 'RECYCLER':
        return AppTheme.recyclerColor;
      case 'ADMIN':
        return AppTheme.adminColor;
      default:
        return AppTheme.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoScrap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: _authService.isAuthenticated ? _buildAuthenticatedShell() : _buildLoginScreen(),
    );
  }

  Widget _buildLoginScreen() {
    return LoginScreen(
      apiService: _apiService,
      authService: _authService,
      currentLang: _currentLang,
      onLangChanged: (lang) => setState(() => _currentLang = lang),
      isDark: _themeMode == ThemeMode.dark,
      onToggleTheme: _toggleTheme,
    );
  }

  Widget _buildAuthenticatedShell() {
    final isDark = _themeMode == ThemeMode.dark;
    final user = _authService.currentUser!;
    final role = user.role.toUpperCase();
    final roleColor = _getRoleColor(role);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 680;

    // Build role screens
    Widget roleMainScreen;
    if (role == 'COLLECTOR') {
      roleMainScreen = CollectorScreen(
        apiService: _apiService,
        offlineStore: widget.offlineStore,
        currentLang: _currentLang,
        onLangChanged: (lang) => setState(() => _currentLang = lang),
        initialTab: _collectorSubTab,
      );
    } else if (role == 'RECYCLER') {
      roleMainScreen = RecyclerScreen(
        apiService: _apiService,
        currentLang: _currentLang,
        initialTab: _recyclerSubTab,
      );
    } else {
      roleMainScreen = AdminScreen(
        apiService: _apiService,
        currentLang: _currentLang,
        initialTab: _adminSubTab,
      );
    }

    final screens = [
      roleMainScreen,
      PassportScreen(
        apiService: _apiService,
        currentLang: _currentLang,
      ),
    ];

    // Mobile Bottom Navigation Destinations
    List<NavigationDestination> bottomDestinations;
    int bottomNavIndex = 0;

    if (role == 'COLLECTOR') {
      bottomDestinations = const [
        NavigationDestination(
          icon: Icon(Icons.camera_alt_outlined),
          selectedIcon: Icon(Icons.camera_alt_rounded),
          label: 'Intake',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2_rounded),
          label: 'Lots',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
          label: 'Earnings',
        ),
        NavigationDestination(
          icon: Icon(Icons.qr_code_scanner_outlined),
          selectedIcon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Passport',
        ),
      ];
      bottomNavIndex = _topScreenIndex == 1 ? 3 : _collectorSubTab.clamp(0, 2);
    } else if (role == 'RECYCLER') {
      bottomDestinations = const [
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront_rounded),
          label: 'Market',
        ),
        NavigationDestination(
          icon: Icon(Icons.gavel_outlined),
          selectedIcon: Icon(Icons.gavel_rounded),
          label: 'Bids',
        ),
        NavigationDestination(
          icon: Icon(Icons.precision_manufacturing_outlined),
          selectedIcon: Icon(Icons.precision_manufacturing_rounded),
          label: 'Pipeline',
        ),
        NavigationDestination(
          icon: Icon(Icons.qr_code_scanner_outlined),
          selectedIcon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Passport',
        ),
      ];
      bottomNavIndex = _topScreenIndex == 1 ? 3 : _recyclerSubTab.clamp(0, 2);
    } else {
      bottomDestinations = const [
        NavigationDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics_rounded),
          label: 'Telemetry',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_alt_outlined),
          selectedIcon: Icon(Icons.people_alt_rounded),
          label: 'Users',
        ),
        NavigationDestination(
          icon: Icon(Icons.trending_up_rounded),
          selectedIcon: Icon(Icons.trending_up_rounded),
          label: 'Market',
        ),
        NavigationDestination(
          icon: Icon(Icons.eco_outlined),
          selectedIcon: Icon(Icons.eco_rounded),
          label: 'Ecosystem',
        ),
      ];
      bottomNavIndex = _adminSubTab.clamp(0, 3);
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: EcoScrapDrawer(
        user: user,
        role: role,
        roleColor: roleColor,
        selectedNavIndex: _drawerNavIndex,
        onDestinationSelected: (idx) => _onDrawerDestinationSelected(role, idx),
        offlineStore: widget.offlineStore,
        apiService: _apiService,
        authService: _authService,
        isDark: isDark,
        onToggleTheme: _toggleTheme,
        currentLang: _currentLang,
        onLangChanged: (lang) => setState(() => _currentLang = lang),
      ),
      appBar: AppBar(
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 24),
          tooltip: 'Open Navigation Drawer',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            const EcoScrapLogo(size: 32, borderRadius: 9),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t('app_title'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3),
                  ),
                  Text(
                    _getNavSubtitle(role, _drawerNavIndex),
                    style: TextStyle(fontSize: 10, color: roleColor.withValues(alpha: 0.85), fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: isDark ? AppTheme.borderSubtle : AppTheme.borderLight, height: 1),
        ),
        actions: [
          // Live Sync Status Pill (Visible on both Mobile & Desktop!)
          _buildAppBarSyncPill(context, roleColor),
          const SizedBox(width: 6),

          // Theme Toggle Button
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : const Color(0xFF475569),
              size: 20,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: _toggleTheme,
          ),

          if (!isMobile) ...[
            // Desktop Role Switcher Popup Menu
            PopupMenuButton<String>(
              tooltip: 'Switch Demo Role',
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: Colors.amberAccent, size: 18),
              ),
              color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? AppTheme.borderSubtle : AppTheme.borderLight),
              ),
              onSelected: (targetRole) async {
                await _authService.quickDemoLogin(apiService: _apiService, role: targetRole);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'COLLECTOR',
                  child: Row(
                    children: [
                      const Icon(Icons.person_pin_circle_rounded, color: AppTheme.collectorColor, size: 18),
                      const SizedBox(width: 8),
                      Text('Switch to Collector (Murugan K.)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'RECYCLER',
                  child: Row(
                    children: [
                      const Icon(Icons.factory_rounded, color: AppTheme.recyclerColor, size: 18),
                      const SizedBox(width: 8),
                      Text('Switch to Recycler (GreenTech)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'ADMIN',
                  child: Row(
                    children: [
                      const Icon(Icons.shield_rounded, color: AppTheme.adminColor, size: 18),
                      const SizedBox(width: 8),
                      Text('Switch to Admin (CPCB Inspector)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),

            // Language Selector
            PopupMenuButton<String>(
              icon: const Icon(Icons.language_rounded, color: AppTheme.primaryGreen, size: 20),
              color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? AppTheme.borderSubtle : AppTheme.borderLight),
              ),
              onSelected: (lang) => setState(() => _currentLang = lang),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'en', child: Text('English', style: TextStyle(fontSize: 13, color: AppTheme.getTextPrimary(context)))),
                PopupMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)', style: TextStyle(fontSize: 13, color: AppTheme.getTextPrimary(context)))),
                PopupMenuItem(value: 'hi', child: Text('हिंदी (Hindi)', style: TextStyle(fontSize: 13, color: AppTheme.getTextPrimary(context)))),
              ],
            ),
            const SizedBox(width: 4),

            // Logout
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppTheme.alertRed, size: 20),
              tooltip: t('logout_btn'),
              onPressed: () async {
                await _authService.logout();
              },
            ),
          ] else ...[
            // Mobile Drawer Trigger Avatar
            InkWell(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: roleColor.withValues(alpha: 0.2),
                  border: Border.all(color: roleColor, width: 1.2),
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: TextStyle(fontWeight: FontWeight.w800, color: roleColor, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 1100,
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
        child: IndexedStack(
          index: _topScreenIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: isMobile && bottomDestinations.isNotEmpty
          ? Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.bgDark : AppTheme.cardLight,
                border: Border(top: BorderSide(color: isDark ? AppTheme.borderSubtle : AppTheme.borderLight, width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: NavigationBar(
                  height: 62,
                  selectedIndex: bottomNavIndex,
                  backgroundColor: isDark ? AppTheme.bgDark : AppTheme.cardLight,
                  indicatorColor: roleColor.withValues(alpha: 0.18),
                  onDestinationSelected: (index) {
                    _onBottomNavSelected(role, index);
                  },
                  destinations: bottomDestinations,
                ),
              ),
            )
          : null,
    );
  }

  void _onBottomNavSelected(String role, int index) {
    setState(() {
      if (role == 'COLLECTOR') {
        switch (index) {
          case 0:
            _topScreenIndex = 0;
            _collectorSubTab = 0;
            _drawerNavIndex = 0;
            break;
          case 1:
            _topScreenIndex = 0;
            _collectorSubTab = 1;
            _drawerNavIndex = 1;
            break;
          case 2:
            _topScreenIndex = 0;
            _collectorSubTab = 2;
            _drawerNavIndex = 2;
            break;
          case 3:
            _topScreenIndex = 1;
            _drawerNavIndex = 3;
            break;
        }
      } else if (role == 'RECYCLER') {
        switch (index) {
          case 0:
            _topScreenIndex = 0;
            _recyclerSubTab = 0;
            _drawerNavIndex = 0;
            break;
          case 1:
            _topScreenIndex = 0;
            _recyclerSubTab = 1;
            _drawerNavIndex = 1;
            break;
          case 2:
            _topScreenIndex = 0;
            _recyclerSubTab = 2;
            _drawerNavIndex = 2;
            break;
          case 3:
            _topScreenIndex = 1;
            _drawerNavIndex = 4;
            break;
        }
      } else {
        // ADMIN
        _topScreenIndex = 0;
        _adminSubTab = index.clamp(0, 3);
        _drawerNavIndex = index.clamp(0, 3);
      }
    });
  }

  void _onDrawerDestinationSelected(String role, int index) {
    setState(() {
      _drawerNavIndex = index;
      if (role == 'COLLECTOR') {
        switch (index) {
          case 0:
            _topScreenIndex = 0;
            _collectorSubTab = 0; // Intake
            break;
          case 1:
            _topScreenIndex = 0;
            _collectorSubTab = 1; // Lots
            break;
          case 2:
            _topScreenIndex = 0;
            _collectorSubTab = 2; // Earnings
            break;
          case 3:
            _topScreenIndex = 1; // Passport
            break;
          case 4:
            _topScreenIndex = 0;
            _collectorSubTab = 3; // Trust & Safety
            break;
        }
      } else if (role == 'RECYCLER') {
        switch (index) {
          case 0:
            _topScreenIndex = 0;
            _recyclerSubTab = 0; // Marketplace
            break;
          case 1:
            _topScreenIndex = 0;
            _recyclerSubTab = 1; // Bids
            break;
          case 2:
            _topScreenIndex = 0;
            _recyclerSubTab = 2; // Pipeline
            break;
          case 3:
            _topScreenIndex = 0;
            _recyclerSubTab = 3; // Performance
            break;
          case 4:
            _topScreenIndex = 1; // Passport
            break;
        }
      } else {
        // ADMIN
        switch (index) {
          case 0:
            _topScreenIndex = 0;
            _adminSubTab = 0; // Overview
            break;
          case 1:
            _topScreenIndex = 0;
            _adminSubTab = 1; // Users
            break;
          case 2:
            _topScreenIndex = 0;
            _adminSubTab = 2; // Market Intel
            break;
          case 3:
            _topScreenIndex = 0;
            _adminSubTab = 3; // Ecosystem
            break;
          case 4:
            _topScreenIndex = 0;
            _adminSubTab = 0; // Overview
            break;
          case 5:
            _topScreenIndex = 1; // Passport
            break;
        }
      }
    });
  }

  String _getNavSubtitle(String role, int navIndex) {
    if (role == 'COLLECTOR') {
      switch (navIndex) {
        case 0:
          return 'AI Intake & Scanner';
        case 1:
          return 'My Collections & Lots';
        case 2:
          return 'Earnings & Settlements';
        case 3:
          return 'Digital Product Passport';
        case 4:
          return 'Trust & Safety Protocols';
        default:
          return 'Collector Workspace';
      }
    } else if (role == 'RECYCLER') {
      switch (navIndex) {
        case 0:
          return 'E-Waste Marketplace';
        case 1:
          return 'My Bids & Handover';
        case 2:
          return 'Processing Pipeline';
        case 3:
          return 'Performance & Stats';
        case 4:
          return 'Digital Passport Audit';
        default:
          return 'Recycler Hub';
      }
    } else {
      switch (navIndex) {
        case 0:
          return 'Governance Telemetry';
        case 1:
          return 'User Verification & KYC';
        case 2:
          return 'Market Intelligence';
        case 3:
          return 'Environmental Impact';
        case 4:
          return 'Fraud & Risk Alerts';
        case 5:
          return 'Universal Passport Inspector';
        default:
          return 'Regulatory Oversight';
      }
    }
  }

  Widget _buildAppBarSyncPill(BuildContext context, Color roleColor) {
    return ListenableBuilder(
      listenable: widget.offlineStore,
      builder: (context, _) {
        final isOffline = widget.offlineStore.isOfflineMode;
        final pending = widget.offlineStore.pendingCount;
        final isSyncing = widget.offlineStore.isSyncing;

        final Color pillColor = isOffline
            ? AppTheme.alertAmber
            : (pending > 0 ? AppTheme.alertAmber : AppTheme.collectorColor);

        final IconData pillIcon = isOffline
            ? Icons.cloud_off_rounded
            : (isSyncing ? Icons.sync_rounded : Icons.cloud_done_rounded);

        final String pillText = isOffline
            ? (pending > 0 ? 'Offline ($pending)' : 'Offline')
            : (isSyncing ? 'Syncing...' : (pending > 0 ? 'Sync ($pending)' : 'Online'));

        return InkWell(
          onTap: () async {
            if (isOffline) {
              widget.offlineStore.toggleOfflineMode();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF065F46),
                    content: Text('Switched to Online mode.'),
                  ),
                );
              }
            } else {
              final count = await widget.offlineStore.syncPendingQueue(_apiService);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF065F46),
                    content: Text(count > 0
                        ? '✅ Synced $count lots to central ledger.'
                        : '✅ All lots are up to date on central ledger.'),
                  ),
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: pillColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: pillColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing)
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(pillColor),
                    ),
                  )
                else
                  Icon(pillIcon, size: 13, color: pillColor),
                const SizedBox(width: 5),
                Text(
                  pillText,
                  style: TextStyle(color: pillColor, fontWeight: FontWeight.w800, fontSize: 10.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

