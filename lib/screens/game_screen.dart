import '../services/api_service.dart';
import '../services/metawear_service.dart';
import '../services/metawear_protocol.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_theme.dart';
import '../widgets/shape_widget.dart';

const int kGestureWindowSize = 64;

const Map<String, String> kMovementIdToLabel = {
  'wave': 'Fala',
  'waving': 'Machanie',
  'circle_cw': 'Okrag_CW',
  'circle_ccw': 'Okrag_CCW',
  'up_down': 'Gora-dol',
};

const int _totalRounds = 10;

class _Shape {
  final ShapeId id;
  final String name;
  const _Shape(this.id, this.name);
}

class _Movement {
  final String id;
  final String name;
  const _Movement(this.id, this.name);
}

const _shapes = <_Shape>[
  _Shape(ShapeId.square, 'Kwadrat'),
  _Shape(ShapeId.triangle, 'Trójkąt'),
  _Shape(ShapeId.circle, 'Koło'),
  _Shape(ShapeId.star, 'Gwiazda'),
  _Shape(ShapeId.diamond, 'Romb'),
];

const _movements = <_Movement>[
  _Movement('wave', 'Fala'),
  _Movement('waving', 'Machanie'),
  _Movement('circle_cw', 'Okrąg w prawo'),
  _Movement('circle_ccw', 'Okrąg w lewo'),
  _Movement('up_down', 'Góra-dół'),
];

class _Pair {
  final _Shape shape;
  final _Movement movement;
  const _Pair(this.shape, this.movement);
}

List<_Pair> _buildMapping() {
  final mov = List<_Movement>.from(_movements);
  mov.shuffle(Random());
  return List<_Pair>.generate(_shapes.length, (i) => _Pair(_shapes[i], mov[i]));
}

enum _Phase { learning, bravo, ready, playing, finished }

