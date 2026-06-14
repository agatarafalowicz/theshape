import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_theme.dart';
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
  bool _isRequesting = false;
  String _error = '';
  bool _granted = false;

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
    _redirectTimer?.cancel();
    _spin.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (_isRequesting) return;
    setState(() {
      _isRequesting = true;
      _error = '';
    });

    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      final anyDenied = statuses.values.any(
        (s) => s.isDenied || s.isPermanentlyDenied,
      );

      if (anyDenied) {
        setState(() {
          _error = 'Aplikacja wymaga uprawnień Bluetooth i lokalizacji.';
          _isRequesting = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _granted = true;
        _isRequesting = false;
      });

      _redirectTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        widget.onPairingSuccess();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Błąd przy żądaniu uprawnień: $e';
        _isRequesting = false;
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
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Potrzebujemy uprawnień',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Aby wykrywać i łączyć się z MetaWear aplikacja potrzebuje dostępu do Bluetooth i lokalizacji.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.purple300,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                PrimaryGradientButton(
                                  onPressed: _isRequesting
                                      ? null
                                      : _requestPermissions,
                                  enabled: !_isRequesting,
                                  child: _isRequesting
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            RotationTransition(
                                              turns: _spin,
                                              child: const Icon(
                                                Icons.refresh,
                                                size: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text('Proszę o permisje...'),
                                          ],
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.verified_user, size: 16),
                                            SizedBox(width: 8),
                                            Text('Przyznaj permisje'),
                                          ],
                                        ),
                                ),
                                if (_error.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.red500.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.red400.withValues(
                                          alpha: 0.20,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      _error,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.red300,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
          child: const Icon(
            Icons.sports_esports,
            color: Colors.white,
            size: 36,
          ),
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
          'Pozwól na dostęp do Bluetooth',
          style: TextStyle(color: AppColors.purple300, fontSize: 14),
        ),
      ],
    );
  }
}
