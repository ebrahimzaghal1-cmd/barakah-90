import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/play_task_session_service.dart';
import '../theme/app_theme.dart';

class SnakesLaddersGame extends StatefulWidget {
  const SnakesLaddersGame({
    super.key,
    this.rewardEligible = false,
    this.onCompleted,
    this.sessionKey = 'free_snakes',
    this.taskStartedAt,
    this.rewardExpiresAt,
  });

  final bool rewardEligible;
  final Future<bool> Function()? onCompleted;
  final String sessionKey;
  final DateTime? taskStartedAt;
  final DateTime? rewardExpiresAt;

  @override
  State<SnakesLaddersGame> createState() => _SnakesLaddersGameState();
}

class _SnakesLaddersGameState extends State<SnakesLaddersGame> {
  static const _lastSquare = 30;
  static const _requiredSuccessfulGames = 5;
  static const _duration = Duration(minutes: 10);
  static const _jumps = <int, int>{
    3: 11,
    8: 17,
    15: 26,
    28: 12,
    24: 16,
    20: 6,
  };

  final _random = Random();
  final _sessions = PlayTaskSessionService();
  Timer? _timer;
  DateTime? _startedAt;
  int _position = 1;
  int _dice = 1;
  int _successfulGames = 0;
  Duration _remaining = _duration;
  bool _rolling = false;
  bool _completed = false;
  bool _roundWon = false;
  bool _rewardDelivered = false;
  bool _rewardClaiming = false;
  bool _expired = false;
  bool _practiceOnly = false;
  String _message = 'ارمِ النرد وابدأ الرحلة!';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final saved = widget.sessionKey.startsWith('practice_')
        ? <String, dynamic>{}
        : await _sessions.load(widget.sessionKey);
    final rulesVersion = saved['rulesVersion'] as int?;
    final wasRewardDelivered =
        rulesVersion == 5 && saved['rewardDelivered'] == true;
    final startedAtMillis = saved['startedAt'] as int?;
    if (widget.rewardEligible && widget.taskStartedAt != null) {
      _startedAt = widget.taskStartedAt;
    } else if (startedAtMillis != null) {
      _startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMillis);
    }
    _position = (saved['position'] as int?)?.clamp(1, _lastSquare) ?? 1;
    _dice = (saved['dice'] as int?)?.clamp(1, 6) ?? 1;
    _successfulGames = rulesVersion == 5
        ? (saved['successfulGames'] as int?)
                ?.clamp(0, _requiredSuccessfulGames) ??
            0
        : saved['completed'] == true
            ? 1
            : 0;
    if (wasRewardDelivered) {
      _successfulGames = _requiredSuccessfulGames;
    }
    _completed = _successfulGames >= _requiredSuccessfulGames;
    _roundWon = !_completed && _position >= _lastSquare;
    if (rulesVersion != 5) {
      _startedAt = null;
      _position = 1;
      _dice = 1;
      _successfulGames = 0;
      _completed = false;
      _roundWon = false;
      _message = 'ارمِ النرد وابدأ اللعبة 1 من 5';
    }
    _rewardDelivered = saved['rewardDelivered'] == true;
    _message = saved['message'] as String? ?? _message;
    _syncRemaining(notify: false);
    if (_startedAt == null && !_expired && !_rewardDelivered) {
      _startedAt = DateTime.now();
      _remaining = _duration;
      await _persist();
    }
    _loading = false;
    if (mounted) setState(() {});
    // Re-submit a completed mission when it is reopened. The server owns the
    // final once-only decision, so this also safely recovers from lost network.
    if (_completed && !_rewardDelivered && _canEarnPoints) {
      unawaited(_claimReward());
    }
    if (!_expired && !_rewardDelivered) _startTimer();
  }

  bool get _canEarnPoints => widget.rewardEligible && !_practiceOnly;

  Future<void> _persist() {
    if (_practiceOnly || widget.sessionKey.startsWith('practice_')) {
      return Future<void>.value();
    }
    return _sessions.save(widget.sessionKey, {
      'rulesVersion': 5,
      'startedAt': _startedAt?.millisecondsSinceEpoch,
      'position': _position,
      'dice': _dice,
      'successfulGames': _successfulGames,
      'completed': _completed,
      'rewardDelivered': _rewardDelivered,
      'message': _message,
    });
  }

  void _syncRemaining({bool notify = true}) {
    if (_startedAt == null) {
      _remaining = _duration;
      return;
    }
    final elapsed = DateTime.now().difference(_startedAt!);
    var next = _duration - elapsed;
    if (_canEarnPoints && widget.rewardExpiresAt != null) {
      final orderWindow = widget.rewardExpiresAt!.difference(DateTime.now());
      if (orderWindow < next) next = orderWindow;
    }
    _remaining = next.isNegative ? Duration.zero : next;
    if (_remaining == Duration.zero && !_rewardDelivered && !_expired) {
      _finishTimedMission(notify: notify);
    }
  }

  void _finishTimedMission({bool notify = true}) {
    _timer?.cancel();
    if (_completed) {
      _message = _rewardDelivered
          ? 'اكتملت الألعاب الخمس وأُضيفت نقطتان'
          : 'اكتملت الألعاب الخمس، جارٍ تثبيت النقاط';
      if (notify && _canEarnPoints) unawaited(_claimReward());
    } else {
      _expired = true;
      _message = 'انتهى وقت هذه المهمة. يمكنك كسب نقاط المهمات الأخرى.';
    }
    _persist();
  }

  Future<void> _claimReward() async {
    if (!_canEarnPoints ||
        !_completed ||
        _rewardDelivered ||
        _rewardClaiming ||
        widget.onCompleted == null) {
      return;
    }
    if (mounted) setState(() => _rewardClaiming = true);
    final confirmed = await widget.onCompleted!.call();
    if (!mounted) return;
    setState(() {
      _rewardClaiming = false;
      if (confirmed) {
        _rewardDelivered = true;
        _message = 'أنهيت الألعاب الخمس وأُضيفت نقطتان ✓';
      } else {
        _message = 'أنهيت المهمة. اضغط لتسجيل النقطتين عند عودة الإنترنت.';
      }
    });
    await _persist();
  }

  void _startTimer() {
    if (_timer != null) return;
    _startedAt ??= DateTime.now();
    _persist();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _syncRemaining();
      setState(() {});
    });
  }

  Future<void> _roll() async {
    if (_rolling || _completed || _roundWon || _expired) return;
    _startTimer();
    setState(() => _rolling = true);
    for (var index = 0; index < 7; index++) {
      await Future<void>.delayed(const Duration(milliseconds: 75));
      if (!mounted) return;
      await SystemSound.play(SystemSoundType.click);
      HapticFeedback.selectionClick();
      setState(() => _dice = _random.nextInt(6) + 1);
    }
    await SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();

    var next = min(_lastSquare, _position + _dice);
    var message = 'تقدّمت $_dice خطوات';
    if (_jumps.containsKey(next)) {
      final destination = _jumps[next]!;
      message = destination > next
          ? 'سلّم رائع! صعدت من $next إلى $destination 🪜'
          : 'أمسكت بك الحيّة! نزلت من $next إلى $destination 🐍';
      next = destination;
    }

    setState(() {
      _position = next;
      _rolling = false;
      _message = message;
    });
    _persist();

    if (_position >= _lastSquare) {
      setState(() {
        _successfulGames += 1;
        _completed = _successfulGames >= _requiredSuccessfulGames;
        _roundWon = !_completed;
        _message = _completed
            ? 'أنهيت اللوحة 5 مرات بنجاح ✓ أُضيفت نقطتا المهمة.'
            : 'نجحت في اللعبة $_successfulGames من $_requiredSuccessfulGames!';
      });
      if (_completed) {
        _timer?.cancel();
        if (_canEarnPoints && !_rewardDelivered) unawaited(_claimReward());
      }
      _persist();
    }
  }

  void _startNextGame() {
    if (_completed || _expired) return;
    setState(() {
      _position = 1;
      _dice = 1;
      _rolling = false;
      _roundWon = false;
      _message = 'ابدأ اللعبة ${_successfulGames + 1} من 5';
    });
    _persist();
  }

  Future<void> _retry() async {
    _timer?.cancel();
    if (widget.rewardEligible) {
      _practiceOnly = true;
    } else {
      await _sessions.clear(widget.sessionKey);
    }
    setState(() {
      _timer = null;
      _startedAt = DateTime.now();
      _position = 1;
      _dice = 1;
      _successfulGames = 0;
      _remaining = _duration;
      _rolling = false;
      _completed = false;
      _roundWon = false;
      _rewardDelivered = false;
      _expired = false;
      _message = 'ارمِ النرد وابدأ الرحلة!';
    });
    _startTimer();
  }

  String get _timeLabel {
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('الحيّة والسلم'),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF5535A5), Color(0xFF167D91), Color(0xFFFFD45A)],
            stops: [0, .62, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              children: [
                _SnakesMissionHeader(
                  time: _timeLabel,
                  successfulGames: _successfulGames,
                  currentSquare: _position,
                  rewardLabel: _rewardDelivered
                      ? 'تم الاحتساب'
                      : _rewardClaiming
                          ? 'جارٍ التسجيل...'
                          : _canEarnPoints
                              ? '+2 بعد 5 ألعاب'
                              : 'لعب حر',
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _completed || _roundWon
                      ? Container(
                          key: const ValueKey('mission-success'),
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0A6A51), Color(0xFF15906A)],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0x99FFE06A)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                color: AppTheme.coolYellow,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _completed
                                      ? _rewardDelivered
                                          ? 'أنهيت الألعاب الخمس وأُضيفت نقطتان'
                                          : 'أنهيت الألعاب الخمس بنجاح'
                                      : 'نجحت في اللعبة $_successfulGames • بقي ${_requiredSuccessfulGames - _successfulGames}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8C5A2B), Color(0xFFD9A85B)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: const Color(0xFF5C351A), width: 4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x59000000),
                          blurRadius: 20,
                          offset: Offset(0, 12),
                        ),
                        BoxShadow(
                          color: Color(0x66FFF0C2),
                          blurRadius: 2,
                          offset: Offset(-2, -2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: LayoutBuilder(
                        builder: (context, board) {
                          const gap = 4.0;
                          final cellWidth = (board.maxWidth - gap * 4) / 5;
                          final cellHeight = (board.maxHeight - gap * 5) / 6;
                          final rowFromBottom = (_position - 1) ~/ 5;
                          final positionInRow = (_position - 1) % 5;
                          final column = rowFromBottom.isEven
                              ? positionInRow
                              : 4 - positionInRow;
                          final visualRow = 5 - rowFromBottom;
                          final tokenSize = min(cellWidth, cellHeight) * .82;
                          final tokenLeft = column * (cellWidth + gap) +
                              (cellWidth - tokenSize) / 2;
                          final tokenTop = visualRow * (cellHeight + gap) +
                              (cellHeight - tokenSize) / 2;

                          return Stack(
                            children: [
                              GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _lastSquare,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  crossAxisSpacing: gap,
                                  mainAxisSpacing: gap,
                                  childAspectRatio: cellWidth / cellHeight,
                                ),
                                itemBuilder: (context, visualIndex) {
                                  final row = visualIndex ~/ 5;
                                  final column = visualIndex % 5;
                                  final base = _lastSquare - (row * 5);
                                  final square = row.isEven
                                      ? base - column
                                      : base - 4 + column;
                                  return _BoardSquare(number: square);
                                },
                              ),
                              const Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _BoardRoutesPainter(_jumps),
                                  ),
                                ),
                              ),
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 520),
                                curve: Curves.easeOutBack,
                                left: tokenLeft,
                                top: tokenTop,
                                width: tokenSize,
                                height: tokenSize,
                                child: const _BarakahRabbitToken(),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.88),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _message,
                      key: ValueKey(_message),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_roundWon)
                  ElevatedButton.icon(
                    onPressed: _startNextGame,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('ابدأ اللعبة ${_successfulGames + 1}'),
                  )
                else if (_completed && _canEarnPoints && !_rewardDelivered)
                  ElevatedButton.icon(
                    onPressed: _rewardClaiming ? null : _claimReward,
                    icon: _rewardClaiming
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_rounded),
                    label: const Text('تسجيل النقطتين'),
                  )
                else if (_expired || _rewardDelivered || _completed)
                  ElevatedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      _completed ? 'العب مرة ثانية' : 'حاول مرة أخرى',
                    ),
                  )
                else
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _rolling || _completed || _roundWon ? null : _roll,
                      child: Ink(
                        width: 235,
                        height: 68,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFE66D), Color(0xFFFF9C31)],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _RealDice(
                              value: _dice,
                              rolling: _rolling,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _completed
                                  ? 'انتظر انتهاء الوقت'
                                  : _rolling
                                      ? 'النرد يدور...'
                                      : 'ارمِ النرد',
                              style: const TextStyle(
                                color: AppTheme.navy,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
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

class _SnakesMissionHeader extends StatelessWidget {
  const _SnakesMissionHeader({
    required this.time,
    required this.successfulGames,
    required this.currentSquare,
    required this.rewardLabel,
  });

  final String time;
  final int successfulGames;
  final int currentSquare;
  final String rewardLabel;

  @override
  Widget build(BuildContext context) {
    final currentGame = min(successfulGames + 1, 5);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF203E68), Color(0xFF0B1E3B)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x77FFD75A)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 15, offset: Offset(0, 7)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.casino_rounded, color: AppTheme.coolYellow),
              const SizedBox(width: 8),
              Text(
                'اللعبة $currentGame من 5',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      color: AppTheme.coolYellow,
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                    ),
                  ),
                  Text(
                    rewardLabel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var index = 0; index < 5; index++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 8,
                    decoration: BoxDecoration(
                      color: index < successfulGames
                          ? AppTheme.coolYellow
                          : Colors.white.withOpacity(.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                if (index < 4) const SizedBox(width: 5),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'تقدّم اللوحة الحالية: $currentSquare من 30',
              style: const TextStyle(
                color: Color(0xFFDCE7F6),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RealDice extends StatelessWidget {
  const _RealDice({required this.value, required this.rolling});

  final int value;
  final bool rolling;

  static const _dotPositions = <int, List<Alignment>>{
    1: [Alignment.center],
    2: [Alignment.topLeft, Alignment.bottomRight],
    3: [Alignment.topLeft, Alignment.center, Alignment.bottomRight],
    4: [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ],
    5: [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.center,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ],
    6: [
      Alignment.topLeft,
      Alignment.centerLeft,
      Alignment.bottomLeft,
      Alignment.topRight,
      Alignment.centerRight,
      Alignment.bottomRight,
    ],
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: rolling ? value / 4 : 0,
      duration: const Duration(milliseconds: 90),
      child: AnimatedScale(
        scale: rolling ? .88 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFE8E8E8), Color(0xFFB9BEC7)],
              stops: [0, .68, 1],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF9E8240), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 6,
                offset: Offset(3, 5),
              ),
              BoxShadow(
                color: Colors.white70,
                blurRadius: 2,
                offset: Offset(-2, -2),
              ),
            ],
          ),
          child: Stack(
            children: [
              for (final alignment in _dotPositions[value]!)
                Align(
                  alignment: alignment,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF111827),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 1,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardSquare extends StatelessWidget {
  const _BoardSquare({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    const freshColors = [
      [Color(0xFFF2E1B9), Color(0xFFD8BD80)],
      [Color(0xFF7FA6A0), Color(0xFF4E7772)],
      [Color(0xFFD88F67), Color(0xFFA95A3C)],
      [Color(0xFFD6C65B), Color(0xFFA99A32)],
      [Color(0xFF7790B2), Color(0xFF4C6688)],
    ];
    final squareColors = freshColors[number % freshColors.length];
    final darkText = number % freshColors.length == 0;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: squareColors),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(.32), width: .8),
        boxShadow: const [
          BoxShadow(
              color: Color(0x26000000), blurRadius: 2, offset: Offset(1, 2)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 3,
            left: 3,
            child: Container(
              width: 21,
              height: 21,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: darkText
                    ? AppTheme.navy.withOpacity(.82)
                    : Colors.white.withOpacity(.82),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  color: darkText ? Colors.white : AppTheme.navy,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarakahRabbitToken extends StatelessWidget {
  const _BarakahRabbitToken();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFD75A),
          border: Border.all(color: Colors.white, width: 2.4),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: Image.asset(
            'assets/images/barakah_header_bunny.png',
            fit: BoxFit.cover,
            alignment: const Alignment(.42, -.18),
          ),
        ),
      );
}

class _BoardRoutesPainter extends CustomPainter {
  const _BoardRoutesPainter(this.jumps);

  final Map<int, int> jumps;
  static const gap = 4.0;

  Offset _centerFor(int square, Size size) {
    final cellWidth = (size.width - gap * 4) / 5;
    final cellHeight = (size.height - gap * 5) / 6;
    final rowFromBottom = (square - 1) ~/ 5;
    final positionInRow = (square - 1) % 5;
    final column = rowFromBottom.isEven ? positionInRow : 4 - positionInRow;
    final visualRow = 5 - rowFromBottom;
    return Offset(
      column * (cellWidth + gap) + cellWidth / 2,
      visualRow * (cellHeight + gap) + cellHeight / 2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in jumps.entries) {
      final start = _centerFor(entry.key, size);
      final end = _centerFor(entry.value, size);
      if (entry.value > entry.key) {
        _drawLadder(canvas, start, end);
      } else {
        _drawSnake(canvas, start, end, entry.key);
      }
    }
  }

  void _drawLadder(Canvas canvas, Offset start, Offset end) {
    final vector = end - start;
    final length = vector.distance;
    if (length == 0) return;
    final direction = vector / length;
    final perpendicular = Offset(-direction.dy, direction.dx);
    final leftStart = start + perpendicular * 6;
    final leftEnd = end + perpendicular * 6;
    final rightStart = start - perpendicular * 6;
    final rightEnd = end - perpendicular * 6;

    final shadow = Paint()
      ..color = Colors.black.withOpacity(.34)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final wood = Paint()
      ..color = const Color(0xFFF1C36A)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(leftStart.translate(2, 2), leftEnd.translate(2, 2), shadow);
    canvas.drawLine(
        rightStart.translate(2, 2), rightEnd.translate(2, 2), shadow);
    canvas.drawLine(leftStart, leftEnd, wood);
    canvas.drawLine(rightStart, rightEnd, wood);

    final rungs = max(4, (length / 22).floor());
    for (var index = 1; index < rungs; index++) {
      final t = index / rungs;
      final middle = Offset.lerp(start, end, t)!;
      canvas.drawLine(
        middle + perpendicular * 6,
        middle - perpendicular * 6,
        Paint()
          ..color = const Color(0xFFFFE2A0)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawSnake(Canvas canvas, Offset head, Offset tail, int seed) {
    final vector = tail - head;
    final length = vector.distance;
    if (length == 0) return;
    final direction = vector / length;
    final perpendicular = Offset(-direction.dy, direction.dx);
    final curve = Path()
      ..moveTo(head.dx, head.dy)
      ..cubicTo(
        head.dx + vector.dx * .30 + perpendicular.dx * 25,
        head.dy + vector.dy * .30 + perpendicular.dy * 25,
        head.dx + vector.dx * .66 - perpendicular.dx * 25,
        head.dy + vector.dy * .66 - perpendicular.dy * 25,
        tail.dx,
        tail.dy,
      );
    canvas.drawPath(
      curve,
      Paint()
        ..color = Colors.black.withOpacity(.36)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
    final snakeColor =
        seed.isEven ? const Color(0xFFB43E39) : const Color(0xFF276D54);
    canvas.drawPath(
      curve,
      Paint()
        ..color = snakeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      curve,
      Paint()
        ..color = Colors.white.withOpacity(.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawOval(
      Rect.fromCenter(center: head, width: 24, height: 20),
      Paint()..color = snakeColor,
    );
    for (final side in [-1.0, 1.0]) {
      final eye = head + perpendicular * side * 5 - direction * 2;
      canvas.drawCircle(eye, 3.2, Paint()..color = Colors.white);
      canvas.drawCircle(
          eye + direction * .7, 1.5, Paint()..color = Colors.black);
    }
    canvas.drawLine(
      head - direction * 11,
      head - direction * 17,
      Paint()
        ..color = const Color(0xFFE24C4B)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BoardRoutesPainter oldDelegate) => false;
}