enum _RoundResult { none, correct, incorrect }

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.onClose,
    required this.onGameFinished,
    required this.userId,
  });

  final VoidCallback onClose;
  final VoidCallback onGameFinished;
  final int? userId;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late List<_Pair> _mapping;
  _Phase _phase = _Phase.learning;
  int _learnIdx = 0;

  List<_Pair> _gameShapes = [];
  int _gameIdx = 0;
  int _score = 0;
  _RoundResult _roundResult = _RoundResult.none;
  int _totalTimeUsed = 0; // seconds
  DateTime? _gameStartedAt;

  Timer? _learnTimer;
  Timer? _bravoTimer;
  Timer? _resultTimer;

  late final AnimationController _pulse;

  final _service = MetaWearService();
  final _localAccBuf = <SensorSample>[];
  final _localGyroBuf = <SensorSample>[];
  StreamSubscription<SensorSample>? _accSub;
  StreamSubscription<SensorSample>? _gyroSub;
  StreamSubscription<bool>? _connSub;
  StreamSubscription<String>? _logSub;
  bool _isPredicting = false;
  bool _isInitializingSensor = false;
  bool _connected = false;
  String _serviceLog = '';
  String? _rememberedDeviceId;
  String? _rememberedDeviceName;

  // Ostatnie odczytane wartości z czujników
  SensorSample? _lastAcc;
  SensorSample? _lastGyro;
  // Ostatnie wysłane dane do API
  String? _lastPrediction;
  String? _expectedMovement;

  @override
  void initState() {
    super.initState();
    _mapping = _buildMapping();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _scheduleLearningAdvance();
    _accSub = _service.accStream.listen((s) {
      setState(() => _lastAcc = s);
      if (_phase == _Phase.playing) _localAccBuf.add(s);
    });
    _gyroSub = _service.gyroStream.listen((s) {
      setState(() => _lastGyro = s);
      if (_phase == _Phase.playing) _localGyroBuf.add(s);
    });
    _connSub = _service.connectionStateStream.listen((c) {
      if (!mounted) return;
      setState(() => _connected = c);
    });
    _logSub = _service.logStream.listen((m) {
      if (!mounted) return;
      setState(() => _serviceLog = m);
    });
    _loadRememberedDevice();
  }

  Future<void> _loadRememberedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _rememberedDeviceId = prefs.getString('selectedDevice');
      _rememberedDeviceName = prefs.getString('selectedDeviceName');
    });
  }

  @override
  void dispose() {
    _learnTimer?.cancel();
    _bravoTimer?.cancel();
    _resultTimer?.cancel();
    _pulse.dispose();
    _accSub?.cancel();
    _gyroSub?.cancel();
    _connSub?.cancel();
    _logSub?.cancel();
    _service.stopIMU();
    _service.dispose();
    super.dispose();
  }

  Future<void> _connectAndStartIMU() async {
    if (_isInitializingSensor) return;
    if (_service.isRunning) return;
    setState(() => _isInitializingSensor = true);
    final prefs = await SharedPreferences.getInstance();
    final deviceId = _rememberedDeviceId ?? prefs.getString('selectedDevice');
    if (deviceId != null && deviceId.isNotEmpty) {
      try {
        await _service.connect(deviceId);
        await _service.startIMU();
        if (mounted) {
          setState(() => _rememberedDeviceId = deviceId);
        }
      } catch (e) {
        debugPrint('IMU connect error: $e');
      }
    }
    if (mounted) setState(() => _isInitializingSensor = false);
  }

  Future<void> _saveGameResult() async {
    debugPrint('SAVE GAME START');
    if (_gameStartedAt != null) {
      _totalTimeUsed = DateTime.now().difference(_gameStartedAt!).inSeconds;
    }
    await _service.stopIMU();

    if (widget.userId == null) {
      widget.onGameFinished();
      return;
    }

    debugPrint('user=${widget.userId} score=$_score time=$_totalTimeUsed');

    try {
      await ApiService.saveGame(
        userId: widget.userId!,
        points: _score,
        length: _totalTimeUsed,
        won: _score >= (_totalRounds / 2),
        livesLeft: null,
      );
    } catch (e) {
      debugPrint('SAVE GAME ERROR: $e');
    }
    // After saving result, fully disconnect and forget the device so the
    // next game requires explicit pairing/connection.
    try {
      await _service.disconnect();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selectedDevice');
    } catch (_) {}
    setState(() {
      _connected = false;
      _serviceLog = '';
    });

    widget.onGameFinished();
  }

  void _scheduleLearningAdvance() {
    _learnTimer?.cancel();
    _learnTimer = Timer(const Duration(milliseconds: 2500), _advanceLearning);
  }

  void _advanceLearning() {
    _learnTimer?.cancel();
    if (_learnIdx < _shapes.length - 1) {
      setState(() => _phase = _Phase.bravo);
      _bravoTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          _learnIdx++;
          _phase = _Phase.learning;
        });
        _scheduleLearningAdvance();
      });
    } else {
      setState(() => _phase = _Phase.bravo);
      _bravoTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() => _phase = _Phase.ready);
      });
    }
  }

  void _advanceRound(bool wasCorrect) {
    setState(() {
      if (wasCorrect) _score++;
      _roundResult = wasCorrect ? _RoundResult.correct : _RoundResult.incorrect;
    });
    _resultTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final next = _gameIdx + 1;
      setState(() => _roundResult = _RoundResult.none);
      if (next >= _totalRounds) {
        _saveGameResult();

        setState(() {
          _phase = _Phase.finished;
        });
      } else {
        setState(() {
          _gameIdx = next;
        });
      }
    });
  }

  void _startGame() {
    final rng = Random();
    final shapes = List<_Pair>.generate(
      _totalRounds,
      (_) => _mapping[rng.nextInt(_mapping.length)],
    );
    setState(() {
      _gameShapes = shapes;
      _gameIdx = 0;
      _score = 0;
      _totalTimeUsed = 0;
      _gameStartedAt = DateTime.now();
      _localAccBuf.clear();
      _localGyroBuf.clear();
      _roundResult = _RoundResult.none;
      _phase = _Phase.playing;
      _lastPrediction = null;
      _expectedMovement = null;
    });
  }

  Future<void> _checkGesture() async {
    if (_isPredicting || _roundResult != _RoundResult.none) return;

    final accCount = _localAccBuf.length;
    final gyroCount = _localGyroBuf.length;
    if (accCount < kGestureWindowSize || gyroCount < kGestureWindowSize) return;

    setState(() => _isPredicting = true);

    final accSlice = _localAccBuf.sublist(accCount - kGestureWindowSize);
    final gyroSlice = _localGyroBuf.sublist(gyroCount - kGestureWindowSize);
    final points = List.generate(
      kGestureWindowSize,
      (i) => [
        accSlice[i].x,
        accSlice[i].y,
        accSlice[i].z,
        gyroSlice[i].x,
        gyroSlice[i].y,
        gyroSlice[i].z,
      ],
    );

    final expectedLabel =
        kMovementIdToLabel[_gameShapes[_gameIdx].movement.id] ?? '';
    setState(() => _expectedMovement = expectedLabel);

    try {
      final result = await ApiService.predictGesture(points);
      final predicted = result['label'] as String;
      setState(() => _lastPrediction = predicted);
      if (mounted && _roundResult == _RoundResult.none) {
        _advanceRound(predicted == expectedLabel);
      }
    } catch (_) {
      if (mounted && _roundResult == _RoundResult.none) {
        _advanceRound(false);
      }
    } finally {
      if (mounted) setState(() => _isPredicting = false);
    }
  }

  void _restart() {
    setState(() {
      _mapping = _buildMapping();
      _learnIdx = 0;
      _phase = _Phase.learning;
      _score = 0;
      _roundResult = _RoundResult.none;
      _totalTimeUsed = 0;
      _gameStartedAt = null;
      _lastPrediction = null;
      _expectedMovement = null;
    });
    _scheduleLearningAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final showSheet =
        _phase == _Phase.learning ||
        _phase == _Phase.playing ||
        _phase == _Phase.bravo;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(child: _content()),
              if (_phase == _Phase.playing) _sensorInitBar(),
              if (_phase == _Phase.playing) _sensorDataPanel(),
              if (showSheet) _cheatSheet(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    Widget center;
    if (_phase == _Phase.learning || _phase == _Phase.bravo) {
      center = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _shapes.length; i++) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == _learnIdx ? 14 : 10,
              height: i == _learnIdx ? 14 : 10,
              margin: EdgeInsets.symmetric(horizontal: i == 0 ? 0 : 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _learnIdx
                    ? AppColors.green400
                    : i == _learnIdx
                    ? AppColors.yellow400
                    : Colors.white.withValues(alpha: 0.20),
              ),
            ),
          ],
        ],
      );
    } else if (_phase == _Phase.playing) {
      center = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.yellow400.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.yellow400.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events,
              color: AppColors.yellow400,
              size: 16,
            ),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: AppColors.yellow400,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(text: '$_score'),
                  TextSpan(
                    text: ' / ${min(_gameIdx + 1, _totalRounds)}',
                    style: TextStyle(
                      color: AppColors.yellow400.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      center = const SizedBox.shrink();
    }

    final right = const SizedBox(width: 36);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () async {
              try {
                if (_service.isRunning) await _service.stopIMU();
              } catch (_) {}
              try {
                await _service.disconnect();
              } catch (_) {}
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('selectedDevice');
              } catch (_) {}
              setState(() {
                _connected = false;
                _serviceLog = '';
              });
              widget.onClose();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          center,
          right,
        ],
      ),
    );
  }

  Widget _content() {
    switch (_phase) {
      case _Phase.learning:
      case _Phase.bravo:
        return _learningContent();
      case _Phase.ready:
        return _readyContent();
      case _Phase.playing:
        return _playingContent();
      case _Phase.finished:
        return _finishedContent();
    }
  }

  Widget _learningContent() {
    final pair = _mapping[_learnIdx];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Text(
            'Kształt ${_learnIdx + 1} / ${_shapes.length}',
            style: TextStyle(color: AppColors.purple300, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 192,
                height: 192,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Center(child: ShapeWidget(id: pair.shape.id, size: 130)),
              ),
              if (_phase == _Phase.bravo)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green400.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Brawo! Pora na kolejny!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            pair.shape.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Text(
                  'Wykonaj ruch:',
                  style: TextStyle(color: AppColors.purple300, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  pair.movement.name,
                  style: const TextStyle(
                    color: AppColors.yellow400,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          if (_phase == _Phase.learning || _phase == _Phase.bravo) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pulseDot(AppColors.purple400),
                const SizedBox(width: 8),
                Text(
                  _phase == _Phase.learning
                      ? 'Czekam na ruch czujnika…'
                      : 'Zaraz przechodzimy dalej…',
                  style: TextStyle(color: AppColors.purple400, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _skipTutorial,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pomiń samouczek',
                    style: TextStyle(color: AppColors.purple400, fontSize: 14),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.purple400,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _readyContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.greenGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.green400.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Świetnie!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Znasz już wszystkie kształty.\nCzas sprawdzić się na czas!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.purple300, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _mappingCard(),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _startGame,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: AppColors.ctaGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orange500.withValues(alpha: 0.30),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_esports, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Zagraj w grę!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playingContent() {
    if (_gameShapes.isEmpty) return const SizedBox();
    final pair = _gameShapes[min(_gameIdx, _gameShapes.length - 1)];
    final correct = _roundResult == _RoundResult.correct;
    final incorrect = _roundResult == _RoundResult.incorrect;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Text(
            'Jaki ruch wykonać?',
            style: TextStyle(color: AppColors.purple300, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 208,
                height: 208,
                decoration: BoxDecoration(
                  color: correct
                      ? AppColors.green400.withValues(alpha: 0.10)
                      : incorrect
                      ? AppColors.red400.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: correct
                        ? AppColors.green400.withValues(alpha: 0.60)
                        : incorrect
                        ? AppColors.red400.withValues(alpha: 0.60)
                        : Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Center(child: ShapeWidget(id: pair.shape.id, size: 140)),
              ),
              if (_roundResult != _RoundResult.none)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: correct
                        ? AppColors.green400.withValues(alpha: 0.90)
                        : AppColors.red500.withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    correct ? '✓ Poprawnie!' : '✗ Niepoprawnie!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            pair.shape.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_roundResult == _RoundResult.none) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final collected = min(
                  _localAccBuf.length,
                  _localGyroBuf.length,
                );
                final ready = collected >= kGestureWindowSize && !_isPredicting;
                return GestureDetector(
                  onTap: ready ? _checkGesture : null,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: ready ? 1.0 : 0.5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isPredicting)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            Text(
                              ready ? 'Zakończ ruch' : 'Czekam na dane...',
                              style: TextStyle(
                                color: AppColors.purple300,
                                fontSize: 12,
                              ),
                            ),
                          if (!_isPredicting)
                            Icon(
                              Icons.chevron_right,
                              color: AppColors.purple300,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _connectAndStartIMU,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isInitializingSensor)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        _service.isRunning
                            ? Icons.bluetooth_connected
                            : Icons.sensors,
                        color: AppColors.purple300,
                        size: 16,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _service.isRunning
                          ? 'Czujnik aktywny'
                          : 'Inicjalizuj czujnik',
                      style: TextStyle(
                        color: AppColors.purple300,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _finishedContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.ctaGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange500.withValues(alpha: 0.30),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Wynik końcowy',
            style: TextStyle(color: AppColors.purple300, fontSize: 14),
          ),
          Text(
            '$_score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '/ $_totalRounds poprawnych ruchów',
            style: TextStyle(color: AppColors.purple300, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Czas gry',
                  style: TextStyle(color: AppColors.purple300, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(_totalTimeUsed),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Średnio na rundę: ${_formatTime((_totalTimeUsed / _totalRounds).round())}',
                  style: TextStyle(color: AppColors.purple300, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Opacity(
                    opacity: _score >= const [5, 7, 10][i] ? 1 : 0.2,
                    child: const Text('⭐', style: TextStyle(fontSize: 24)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _mappingCard(headline: 'Kształty tej gry:'),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _restart,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.ctaGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orange500.withValues(alpha: 0.30),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_esports, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Zagraj ponownie',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              try {
                if (_service.isRunning) await _service.stopIMU();
              } catch (_) {}
              try {
                await _service.disconnect();
              } catch (_) {}
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('selectedDevice');
              } catch (_) {}
              setState(() {
                _connected = false;
                _serviceLog = '';
              });
              widget.onClose();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Center(
                child: Text(
                  'Wróć do menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mappingCard({String? headline}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headline != null) ...[
            Text(
              headline,
              style: TextStyle(color: AppColors.purple300, fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          for (final pair in _mapping)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ShapeWidget(id: pair.shape.id, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        pair.shape.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        pair.movement.name,
                        style: const TextStyle(
                          color: AppColors.yellow400,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _cheatSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final pair in _mapping)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShapeWidget(id: pair.shape.id, size: 22),
                const SizedBox(height: 4),
                SizedBox(
                  width: 50,
                  child: Text(
                    pair.movement.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.purple400,
                      fontSize: 9,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _sensorInitBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _showPairingDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.ctaGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isInitializingSensor)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(Icons.sensors, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _connected
                          ? 'Czujnik: połączony${_rememberedDeviceName != null ? ' • $_rememberedDeviceName' : ''}'
                          : (_service.isRunning
                                ? 'Czujnik: aktywny${_rememberedDeviceName != null ? ' • $_rememberedDeviceName' : ''}'
                                : 'Uruchom czujnik BLE'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPairingDialog() async {
    if (_isInitializingSensor) return;
    setState(() => _isInitializingSensor = true);

    final devices = <Map<String, dynamic>>[];
    StreamSubscription? sub;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (c, setStateDialog) {
            // start scan when dialog builds
            sub = FlutterBluePlus.scanResults.listen((results) {
              for (final r in results) {
                final name = r.device.platformName;
                final uuids = r.advertisementData.serviceUuids
                    .map((u) => u.toString().toLowerCase())
                    .toList();
                final isMetaWear =
                    name.toLowerCase().contains('metawear') ||
                    name.toLowerCase().contains('metamotion') ||
                    uuids.contains(kServiceUuid.toLowerCase());
                if (!isMetaWear) continue;
                final id = r.device.remoteId.str;
                if (devices.any((d) => d['id'] == id)) continue;
                setStateDialog(() {
                  devices.add({
                    'id': id,
                    'name': name.isEmpty ? 'MetaWear ($id)' : name,
                    'rssi': r.rssi,
                  });
                });
              }
            });

            // Request permissions and start scan
            () async {
              if (Platform.isAndroid) {
                await [
                  Permission.bluetoothScan,
                  Permission.bluetoothConnect,
                  Permission.locationWhenInUse,
                ].request();
              } else if (Platform.isIOS) {
                final bt = await Permission.bluetooth.request();
                if (bt.isDenied || bt.isPermanentlyDenied) return;
              }
              devices.clear();
              await FlutterBluePlus.stopScan();
              await FlutterBluePlus.startScan(
                withServices: [Guid(kServiceUuid)],
                timeout: const Duration(seconds: 12),
              );
            }();

            return AlertDialog(
              backgroundColor: const Color(0xFF17132A),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.ctaGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bluetooth_searching,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Połącz z MetaWear',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Wybierz urządzenie i uruchom czujnik dla tej gry.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          RotationTransition(
                            turns: _pulse,
                            child: const Icon(
                              Icons.radar,
                              color: AppColors.yellow400,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Skanuję BLE i szukam MetaWear w pobliżu.',
                              style: TextStyle(
                                color: AppColors.purple200,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (devices.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.bluetooth_disabled,
                              color: Colors.white54,
                              size: 28,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Skanowanie...',
                              style: TextStyle(
                                color: AppColors.purple300,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Jeśli urządzenie jest włączone, pojawi się tu po chwili.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.purple200,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (devices.isNotEmpty)
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: devices.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final d = devices[i];
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.purple500.withValues(
                                      alpha: 0.20,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.sensors,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  d['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${Platform.isIOS ? 'UUID' : 'MAC'}: ${d['id']}\n${d['rssi']} dBm',
                                  style: TextStyle(
                                    color: AppColors.purple200,
                                    fontSize: 11,
                                    height: 1.2,
                                  ),
                                ),
                                isThreeLine: true,
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await FlutterBluePlus.stopScan();
                                      await sub?.cancel();
                                      await _service.connect(d['id']);
                                      await _service.initializeBoard();
                                      await _service.startIMU();
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setString(
                                        'selectedDevice',
                                        d['id'],
                                      );
                                      await prefs.setString(
                                        'selectedDeviceName',
                                        d['name'] as String,
                                      );
                                      if (mounted) {
                                        setState(() {
                                          _rememberedDeviceId = d['id'];
                                          _rememberedDeviceName =
                                              d['name'] as String;
                                        });
                                      }
                                      if (!mounted) return;
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pop();
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Błąd połączenia: $e'),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Połącz'),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await FlutterBluePlus.stopScan();
                    await sub?.cancel();
                    if (mounted)
                      Navigator.of(context, rootNavigator: true).pop();
                  },
                  child: const Text('Anuluj'),
                ),
              ],
            );
          },
        );
      },
    );

    await FlutterBluePlus.stopScan();
    await sub?.cancel();
    if (mounted) setState(() => _isInitializingSensor = false);
  }

  Widget _sensorDataPanel() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.30),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Akcelerometr
            _sensorCell(
              title: 'ACC',
              emoji: '📍',
              x: _lastAcc?.x ?? 0,
              y: _lastAcc?.y ?? 0,
              z: _lastAcc?.z ?? 0,
            ),
            const SizedBox(width: 8),
            // Żyroskop
            _sensorCell(
              title: 'GYRO',
              emoji: '🔄',
              x: _lastGyro?.x ?? 0,
              y: _lastGyro?.y ?? 0,
              z: _lastGyro?.z ?? 0,
            ),
            // Predykcja
            if (_lastPrediction != null || _expectedMovement != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Predykcja 🎯',
                      style: TextStyle(
                        color: AppColors.purple300,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _lastPrediction ?? '—',
                      style: TextStyle(
                        color: AppColors.yellow400,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_expectedMovement != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'oczek: $_expectedMovement',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 9,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    if (_serviceLog.isNotEmpty)
                      Text(
                        _serviceLog,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _skipTutorial() {
    _learnTimer?.cancel();
    _bravoTimer?.cancel();
    setState(() {
      _learnIdx = _shapes.length - 1;
      _phase = _Phase.ready;
    });
  }

  Widget _sensorCell({
    required String title,
    required String emoji,
    required double x,
    required double y,
    required double z,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$emoji $title',
            style: TextStyle(
              color: AppColors.purple300,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'X: ${x.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.yellow400, fontSize: 10),
          ),
          Text(
            'Y: ${y.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.yellow400, fontSize: 10),
          ),
          Text(
            'Z: ${z.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.yellow400, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _pulseDot(Color color) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.5 + 0.5 * _pulse.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
