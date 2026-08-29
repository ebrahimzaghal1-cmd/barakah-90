import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/play_task_session_service.dart';
import '../theme/app_theme.dart';

const List<String> _dhikrPhrases = [
  'سبحان الله',
  'الحمد لله',
  'لا إله إلا الله',
  'الله أكبر',
  'سبحان الله وبحمده',
  'سبحان الله العظيم',
  'أستغفر الله',
  'أستغفر الله وأتوب إليه',
  'لا حول ولا قوة إلا بالله',
  'حسبي الله ونعم الوكيل',
  'اللهم صلِّ وسلم على نبينا محمد',
  'اللهم اغفر لي وارحمني',
];

class IstighfarRingTask extends StatefulWidget {
  const IstighfarRingTask({
    super.key,
    this.rewardEligible = false,
    this.onCompleted,
    this.sessionKey = 'free_istighfar',
    this.taskStartedAt,
    this.rewardExpiresAt,
  });

  final bool rewardEligible;
  final Future<bool> Function()? onCompleted;
  final String sessionKey;
  final DateTime? taskStartedAt;
  final DateTime? rewardExpiresAt;

  @override
  State<IstighfarRingTask> createState() => _IstighfarRingTaskState();
}

class _IstighfarRingTaskState extends State<IstighfarRingTask> {
  static const _target = 100;
  static const _requiredRings = 5;
  static const _duration = Duration(minutes: 10);

