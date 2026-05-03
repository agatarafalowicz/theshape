import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../widgets/decorative_blobs.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLoginSuccess});
  final VoidCallback onLoginSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _mockUser = {
    'id': 1,
    'name': 'Test Test',
    'email': 'test@t.pl',
    'password': 'password',
  };

  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _registerName = TextEditingController();
  final _registerEmail = TextEditingController();
  final _registerPassword = TextEditingController();

  String _tab = 'login';
  String _error = '';
  bool _showLoginPass = false;
  bool _showRegPass = false;

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPassword.dispose();
    _registerName.dispose();
    _registerEmail.dispose();
    _registerPassword.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _error = '');
    final email = _loginEmail.text.trim();
    final pass = _loginPassword.text;

    if (email == _mockUser['email'] && pass == _mockUser['password']) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUser', jsonEncode(_mockUser));
      widget.onLoginSuccess();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('users') ?? '[]';
    final users = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final user = users.firstWhere(
      (u) => u['email'] == email && u['password'] == pass,
      orElse: () => const {},
    );

    if (user.isNotEmpty) {
      await prefs.setString('currentUser', jsonEncode(user));
      widget.onLoginSuccess();
    } else {
      setState(() => _error = 'Nieprawidłowy email lub hasło');
    }
  }

  Future<void> _handleRegister() async {
    setState(() => _error = '');
    final name = _registerName.text.trim();
    final email = _registerEmail.text.trim();
    final pass = _registerPassword.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Wszystkie pola są wymagane');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('users') ?? '[]';
    final users = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    if (users.any((u) => u['email'] == email)) {
      setState(() => _error = 'Użytkownik z tym emailem już istnieje');
      return;
    }

    final newUser = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'name': name,
      'email': email,
      'password': pass,
    };
    users.add(newUser);
    await prefs.setString('users', jsonEncode(users));
    await prefs.setString('currentUser', jsonEncode(newUser));
    widget.onLoginSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Stack(
          children: [
            const DecorativeBlobs(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 384),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LogoHeader(subtitle: 'Sprawdź swoje możliwości'),
                        const SizedBox(height: 32),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _TabSwitcher(
                                tab: _tab,
                                onChanged: (t) => setState(() {
                                  _tab = t;
                                  _error = '';
                                }),
                              ),
                              const SizedBox(height: 24),
                              if (_tab == 'login') ..._buildLoginForm(),
                              if (_tab == 'register') ..._buildRegisterForm(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'The Shape v1.0.0',
                          style: TextStyle(
                            color: AppColors.purple500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLoginForm() {
    return [
      _IconInput(
        controller: _loginEmail,
        hint: 'Email',
        icon: Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),
      _IconInput(
        controller: _loginPassword,
        hint: 'Hasło',
        icon: Icons.lock_outline,
        obscure: !_showLoginPass,
        suffix: IconButton(
          icon: Icon(
            _showLoginPass ? Icons.visibility_off : Icons.visibility,
            size: 18,
            color: AppColors.purple400,
          ),
          onPressed: () => setState(() => _showLoginPass = !_showLoginPass),
        ),
      ),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 16),
        _ErrorBanner(text: _error),
      ],
      const SizedBox(height: 16),
      PrimaryGradientButton(
        onPressed: _handleLogin,
        child: const Text('Zaloguj się'),
      ),
    ];
  }

  List<Widget> _buildRegisterForm() {
    return [
      _IconInput(
        controller: _registerName,
        hint: 'Imię i nazwisko',
        icon: Icons.person_outline,
      ),
      const SizedBox(height: 16),
      _IconInput(
        controller: _registerEmail,
        hint: 'Email',
        icon: Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),
      _IconInput(
        controller: _registerPassword,
        hint: 'Hasło',
        icon: Icons.lock_outline,
        obscure: !_showRegPass,
        suffix: IconButton(
          icon: Icon(
            _showRegPass ? Icons.visibility_off : Icons.visibility,
            size: 18,
            color: AppColors.purple400,
          ),
          onPressed: () => setState(() => _showRegPass = !_showRegPass),
        ),
      ),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 16),
        _ErrorBanner(text: _error),
      ],
      const SizedBox(height: 16),
      PrimaryGradientButton(
        onPressed: _handleRegister,
        child: const Text('Zarejestruj się'),
      ),
    ];
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader({required this.subtitle});
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: AppColors.ctaGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange500.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.sports_esports,
              color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        const Text(
          'The Shape',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: AppColors.purple300, fontSize: 14),
        ),
      ],
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({required this.tab, required this.onChanged});
  final String tab;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _tabItem('Logowanie', 'login'),
          _tabItem('Rejestracja', 'register'),
        ],
      ),
    );
  }

  Widget _tabItem(String label, String key) {
    final selected = key == tab;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.purple300,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconInput extends StatelessWidget {
  const _IconInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.suffix,
    this.obscure = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Widget? suffix;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: AppColors.purple300,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.purple400, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.purple400, size: 18),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 40),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.10),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _border(Colors.white.withValues(alpha: 0.15)),
        enabledBorder: _border(Colors.white.withValues(alpha: 0.15)),
        focusedBorder: _border(AppColors.purple400),
      ),
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: 1),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.red500.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red500.withValues(alpha: 0.20)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.red400, fontSize: 12),
      ),
    );
  }
}
