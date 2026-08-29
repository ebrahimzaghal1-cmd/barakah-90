import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/play_task_session_service.dart';
import '../theme/app_theme.dart';

class GoldWormGame extends StatefulWidget {
  final bool rewardEligible;
  final Future<bool> Function()? onRewardEarned;
  final DateTime? rewardExpiresAt;
  final DateTime? taskStartedAt;
  final String sessionKey;

  const GoldWormGame({
    super.key,
    this.rewardEligible = false,
    this.onRewardEarned,
    this.rewardExpiresAt,
    this.taskStartedAt,
    this.sessionKey = 'free_goldWorm',
  });

  @override
  State<GoldWormGame> createState() => _GoldWormGameState();
}

enum Direction {
  up,
  down,
  left,
  right,
}

class _GoldWormGameState extends State<GoldWormGame>
    with WidgetsBindingObserver {
  static const int rows = 20;
  static const int columns = 16;
  static const int coinsPerGame = 5;
  static const int requiredSuccessfulGames = 5;
  static const Duration rewardDuration = Duration(minutes: 30);

  final Random random = Random();
  final PlayTaskSessionService sessions = PlayTaskSessionService();

  List<Point<int>> worm = [];
  Point<int> gold = const Point<int>(8, 8);

  Direction direction = Direction.right;

  Timer? gameTimer;
  Timer? countdownTimer;
  DateTime? startedAt;

  int score = 0;
  int successfulGames = 0;
  int speed = 260;

  bool gameStarted = false;
  bool gameOver = false;
  bool gameWon = false;
  bool roundWon = false;
  bool timeCompleted = false;
  bool rewardSent = false;
  bool rewardClaiming = false;
  bool practiceOnly = false;
  Duration remaining = rewardDuration;
  bool loading = true;

  Offset? dragStart;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    practiceOnly = widget.sessionKey.startsWith('practice_');
    _prepareRound();
    _restoreSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    gameTimer?.cancel();
    countdownTimer?.cancel();
    _persist();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    gameTimer?.cancel();
    if (gameStarted) {
      gameStarted = false;
      if (mounted) setState(() {});
    }
    _persist();
  }

  void _prepareRound() {
    gameTimer?.cancel();

    worm = [
      const Point(5, 10),
      const Point(4, 10),
      const Point(3, 10),
    ];

    direction = Direction.right;
    score = 0;
    speed = 260;
    gameStarted = false;
    gameOver = false;

    _spawnGold();
  }

  Future<void> _restoreSession() async {
    final loaded = widget.sessionKey.startsWith('practice_')
        ? <String, dynamic>{}
        : await sessions.load(widget.sessionKey);
    final saved = loaded['rulesVersion'] == 5 ? loaded : <String, dynamic>{};
    final wasRewardSent = saved['rewardSent'] == true;
    final startedAtMillis = saved['startedAt'] as int?;
    if (widget.rewardEligible && widget.taskStartedAt != null) {
      startedAt = widget.taskStartedAt;
    } else if (startedAtMillis != null) {
      startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMillis);
    }
    score = (saved['score'] as int?)?.clamp(0, coinsPerGame - 1) ?? 0;
    successfulGames =
        (saved['successfulGames'] as int?)?.clamp(0, requiredSuccessfulGames) ??
            0;
    gameWon =
        saved['gameWon'] == true || successfulGames >= requiredSuccessfulGames;
    rewardSent = wasRewardSent;
    gameOver = saved['gameOver'] == true && !gameWon;
    roundWon = saved['roundWon'] == true && !gameWon;
    speed = (saved['speed'] as int?)?.clamp(90, 260) ?? 260;
    direction = Direction.values.firstWhere(
      (value) => value.name == saved['direction'],
      orElse: () => Direction.right,
    );
    final restoredWorm = _decodeWorm(saved['worm']);
    if (restoredWorm != null) worm = restoredWorm;
    final restoredGold = _decodePoint(saved['gold']);
    if (restoredGold != null && !worm.contains(restoredGold)) {
      gold = restoredGold;
    } else {
      _spawnGold();
    }
    gameStarted = false;
    if (gameWon) timeCompleted = true;
    _syncRemaining(notify: false);
    if (startedAt == null && !timeCompleted) {
      startedAt = DateTime.now();
      remaining = rewardDuration;
      await _persist();
    }
    loading = false;
    if (mounted) setState(() {});
    // Retrying the secure claim is intentional: the server de-duplicates it.
    if (gameWon && !rewardSent && canEarnPoints) {
      unawaited(_claimReward());
    }
    if (!timeCompleted) _startCountdown();
  }

  bool get canEarnPoints => widget.rewardEligible && !practiceOnly;

  Future<void> _persist() {
    if (practiceOnly || widget.sessionKey.startsWith('practice_')) {
      return Future<void>.value();
    }
    return sessions.save(widget.sessionKey, {
      'rulesVersion': 5,
      'startedAt': startedAt?.millisecondsSinceEpoch,
      'score': score,
      'successfulGames': successfulGames,
      'gameWon': gameWon,
      'rewardSent': rewardSent,
      'gameOver': gameOver,
      'roundWon': roundWon,
      'speed': speed,
      'direction': direction.name,
      'worm': worm.map(_encodePoint).toList(growable: false),
      'gold': _encodePoint(gold),
    });
  }

  Map<String, int> _encodePoint(Point<int> point) => {
        'x': point.x,
        'y': point.y,
      };

  Point<int>? _decodePoint(Object? raw) {
    if (raw is! Map) return null;
    final x = raw['x'];
    final y = raw['y'];
    if (x is! num || y is! num) return null;
    final point = Point<int>(x.toInt(), y.toInt());
    return _hitWall(point) ? null : point;
  }

  List<Point<int>>? _decodeWorm(Object? raw) {
    if (raw is! List) return null;
    final points = raw.map(_decodePoint).whereType<Point<int>>().toList();
    if (points.length < 3 || points.length != raw.length) return null;
    if (points.toSet().length != points.length) return null;
    return points;
  }

  void _syncRemaining({bool notify = true}) {
    if (startedAt == null) {
      remaining = rewardDuration;
      return;
    }
    var next = rewardDuration - DateTime.now().difference(startedAt!);
    if (canEarnPoints && widget.rewardExpiresAt != null) {
      final orderWindow = widget.rewardExpiresAt!.difference(DateTime.now());
      if (orderWindow < next) next = orderWindow;
    }
    remaining = next.isNegative ? Duration.zero : next;
    if (remaining == Duration.zero && !timeCompleted) {
      _finishTimedMission(notify: notify);
    }
  }

  void _finishTimedMission({bool notify = true}) {
    countdownTimer?.cancel();
    gameTimer?.cancel();
    timeCompleted = true;
    gameStarted = false;
    roundWon = false;
    gameOver = !gameWon;
    if (gameWon && canEarnPoints && !rewardSent) {
      if (notify) unawaited(_claimReward());
    }
    _persist();
  }

  Future<void> _claimReward() async {
    if (!canEarnPoints ||
        !gameWon ||
        rewardSent ||
        rewardClaiming ||
        widget.onRewardEarned == null) {
      return;
    }
    if (mounted) setState(() => rewardClaiming = true);
    final confirmed = await widget.onRewardEarned!.call();
    if (!mounted) return;
    setState(() {
      rewardClaiming = false;
      if (confirmed) rewardSent = true;
    });
    await _persist();
  }

  void _restartRound() {
    if (timeCompleted || gameWon) return;
    gameTimer?.cancel();
    successfulGames = 0;
    worm = const [Point(5, 10), Point(4, 10), Point(3, 10)];
    direction = Direction.right;
    score = 0;
    speed = 260;
    gameStarted = false;
    gameOver = false;
    roundWon = false;
    _spawnGold();
    _persist();
    setState(() {});
  }

  void _startNextGame() {
    if (timeCompleted || gameWon) return;
    gameTimer?.cancel();
    worm = const [Point(5, 10), Point(4, 10), Point(3, 10)];
    direction = Direction.right;
    score = 0;
    speed = 260;
    gameStarted = false;
    gameOver = false;
    roundWon = false;
    _spawnGold();
    _persist();
    setState(() {});
  }

  void _playAgain() {
    gameTimer?.cancel();
    countdownTimer?.cancel();
    practiceOnly = true;
    startedAt = DateTime.now();
    remaining = rewardDuration;
    gameWon = false;
    roundWon = false;
    successfulGames = 0;
    timeCompleted = false;
    rewardSent = false;
    _prepareRound();
    _startCountdown();
    setState(() {});
  }

  void _startGame() {
    if (gameStarted || gameOver || gameWon || roundWon || timeCompleted) return;

    startedAt ??= DateTime.now();

    setState(() {
      gameStarted = true;
    });

    _startTimer();
    _startCountdown();
    _persist();
  }

  void _startCountdown() {
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || timeCompleted) return;
      _syncRemaining();
      setState(() {});
    });
  }

  void _startTimer() {
    gameTimer?.cancel();

    gameTimer = Timer.periodic(
      Duration(milliseconds: speed),
      (_) => _moveWorm(),
    );
  }

  void _moveWorm() {
    if (!gameStarted || gameOver) return;

    final head = worm.first;

    Point<int> newHead;

    switch (direction) {
      case Direction.up:
        newHead = Point(head.x, head.y - 1);
        break;

      case Direction.down:
        newHead = Point(head.x, head.y + 1);
        break;

      case Direction.left:
        newHead = Point(head.x - 1, head.y);
        break;

      case Direction.right:
        newHead = Point(head.x + 1, head.y);
        break;
    }

    if (_hitWall(newHead) || _hitSelf(newHead)) {
      _finishGame();
      return;
    }

    worm.insert(0, newHead);

    if (newHead == gold) {
      score += 1;
      _persist();

      if (score >= coinsPerGame) {
        _completeSuccessfulGame();
        return;
      }

      if (speed > 90) {
        speed -= 10;
        _startTimer();
      }

      _spawnGold();
    } else {
      worm.removeLast();
    }

    setState(() {});
  }

  bool _hitWall(Point<int> point) {
    return point.x < 0 || point.x >= columns || point.y < 0 || point.y >= rows;
  }

  bool _hitSelf(Point<int> point) {
    return worm.contains(point);
  }

  void _finishGame() {
    gameTimer?.cancel();

    setState(() {
      score = 0;
      gameOver = true;
      gameStarted = false;
    });
    _persist();
  }

  void _winReward() {
    gameTimer?.cancel();
    countdownTimer?.cancel();
    setState(() {
      gameWon = true;
      gameStarted = false;
      timeCompleted = true;
    });
    if (canEarnPoints && !rewardSent) {
      unawaited(_claimReward());
    }
    _persist();
  }

  void _completeSuccessfulGame() {
    gameTimer?.cancel();
    successfulGames += 1;
    score = 0;
    gameStarted = false;
    if (successfulGames >= requiredSuccessfulGames) {
      _winReward();
      return;
    }
    setState(() => roundWon = true);
    _persist();
  }

  String get _timeLabel {
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _spawnGold() {
    Point<int> newGold;

    do {
      newGold = Point(
        random.nextInt(columns),
        random.nextInt(rows),
      );
    } while (worm.contains(newGold));

    gold = newGold;
  }

  void _changeDirection(Direction newDirection) {
    if (direction == Direction.up && newDirection == Direction.down) {
      return;
    }

    if (direction == Direction.down && newDirection == Direction.up) {
      return;
    }

    if (direction == Direction.left && newDirection == Direction.right) {
      return;
    }

    if (direction == Direction.right && newDirection == Direction.left) {
      return;
    }

    direction = newDirection;
    _persist();

    if (!gameStarted && !gameOver && !gameWon) {
      _startGame();
    }
  }

  void _onPanStart(DragStartDetails details) {
    dragStart = details.localPosition;
  }

  void _onPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;

    if (velocity.dx.abs() > velocity.dy.abs()) {
      if (velocity.dx > 0) {
        _changeDirection(Direction.right);
      } else {
        _changeDirection(Direction.left);
      }
    } else {
      if (velocity.dy > 0) {
        _changeDirection(Direction.down);
      } else {
        _changeDirection(Direction.up);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF281B63),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.navy,
        centerTitle: true,
        title: const Text(
          'دودة الذهب',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppTheme.background, Color(0xFFF5E9B7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 14),
              _buildScoreCard(),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: columns / rows,
                      child: GestureDetector(
                        onPanStart: _onPanStart,
                        onPanEnd: _onPanEnd,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFF1A8),
                                Color(0xFFD39A18),
                                Color(0xFF78500A),
                                Color(0xFFFFD75B),
                              ],
                              stops: [0, .34, .66, 1],
                            ),
                            borderRadius: BorderRadius.circular(31),
                            border: Border.all(
                              color: const Color(0xFFFFED9A),
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 28,
                                color: Color(0x55382100),
                                offset: Offset(0, 14),
                              ),
                              BoxShadow(
                                blurRadius: 12,
                                color: Color(0x66FFE067),
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF07152C),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: Colors.white.withOpacity(.22),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(-.55, -.7),
                                    radius: 1.35,
                                    colors: [
                                      Color(0xFF244A78),
                                      Color(0xFF102B52),
                                      Color(0xFF07172F),
                                    ],
                                    stops: [0, .48, 1],
                                  ),
                                ),
                                child: CustomPaint(
                                  painter: WormGamePainter(
                                    worm: worm,
                                    gold: gold,
                                    rows: rows,
                                    columns: columns,
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: _arenaBadge(),
                                      ),
                                      if (!gameStarted &&
                                          !gameOver &&
                                          !gameWon &&
                                          !roundWon)
                                        _buildStartOverlay(),
                                      if (gameOver) _buildGameOverOverlay(),
                                      if (roundWon) _buildRoundWonOverlay(),
                                      if (gameWon) _buildWinOverlay(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildControls(),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final completedCoins = successfulGames * coinsPerGame + score;
    const totalCoins = requiredSuccessfulGames * coinsPerGame;
    final progress = (completedCoins / totalCoins).clamp(0.0, 1.0);
    final currentGame = min(successfulGames + 1, requiredSuccessfulGames);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF203E68), Color(0xFF0B1E3B)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x66FFD64D)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              color: Color(0x33201700),
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const _GoldMedallionIcon(),
                    const SizedBox(width: 10),
                    Text(
                      'اللعبة $currentGame من $requiredSuccessfulGames',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _timeLabel,
                      style: const TextStyle(
                        color: AppTheme.coolYellow,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '$score من $coinsPerGame عملات',
                      style: const TextStyle(
                        color: Color(0xFFDCE7F6),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Container(height: 8, color: const Color(0xFF06152C)),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFB77B08), Color(0xFFFFE169)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _arenaBadge() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC07172F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x77FFD85A)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppTheme.coolYellow),
            SizedBox(width: 5),
            Text(
              'ساحة الذهب',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumDialog({
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Container(
      color: const Color(0xAA020A18),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(25),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF233F69), Color(0xFF0A1B35)],
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0x99FFD75A), width: 1.4),
          boxShadow: const [
            BoxShadow(
                color: Colors.black54, blurRadius: 24, offset: Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFE985), Color(0xFFB97800)],
                ),
              ),
              child: Icon(icon, color: AppTheme.navy, size: 31),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 10),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildStartOverlay() {
    return _premiumDialog(
      icon: Icons.workspace_premium_rounded,
      title: 'دودة الذهب',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'أنهِ 5 ألعاب ناجحة خلال 10 دقائق\nواجمع في كل لعبة 5 عملات دون اصطدام',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFDCE7F6),
              height: 1.5,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD338),
              foregroundColor: const Color(0xFF101D3B),
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'دخول الساحة',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return _premiumDialog(
      icon: Icons.refresh_rounded,
      title: 'حاول مرة أخرى',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'اصطدمت الدودة، لكن العداد لم يتوقف.\nالألعاب الناجحة: $successfulGames من $requiredSuccessfulGames\nابدأ من جديد واجمع 5 عملات.\nالوقت المتبقي: $_timeLabel',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFDCE7F6),
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: timeCompleted ? _playAgain : _restartRound,
            icon: const Icon(Icons.replay_rounded),
            label: const Text(
              'ابدأ من البداية',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coolYellow,
              foregroundColor: AppTheme.navy,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundWonOverlay() {
    return _premiumDialog(
      icon: Icons.verified_rounded,
      title: 'نجحت في اللعبة $successfulGames!',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'بقي ${requiredSuccessfulGames - successfulGames} ألعاب ناجحة\nالعداد مستمر: $_timeLabel',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFDCE7F6),
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _startNextGame,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              'ابدأ اللعبة ${successfulGames + 1}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coolYellow,
              foregroundColor: AppTheme.navy,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinOverlay() {
    return _premiumDialog(
      icon: timeCompleted ? Icons.verified_rounded : Icons.emoji_events_rounded,
      title: timeCompleted ? 'اكتملت المهمة!' : 'أحسنت!',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rewardSent
                ? 'أنهيت الألعاب الخمس وأُضيفت نقطتان إلى رصيدك'
                : rewardClaiming
                    ? 'أنهيت الألعاب الخمس، جارٍ تسجيل النقطتين...'
                    : canEarnPoints
                        ? 'أنهيت الألعاب الخمس. ثبّت النقطتين في رصيدك.'
                        : 'أنهيت الألعاب الخمس بنجاح',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFDCE7F6),
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          if (timeCompleted) ...[
            const SizedBox(height: 16),
            if (canEarnPoints && !rewardSent)
              ElevatedButton.icon(
                onPressed: rewardClaiming ? null : _claimReward,
                icon: rewardClaiming
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: const Text(
                  'تسجيل النقطتين',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coolYellow,
                  foregroundColor: AppTheme.navy,
                  elevation: 0,
                ),
              ),
            if (canEarnPoints && !rewardSent) const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _playAgain,
              icon: const Icon(Icons.replay_rounded),
              label: const Text(
                'ابدأ من البداية',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coolYellow,
                foregroundColor: AppTheme.navy,
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x334F6382)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F14213D),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe_rounded, color: AppTheme.navy, size: 18),
                SizedBox(width: 7),
                Text(
                  'اسحب على اللوحة أو استخدم الأسهم',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _controlButton(
                    icon: Icons.keyboard_arrow_left_rounded,
                    onPressed: () => _changeDirection(Direction.left),
                  ),
                  const SizedBox(width: 9),
                  Column(
                    children: [
                      _controlButton(
                        icon: Icons.keyboard_arrow_up_rounded,
                        onPressed: () => _changeDirection(Direction.up),
                      ),
                      const SizedBox(height: 7),
                      _controlButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        onPressed: () => _changeDirection(Direction.down),
                      ),
                    ],
                  ),
                  const SizedBox(width: 9),
                  _controlButton(
                    icon: Icons.keyboard_arrow_right_rounded,
                    onPressed: () => _changeDirection(Direction.right),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 58,
      height: 46,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF294D7B), Color(0xFF0B1E3B)],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0x88FFD75A)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33101D3B),
                blurRadius: 7,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onPressed,
            child: Icon(icon, color: AppTheme.coolYellow, size: 31),
          ),
        ),
      ),
    );
  }
}

