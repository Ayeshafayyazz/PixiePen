import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

enum _DashItemType { star, obstacle, shield, magnet }

class PixieDashScreen extends StatefulWidget {
  const PixieDashScreen({super.key});

  @override
  State<PixieDashScreen> createState() => _PixieDashScreenState();
}

class _PixieDashScreenState extends State<PixieDashScreen>
    with SingleTickerProviderStateMixin {
  static const _bestScoreKey = 'pixie_dash_best_score';
  static const _dailyScoreKey = 'pixie_dash_daily_score';
  static const _dailyDateKey = 'pixie_dash_daily_date';
  static const _gemsKey = 'pixie_dash_gems';
  static const _selectedSkinKey = 'pixie_dash_selected_skin';
  static const _unlockedSkinsKey = 'pixie_dash_unlocked_skins';

  late final AnimationController _ticker;
  final math.Random _random = math.Random();
  final List<_DashItem> _items = [];
  final List<_DashSpark> _sparks = [];

  int _lane = 1;
  int _score = 0;
  int _stars = 0;
  int _gems = 0;
  int _bestScore = 0;
  int _dailyBest = 0;
  int _selectedSkin = 0;
  Set<int> _unlockedSkins = {0};
  double _speed = 0.42;
  double _spawnClock = 0;
  double _shieldClock = 0;
  double _magnetClock = 0;
  Duration _lastTick = Duration.zero;
  bool _running = false;
  bool _loaded = false;
  bool _gameOver = false;

  bool get _hasShield => _shieldClock > 0;
  bool get _hasMagnet => _magnetClock > 0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_tick);
    _loadProgress();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final storedDailyDate = prefs.getString(_dailyDateKey);
    if (storedDailyDate != today) {
      await prefs.setString(_dailyDateKey, today);
      await prefs.setInt(_dailyScoreKey, 0);
      await prefs.setInt(_gemsKey, 0);
      await prefs.setInt(_selectedSkinKey, 0);
      await prefs.setStringList(_unlockedSkinsKey, ['0']);
    }

    final unlocked = prefs
        .getStringList(_unlockedSkinsKey)
        ?.map(int.tryParse)
        .whereType<int>()
        .toSet();

    if (!mounted) return;
    setState(() {
      _bestScore = prefs.getInt(_bestScoreKey) ?? 0;
      _dailyBest = prefs.getInt(_dailyScoreKey) ?? 0;
      _gems = prefs.getInt(_gemsKey) ?? 0;
      _selectedSkin = prefs.getInt(_selectedSkinKey) ?? 0;
      _unlockedSkins = unlocked == null || unlocked.isEmpty ? {0} : unlocked;
      if (!_unlockedSkins.contains(_selectedSkin)) _selectedSkin = 0;
      _loaded = true;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestScoreKey, _bestScore);
    await prefs.setInt(_dailyScoreKey, _dailyBest);
    await prefs.setString(_dailyDateKey, _todayKey());
    await prefs.setInt(_gemsKey, _gems);
    await prefs.setInt(_selectedSkinKey, _selectedSkin);
    await prefs.setStringList(
      _unlockedSkinsKey,
      _unlockedSkins.map((skin) => '$skin').toList(),
    );
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  void _startRun() {
    setState(() {
      _items.clear();
      _sparks.clear();
      _lane = 1;
      _score = 0;
      _stars = 0;
      _speed = 0.42;
      _spawnClock = 0;
      _shieldClock = 0;
      _magnetClock = 0;
      _gameOver = false;
      _running = true;
      _lastTick = Duration.zero;
    });
    _ticker
      ..reset()
      ..repeat();
  }

  Future<void> _endRun() async {
    _ticker.stop();
    final earnedGems = 4 + (_score ~/ 250) + (_stars ~/ 12);
    setState(() {
      _running = false;
      _gameOver = true;
      _gems += earnedGems;
      _bestScore = math.max(_bestScore, _score);
      _dailyBest = math.max(_dailyBest, _score);
    });
    await _unlockEarnedSkins();
    await _saveProgress();
  }

  Future<void> _unlockEarnedSkins() async {
    var changed = false;
    for (var index = 0; index < _skins.length; index++) {
      if (_gems >= _skins[index].dailyCost && _unlockedSkins.add(index)) {
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  void _tick() {
    if (!_running) return;
    final elapsed = _ticker.lastElapsedDuration ?? Duration.zero;
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    final delta = (elapsed - _lastTick).inMicroseconds / 1000000;
    _lastTick = elapsed;
    if (delta <= 0 || delta > 0.08) return;

    setState(() {
      _score += (delta * 90).round();
      _speed = math.min(0.92, _speed + delta * 0.012);
      _shieldClock = math.max(0, _shieldClock - delta);
      _magnetClock = math.max(0, _magnetClock - delta);
      _spawnClock -= delta;

      if (_spawnClock <= 0) {
        _spawnItem();
        _spawnClock = math.max(0.34, 0.92 - _score / 2600);
      }

      for (final item in _items) {
        item.y += _speed * delta;
        if (_hasMagnet && item.type == _DashItemType.star) {
          item.x += (_lane - item.x) * math.min(1, delta * 4.4);
        }
      }
      for (final spark in _sparks) {
        spark.life -= delta;
        spark.y += delta * 0.24;
      }

      _collectItems();
      _items.removeWhere((item) => item.y > 1.18);
      _sparks.removeWhere((spark) => spark.life <= 0);
    });
  }

  void _spawnItem() {
    final lane = _random.nextInt(3);
    final roll = _random.nextDouble();
    final type = roll < 0.66
        ? _DashItemType.star
        : roll < 0.86
            ? _DashItemType.obstacle
            : roll < 0.94
                ? _DashItemType.shield
                : _DashItemType.magnet;

    _items.add(_DashItem(
      x: lane.toDouble(),
      y: -0.12,
      type: type,
      drift: (_random.nextDouble() - 0.5) * 0.08,
    ));
  }

  void _collectItems() {
    const playerY = 0.82;
    for (final item in List<_DashItem>.from(_items)) {
      final sameLane = (item.x - _lane).abs() < 0.42;
      final close = (item.y - playerY).abs() < 0.075;
      if (!sameLane || !close) continue;

      _items.remove(item);
      switch (item.type) {
        case _DashItemType.star:
          _stars++;
          _score += 25;
          _addSparks(_lane.toDouble(), playerY, const Color(0xFFFFD54F));
          break;
        case _DashItemType.shield:
          _shieldClock = 5.5;
          _score += 35;
          _addSparks(_lane.toDouble(), playerY, const Color(0xFF4DD0E1));
          break;
        case _DashItemType.magnet:
          _magnetClock = 5.5;
          _score += 35;
          _addSparks(_lane.toDouble(), playerY, const Color(0xFFFF8A65));
          break;
        case _DashItemType.obstacle:
          if (_hasShield) {
            _shieldClock = 0;
            _score += 45;
            _addSparks(_lane.toDouble(), playerY, const Color(0xFFB388FF));
          } else {
            _endRun();
          }
          break;
      }
    }
  }

  void _addSparks(double x, double y, Color color) {
    for (var i = 0; i < 8; i++) {
      _sparks.add(_DashSpark(
        x: x + (_random.nextDouble() - 0.5) * 0.5,
        y: y + (_random.nextDouble() - 0.5) * 0.08,
        color: color,
        life: 0.35 + _random.nextDouble() * 0.35,
      ));
    }
  }

  void _move(int direction) {
    if (!_running) return;
    setState(() => _lane = math.min(2, math.max(0, _lane + direction)));
  }

  void _handleDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 80) _move(1);
    if (velocity < -80) _move(-1);
  }

  Future<void> _selectSkin(int index) async {
    if (!_unlockedSkins.contains(index)) return;
    setState(() => _selectedSkin = index);
    await _saveProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF6),
      appBar: AppBar(
        backgroundColor: kAppPrimary,
        foregroundColor: Colors.white,
        title: const Text('Pixie Dash'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: _TinyStat(
                icon: Icons.diamond_outlined,
                label: '$_gems',
                color: const Color(0xFFFFD54F),
              ),
            ),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: kAppPrimary))
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: _handleDrag,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              CustomPaint(
                                size: Size.infinite,
                                painter: _PixieDashPainter(
                                  lane: _lane,
                                  items: _items,
                                  sparks: _sparks,
                                  score: _score,
                                  stars: _stars,
                                  skin: _skins[_selectedSkin],
                                  hasShield: _hasShield,
                                  hasMagnet: _hasMagnet,
                                  worldShift: _score * 0.002,
                                ),
                              ),
                              Positioned(
                                left: 12,
                                right: 12,
                                top: 12,
                                child: _DashHud(
                                  score: _score,
                                  stars: _stars,
                                  best: _bestScore,
                                  dailyBest: _dailyBest,
                                  hasShield: _hasShield,
                                  hasMagnet: _hasMagnet,
                                ),
                              ),
                              if (!_running)
                                Positioned.fill(
                                  child: _StartOverlay(
                                    gameOver: _gameOver,
                                    score: _score,
                                    bestScore: _bestScore,
                                    dailyBest: _dailyBest,
                                    onStart: _startRun,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  _ControlsBar(
                    running: _running,
                    onLeft: () => _move(-1),
                    onRight: () => _move(1),
                    onStart: _startRun,
                  ),
                  _SkinShelf(
                    gems: _gems,
                    selectedSkin: _selectedSkin,
                    unlockedSkins: _unlockedSkins,
                    onSelect: _selectSkin,
                  ),
                ],
              ),
            ),
    );
  }
}

