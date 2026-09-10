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
import 'models/user_model.dart';

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
  int _currentIndex = 0;
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
      _currentIndex = 0; // Reset tab index on role switch / login
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

    List<Widget> screens = [];
    List<NavigationDestination> destinations = [];

    if (role == 'COLLECTOR') {
      screens = [
        CollectorScreen(
          apiService: _apiService,
          offlineStore: widget.offlineStore,
          currentLang: _currentLang,
          onLangChanged: (lang) => setState(() => _currentLang = lang),
        ),
        PassportScreen(
          apiService: _apiService,
          currentLang: _currentLang,
        ),
      ];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.recycling_rounded),
          label: 'Collector',
        ),
        NavigationDestination(
          icon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Passport',
        ),
      ];
    } else if (role == 'RECYCLER') {
      screens = [
        RecyclerScreen(
          apiService: _apiService,
          currentLang: _currentLang,
        ),
        PassportScreen(
          apiService: _apiService,
          currentLang: _currentLang,
        ),
      ];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.storefront_rounded),
          label: 'Recycler Hub',
        ),
        NavigationDestination(
          icon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Passport',
        ),
      ];
    } else {
      // ADMIN role - Complete Ecosystem Oversight
      screens = [
        AdminScreen(
          apiService: _apiService,
          currentLang: _currentLang,
        ),
        RecyclerScreen(
          apiService: _apiService,
          currentLang: _currentLang,
        ),
        CollectorScreen(
          apiService: _apiService,
          offlineStore: widget.offlineStore,
          currentLang: _currentLang,
          onLangChanged: (lang) => setState(() => _currentLang = lang),
        ),
        PassportScreen(
          apiService: _apiService,
          currentLang: _currentLang,
        ),
      ];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.analytics_rounded),
          label: 'Governance',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_rounded),
          label: 'Recycler',
        ),
        NavigationDestination(
          icon: Icon(Icons.recycling_rounded),
          label: 'Collector',
        ),
        NavigationDestination(
          icon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Passport',
        ),
      ];
    }

    // Guard index within bounds
    final activeIndex = _currentIndex < screens.length ? _currentIndex : 0;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 680;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Row(
          children: [
            const EcoScrapLogo(size: 36, borderRadius: 10),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('app_title'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
                ),
                Text(
                  role == 'COLLECTOR'
                      ? 'Collector Workspace'
                      : (role == 'RECYCLER' ? 'Recycler Hub' : 'Regulatory Oversight'),
                  style: TextStyle(fontSize: 10, color: roleColor.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: isDark ? AppTheme.borderSubtle : AppTheme.borderLight, height: 1),
        ),
        actions: isMobile
            ? [
                // Mobile compact role pill & bottom sheet trigger
                InkWell(
                  onTap: () => _showMobileMenuBottomSheet(
                    context: context,
                    user: user,
                    role: role,
                    roleColor: roleColor,
                    isDark: isDark,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: roleColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: roleColor),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          role,
                          style: TextStyle(color: roleColor, fontWeight: FontWeight.w800, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  tooltip: 'Menu & Settings',
                  onPressed: () => _showMobileMenuBottomSheet(
                    context: context,
                    user: user,
                    role: role,
                    roleColor: roleColor,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 6),
              ]
            : [
                // Desktop / Tablet Expanded Actions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: roleColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: roleColor,
                          boxShadow: [
                            BoxShadow(
                              color: roleColor.withValues(alpha: 0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${user.name} • $role',
                        style: TextStyle(color: roleColor, fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Quick Demo Role Switcher Popup Menu
                PopupMenuButton<String>(
                  tooltip: 'Switch Demo Role (Hackathon)',
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

                // Logout Button
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.alertRed, size: 20),
                  tooltip: t('logout_btn'),
                  onPressed: () async {
                    await _authService.logout();
                  },
                ),
                const SizedBox(width: 8),
              ],
      ),
      body: ResponsiveContainer(
        maxWidth: 1100,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: IndexedStack(
          index: activeIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: destinations.length > 1
          ? Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.bgDark : AppTheme.cardLight,
                border: Border(top: BorderSide(color: isDark ? AppTheme.borderSubtle : AppTheme.borderLight, width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: NavigationBar(
                  height: 64,
                  selectedIndex: activeIndex,
                  backgroundColor: isDark ? AppTheme.bgDark : AppTheme.cardLight,
                  indicatorColor: roleColor.withValues(alpha: 0.18),
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                  },
                  destinations: destinations,
                ),
              ),
            )
          : null,
    );
  }

  void _showMobileMenuBottomSheet({
    required BuildContext context,
    required UserModel user,
    required String role,
    required Color roleColor,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ListView(
              shrinkWrap: true,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.getTextMuted(context).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const EcoScrapLogo(size: 28, borderRadius: 8),
                      const SizedBox(width: 8),
                      Text(
                        'EcoScrap Platform',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: isDark ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: roleColor.withValues(alpha: 0.2),
                          border: Border.all(color: roleColor, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                            style: TextStyle(fontWeight: FontWeight.w800, color: roleColor, fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.getTextPrimary(context))),
                            const SizedBox(height: 2),
                            Text('${user.phone} • $role', style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: AppTheme.pillBadgeDecoration(roleColor, context: context),
                        child: Text(role, style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.amber : Colors.blueGrey).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: isDark ? Colors.amber : const Color(0xFF475569),
                      size: 20,
                    ),
                  ),
                  title: Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.getTextPrimary(context))),
                  subtitle: Text(isDark ? 'Dark Mode Active' : 'Light Mode (Default)', style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
                  trailing: Switch.adaptive(
                    value: isDark,
                    activeTrackColor: AppTheme.primaryGreen,
                    onChanged: (_) {
                      Navigator.pop(ctx);
                      _toggleTheme();
                    },
                  ),
                ),
                const Divider(height: 16),
                Text('Language / மொழி / भाषा', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.getTextSecondary(context))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _langChip(ctx, 'en', 'English'),
                    const SizedBox(width: 8),
                    _langChip(ctx, 'ta', 'தமிழ்'),
                    const SizedBox(width: 8),
                    _langChip(ctx, 'hi', 'हिंदी'),
                  ],
                ),
                const Divider(height: 20),
                Text('Switch Demo Role (Hackathon)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.getTextSecondary(context))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _roleChip(ctx, 'COLLECTOR', 'Collector', AppTheme.collectorColor),
                    const SizedBox(width: 8),
                    _roleChip(ctx, 'RECYCLER', 'Recycler', AppTheme.recyclerColor),
                    const SizedBox(width: 8),
                    _roleChip(ctx, 'ADMIN', 'Admin', AppTheme.adminColor),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.alertRed,
                      side: BorderSide(color: AppTheme.alertRed.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(t('logout_btn'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _authService.logout();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _langChip(BuildContext ctx, String code, String label) {
    final isSelected = _currentLang == code;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _currentLang = code);
          Navigator.pop(ctx);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.15) : AppTheme.getSurface(ctx),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : AppTheme.getBorder(ctx),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppTheme.primaryGreen : AppTheme.getTextPrimary(ctx),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleChip(BuildContext ctx, String targetRole, String label, Color color) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          Navigator.pop(ctx);
          await _authService.quickDemoLogin(apiService: _apiService, role: targetRole);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