class _GoldMedallionIcon extends StatelessWidget {
  const _GoldMedallionIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-.3, -.35),
          colors: [Color(0xFFFFFFB4), Color(0xFFFFCE35), Color(0xFF9C6500)],
        ),
        border: Border.all(color: const Color(0xFFFFECB0), width: 1.4),
        boxShadow: const [
          BoxShadow(color: Color(0x66FFD338), blurRadius: 8),
        ],
      ),
      child: const Icon(Icons.stars_rounded, color: AppTheme.navy, size: 21),
    );
  }
}

class WormGamePainter extends CustomPainter {
  final List<Point<int>> worm;
  final Point<int> gold;
  final int rows;
  final int columns;

  WormGamePainter({
    required this.worm,
    required this.gold,
    required this.rows,
    required this.columns,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;

    canvas.drawCircle(
      Offset(size.width * .12, size.height * .18),
      size.width * .34,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withOpacity(.09), Colors.transparent],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * .12, size.height * .18),
            radius: size.width * .34,
          ),
        ),
    );

    final accentPaint = Paint()
      ..color = const Color(0xFFFFD75A).withOpacity(.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 1.02, size.height * .18),
        radius: size.width * .42,
      ),
      1.5,
      2.8,
      false,
      accentPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(-size.width * .04, size.height * .84),
        radius: size.width * .34,
      ),
      -1.6,
      2.5,
      false,
      accentPaint,
    );

    for (var index = 0; index < 24; index++) {
      final x = ((index * 47) % 101) / 101 * size.width;
      final y = ((index * 83) % 97) / 97 * size.height;
      final isGold = index % 4 == 0;
      canvas.drawCircle(
        Offset(x, y),
        isGold ? 1.35 : .75,
        Paint()
          ..color = (isGold ? const Color(0xFFFFD75A) : Colors.white)
              .withOpacity(isGold ? .24 : .12),
      );
    }

    _drawGold(
      canvas,
      gold,
      cellWidth,
      cellHeight,
    );

    final bodyWidth = min(cellWidth, cellHeight) * .68;
    final bodyShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFF0A8), AppTheme.coolYellow, Color(0xFFB58412)],
    ).createShader(Offset.zero & size);
    for (int index = worm.length - 1; index > 0; index--) {
      final from = Offset(
        worm[index].x * cellWidth + cellWidth / 2,
        worm[index].y * cellHeight + cellHeight / 2,
      );
      final to = Offset(
        worm[index - 1].x * cellWidth + cellWidth / 2,
        worm[index - 1].y * cellHeight + cellHeight / 2,
      );
      canvas.drawLine(
        from.translate(1.5, 2.5),
        to.translate(1.5, 2.5),
        Paint()
          ..color = Colors.black.withOpacity(.28)
          ..strokeWidth = bodyWidth + 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        from,
        to,
        Paint()
          ..shader = bodyShader
          ..strokeWidth = bodyWidth
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        from.translate(-1, -1.5),
        to.translate(-1, -1.5),
        Paint()
          ..color = Colors.white.withOpacity(.28)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }

    for (int i = worm.length - 1; i >= 0; i--) {
      _drawWormPart(
        canvas,
        worm[i],
        cellWidth,
        cellHeight,
        isHead: i == 0,
        segmentIndex: i,
      );
    }
  }

  void _drawGold(
    Canvas canvas,
    Point<int> point,
    double cellWidth,
    double cellHeight,
  ) {
    final center = Offset(
      point.x * cellWidth + cellWidth / 2,
      point.y * cellHeight + cellHeight / 2,
    );

    final radius = min(cellWidth, cellHeight) * 0.34;

    final glowPaint = Paint()
      ..color = const Color(0xFFFFD338).withOpacity(0.25);

    canvas.drawCircle(
      center,
      radius * 1.55,
      glowPaint,
    );

    final goldPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-.35, -.35),
        colors: [Color(0xFFFFFFBE), Color(0xFFFFD338), Color(0xFFB97800)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(
      center,
      radius,
      goldPaint,
    );

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..color = const Color(0xFFFFF0A0);

    canvas.drawCircle(
      center,
      radius * 0.72,
      innerPaint,
    );

    final symbolPainter = TextPainter(
      text: const TextSpan(
        text: '★',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    symbolPainter.layout();

    symbolPainter.paint(
      canvas,
      Offset(
        center.dx - symbolPainter.width / 2,
        center.dy - symbolPainter.height / 2,
      ),
    );
  }

  void _drawWormPart(
    Canvas canvas,
    Point<int> point,
    double cellWidth,
    double cellHeight, {
    required bool isHead,
    required int segmentIndex,
  }) {
    final center = Offset(
      point.x * cellWidth + cellWidth / 2,
      point.y * cellHeight + cellHeight / 2,
    );
    final baseRadius = min(cellWidth, cellHeight) * (isHead ? .47 : .40);
    final shadow = Paint()
      ..color = Colors.black.withOpacity(.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center.translate(1.5, 2.5), baseRadius, shadow);

    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.35, -.4),
        colors: isHead
            ? const [Color(0xFFFFED99), AppTheme.coolYellow]
            : const [Color(0xFFFFE9A2), Color(0xFFC79521)],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius));
    canvas.drawCircle(center, baseRadius, bodyPaint);
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFF16375B),
    );

    if (!isHead && segmentIndex.isEven) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: baseRadius * .70),
        -.9,
        1.8,
        false,
        Paint()
          ..color = AppTheme.navy.withOpacity(.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    if (isHead) {
      final facePaint = Paint()..color = AppTheme.navy;
      final eyeWhite = Paint()..color = Colors.white;

      for (final side in [-1.0, 1.0]) {
        final eyeCenter =
            center.translate(side * baseRadius * .30, -baseRadius * .16);
        canvas.drawOval(
          Rect.fromCenter(
            center: eyeCenter,
            width: baseRadius * .34,
            height: baseRadius * .43,
          ),
          eyeWhite,
        );
        canvas.drawCircle(
          eyeCenter.translate(side * baseRadius * .025, baseRadius * .025),
          baseRadius * .09,
          facePaint,
        );
        canvas.drawCircle(
          eyeCenter.translate(side * baseRadius * .01, -baseRadius * .01),
          baseRadius * .025,
          Paint()..color = Colors.white,
        );
      }

      final browPaint = Paint()
        ..color = AppTheme.navy
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center.translate(-baseRadius * .45, -baseRadius * .50),
        center.translate(-baseRadius * .18, -baseRadius * .55),
        browPaint,
      );
      canvas.drawLine(
        center.translate(baseRadius * .18, -baseRadius * .58),
        center.translate(baseRadius * .45, -baseRadius * .48),
        browPaint,
      );

      final smile = Path()
        ..moveTo(center.dx - baseRadius * .25, center.dy + baseRadius * .22)
        ..quadraticBezierTo(
          center.dx,
          center.dy + baseRadius * .48,
          center.dx + baseRadius * .27,
          center.dy + baseRadius * .19,
        );
      canvas.drawPath(
        smile,
        Paint()
          ..color = AppTheme.navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.9
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        center.translate(-baseRadius * .57, baseRadius * .16),
        baseRadius * .09,
        Paint()..color = const Color(0xFFD98E76).withOpacity(.42),
      );
      canvas.drawCircle(
        center.translate(baseRadius * .57, baseRadius * .16),
        baseRadius * .09,
        Paint()..color = const Color(0xFFD98E76).withOpacity(.42),
      );
    }
  }

  @override
  bool shouldRepaint(covariant WormGamePainter oldDelegate) {
    return true;
  }
}
