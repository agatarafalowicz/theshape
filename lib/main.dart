import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/bluetooth_pairing.dart';
import 'screens/login_page.dart';
import 'screens/main_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  runApp(const TheShapeApp());
}

class TheShapeApp extends StatelessWidget {
  const TheShapeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'The Shape',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF312E81),
      ),
      home: const _AppRoot(),
    );
  }
}

enum _AppState { login, bluetooth, main }

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  _AppState _state = _AppState.login;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final hasUser = prefs.getString('currentUser') != null;
    final paired = prefs.getBool('devicePaired') ?? false;
    setState(() {
      if (hasUser) {
        _state = paired ? _AppState.main : _AppState.bluetooth;
      } else {
        _state = _AppState.login;
      }
      _bootstrapped = true;
    });
  }

  Future<void> _handleLoginSuccess() async {
    setState(() => _state = _AppState.bluetooth);
  }

  Future<void> _handlePairingSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('devicePaired', true);
    setState(() => _state = _AppState.main);
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUser');
    await prefs.remove('devicePaired');
    setState(() => _state = _AppState.login);
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootstrapped) {
      return const Scaffold(
        backgroundColor: Color(0xFF312E81),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    switch (_state) {
      case _AppState.login:
        return LoginPage(onLoginSuccess: _handleLoginSuccess);
      case _AppState.bluetooth:
        return BluetoothPairingPage(onPairingSuccess: _handlePairingSuccess);
      case _AppState.main:
        return MainPage(onLogout: _handleLogout);
    }
  }
}