class _DashItem {
  double x;
  double y;
  final double drift;
  final _DashItemType type;

  _DashItem({
    required this.x,
    required this.y,
    required this.drift,
    required this.type,
  });
}

class _DashSpark {
  final double x;
  double y;
  final Color color;
  double life;

  _DashSpark({
    required this.x,
    required this.y,
    required this.color,
    required this.life,
  });
}

class _DashSkin {
  final String name;
  final Color body;
  final Color wing;
  final Color trail;
  final int dailyCost;

  const _DashSkin({
    required this.name,
    required this.body,
    required this.wing,
    required this.trail,
    required this.dailyCost,
  });
}

const _skins = [
  _DashSkin(
    name: 'Violet',
    body: Color(0xFF8E24AA),
    wing: Color(0xFFE1BEE7),
    trail: Color(0xFFCE93D8),
    dailyCost: 0,
  ),
  _DashSkin(
    name: 'Mint',
    body: Color(0xFF00897B),
    wing: Color(0xFFB2DFDB),
    trail: Color(0xFF80CBC4),
    dailyCost: 80,
  ),
  _DashSkin(
    name: 'Sunny',
    body: Color(0xFFF9A825),
    wing: Color(0xFFFFECB3),
    trail: Color(0xFFFFD54F),
    dailyCost: 180,
  ),
  _DashSkin(
    name: 'Rose',
    body: Color(0xFFD81B60),
    wing: Color(0xFFF8BBD0),
    trail: Color(0xFFF48FB1),
    dailyCost: 350,
  ),
];