  Timer? _timer;
  final _sessions = PlayTaskSessionService();
  DateTime? _startedAt;
  int _count = 0;
  int _dhikrPhraseIndex = 0;
  int _completedRings = 0;
  Duration _remaining = _duration;
  bool _completed = false;
  bool _ringWon = false;
  bool _rewardDelivered = false;
  bool _rewardClaiming = false;
  bool _expired = false;
  bool _loading = true;
  bool _practiceOnly = false;

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
    _count = (saved['count'] as int?)?.clamp(0, _target) ?? 0;
    _completedRings = rulesVersion == 5
        ? (saved['completedRings'] as int?)?.clamp(0, _requiredRings) ?? 0
        : saved['completed'] == true
            ? 1
            : 0;
    if (wasRewardDelivered) _completedRings = _requiredRings;
    _completed = _completedRings >= _requiredRings;
    _ringWon = !_completed && _count >= _target;
    if (rulesVersion != 5) {
      _startedAt = null;
      _completedRings = 0;
      _completed = false;
      _ringWon = false;
      _count = 0;
    }
    _rewardDelivered = wasRewardDelivered;
    _syncRemaining(notify: false);
    if (_startedAt == null && !_expired && !_rewardDelivered) {
      _startedAt = DateTime.now();
      _remaining = _duration;
      await _persist();
    }
    _loading = false;
    if (mounted) setState(() {});
    // Re-submit after reopening so an offline completion is not lost. The
    // secure server prevents the same task from ever being counted twice.
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
      'count': _count,
      'completedRings': _completedRings,
      'completed': _completed,
      'rewardDelivered': _rewardDelivered,
    });
  }

  void _syncRemaining({bool notify = true}) {
    if (_startedAt == null) {
      _remaining = _duration;
      return;
    }
    var next = _duration - DateTime.now().difference(_startedAt!);
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
      if (notify && _canEarnPoints) unawaited(_claimReward());
    } else {
      _expired = true;
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
      if (confirmed) _rewardDelivered = true;
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

  void _increment() {
    if (_completed || _ringWon || _expired) return;
    _startTimer();
    HapticFeedback.selectionClick();
    setState(() {
      _count++;
      _dhikrPhraseIndex = (_dhikrPhraseIndex + 1) % _dhikrPhrases.length;
    });
    if (_count >= _target) {
      setState(() {
        _completedRings += 1;
        _completed = _completedRings >= _requiredRings;
        _ringWon = !_completed;
      });
      if (_completed) {
        _timer?.cancel();
        if (_canEarnPoints && !_rewardDelivered) unawaited(_claimReward());
      }
    }
    _persist();
  }

  void _startNextRing() {
    if (_completed || _expired) return;
    setState(() {
      _count = 0;
      _dhikrPhraseIndex = 0;
      _ringWon = false;
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
      _count = 0;
      _dhikrPhraseIndex = 0;
      _completedRings = 0;
      _remaining = _duration;
      _completed = false;
      _ringWon = false;
      _rewardDelivered = false;
      _expired = false;
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
        title: const Text('خاتم الاستغفار'),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF193A5A), Color(0xFF4B2469), Color(0xFFB36A3C)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                _IstighfarMissionHeader(
                  time: _timeLabel,
                  completedRings: _completedRings,
                  currentCount: _count,
                  rewardLabel: _rewardDelivered
                      ? 'تم الاحتساب'
                      : _rewardClaiming
                          ? 'جارٍ التسجيل...'
                          : _canEarnPoints
                              ? '+2 بعد 5 حلقات'
                              : 'لعب حر',
                ),
                const Spacer(),
                SizedBox(
                  width: 306,
                  height: 306,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(painter: _LuxuryRingPainter()),
                      ),
                      SizedBox.expand(
                        child: Padding(
                          padding: const EdgeInsets.all(25),
                          child: CircularProgressIndicator(
                            value: _count / _target,
                            strokeWidth: 11,
                            color: const Color(0xFFFFE88A),
                            strokeCap: StrokeCap.round,
                            backgroundColor: Colors.white.withOpacity(.13),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        elevation: 18,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _increment,
                          child: Ink(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                center: Alignment(-.25, -.3),
                                colors: [Color(0xFF315278), Color(0xFF101A35)],
                              ),
                              border: Border.all(
                                color: const Color(0xFFFFD75A),
                                width: 4,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x99FFCA3A),
                                  blurRadius: 22,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFFFFE88A),
                                  size: 26,
                                ),
                                Text(
                                  '$_count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 64,
                                    height: 1.05,
                                    fontWeight: FontWeight.w900,
                                    shadows: [
                                      Shadow(
                                          color: Color(0xFFFFD75A),
                                          blurRadius: 16),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    _dhikrPhrases[_dhikrPhraseIndex],
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFFFE88A),
                                      fontSize: 18,
                                      height: 1.25,
                                      fontWeight: FontWeight.w900,
                                    ),
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
                const SizedBox(height: 26),
                Text(
                  _completed
                      ? _rewardDelivered
                          ? _canEarnPoints
                              ? 'أتممت الحلقات الخمس وأُضيفت نقطتان 🎉'
                              : 'أتممت الحلقات الخمس، تقبّل الله منك 🎉'
                          : 'أتممت الحلقات الخمس بنجاح ✓'
                      : _ringWon
                          ? 'أتممت الحلقة $_completedRings من $_requiredRings ✓'
                          : _expired
                              ? 'انتهى الوقت، يمكنك المحاولة مجددًا.'
                              : 'أكمل 5 حلقات، كل حلقة 100 استغفار',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_ringWon) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _startNextRing,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('ابدأ الحلقة ${_completedRings + 1}'),
                  ),
                ] else if (_expired || _rewardDelivered || _completed) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _completed && _canEarnPoints && !_rewardDelivered
                        ? (_rewardClaiming ? null : _claimReward)
                        : _retry,
                    icon: _completed && _canEarnPoints && !_rewardDelivered
                        ? const Icon(Icons.cloud_upload_rounded)
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      _completed && _canEarnPoints && !_rewardDelivered
                          ? 'تسجيل النقطتين'
                          : _completed
                              ? 'ابدأ من جديد'
                              : 'حاول مرة أخرى',
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IstighfarMissionHeader extends StatelessWidget {
  const _IstighfarMissionHeader({
    required this.time,
    required this.completedRings,
    required this.currentCount,
    required this.rewardLabel,
  });

  final String time;
  final int completedRings;
  final int currentCount;
  final String rewardLabel;

  @override
  Widget build(BuildContext context) {
    final currentRing = min(completedRings + 1, 5);
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
              const Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.coolYellow),
              const SizedBox(width: 8),
              Text(
                'الحلقة $currentRing من 5',
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
                      color: index < completedRings
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
              'تقدّم الحلقة الحالية: $currentCount من 100',
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

class _LuxuryRingPainter extends CustomPainter {
  const _LuxuryRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .46;
    final glow = Paint()
      ..color = const Color(0xFFFFC93B).withOpacity(.23)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, radius, glow);

    for (var index = 0; index < 24; index++) {
      final angle = (pi * 2 * index / 24) - pi / 2;
      final beadCenter = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      final bead = Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.35),
          colors: [Color(0xFFFFF1A6), Color(0xFFFFC82E), Color(0xFF9D5B00)],
        ).createShader(Rect.fromCircle(center: beadCenter, radius: 9));
      canvas.drawCircle(beadCenter, index % 6 == 0 ? 10 : 8, bead);
      canvas.drawCircle(
        beadCenter,
        index % 6 == 0 ? 10 : 8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFFFF4B0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LuxuryRingPainter oldDelegate) => false;
}
