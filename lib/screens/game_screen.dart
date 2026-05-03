import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../widgets/shape_widget.dart';

const int _totalRounds = 10;
const int _shapeSeconds = 6;

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
  return List<_Pair>.generate(
    _shapes.length,
    (i) => _Pair(_shapes[i], mov[i]),
  );
}

enum _Phase { learning, bravo, ready, playing, finished }

enum _RoundResult { none, correct, timeout }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late List<_Pair> _mapping;
  _Phase _phase = _Phase.learning;
  int _learnIdx = 0;

  List<_Pair> _gameShapes = [];
  int _gameIdx = 0;
  int _score = 0;
  int _shapeTimeLeft = _shapeSeconds;
  _RoundResult _roundResult = _RoundResult.none;

  Timer? _learnTimer;
  Timer? _bravoTimer;
  Timer? _shapeTicker;
  Timer? _resultTimer;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _mapping = _buildMapping();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _scheduleLearningAdvance();
  }

  @override
  void dispose() {
    _learnTimer?.cancel();
    _bravoTimer?.cancel();
    _shapeTicker?.cancel();
    _resultTimer?.cancel();
    _pulse.dispose();
    super.dispose();
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
    _shapeTicker?.cancel();
    setState(() {
      if (wasCorrect) _score++;
      _roundResult =
          wasCorrect ? _RoundResult.correct : _RoundResult.timeout;
    });
    _resultTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final next = _gameIdx + 1;
      setState(() => _roundResult = _RoundResult.none);
      if (next >= _totalRounds) {
        setState(() => _phase = _Phase.finished);
      } else {
        setState(() {
          _gameIdx = next;
          _shapeTimeLeft = _shapeSeconds;
        });
        _startShapeTicker();
      }
    });
  }

  void _startShapeTicker() {
    _shapeTicker?.cancel();
    setState(() => _shapeTimeLeft = _shapeSeconds);
    _shapeTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_shapeTimeLeft <= 1) {
        _shapeTicker?.cancel();
        if (_roundResult == _RoundResult.none) {
          _advanceRound(false);
        } else {
          setState(() => _shapeTimeLeft = 0);
        }
      } else {
        setState(() => _shapeTimeLeft--);
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
      _shapeTimeLeft = _shapeSeconds;
      _roundResult = _RoundResult.none;
      _phase = _Phase.playing;
    });
    _startShapeTicker();
  }

  void _restart() {
    _shapeTicker?.cancel();
    setState(() {
      _mapping = _buildMapping();
      _learnIdx = 0;
      _phase = _Phase.learning;
      _score = 0;
      _roundResult = _RoundResult.none;
    });
    _scheduleLearningAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final showSheet = _phase == _Phase.learning ||
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
              if (_phase == _Phase.playing) _playingProgress(),
              Expanded(child: _content()),
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
          border:
              Border.all(color: AppColors.yellow400.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events,
                color: AppColors.yellow400, size: 16),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: AppColors.yellow400,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
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

    Widget right;
    if (_phase == _Phase.playing) {
      right = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined,
                color: AppColors.purple300, size: 16),
            const SizedBox(width: 6),
            Text(
              '${_shapeTimeLeft}s',
              style: TextStyle(
                color:
                    _shapeTimeLeft <= 2 ? AppColors.red400 : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      right = const SizedBox(width: 36);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back,
                  color: Colors.white, size: 20),
            ),
          ),
          center,
          right,
        ],
      ),
    );
  }

  Widget _playingProgress() {
    final progress = _shapeTimeLeft / _shapeSeconds;
    final color = _shapeTimeLeft <= 2
        ? const LinearGradient(
            colors: [AppColors.red500, AppColors.red400])
        : _shapeTimeLeft <= 4
            ? const LinearGradient(
                colors: [Color(0xFFFB923C), AppColors.yellow400])
            : const LinearGradient(
                colors: [AppColors.indigo400, AppColors.purple400]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Runda ${min(_gameIdx + 1, _totalRounds)} / $_totalRounds',
                  style: TextStyle(
                      color: AppColors.purple400, fontSize: 10)),
              Text('Poprawne: $_score',
                  style: TextStyle(
                      color: AppColors.purple400, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: Colors.white.withValues(alpha: 0.10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(seconds: 1),
                  widthFactor: progress.clamp(0, 1).toDouble(),
                  child: DecoratedBox(decoration: BoxDecoration(gradient: color)),
                ),
              ),
            ),
          ),
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
          Text('Kształt ${_learnIdx + 1} / ${_shapes.length}',
              style: TextStyle(color: AppColors.purple300, fontSize: 14)),
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
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Center(child: ShapeWidget(id: pair.shape.id, size: 130)),
              ),
              if (_phase == _Phase.bravo)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.green400.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 12,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Brawo! Pora na kolejny!',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(pair.shape.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Text('Wykonaj ruch:',
                    style: TextStyle(
                        color: AppColors.purple300, fontSize: 12)),
                const SizedBox(height: 2),
                Text(pair.movement.name,
                    style: const TextStyle(
                        color: AppColors.yellow400,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ],
            ),
          ),
          if (_phase == _Phase.learning) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pulseDot(AppColors.purple400),
                const SizedBox(width: 8),
                Text('Czekam na ruch czujnika…',
                    style: TextStyle(
                        color: AppColors.purple400, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _advanceLearning,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Pomiń',
                      style: TextStyle(
                          color: AppColors.purple400, fontSize: 14)),
                  Icon(Icons.chevron_right,
                      color: AppColors.purple400, size: 18),
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
            child: const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          const Text('Świetnie!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Znasz już wszystkie kształty.\nCzas sprawdzić się na czas!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.purple300, fontSize: 14)),
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
                  Icon(Icons.sports_esports,
                      color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Zagraj w grę!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
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
    final timeout = _roundResult == _RoundResult.timeout;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Text('Jaki ruch wykonać?',
              style: TextStyle(color: AppColors.purple300, fontSize: 14)),
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
                      : timeout
                          ? AppColors.red400.withValues(alpha: 0.10)
                          : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: correct
                        ? AppColors.green400.withValues(alpha: 0.60)
                        : timeout
                            ? AppColors.red400.withValues(alpha: 0.60)
                            : Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Center(child: ShapeWidget(id: pair.shape.id, size: 140)),
              ),
              if (_roundResult != _RoundResult.none)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: correct
                        ? AppColors.green400.withValues(alpha: 0.90)
                        : AppColors.red500.withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    correct ? '✓ Poprawnie!' : '⏱ Czas!',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(pair.shape.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          if (_roundResult == _RoundResult.none) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pulseDot(AppColors.purple400),
                const SizedBox(width: 8),
                Text('Wykrywam ruch czujnika…',
                    style: TextStyle(
                        color: AppColors.purple400, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                if (_roundResult == _RoundResult.none) _advanceRound(true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Wykonano',
                        style: TextStyle(
                            color: AppColors.purple300, fontSize: 12)),
                    Icon(Icons.chevron_right,
                        color: AppColors.purple300, size: 16),
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
            child: const Icon(Icons.emoji_events,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          Text('Wynik końcowy',
              style: TextStyle(color: AppColors.purple300, fontSize: 14)),
          Text('$_score',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  height: 1,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('/ $_totalRounds poprawnych ruchów',
              style: TextStyle(color: AppColors.purple300, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Opacity(
                    opacity: _score >= (i + 1) * (_totalRounds / 3).ceil()
                        ? 1
                        : 0.2,
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
                  Text('Zagraj ponownie',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Center(
                child: Text('Wróć do menu',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
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
            Text(headline,
                style: TextStyle(color: AppColors.purple300, fontSize: 12)),
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
                      child: Text(pair.shape.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(pair.movement.name,
                          style: const TextStyle(
                              color: AppColors.yellow400,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cheatSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
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
                        height: 1.1),
                  ),
                ),
              ],
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
