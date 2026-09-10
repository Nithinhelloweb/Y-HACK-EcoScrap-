import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../i18n/translations.dart';
import '../theme/app_theme.dart';

import '../widgets/ecoscrap_logo.dart';

class LoginScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthService authService;
  final String currentLang;
  final Function(String) onLangChanged;
  final VoidCallback? onToggleTheme;
  final bool isDark;

  const LoginScreen({
    super.key,
    required this.apiService,
    required this.authService,
    required this.currentLang,
    required this.onLangChanged,
    this.onToggleTheme,
    this.isDark = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController(text: '9842100001');
  final _passwordController = TextEditingController(text: 'password123');
  final _regNameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regPasswordController = TextEditingController();

  String _selectedRole = 'COLLECTOR';
  bool _isPasswordVisible = false;
  bool _isRegisterMode = false;
  String? _errorMessage;

  String t(String key) => AppTranslations.get(key, widget.currentLang);

  Color get _roleColor {
    switch (_selectedRole) {
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

  void _onRoleChanged(String role) {
    setState(() {
      _selectedRole = role;
      _errorMessage = null;
      if (role == 'COLLECTOR') {
        _identifierController.text = '9842100001';
        _passwordController.text = 'password123';
      } else if (role == 'RECYCLER') {
        _identifierController.text = '9842100010';
        _passwordController.text = 'password123';
      } else if (role == 'ADMIN') {
        _identifierController.text = 'admin@ecoscrap.in';
        _passwordController.text = 'admin123';
      }
    });
  }

  Future<void> _handleLogin() async {
    final id = _identifierController.text.trim();
    final pwd = _passwordController.text.trim();

    if (id.isEmpty || pwd.isEmpty) {
      setState(() => _errorMessage = 'Please enter phone/email and password.');
      return;
    }

    setState(() => _errorMessage = null);
    try {
      await widget.authService.login(
        apiService: widget.apiService,
        identifier: id,
        password: pwd,
        role: _selectedRole,
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleRegister() async {
    final name = _regNameController.text.trim();
    final phone = _regPhoneController.text.trim();
    final pwd = _regPasswordController.text.trim();

    if (name.isEmpty || phone.isEmpty || pwd.isEmpty) {
      setState(() => _errorMessage = 'All registration fields are required.');
      return;
    }

    setState(() => _errorMessage = null);
    try {
      await widget.authService.register(
        apiService: widget.apiService,
        name: name,
        phone: phone,
        password: pwd,
        role: _selectedRole,
        language: widget.currentLang,
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleQuickDemo(String role) async {
    setState(() {
      _selectedRole = role;
      _errorMessage = null;
    });
    try {
      await widget.authService.quickDemoLogin(
        apiService: widget.apiService,
        role: role,
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const EcoScrapLogo(size: 34, borderRadius: 10),
            const SizedBox(width: 10),
            Text(
              t('app_title'),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppTheme.getTextPrimary(context)),
            ),
          ],
        ),
        actions: [
          // Theme Toggle in Login AppBar
          if (widget.onToggleTheme != null) ...[
            IconButton(
              icon: Icon(
                widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: widget.isDark ? Colors.amber : const Color(0xFF475569),
                size: 20,
              ),
              tooltip: widget.isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              onPressed: widget.onToggleTheme,
            ),
            const SizedBox(width: 4),
          ],

          // Language Selector Dropdown
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.getCardBg(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: widget.currentLang,
                dropdownColor: AppTheme.getCardBg(context),
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.language_rounded, color: AppTheme.primaryGreen, size: 18),
                items: [
                  DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(fontSize: 13, color: AppTheme.getTextPrimary(context)))),
                  DropdownMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)', style: TextStyle(fontSize: 13, color: AppTheme.getTextPrimary(context)))),
                  DropdownMenuItem(value: 'hi', child: Text('हिंदी (Hindi)', style: TextStyle(fontSize: 13, color: AppTheme.getTextPrimary(context)))),
                ],
                onChanged: (val) {
                  if (val != null) widget.onLangChanged(val);
                },
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Prominent Hero EcoScrap Logo
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: const EcoScrapLogo(
                      size: 88,
                      borderRadius: 22,
                      heroTag: 'ecoscrap_hero_logo',
                    ),
                  ),
                ),

                // Clean Pill Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: AppTheme.pillBadgeDecoration(AppTheme.primaryGreen, context: context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 14, color: AppTheme.primaryGreen),
                        SizedBox(width: 6),
                        Text(
                          'E-Waste Formalization • Challenge 19',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryGreen,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tagline & Intro
                Text(
                  t('login_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.getTextPrimary(context), letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  t('login_subtitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context), height: 1.4),
                ),
                const SizedBox(height: 24),

                // 1-Tap Quick Demo Logins Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardBoxDecoration(
                    color: AppTheme.getCardBg(context),
                    borderColor: Colors.amber.withValues(alpha: 0.35),
                    glow: true,
                    glowColor: Colors.amber,
                    context: context,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.bolt_rounded, color: AppTheme.alertAmber, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t('quick_demo_heading'),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.alertAmber),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 3 Quick Login Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _demoButton(
                              context: context,
                              label: 'Collector',
                              sub: 'Murugan K.',
                              color: AppTheme.collectorColor,
                              icon: Icons.person_pin_circle_rounded,
                              onTap: () => _handleQuickDemo('COLLECTOR'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _demoButton(
                              context: context,
                              label: 'Recycler',
                              sub: 'GreenTech',
                              color: AppTheme.recyclerColor,
                              icon: Icons.factory_rounded,
                              onTap: () => _handleQuickDemo('RECYCLER'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _demoButton(
                              context: context,
                              label: 'Admin',
                              sub: 'CPCB Officer',
                              color: AppTheme.adminColor,
                              icon: Icons.shield_rounded,
                              onTap: () => _handleQuickDemo('ADMIN'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Role Selector Tabs
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppTheme.isDark(context) ? AppTheme.surfaceDark : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.getBorder(context)),
                  ),
                  child: Row(
                    children: [
                      _roleTab(
                        context: context,
                        role: 'COLLECTOR',
                        label: t('role_collector'),
                        icon: Icons.handyman_rounded,
                        color: AppTheme.collectorColor,
                      ),
                      _roleTab(
                        context: context,
                        role: 'RECYCLER',
                        label: t('role_recycler'),
                        icon: Icons.precision_manufacturing_rounded,
                        color: AppTheme.recyclerColor,
                      ),
                      _roleTab(
                        context: context,
                        role: 'ADMIN',
                        label: t('role_admin'),
                        icon: Icons.gavel_rounded,
                        color: AppTheme.adminColor,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Contextual Role Explanation Card
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _roleColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _roleColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: _roleColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _roleDescription(),
                          style: TextStyle(color: _roleColor, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Main Credential Form Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: AppTheme.cardBoxDecoration(
                    color: AppTheme.getCardBg(context),
                    borderColor: AppTheme.getBorder(context),
                    context: context,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.alertRed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppTheme.alertRed, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (!_isRegisterMode) ...[
                        // Identifier Field
                        TextField(
                          controller: _identifierController,
                          style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 14),
                          decoration: InputDecoration(
                            labelText: t('identifier_label'),
                            prefixIcon: Icon(Icons.badge_outlined, color: _roleColor, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 14),
                          decoration: InputDecoration(
                            labelText: t('password_label'),
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: _roleColor, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: AppTheme.getTextSecondary(context),
                                size: 20,
                              ),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        // Login Action Button
                        ElevatedButton(
                          onPressed: widget.authService.isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _roleColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: widget.authService.isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(
                                  '${t('login_button')} as $_selectedRole',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.3),
                                ),
                        ),
                      ] else ...[
                        // Registration Form
                        TextField(
                          controller: _regNameController,
                          style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Full Name / Organization',
                            prefixIcon: Icon(Icons.person_outline_rounded, color: _roleColor, size: 20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _regPhoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 14),
                          decoration: InputDecoration(
                            labelText: '10-Digit Mobile Number',
                            prefixIcon: Icon(Icons.phone_outlined, color: _roleColor, size: 20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _regPasswordController,
                          obscureText: true,
                          style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Choose Password',
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: _roleColor, size: 20),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: widget.authService.isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _roleColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: widget.authService.isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(
                                  'Register as $_selectedRole',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.3),
                                ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Toggle between Login & Register
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isRegisterMode = !_isRegisterMode;
                              _errorMessage = null;
                            });
                          },
                          child: Text(
                            _isRegisterMode
                                ? 'Already have an account? Sign In'
                                : t('register_link'),
                            style: TextStyle(color: _roleColor, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleTab({
    required BuildContext context,
    required String role,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedRole == role;
    final isDark = AppTheme.isDark(context);
    return Expanded(
      child: GestureDetector(
        onTap: () => _onRoleChanged(role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? color.withValues(alpha: 0.22) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: isDark ? Colors.black38 : color.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : AppTheme.getTextSecondary(context), size: 20),
              const SizedBox(height: 5),
              Text(
                role == 'COLLECTOR' ? 'Collector' : (role == 'RECYCLER' ? 'Recycler' : 'Admin'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? AppTheme.getTextPrimary(context) : AppTheme.getTextSecondary(context),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _demoButton({
    required BuildContext context,
    required String label,
    required String sub,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(color: AppTheme.getTextPrimary(context), fontWeight: FontWeight.w700, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _roleDescription() {
    switch (_selectedRole) {
      case 'COLLECTOR':
        return 'Access AI Lens waste assessment, fair pricing, vernacular voice input, and offline lot collection.';
      case 'RECYCLER':
        return 'Access the open marketplace to bid on verified scrap lots and verify scale weights via OTP.';
      case 'ADMIN':
        return 'Monitor live circularity KPIs (CO2e, heavy metals), price anomaly radar, and tamper-evident ledgers.';
      default:
        return '';
    }
  }
}