class _PixieDashPainter extends CustomPainter {
  final int lane;
  final List<_DashItem> items;
  final List<_DashSpark> sparks;
  final int score;
  final int stars;
  final _DashSkin skin;
  final bool hasShield;
  final bool hasMagnet;
  final double worldShift;

  _PixieDashPainter({
    required this.lane,
    required this.items,
    required this.sparks,
    required this.score,
    required this.stars,
    required this.skin,
    required this.hasShield,
    required this.hasMagnet,
    required this.worldShift,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawPath(canvas, size);
    for (final item in items) {
      _drawItem(canvas, size, item);
    }
    for (final spark in sparks) {
      _drawSpark(canvas, size, spark);
    }
    _drawPixie(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFDDF7FF), Color(0xFFF6FFF1)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final trunkPaint = Paint()..color = const Color(0xFF6D4C41);
    final leafPaint = Paint()..color = const Color(0xFF2E7D68);
    for (var i = 0; i < 8; i++) {
      final side = i.isEven ? 0.0 : size.width;
      final x = side + (i.isEven ? 18.0 : -18.0);
      final y = ((i * 103 + worldShift * 70) % (size.height + 160)) - 90;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y + 54), width: 18, height: 120),
          const Radius.circular(8),
        ),
        trunkPaint,
      );
      canvas.drawCircle(Offset(x, y), 46, leafPaint);
      canvas.drawCircle(
        Offset(x + (i.isEven ? 22 : -22), y + 28),
        34,
        Paint()..color = const Color(0xFF43A047),
      );
    }
  }

  void _drawPath(Canvas canvas, Size size) {
    final pathRect = Rect.fromLTWH(
      size.width * 0.14,
      0,
      size.width * 0.72,
      size.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pathRect, const Radius.circular(28)),
      Paint()..color = const Color(0xFFE8D9B5),
    );

    final lanePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < 3; i++) {
      final x = size.width * (0.14 + 0.72 * i / 3);
      for (var y = -30.0; y < size.height; y += 56) {
        final shifted = (y + worldShift * 90) % size.height;
        canvas.drawLine(Offset(x, shifted), Offset(x, shifted + 24), lanePaint);
      }
    }
  }

  Offset _lanePoint(Size size, double itemLane, double yFactor) {
    final pathLeft = size.width * 0.14;
    final laneWidth = size.width * 0.72 / 3;
    return Offset(
        pathLeft + laneWidth * (itemLane + 0.5), size.height * yFactor);
  }

  void _drawItem(Canvas canvas, Size size, _DashItem item) {
    final center = _lanePoint(size, item.x + item.drift, item.y);
    final radius = size.shortestSide * 0.036;
    switch (item.type) {
      case _DashItemType.star:
        _drawStar(canvas, center, radius, const Color(0xFFFFCA28));
        break;
      case _DashItemType.obstacle:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: radius * 2.4,
              height: radius * 1.8,
            ),
            Radius.circular(radius * 0.3),
          ),
          Paint()..color = const Color(0xFF5D4037),
        );
        canvas.drawCircle(
          center.translate(radius * 0.25, -radius * 0.18),
          radius * 0.34,
          Paint()..color = const Color(0xFF8D6E63),
        );
        break;
      case _DashItemType.shield:
        canvas.drawCircle(
          center,
          radius * 1.1,
          Paint()..color = const Color(0xFF4DD0E1),
        );
        canvas.drawCircle(center, radius * 0.62, Paint()..color = Colors.white);
        break;
      case _DashItemType.magnet:
        final paint = Paint()
          ..color = const Color(0xFFFF7043)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.38
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          math.pi * 0.15,
          math.pi * 1.7,
          false,
          paint,
        );
        break;
    }
  }

  void _drawSpark(Canvas canvas, Size size, _DashSpark spark) {
    final center = _lanePoint(size, spark.x, spark.y);
    canvas.drawCircle(
      center,
      size.shortestSide * 0.012 * spark.life * 2,
      Paint()
        ..color = spark.color.withValues(
          alpha: spark.life.clamp(0.0, 1.0).toDouble(),
        ),
    );
  }

  void _drawPixie(Canvas canvas, Size size) {
    final center = _lanePoint(size, lane.toDouble(), 0.82);
    final bodyRadius = size.shortestSide * 0.045;
    final bob = math.sin(score * 0.08) * 4;
    final pixie = center.translate(0, bob);

    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        pixie.translate(0, 42 + i * 13),
        bodyRadius * (0.75 - i * 0.08),
        Paint()..color = skin.trail.withValues(alpha: 0.34 - i * 0.045),
      );
    }

    final wingPaint = Paint()..color = skin.wing.withValues(alpha: 0.82);
    canvas.drawOval(
      Rect.fromCenter(
        center: pixie.translate(-bodyRadius * 1.15, -bodyRadius * 0.1),
        width: bodyRadius * 1.65,
        height: bodyRadius * 2.2,
      ),
      wingPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: pixie.translate(bodyRadius * 1.15, -bodyRadius * 0.1),
        width: bodyRadius * 1.65,
        height: bodyRadius * 2.2,
      ),
      wingPaint,
    );
    canvas.drawCircle(pixie, bodyRadius, Paint()..color = skin.body);
    canvas.drawCircle(
      pixie.translate(0, -bodyRadius * 0.82),
      bodyRadius * 0.78,
      Paint()..color = const Color(0xFFFFD7B5),
    );
    canvas.drawCircle(
      pixie.translate(-bodyRadius * 0.24, -bodyRadius * 0.92),
      bodyRadius * 0.08,
      Paint()..color = Colors.black87,
    );
    canvas.drawCircle(
      pixie.translate(bodyRadius * 0.24, -bodyRadius * 0.92),
      bodyRadius * 0.08,
      Paint()..color = Colors.black87,
    );

    if (hasShield) {
      canvas.drawCircle(
        pixie,
        bodyRadius * 1.95,
        Paint()
          ..color = const Color(0xFF4DD0E1).withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        pixie,
        bodyRadius * 1.95,
        Paint()
          ..color = const Color(0xFF00ACC1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    if (hasMagnet) {
      canvas.drawCircle(
        pixie,
        bodyRadius * 2.35,
        Paint()
          ..color = const Color(0xFFFF7043).withValues(alpha: 0.13)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? radius : radius * 0.42;
      final point = Offset(
          center.dx + math.cos(angle) * r, center.dy + math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PixieDashPainter oldDelegate) => true;
}

class _DashHud extends StatelessWidget {
  final int score;
  final int stars;
  final int best;
  final int dailyBest;
  final bool hasShield;
  final bool hasMagnet;

  const _DashHud({
    required this.score,
    required this.stars,
    required this.best,
    required this.dailyBest,
    required this.hasShield,
    required this.hasMagnet,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _HudPill(icon: Icons.bolt, label: '$score', color: kAppPrimary),
        _HudPill(
            icon: Icons.star, label: '$stars', color: const Color(0xFFF9A825)),
        _HudPill(
            icon: Icons.emoji_events,
            label: '$best',
            color: const Color(0xFF00897B)),
        _HudPill(
            icon: Icons.today,
            label: '$dailyBest',
            color: const Color(0xFFD81B60)),
        if (hasShield)
          const _HudPill(
              icon: Icons.shield_outlined,
              label: 'Shield',
              color: Color(0xFF00ACC1)),
        if (hasMagnet)
          const _HudPill(
              icon: Icons.auto_awesome,
              label: 'Magnet',
              color: Color(0xFFFF7043)),
      ],
    );
  }
}

class _HudPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HudPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartOverlay extends StatelessWidget {
  final bool gameOver;
  final int score;
  final int bestScore;
  final int dailyBest;
  final VoidCallback onStart;

  const _StartOverlay({
    required this.gameOver,
    required this.score,
    required this.bestScore,
    required this.dailyBest,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  gameOver ? Icons.replay_circle_filled : Icons.auto_awesome,
                  color: kAppPrimary,
                  size: 42,
                ),
                const SizedBox(height: 8),
                Text(
                  gameOver ? 'Run Complete' : 'Pixie Dash',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  gameOver
                      ? 'Score $score  |  Best $bestScore  |  Today $dailyBest'
                      : 'Swipe or tap arrows to dodge logs, collect stars, and grab magic boosts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(gameOver ? 'Run Again' : 'Start Run'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAppPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlsBar extends StatelessWidget {
  final bool running;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onStart;

  const _ControlsBar({
    required this.running,
    required this.onLeft,
    required this.onRight,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Row(
          children: [
            _ControlButton(
                icon: Icons.keyboard_arrow_left,
                onPressed: running ? onLeft : null),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: running ? null : onStart,
                icon: Icon(running ? Icons.swipe : Icons.play_arrow),
                label: Text(running ? 'Swipe to dash' : 'Start'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAppPrimary,
                  side: const BorderSide(color: kAppPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _ControlButton(
                icon: Icons.keyboard_arrow_right,
                onPressed: running ? onRight : null),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _ControlButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: IconButton.filled(
        tooltip: icon == Icons.keyboard_arrow_left ? 'Move left' : 'Move right',
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: kAppPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
        ),
      ),
    );
  }
}

class _SkinShelf extends StatelessWidget {
  final int gems;
  final int selectedSkin;
  final Set<int> unlockedSkins;
  final ValueChanged<int> onSelect;

  const _SkinShelf({
    required this.gems,
    required this.selectedSkin,
    required this.unlockedSkins,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Responsive sizing: derive every dimension from the available screen
    // width so the shelf looks balanced on small phones, big phones, and
    // tablets. Each dimension is clamped to safe min/max values so it can
    // never collapse to nothing or stretch absurdly wide.
    final screenWidth = MediaQuery.of(context).size.width;
    final tileWidth = screenWidth.clamp(320.0, 900.0) * 0.36;
    final clampedTileWidth = tileWidth.clamp(132.0, 200.0);
    final outerAvatarRadius = (clampedTileWidth * 0.16).clamp(16.0, 24.0);
    final innerAvatarRadius = outerAvatarRadius * 0.6;
    final nameFontSize = (clampedTileWidth * 0.11).clamp(12.0, 15.0);
    final statusFontSize = (clampedTileWidth * 0.095).clamp(11.0, 13.0);
    final shelfHeight = (clampedTileWidth * 0.78).clamp(96.0, 132.0);

    return Material(
      color: Colors.white,
      child: SizedBox(
        height: shelfHeight,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          scrollDirection: Axis.horizontal,
          itemCount: _skins.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final skin = _skins[index];
            final unlocked = unlockedSkins.contains(index);
            final selected = selectedSkin == index;

            // Clear, kid-friendly unlock copy. Locked tiles always tell the
            // player the exact target ("Unlocks at 80 gems") so they know what
            // they're working toward; unlocked tiles say "Unlocked" with a
            // small check icon so the achievement is unmistakable.
            final statusText =
                unlocked ? 'Unlocked' : 'Unlocks at ${skin.dailyCost} gems';
            final statusColor =
                unlocked ? Colors.green.shade700 : Colors.grey.shade700;

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: unlocked ? () => onSelect(index) : null,
              child: Container(
                width: clampedTileWidth,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected
                      ? skin.trail.withValues(alpha: 0.22)
                      : const Color(0xFFF7F3FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? skin.body : const Color(0xFFE2D9F3),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: outerAvatarRadius,
                      backgroundColor: skin.wing,
                      child: CircleAvatar(
                        radius: innerAvatarRadius,
                        backgroundColor: skin.body,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            skin.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: nameFontSize,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (unlocked) ...[
                                Icon(
                                  Icons.check_circle,
                                  size: statusFontSize + 2,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 3),
                              ],
                              // `maxLines: 2` + `softWrap` ensures the unlock
                              // instruction is never cut off mid-word on
                              // narrow screens — the second line wraps
                              // gracefully instead of showing "...".
                              Expanded(
                                child: Text(
                                  statusText,
                                  maxLines: 2,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: statusFontSize,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TinyStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TinyStat({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
