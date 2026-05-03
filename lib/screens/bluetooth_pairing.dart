import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../widgets/decorative_blobs.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

enum SensorType { rl, s, c }

extension on SensorType {
  String get label => switch (this) {
        SensorType.rl => 'RL',
        SensorType.s => 'S',
        SensorType.c => 'C',
      };
}

class BluetoothPairingPage extends StatefulWidget {
  const BluetoothPairingPage({super.key, required this.onPairingSuccess});
  final VoidCallback onPairingSuccess;

  @override
  State<BluetoothPairingPage> createState() => _BluetoothPairingPageState();
}

class _BluetoothPairingPageState extends State<BluetoothPairingPage>
    with SingleTickerProviderStateMixin {
  bool _isConnecting = false;
  bool _isConnected = false;
  String _error = '';
  String _deviceName = '';
  bool _isSimulationMode = false;
  SensorType? _selectedSensor;

  Timer? _connectTimer;
  Timer? _redirectTimer;

  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _connectTimer?.cancel();
    _redirectTimer?.cancel();
    _spin.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    if (_selectedSensor == null) return;
    setState(() {
      _isConnecting = true;
      _error = '';
      _isSimulationMode = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedSensor', _selectedSensor!.label);

    _connectTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _deviceName = 'MetaMotion ${_selectedSensor!.label}';
        _isConnected = true;
        _isConnecting = false;
      });
      _redirectTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        widget.onPairingSuccess();
      });
    });
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
                        _LogoHeader(),
                        const SizedBox(height: 32),
                        GlassCard(
                          child: _isConnected
                              ? _buildConnected()
                              : _buildPairing(),
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

  Widget _buildPairing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Z jakiego czujnika MetaMotion korzystasz?',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.purple300, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final s in SensorType.values) ...[
              Expanded(child: _sensorTile(s)),
              if (s != SensorType.values.last) const SizedBox(width: 12),
            ],
          ],
        ),
        const SizedBox(height: 20),
        _instructions(),
        if (_isSimulationMode && !_isConnected && _error.isEmpty) ...[
          const SizedBox(height: 20),
          _simulationNotice(),
        ],
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 20),
          _errorBox(),
        ],
        if (_selectedSensor != null) ...[
          const SizedBox(height: 20),
          PrimaryGradientButton(
            onPressed: _isConnecting ? null : _handleConnect,
            enabled: !_isConnecting,
            child: _isConnecting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _spinnerIcon(),
                      const SizedBox(width: 8),
                      const Text('Łączenie...'),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bluetooth, size: 16),
                      const SizedBox(width: 8),
                      Text('Połącz z MetaMotion ${_selectedSensor!.label}'),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  Widget _sensorTile(SensorType s) {
    final selected = _selectedSensor == s;
    return GestureDetector(
      onTap: _isConnecting ? null : () => setState(() => _selectedSensor = s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.purple500.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.purple400
                : Colors.white.withValues(alpha: 0.15),
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.purple400.withValues(alpha: 0.30),
                    blurRadius: 0,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            s.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _instructions() {
    final items = const [
      'MetaMotion jest włączony',
      'Urządzenie jest w pobliżu',
      'Bluetooth jest aktywny',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upewnij się, że:',
            style: TextStyle(
              color: AppColors.purple300,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.purple400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(item,
                      style: TextStyle(
                          color: AppColors.purple200, fontSize: 12)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _simulationNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber500.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amber400.withValues(alpha: 0.20)),
      ),
      child: Text(
        'Tryb symulacji – Web Bluetooth API niedostępne',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.amber300, fontSize: 12),
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red500.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red400.withValues(alpha: 0.20)),
      ),
      child: Text(
        _error,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.red300, fontSize: 12),
      ),
    );
  }

  Widget _buildConnected() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.greenGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.green400.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Połączono!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_deviceName,
              style: TextStyle(color: AppColors.purple300, fontSize: 14)),
          if (_isSimulationMode) ...[
            const SizedBox(height: 4),
            Text('(Tryb symulacji)',
                style: TextStyle(color: AppColors.amber400, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _spinnerIcon(color: AppColors.purple300),
              const SizedBox(width: 8),
              Text('Przekierowywanie...',
                  style: TextStyle(color: AppColors.purple300, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _spinnerIcon({Color color = Colors.white}) {
    return RotationTransition(
      turns: _spin,
      child: Icon(Icons.refresh, size: 16, color: color),
    );
  }
}

class _LogoHeader extends StatelessWidget {
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
          'Podłącz swój czujnik',
          style: TextStyle(color: AppColors.purple300, fontSize: 14),
        ),
      ],
    );
  }
}
