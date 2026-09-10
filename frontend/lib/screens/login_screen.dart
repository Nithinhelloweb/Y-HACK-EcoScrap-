import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../i18n/translations.dart';

class LoginScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthService authService;
  final String currentLang;
  final Function(String) onLangChanged;

  const LoginScreen({
    super.key,
    required this.apiService,
    required this.authService,
    required this.currentLang,
    required this.onLangChanged,
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
        return Colors.tealAccent;
      case 'RECYCLER':
        return Colors.lightBlueAccent;
      case 'ADMIN':
        return Colors.purpleAccent;
      default:
        return Colors.tealAccent;
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
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.recycling_rounded, color: Colors.tealAccent, size: 24),
            ),
            const SizedBox(width: 10),
            Text(
              t('app_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButton<String>(
              value: widget.currentLang,
              underline: const SizedBox(),
              dropdownColor: const Color(0xFF1C2541),
              icon: const Icon(Icons.language, color: Colors.tealAccent, size: 18),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'ta', child: Text('தமிழ்', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'hi', child: Text('हिंदी', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (val) {
                if (val != null) widget.onLangChanged(val);
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tagline & Intro
                Text(
                  t('login_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  t('login_subtitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 20),

                // 1-Tap Quick Demo Logins Section
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2541),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt, color: Colors.amberAccent, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t('quick_demo_heading'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // 3 Quick Login Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _demoButton(
                              label: 'Collector',
                              sub: 'Murugan K.',
                              color: Colors.teal,
                              icon: Icons.person_pin_circle_rounded,
                              onTap: () => _handleQuickDemo('COLLECTOR'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _demoButton(
                              label: 'Recycler',
                              sub: 'GreenTech',
                              color: Colors.indigo,
                              icon: Icons.factory_rounded,
                              onTap: () => _handleQuickDemo('RECYCLER'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _demoButton(
                              label: 'Admin',
                              sub: 'CPCB Officer',
                              color: Colors.purple,
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
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2541),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _roleTab(
                        role: 'COLLECTOR',
                        label: t('role_collector'),
                        icon: Icons.handyman_rounded,
                        color: Colors.tealAccent,
                      ),
                      _roleTab(
                        role: 'RECYCLER',
                        label: t('role_recycler'),
                        icon: Icons.precision_manufacturing_rounded,
                        color: Colors.lightBlueAccent,
                      ),
                      _roleTab(
                        role: 'ADMIN',
                        label: t('role_admin'),
                        icon: Icons.gavel_rounded,
                        color: Colors.purpleAccent,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Contextual Role Explanation Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _roleColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _roleColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: _roleColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _roleDescription(),
                          style: TextStyle(color: _roleColor, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Main Credential Form Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2541),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: Text(
                            '⚠️ $_errorMessage',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (!_isRegisterMode) ...[
                        // Identifier Field
                        TextField(
                          controller: _identifierController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: t('identifier_label'),
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.badge_outlined, color: Colors.tealAccent),
                            filled: true,
                            fillColor: const Color(0xFF0B132B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: t('password_label'),
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.tealAccent),
                            suffixIcon: IconButton(
                              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF0B132B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Login Action Button
                        ElevatedButton(
                          onPressed: widget.authService.isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _roleColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: widget.authService.isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : Text(
                                  '${t('login_button')} as $_selectedRole',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                      ] else ...[
                        // Registration Form
                        TextField(
                          controller: _regNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Full Name / Organization Name',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.person_outline, color: Colors.tealAccent),
                            filled: true,
                            fillColor: const Color(0xFF0B132B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _regPhoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: '10-Digit Mobile Number',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.phone_outlined, color: Colors.tealAccent),
                            filled: true,
                            fillColor: const Color(0xFF0B132B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _regPasswordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Choose Password',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.tealAccent),
                            filled: true,
                            fillColor: const Color(0xFF0B132B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: widget.authService.isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _roleColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: widget.authService.isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : Text(
                                  'Register as $_selectedRole',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                            style: const TextStyle(color: Colors.tealAccent, fontSize: 13),
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
    required String role,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onRoleChanged(role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.white60, size: 20),
              const SizedBox(height: 4),
              Text(
                role == 'COLLECTOR' ? 'Collector' : (role == 'RECYCLER' ? 'Recycler' : 'Admin'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    required String label,
    required String sub,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Text(
              sub,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
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
