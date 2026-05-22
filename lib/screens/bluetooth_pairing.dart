import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../models/metawear_device.dart';
import '../services/metawear_service.dart';
import '../widgets/decorative_blobs.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';



class BluetoothPairingPage extends StatefulWidget {
  const BluetoothPairingPage({super.key, required this.onPairingSuccess});
  final VoidCallback onPairingSuccess;

  @override
  State<BluetoothPairingPage> createState() => _BluetoothPairingPageState();
}

class _BluetoothPairingPageState extends State<BluetoothPairingPage>
    with SingleTickerProviderStateMixin {
  late MetaWearService _metaWearService;
  List<MetawearDevice> _scannedDevices = [];
  MetawearDevice? _selectedDevice;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  String _error = '';
  String _logMessage = '';

  Timer? _redirectTimer;
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _metaWearService = MetaWearService();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    // Listen to connection state changes
    _metaWearService.connectionStateStream.listen((connected) {
      if (!mounted) return;
      setState(() {
        _isConnected = connected;
        if (connected) {
          _error = '';
          _redirectTimer = Timer(const Duration(seconds: 2), () {
            if (!mounted) return;
            widget.onPairingSuccess();
          });
        }
      });
    });

    // Listen to log messages
    _metaWearService.logStream.listen((msg) {
      if (!mounted) return;
      setState(() => _logMessage = msg);
    });

    _startScanning();
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _spin.dispose();
    _metaWearService.dispose();
    super.dispose();
  }

  Future<void> _startScanning() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _error = '';
      _scannedDevices = [];
    });

    try {
      await _metaWearService.scanAndConnect();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Błąd: ${e.toString()}';
        _isScanning = false;
      });
    }
  }

  Future<void> _handleConnect() async {
    if (_selectedDevice == null) return;

    setState(() {
      _isConnecting = true;
      _error = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedDevice', _selectedDevice!.id);

      await _metaWearService.connect(_selectedDevice!.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Błąd połączenia: ${e.toString()}';
        _isConnecting = false;
      });
    }
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
          'Wyszukuję urządzenia MetaWear...',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.purple300, fontSize: 14),
        ),
        const SizedBox(height: 12),
        if (_isScanning) ...[
          Center(
            child: Column(
              children: [
                RotationTransition(
                  turns: _spin,
                  child: const Icon(Icons.bluetooth_searching,
                      size: 32, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text('Skanowanie...',
                    style: TextStyle(color: AppColors.purple300, fontSize: 12)),
              ],
            ),
          ),
        ] else if (_scannedDevices.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.amber500.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.amber400.withValues(alpha: 0.20)),
            ),
            child: Column(
              children: [
                Text(
                  'Nie znaleziono urządzeń',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.amber300, fontSize: 12),
                ),
                const SizedBox(height: 12),
                PrimaryGradientButton(
                  onPressed: _startScanning,
                  enabled: true,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 16),
                      SizedBox(width: 8),
                      Text('Ponownie skanuj'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _scannedDevices.length,
            itemBuilder: (context, index) {
              final device = _scannedDevices[index];
              final selected = _selectedDevice?.id == device.id;
              return GestureDetector(
                onTap: _isConnecting
                    ? null
                    : () => setState(() => _selectedDevice = device),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name.isEmpty ? 'Urządzenie' : device.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.id,
                        style: TextStyle(
                          color: AppColors.purple300,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (device.rssi != 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Siła sygnału: ${device.rssi} dBm',
                          style: TextStyle(
                            color: AppColors.purple200,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 20),
        _instructions(),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 20),
          _errorBox(),
        ],
        if (_logMessage.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.20)),
            ),
            child: Text(
              _logMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blue[300], fontSize: 11),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (_selectedDevice != null && !_isScanning) ...[
          const SizedBox(height: 20),
          PrimaryGradientButton(
            onPressed: _isConnecting ? null : _handleConnect,
            enabled: !_isConnecting,
            child: _isConnecting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotationTransition(
                        turns: _spin,
                        child: const Icon(Icons.refresh, size: 16),
                      ),
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
                      Text('Połącz z ${_selectedDevice?.name ?? 'urządzeniem'}'),
                    ],
                  ),
          ),
        ],
      ],
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
          Text(_selectedDevice?.name ?? 'MetaWear',
              style: TextStyle(color: AppColors.purple300, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RotationTransition(
                turns: _spin,
                child: const Icon(Icons.refresh, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text('Przekierowywanie...',
                  style: TextStyle(color: AppColors.purple300, fontSize: 14)),
            ],
          ),
        ],
      ),
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
