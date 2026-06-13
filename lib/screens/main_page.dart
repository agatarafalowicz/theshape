import 'dart:convert';
import 'dart:ui';
import '../services/api_service.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import 'game_screen.dart';

enum _Tab { game, home, settings }

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  _Tab _tab = _Tab.game;
  final bool _gameStarted = false;
  bool _showGame = false;

  String _displayName = 'Graczu';
  int? _userId;
  int? get userId => _userId;
  String? _connectedDeviceName;

  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _weeklyStats;

  List<dynamic> _leaderboard = [];

  bool _loadingStats = true;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _loadUser().then((_) {
      _loadStats();
      _loadLeaderboard();
      _loadWeeklyStats();
    });
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString('currentUser');

    if (raw == null) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;

      setState(() {
        _userId = data['user_id'] as int?;
        _displayName =
            (data['user_name'] as String?) ?? 'Graczu';
        _connectedDeviceName = prefs.getString('selectedDeviceName');
      });
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    if (_userId == null) return;

    try {
      final stats = await ApiService.getStats(_userId!);

      setState(() {
        _stats = stats;
        _loadingStats = false;
      });
    } catch (e) {
      debugPrint('LOAD STATS ERROR: $e');

      setState(() {
        _loadingStats = false;
      });
    }
  }

  Future<void> _loadWeeklyStats() async {
    if (_userId == null) return;
    try {
      final stats = await ApiService.getWeeklyStats(_userId!);
      setState(() {
        _weeklyStats = stats;
      });
    } catch (e) {
      debugPrint('LOAD WEEKLY STATS ERROR: $e');
    }
  }

  Future<void> _loadLeaderboard() async {
    try {
      final leaderboard = await ApiService.getLeaderboard();

      setState(() {
        _leaderboard = leaderboard;
      });
    } catch (e) {
      debugPrint('LOAD LEADERBOARD ERROR: $e');
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = _displayName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.length >= 2
          ? parts.first.substring(0, 2).toUpperCase()
          : parts.first.toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _formatScore(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: switch (_tab) {
                  _Tab.game => _buildGameTab(),
                  _Tab.home => _buildHomeTab(),
                  _Tab.settings => _buildSettingsTab(),
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _bottomNav(),
            ),
            if (_showGame)
              Positioned.fill(
                child: GameScreen(
                  userId: _userId,
                  onGameFinished: () {
                    _loadStats();
                    _loadLeaderboard();
                    _loadWeeklyStats();
                    _loadUser();
                  },
                  onClose: () => setState(() => _showGame = false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Witaj,',
                          style: TextStyle(
                              color: AppColors.purple300, fontSize: 14)),
                      Text(_displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _pulseDot(AppColors.green400),
                      const SizedBox(width: 8),
                      const Text('Podłączono',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _heroCard(),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
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
                  child: const Icon(Icons.gavel,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Pora zmierzyć się\nz dzisiejszą grą!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white, fontSize: 22, height: 1.25),
                ),
                const SizedBox(height: 8),
                Text(
                  'Twój czujnik MetaMotion jest gotowy.\nSprawdź swoje możliwości!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.purple300, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _statTile(
                      '${_stats?['wins'] ?? 0}',
                      'Wygrane',
                    ),
                    const SizedBox(width: 12),
                    _statTile(
                      _formatScore(
                        (_stats?['rank']?['points'] ?? 0) as int,
                      ),
                      'Rekord',
                    ),
                    const SizedBox(width: 12),
                    _statTile(
                      '#${_stats?['rank']?['rank'] ?? '-'}',
                      'Ranking',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!_gameStarted)
                  GestureDetector(
                    onTap: () => setState(() => _showGame = true),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: AppColors.ctaGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.orange500.withValues(alpha: 0.40),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sports_esports,
                              color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Text('Zagraj w grę',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                        ],
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

  Widget _statTile(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: AppColors.yellow400,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            Text(label,
                style: TextStyle(color: AppColors.purple300, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {


    if (_loadingStats) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final allRankings = _leaderboard.map((player) {
      return _RankItem(
        name: player['user_name'],
        avatar: player['user_name']
            .substring(0, 2)
            .toUpperCase(),
        score: player['points'],
        won: player['won'] ?? false,
        gradient: const LinearGradient(
          colors: [
            AppColors.indigo500,
            AppColors.purple600,
          ],
        ),
        isMe: player['user_id'] == _userId,
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Inni gracze',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600)),
                    Text('Rywalizuj z innymi',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.purple300, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 24),
          _myPositionCard(allRankings),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Ranking graczy',
                style: TextStyle(color: AppColors.purple300, fontSize: 14)),
          ),
          for (int i = 0; i < allRankings.length; i++) ...[
            _rankingTile(allRankings[i], i + 1),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Tygodniowe porównanie wyników',
                style: TextStyle(color: AppColors.purple300, fontSize: 14)),
          ),
          _statsCard(),
        ],
      ),
    );
  }

  Widget _myPositionCard(List<_RankItem> ranks) {
    final myRank = _stats?['rank']?['rank'] as int?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.indigo500.withValues(alpha: 0.30),
            AppColors.purple600.withValues(alpha: 0.30),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.indigo400.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Twoja pozycja w rankingu',
              style: TextStyle(color: AppColors.purple300, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.indigo500, AppColors.purple600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(_initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(_displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 4),
                        Text('(Ty)',
                            style: TextStyle(
                                color: AppColors.purple300, fontSize: 12)),
                      ],
                    ),
                    Text(
                        '${_stats?['wins'] ?? 0} wygranych',
                        style: TextStyle(
                            color: AppColors.purple300, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.yellow400.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(myRank != null ? '#$myRank' : '-',
                    style: const TextStyle(
                        color: AppColors.yellow400,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rankingTile(_RankItem r, int rank) {
    Widget rankBadge() {
      if (rank == 1) return const Text('🥇', style: TextStyle(fontSize: 20));
      if (rank == 2) return const Text('🥈', style: TextStyle(fontSize: 20));
      if (rank == 3) return const Text('🥉', style: TextStyle(fontSize: 20));
      return Text('#$rank',
          style: TextStyle(
              color: AppColors.purple400,
              fontSize: 14,
              fontWeight: FontWeight.w500));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: r.isMe
            ? AppColors.indigo500.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: r.isMe
                ? AppColors.indigo400.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Center(child: rankBadge())),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: r.gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(r.avatar,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(r.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ),
                    if (r.isMe) ...[
                      const SizedBox(width: 4),
                      Text('(Ty)',
                          style: TextStyle(
                              color: AppColors.purple400, fontSize: 12)),
                    ],
                  ],
                ),
                Text(r.won ? 'Wygrana' : 'Przegrana',
                    style: TextStyle(
                        color: AppColors.purple400, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatScore(r.score),
                  style: const TextStyle(
                      color: AppColors.yellow400,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              Text('pkt',
                  style: TextStyle(
                      color: AppColors.purple400, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsCard() {
    if (_weeklyStats == null || _stats?['rank'] == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Center(
          child: Text(
            'Zagraj pierwszą grę, aby zobaczyć statystyki',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.purple300, fontSize: 13),
          ),
        ),
      );
    }

    final winRateYou =
        ((_weeklyStats!['win_rate']?['you'] ?? 0.0) as num).toDouble() * 100;
    final winRateAvg =
        ((_weeklyStats!['win_rate']?['avg'] ?? 0.0) as num).toDouble() * 100;
    final avgPtsYou =
        ((_weeklyStats!['avg_points']?['you'] ?? 0.0) as num).toDouble();
    final avgPtsAvg =
        ((_weeklyStats!['avg_points']?['avg'] ?? 0.0) as num).toDouble();
    final playtimeYou =
        ((_weeklyStats!['playtime']?['you'] ?? 0) as num).toDouble();
    final playtimeAvg =
        ((_weeklyStats!['playtime']?['avg'] ?? 0.0) as num).toDouble();

    final stats = [
      _Stat('Wygrane', winRateYou, winRateAvg, '%', _StatType.winRate),
      _Stat('Średnia punktów', avgPtsYou, avgPtsAvg, '', _StatType.avgPoints),
      _Stat('Czas', playtimeYou, playtimeAvg, '', _StatType.playtime),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _statBar(stats[i]),
          ],
        ],
      ),
    );
  }

  Widget _statBar(_Stat s) {
    final sum = s.me + s.avg;
    final ratio = sum == 0 ? 0.0 : (s.me / sum) * 1.3;
    final width = ratio.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(s.label,
                style: TextStyle(color: AppColors.purple300, fontSize: 12)),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
                children: [
                  const TextSpan(text: 'Ty: '),
                  TextSpan(
                    text: _fmtStatVal(s, s.me),
                    style: const TextStyle(color: AppColors.yellow400),
                  ),
                  TextSpan(text: ' · Inni: ${_fmtStatVal(s, s.avg)}'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 8,
            color: Colors.white.withValues(alpha: 0.10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: width,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.indigo400, AppColors.purple500],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _fmtPlaytime(num seconds) {
    final totalSec = seconds.round();
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    if (min == 0) return '${sec}s';
    if (sec == 0) return '${min}m';
    return '${min}m ${sec}s';
  }

  String _fmtStatVal(_Stat s, num v) {
    switch (s.type) {
      case _StatType.winRate:
        return '${v.round()}${s.unit}';
      case _StatType.avgPoints:
        return v.toStringAsFixed(1);
      case _StatType.playtime:
        return _fmtPlaytime(v);
    }
  }

  Widget _buildSettingsTab() {
    final items = [
      _SettingItem('Urządzenie', _connectedDeviceName ?? 'Brak połączenia', '📡'),
      const _SettingItem('Język aplikacji', 'Polski', '🌐'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Profil',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600)),
          Text('Twoje dane',
              style: TextStyle(color: AppColors.purple300, fontSize: 14)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.indigo500, AppColors.purple600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(_initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.green400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('Aktywny',
                              style: TextStyle(
                                  color: AppColors.green400, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Row(
                  children: [
                    Text(item.icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item.label,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                    ),
                    Text(item.value,
                        style: TextStyle(
                            color: AppColors.purple300, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: Text('The Shape v1.0.0',
                style: TextStyle(color: AppColors.purple500, fontSize: 12)),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _openLogoutDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.red500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.red500.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: AppColors.red400, size: 20),
                  const SizedBox(width: 12),
                  Text('Wyloguj się',
                      style: TextStyle(
                          color: AppColors.red400,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomNav() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.40),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(_Tab.game, Icons.sports_esports, 'Gra'),
              _navItem(_Tab.home, Icons.home, 'Inni gracze'),
              _navItem(_Tab.settings, Icons.person, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(_Tab tab, IconData icon, String label) {
    final selected = _tab == tab;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 24,
                color: selected ? AppColors.yellow400 : AppColors.purple400),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : AppColors.purple400,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Future<void> _openLogoutDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.gray900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Wylogować się?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Czy na pewno chcesz się wylogować z aplikacji?',
                  style: TextStyle(
                      color: AppColors.purple300, fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _outlineButton(
                      label: 'Anuluj',
                      onTap: () => Navigator.of(ctx).pop()),
                  const SizedBox(width: 8),
                  _destructiveButton(
                    label: 'Wyloguj',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      widget.onLogout();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAddFriendDialog() async {
    final controller = TextEditingController();
    bool added = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Dialog(
          backgroundColor: AppColors.gray900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_add_alt_1,
                        color: AppColors.purple400, size: 20),
                    const SizedBox(width: 8),
                    const Text('Dodaj znajomego',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Wpisz adres email znajomego, aby wysłać zaproszenie.',
                    style: TextStyle(
                        color: AppColors.purple300, fontSize: 14)),
                const SizedBox(height: 16),
                if (!added)
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'email@znajomy.pl',
                      hintStyle: TextStyle(
                          color: AppColors.purple400, fontSize: 14),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.20)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.20)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.purple400),
                      ),
                    ),
                    onChanged: (_) => setLocalState(() {}),
                  )
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          const Text('✅', style: TextStyle(fontSize: 36)),
                          const SizedBox(height: 8),
                          Text('Zaproszenie wysłane!',
                              style: TextStyle(
                                  color: AppColors.green400,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                if (!added) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _outlineButton(
                          label: 'Anuluj',
                          onTap: () => Navigator.of(ctx).pop()),
                      const SizedBox(width: 8),
                      _gradientButtonSmall(
                        label: 'Wyślij zaproszenie',
                        enabled: controller.text.trim().isNotEmpty,
                        onTap: () {
                          if (controller.text.trim().isEmpty) return;
                          setLocalState(() => added = true);
                          final nav = Navigator.of(ctx);
                          Future.delayed(const Duration(milliseconds: 1500),
                              () {
                            if (nav.canPop()) nav.pop();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlineButton(
      {required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _destructiveButton(
      {required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFD4183D),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _gradientButtonSmall(
      {required String label,
      required bool enabled,
      required VoidCallback onTap}) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppColors.indigoPurpleGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ),
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

class _Friend {
  final int id;
  final String name;
  final String avatar;
  final int score;
  final int wins;
  final LinearGradient gradient;
  const _Friend(this.id, this.name, this.avatar, this.score, this.wins,
      this.gradient);
}

class _RankItem {
  final String name;
  final String avatar;
  final int score;
  final bool won;
  final LinearGradient gradient;
  final bool isMe;
  const _RankItem({
    required this.name,
    required this.avatar,
    required this.score,
    required this.won,
    required this.gradient,
    required this.isMe,
  });
}

enum _StatType { winRate, avgPoints, playtime }

class _Stat {
  final String label;
  final num me;
  final num avg;
  final String unit;
  final _StatType type;
  const _Stat(this.label, this.me, this.avg, this.unit, this.type);
}

class _SettingItem {
  final String label;
  final String value;
  final String icon;
  const _SettingItem(this.label, this.value, this.icon);
}
