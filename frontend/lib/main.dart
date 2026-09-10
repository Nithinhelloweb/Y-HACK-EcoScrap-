import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/offline_store.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/collector_screen.dart';
import 'screens/recycler_screen.dart';
import 'screens/passport_screen.dart';
import 'screens/admin_screen.dart';
import 'i18n/translations.dart';

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

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _authService.addListener(_onAuthChanged);
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
        return Colors.tealAccent;
      case 'RECYCLER':
        return Colors.lightBlueAccent;
      case 'ADMIN':
        return Colors.purpleAccent;
      default:
        return Colors.tealAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoScrap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Color(0xFF059669),
          surface: Color(0xFF1E293B),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E293B),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: _authService.isAuthenticated ? _buildAuthenticatedShell() : _buildLoginScreen(),
    );
  }

  Widget _buildLoginScreen() {
    return LoginScreen(
      apiService: _apiService,
      authService: _authService,
      currentLang: _currentLang,
      onLangChanged: (lang) => setState(() => _currentLang = lang),
    );
  }

  Widget _buildAuthenticatedShell() {
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                role == 'COLLECTOR'
                    ? Icons.recycling_rounded
                    : (role == 'RECYCLER' ? Icons.precision_manufacturing_rounded : Icons.gavel_rounded),
                color: roleColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              t('app_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Active User Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: roleColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 4,
                  backgroundColor: roleColor,
                ),
                const SizedBox(width: 6),
                Text(
                  ' ()',
                  style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Quick Demo Role Switcher Popup Menu
          PopupMenuButton<String>(
            tooltip: 'Switch Demo Role (Hackathon)',
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.amberAccent),
            color: const Color(0xFF1E293B),
            onSelected: (targetRole) async {
              await _authService.quickDemoLogin(apiService: _apiService, role: targetRole);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'COLLECTOR',
                child: Row(
                  children: [
                    Icon(Icons.person_pin_circle_rounded, color: Colors.tealAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Switch to Collector (Murugan K.)', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'RECYCLER',
                child: Row(
                  children: [
                    Icon(Icons.factory_rounded, color: Colors.lightBlueAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Switch to Recycler (GreenTech)', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'ADMIN',
                child: Row(
                  children: [
                    Icon(Icons.shield_rounded, color: Colors.purpleAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Switch to Admin (CPCB Inspector)', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),

          // Language Selector
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, color: Colors.tealAccent, size: 20),
            color: const Color(0xFF1E293B),
            onSelected: (lang) => setState(() => _currentLang = lang),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'en', child: Text('English', style: TextStyle(fontSize: 13))),
              PopupMenuItem(value: 'ta', child: Text('தமிழ்', style: TextStyle(fontSize: 13))),
              PopupMenuItem(value: 'hi', child: Text('हिंदी', style: TextStyle(fontSize: 13))),
            ],
          ),

          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            tooltip: t('logout_btn'),
            onPressed: () async {
              await _authService.logout();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: activeIndex,
        children: screens,
      ),
      bottomNavigationBar: destinations.length > 1
          ? NavigationBar(
              selectedIndex: activeIndex,
              backgroundColor: const Color(0xFF0F172A),
              indicatorColor: roleColor.withValues(alpha: 0.2),
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              destinations: destinations,
            )
          : null,
    );
  }
}
