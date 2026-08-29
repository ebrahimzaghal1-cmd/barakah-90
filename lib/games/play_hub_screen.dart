import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firebase_state.dart';
import '../services/order_service.dart';
import '../services/play_rewards_service.dart';
import '../services/play_task_session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/barakah_brand.dart';
import 'gold_worm_game.dart';
import 'istighfar_ring_task.dart';
import 'snakes_ladders_game.dart';

class PlayHubScreen extends StatefulWidget {
  const PlayHubScreen({super.key});

  @override
  State<PlayHubScreen> createState() => _PlayHubScreenState();
}

class _PlayHubScreenState extends State<PlayHubScreen> {
  final _rewards = PlayRewardsService();
  final Set<String> _claiming = {};
  final Set<String> _starting = {};
  final Map<String, Future<bool>> _claimRequests = {};

  static const _taskIds = ['snakes', 'istighfar', 'goldWorm'];
  static const _rewardWindow = Duration(minutes: 30);
  Timer? _windowTicker;

  @override
  void initState() {
    super.initState();
    unawaited(PlayTaskSessionService().clearPracticeSessions());
    _windowTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _windowTicker?.cancel();
    super.dispose();
  }

  Future<bool> _claimTask(
    String orderId,
    String taskId,
    PlayTaskRewardSession session,
  ) {
    final existing = _claimRequests[taskId];
    if (existing != null) return existing;
    final request = _performClaim(orderId, taskId, session);
    _claimRequests[taskId] = request;
    request.whenComplete(() => _claimRequests.remove(taskId));
    return request;
  }

  Future<bool> _performClaim(
    String orderId,
    String taskId,
    PlayTaskRewardSession session,
  ) async {
    setState(() => _claiming.add(taskId));
    try {
      final result = await _rewards.claimTask(
        orderId: orderId,
        taskId: taskId,
        session: session,
      );
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            result.newlyAwarded
                ? 'مبروك! أُضيفت نقطتان إلى رصيدك 🎉'
                : 'هذه المهمة محسوبة سابقًا.',
          ),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      final message = error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('StateError: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message.isEmpty
              ? 'تعذر تسجيل النقاط الآن. تحقق من الإنترنت وحاول مجددًا.'
              : message),
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _claiming.remove(taskId));
    }
  }

  Future<bool> _confirmTaskInstructions({
    required String taskId,
    required bool rewardMode,
  }) async {
    final title = switch (taskId) {
      'snakes' => 'تعليمات الحيّة والسلم',
      'istighfar' => 'تعليمات خاتم الاستغفار',
      _ => 'تعليمات دودة الذهب',
    };

    final mission = switch (taskId) {
      'snakes' =>
        'أكمل اللوحة المطلوبة بنجاح. إذا فشلت يمكنك إعادة المحاولة من البداية ما دام الوقت متاحًا.',
      'istighfar' =>
        'أكمل 5 حلقات، كل حلقة 100 استغفار. يمكنك إعادة المحاولة إذا لم تكتمل المهمة.',
      _ =>
        'اجمع 5 عملات دون اصطدام وحقق 5 ألعاب ناجحة. إذا اصطدمت تبدأ المهمة من البداية ويمكنك المحاولة مجددًا.',
    };

    final modeText = rewardMode
        ? 'هذه مهمة مرافقة للطلب. لديك حتى 30 دقيقة من وقت إنشاء الطلب. عند إكمال 5 جولات ناجحة في المهمة تحصل على نقطتين، وتُحتسب المكافأة مرة واحدة فقط للطلب.'
        : 'أنت الآن في اللعب الحر. يمكنك اللعب بلا حدود، لكن لا تُحتسب نقاط. عند إنشاء طلب تتفعّل مهمة بركة لمدة 30 دقيقة.';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 54,
              color: AppTheme.deepYellow,
            ),
            const SizedBox(height: 14),
            Text(
              mission,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              modeText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('ابدأ اللعبة'),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _openTask({
    required String? orderId,
    required String taskId,
    bool practiceReplay = false,
    DateTime? rewardExpiresAt,
  }) async {
    final confirmed = await _confirmTaskInstructions(
      taskId: taskId,
      rewardMode: orderId != null && !practiceReplay,
    );
    if (!confirmed || !mounted) return;

    final rewardEligible = orderId != null && !practiceReplay;
    PlayTaskRewardSession? rewardSession;
    if (rewardEligible) {
      if (_starting.contains(taskId)) return;
      setState(() => _starting.add(taskId));
      try {
        rewardSession = await _rewards.startTask(
          orderId: orderId,
          taskId: taskId,
        );
      } catch (error) {
        if (!mounted) return;
        final message = error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('StateError: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(message),
          ),
        );
        return;
      } finally {
        if (mounted) setState(() => _starting.remove(taskId));
      }
    }
    if (!mounted) return;
    final sessionKey = practiceReplay
        ? 'practice_${taskId}_${DateTime.now().millisecondsSinceEpoch}'
        : '${orderId ?? 'free'}_$taskId';
    Future<bool> onCompleted() {
      if (orderId == null || rewardSession == null) {
        return Future<bool>.value(false);
      }
      return _claimTask(orderId, taskId, rewardSession);
    }

    final Widget screen = switch (taskId) {
      'snakes' => SnakesLaddersGame(
          rewardEligible: rewardEligible,
          onCompleted: onCompleted,
          sessionKey: sessionKey,
          taskStartedAt: rewardSession?.startedAt,
          rewardExpiresAt: rewardSession?.expiresAt ?? rewardExpiresAt,
        ),
      'istighfar' => IstighfarRingTask(
          rewardEligible: rewardEligible,
          onCompleted: onCompleted,
          sessionKey: sessionKey,
          taskStartedAt: rewardSession?.startedAt,
          rewardExpiresAt: rewardSession?.expiresAt ?? rewardExpiresAt,
        ),
      _ => GoldWormGame(
          rewardEligible: rewardEligible,
          onRewardEarned: onCompleted,
          sessionKey: sessionKey,
          taskStartedAt: rewardSession?.startedAt,
          rewardExpiresAt: rewardSession?.expiresAt ?? rewardExpiresAt,
        ),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Map<String, bool> _completedTasks(Map<String, dynamic> order) {
    final raw = order['playRewardTasks'];
    if (raw is! Map) return const {};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value == true),
    );
  }

  Widget _freePlayContent() => _PlayHubContent(
        completed: const {},
        completedCount: 0,
        claiming: const {},
        rewardMode: false,
        onOpen: (taskId) => _openTask(orderId: null, taskId: taskId),
      );

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseState.isReady ? FirebaseAuth.instance.currentUser : null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'تسلّى مع بركة',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      backgroundColor: Colors.transparent,
      body: BarakahBrandBackdrop(
        child: !FirebaseState.isReady || user == null
            ? _freePlayContent()
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: OrderService().customerOrders(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _freePlayContent();
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  const excludedStatuses = {
                    'rejected',
                    'cancelled',
                    'canceled',
                    'delivered',
                    'completed',
                    'finished',
                  };
                  final eligibleOrders = snapshot.data!.docs
                      .where((doc) => !excludedStatuses
                          .contains(doc.data()['status']?.toString()))
                      .toList()
                    ..sort((a, b) {
                      final left = a.data()['createdAt'] as Timestamp?;
                      final right = b.data()['createdAt'] as Timestamp?;
                      return (right?.millisecondsSinceEpoch ?? 0)
                          .compareTo(left?.millisecondsSinceEpoch ?? 0);
                    });

                  if (eligibleOrders.isEmpty) {
                    return _freePlayContent();
                  }

                  final activeOrder = eligibleOrders.first;
                  final completed = _completedTasks(activeOrder.data());
                  final completedCount =
                      _taskIds.where((task) => completed[task] == true).length;
                  final createdAt =
                      activeOrder.data()['createdAt'] as Timestamp?;
                  final rewardExpiresAt =
                      createdAt?.toDate().add(_rewardWindow);
                  final rewardWindowOpen = rewardExpiresAt != null &&
                      rewardExpiresAt.isAfter(DateTime.now());
                  if (completedCount < _taskIds.length && !rewardWindowOpen) {
                    return _freePlayContent();
                  }
                  return _PlayHubContent(
                    completed: completed,
                    completedCount: completedCount,
                    claiming: {..._claiming, ..._starting},
                    rewardMode: true,
                    onOpen: (taskId) {
                      final replay = completed[taskId] == true;
                      _openTask(
                        orderId: replay ? null : activeOrder.id,
                        taskId: taskId,
                        practiceReplay: replay,
                        rewardExpiresAt: replay ? null : rewardExpiresAt,
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _PlayHubContent extends StatelessWidget {
  const _PlayHubContent({
    required this.completed,
    required this.completedCount,
    required this.claiming,
    required this.rewardMode,
    required this.onOpen,
  });

  final Map<String, bool> completed;
  final int completedCount;
  final Set<String> claiming;
  final bool rewardMode;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final points = completedCount * PlayRewardsService.taskPoints;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.coolYellow.withOpacity(.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.deepYellow.withOpacity(.24)),
          ),
          child: const Text(
            'اطلب، العب، واجمع النقاط… ووفّر أكثر في طلباتك القادمة! 🎁',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 14),
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 650),
          tween: Tween(begin: .92, end: 1),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.scale(
            scale: scale,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [Color(0xFF0B1937), Color(0xFF29497E)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x42122447),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                PositionedDirectional(
                  end: -26,
                  top: -34,
                  child: Container(
                    width: 126,
                    height: 126,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.coolYellow.withOpacity(.12),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(rewardMode ? '🏆' : '🎮',
                            style: const TextStyle(fontSize: 34)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rewardMode
                                ? 'جولة طلبك جاهزة!'
                                : 'استمتع باللعب مجانًا',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      rewardMode
                          ? 'أنهِ المهام الثلاث خلال 10 دقائق لكل مهمة واجمع 6 نقاط.'
                          : 'الألعاب متاحة للجميع، والنقاط تتفعّل تلقائيًا عند إنشاء طلب.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(.78),
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (rewardMode) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: completedCount / 3,
                          minHeight: 11,
                          color: AppTheme.coolYellow,
                          backgroundColor: Colors.white.withOpacity(.16),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '$completedCount/3 مهام',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$points/6 نقاط',
                            style: const TextStyle(
                              color: AppTheme.coolYellow,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.12),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text(
                          'لعب حر • بدون نقاط محتسبة',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (rewardMode && completedCount == 3) ...[
          const _MissionCompleteCelebration(),
          const SizedBox(height: 18),
        ],
        const Text(
          'اختر مهمتك',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.deepYellow.withOpacity(.35)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x17122447),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppTheme.coolYellow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: AppTheme.navy),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  rewardMode
                      ? 'تعليمات اللعب: أكمل 5 جولات ناجحة في المهمة لتحصل على نقطتين. لديك 30 دقيقة من وقت إنشاء الطلب، ويمكنك إعادة المحاولة عند الفشل ما دام الوقت لم ينتهِ. تُحتسب المكافأة مرة واحدة فقط للطلب.'
                      : 'تعليمات اللعب: اختر أي لعبة واستمتع بها مجانًا. اللعب الحر لا يمنح نقاطًا. عند إنشاء طلب تتفعّل مهمة بركة لمدة 30 دقيقة.',
                  style: const TextStyle(
                    color: AppTheme.navy,
                    height: 1.55,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        _PlayTaskCard(
          title: 'الحيّة والسلم',
          subtitle: 'أنهِ اللوحة 5 مرات ناجحة خلال عشر دقائق',
          artwork: _MissionArtworkType.snakes,
          colors: const [Color(0xFF27A76B), Color(0xFF0A6A51)],
          completed: completed['snakes'] == true,
          loading: claiming.contains('snakes'),
          rewardMode: rewardMode,
          onTap: () => onOpen('snakes'),
        ),
        _PlayTaskCard(
          title: 'خاتم الاستغفار',
          subtitle: 'أكمل 5 حلقات؛ كل حلقة 100 استغفار',
          artwork: _MissionArtworkType.ring,
          colors: const [Color(0xFF9B68D4), Color(0xFF59369A)],
          completed: completed['istighfar'] == true,
          loading: claiming.contains('istighfar'),
          rewardMode: rewardMode,
          onTap: () => onOpen('istighfar'),
        ),
        _PlayTaskCard(
          title: 'دودة الذهب',
          subtitle: 'أنهِ 5 ألعاب؛ في كل لعبة اجمع 5 عملات دون اصطدام',
          artwork: _MissionArtworkType.worm,
          colors: const [Color(0xFFFFC52D), Color(0xFFE67B13)],
          completed: completed['goldWorm'] == true,
          loading: claiming.contains('goldWorm'),
          rewardMode: rewardMode,
          onTap: () => onOpen('goldWorm'),
        ),
      ],
    );
  }
}

class _MissionCompleteCelebration extends StatelessWidget {
  const _MissionCompleteCelebration();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF7B3FC6), Color(0xFF243F86)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x554C2A91),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: List.generate(
                6,
                (_) => const Icon(
                  Icons.star_rounded,
                  color: AppTheme.coolYellow,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'مبروك! لقد حصلت على 6 نقاط',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'أنجزت مهمة الطلب بنجاح. يمكنك متابعة اللعب للتسلية دون احتساب نقاط إضافية.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(.82),
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _PlayTaskCard extends StatelessWidget {
  const _PlayTaskCard({
    required this.title,
    required this.subtitle,
    required this.artwork,
    required this.colors,
    required this.completed,
    required this.loading,
    required this.rewardMode,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final _MissionArtworkType artwork;
  final List<Color> colors;
  final bool completed;
  final bool loading;
  final bool rewardMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 20,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: ClipPath(
            clipper: const _MissionTicketClipper(),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: loading ? null : onTap,
                child: Ink(
                  height: 132,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: completed
                          ? const [Color(0xFF657181), Color(0xFF414B59)]
                          : colors,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              20, 13, 14, 13),
                          child: Row(
                            children: [
                              Container(
                                width: 76,
                                height: 86,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF263F67),
                                      Color(0xFF08162D),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xAAFFE172),
                                    width: 1.2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x44000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(19),
                                  child: CustomPaint(
                                    painter: _MissionArtworkPainter(artwork),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      completed ? 'اكتملت المهمة ⭐⭐' : subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        height: 1.3,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    const Row(
                                      children: [
                                        Icon(Icons.timer_outlined,
                                            color: Colors.white70, size: 15),
                                        SizedBox(width: 4),
                                        Text('10:00',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 82,
                        child: CustomPaint(
                          painter: _TicketPerforationPainter(),
                          child: Container(
                            color: Colors.black.withOpacity(.13),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (loading)
                                  const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  Icon(
                                    completed
                                        ? Icons.verified_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 35,
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  completed
                                      ? 'العب مجددًا'
                                      : rewardMode
                                          ? 'العب'
                                          : 'مجاني',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: completed
                                        ? const Color(0xFF26C281)
                                        : const Color(0xFFFFD338),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    rewardMode ? '+2 ★' : 'حر',
                                    style: TextStyle(
                                      color: completed
                                          ? Colors.white
                                          : AppTheme.navy,
                                      fontSize: 11,
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
              ),
            ),
          ),
        ),
      );
}

enum _MissionArtworkType { snakes, ring, worm }

class _MissionArtworkPainter extends CustomPainter {
  const _MissionArtworkPainter(this.type);

  final _MissionArtworkType type;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      size.width * .42,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x55FFE68A), Colors.transparent],
        ).createShader(
            Rect.fromCircle(center: center, radius: size.width * .42)),
    );
    switch (type) {
      case _MissionArtworkType.snakes:
        _drawBoard(canvas, size);
        return;
      case _MissionArtworkType.ring:
        _drawRing(canvas, size);
        return;
      case _MissionArtworkType.worm:
        _drawWorm(canvas, size);
        return;
    }
  }

  void _drawBoard(Canvas canvas, Size size) {
    final board = Rect.fromLTWH(size.width * .16, size.height * .14,
        size.width * .68, size.height * .72);
    final boardPaint = Paint()..color = const Color(0xFFF0D99E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(7)),
      boardPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(7)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFD39A18),
    );
    final cell = board.width / 4;
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 4; column++) {
        if ((row + column).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(board.left + column * cell,
                board.top + row * board.height / 4, cell, board.height / 4),
            Paint()..color = const Color(0xFF5B8C82).withOpacity(.72),
          );
        }
      }
    }
    final ladder = Paint()
      ..color = const Color(0xFFFFE88D)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(board.left + 12, board.bottom - 10),
        Offset(board.right - 17, board.top + 10), ladder);
    canvas.drawLine(Offset(board.left + 21, board.bottom - 7),
        Offset(board.right - 8, board.top + 13), ladder);
    for (var index = 1; index < 5; index++) {
      final t = index / 5;
      final a = Offset.lerp(Offset(board.left + 12, board.bottom - 10),
          Offset(board.right - 17, board.top + 10), t)!;
      final b = Offset.lerp(Offset(board.left + 21, board.bottom - 7),
          Offset(board.right - 8, board.top + 13), t)!;
      canvas.drawLine(a, b, ladder..strokeWidth = 2.2);
    }
    final snake = Path()
      ..moveTo(board.left + 10, board.top + 14)
      ..cubicTo(board.right - 6, board.top + 18, board.left + 8,
          board.bottom - 18, board.right - 12, board.bottom - 9);
    canvas.drawPath(
      snake,
      Paint()
        ..color = const Color(0xFFC64B45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawRing(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 1);
    final radius = size.width * .28;
    canvas.drawCircle(
      center,
      radius * .72,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF1D385F), Color(0xFF07152A)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    for (var index = 0; index < 16; index++) {
      final angle = -pi / 2 + index * pi * 2 / 16;
      final bead = center + Offset(cos(angle), sin(angle)) * radius;
      canvas.drawCircle(
        bead.translate(1, 2),
        4.7,
        Paint()..color = Colors.black.withOpacity(.35),
      );
      canvas.drawCircle(
        bead,
        4.5,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.35, -.4),
            colors: [Color(0xFFFFFFB5), Color(0xFFD89B18), Color(0xFF704500)],
          ).createShader(Rect.fromCircle(center: bead, radius: 5)),
      );
    }
    final text = TextPainter(
      text: const TextSpan(
        text: '100',
        style: TextStyle(
          color: Color(0xFFFFE06B),
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  void _drawWorm(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .18, size.height * .68)
      ..cubicTo(size.width * .35, size.height * .28, size.width * .62,
          size.height * .78, size.width * .78, size.height * .34);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF9B6200), Color(0xFFFFE578), Color(0xFFC58B15)],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    final head = Offset(size.width * .78, size.height * .34);
    canvas.drawCircle(
      head,
      10,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.4),
          colors: [Color(0xFFFFFFAC), Color(0xFFD49B20)],
        ).createShader(Rect.fromCircle(center: head, radius: 10)),
    );
    for (final side in [-1.0, 1.0]) {
      final eye = head.translate(side * 3.5, -2.5);
      canvas.drawCircle(eye, 1.8, Paint()..color = AppTheme.navy);
    }
    final coin = Offset(size.width * .26, size.height * .25);
    canvas.drawCircle(
      coin,
      8,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFC4), Color(0xFFFFC72F), Color(0xFF9E6500)],
        ).createShader(Rect.fromCircle(center: coin, radius: 8)),
    );
    canvas.drawCircle(
      coin,
      5.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFFFE995),
    );
  }

  @override
  bool shouldRepaint(covariant _MissionArtworkPainter oldDelegate) =>
      oldDelegate.type != type;
}

class _MissionTicketClipper extends CustomClipper<Path> {
  const _MissionTicketClipper();

  @override
  Path getClip(Size size) {
    const radius = 22.0;
    const notch = 11.0;
    final middle = size.height / 2;
    return Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, middle - notch)
      ..arcToPoint(
        Offset(size.width, middle + notch),
        radius: const Radius.circular(notch),
        clockwise: false,
      )
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
          size.width, size.height, size.width - radius, size.height)
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, middle + notch)
      ..arcToPoint(
        Offset(0, middle - notch),
        radius: const Radius.circular(notch),
        clockwise: false,
      )
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _MissionTicketClipper oldClipper) => false;
}

class _TicketPerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.42)
      ..strokeWidth = 1.5;
    for (double y = 8; y < size.height - 8; y += 10) {
      canvas.drawLine(Offset(0, y), Offset(0, min(y + 5, size.height)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TicketPerforationPainter oldDelegate) => false;
}
