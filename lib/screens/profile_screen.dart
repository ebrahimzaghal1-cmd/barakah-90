import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/auth_service.dart';
import '../services/admin_notification_service.dart';
import '../services/admin_submission_notification_service.dart';
import '../services/app_language_service.dart';
import '../services/firebase_state.dart';
import '../services/loyalty_service.dart';
import '../services/order_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/responsive_page.dart';
import '../widgets/barakah_brand.dart';
import '../theme/app_theme.dart';
import '../admin/admin_dashboard.dart';
import '../games/play_hub_screen.dart';
import 'admin_login_screen.dart';
import 'authentication_screen.dart';
import 'orders_screen.dart';
import 'location_picker_screen.dart';
import 'merchant_dashboard.dart';
import 'driver_dashboard.dart';
import 'driver_registration_screen.dart';
import 'customer_service_join_screen.dart';
import 'customer_service_portal.dart';
import 'customer_support_chat_screen.dart';
import 'favorites_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _openAdmin(BuildContext context, User? user) async {
    // عندما يكون المستخدم مسجلاً بالفعل لا نعيد طلب كلمة المرور. هذا يمنع
    // حظر Firebase المؤقت بسبب محاولات تسجيل الدخول المتكررة.
    if (user != null) {
      try {
        final isAdmin = await UserProfileService().isAdmin(user.uid);
        if (!context.mounted) return;
        if (isAdmin) {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminDashboard()));
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('هذا الحساب لا يملك صلاحية الأدمن.'),
          backgroundColor: Colors.red,
        ));
        return;
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر التحقق من صلاحية الأدمن. حاول بعد قليل.'),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Firebase Web is not configured yet. Do not call FirebaseAuth in the
    // Chrome preview, so the screen remains usable instead of showing an error.
    if (!FirebaseState.isReady) return const _WebPreviewProfile();
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguageService.instance.locale,
      builder: (context, locale, _) {
        final copy = _ProfileCopy(locale.languageCode);
        return Scaffold(
          backgroundColor: const Color(0xFFFFFCF5),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            surfaceTintColor: Colors.transparent,
            title: Text(
              copy.myPage,
              style: const TextStyle(
                color: AppTheme.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
            iconTheme: const IconThemeData(color: AppTheme.navy),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/profile_gold_background.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              const ColoredBox(color: Color(0xB8FFFCF5)),
              ResponsivePage(
                child: StreamBuilder<User?>(
                  stream: AuthService().authStateChanges,
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    if (user == null) {
                      return _ProfileBody(
                          user: null,
                          data: const {},
                          copy: copy,
                          onAdmin: _openAdmin);
                    }
                    return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots(),
                      builder: (context, profileSnapshot) => _ProfileBody(
                        user: user,
                        data: profileSnapshot.data?.data() ?? const {},
                        copy: copy,
                        onAdmin: _openAdmin,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody(
      {required this.user,
      required this.data,
      required this.copy,
      required this.onAdmin});

  final User? user;
  final Map<String, dynamic> data;
  final _ProfileCopy copy;
  final Future<void> Function(BuildContext, User?) onAdmin;

  @override
  Widget build(BuildContext context) {
    final name = data['displayName']?.toString().trim();
    final displayName = name?.isNotEmpty == true
        ? name!
        : user?.displayName?.trim().isNotEmpty == true
            ? user!.displayName!
            : copy.profile;
    final email = user?.email ?? data['email']?.toString();
    final address = data['address']?.toString() ?? '';
    final agentNumber = data['agentNumber']?.toString() ?? '';
    final agentLocation = data['agentLocation']?.toString() ?? '';
    final role = data['role']?.toString() ?? '';
    final isMerchant = role == 'merchant';
    final isDriver = role == 'driver';
    final isCustomerService =
        role == 'customer_service' && data['customerServiceEnabled'] == true;

    void requireLogin(VoidCallback action) {
      if (user != null) {
        action();
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthenticationScreen()),
      );
    }

    void showMessage(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    void openSupport() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerSupportChatScreen()),
      );
    }

    Future<void> openShareSheet(String text) async {
      if (!context.mounted) return;
      final renderObject = context.findRenderObject();
      final origin = renderObject is RenderBox && renderObject.hasSize
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : null;
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: 'Barakah | بركة',
          sharePositionOrigin: origin,
        ),
      );
      if (result.status == ShareResultStatus.unavailable && context.mounted) {
        showMessage('المشاركة غير متاحة على هذا الجهاز حاليًا.');
      }
    }

    Future<void> shareBarakah() async {
      var shareText = copy.shareMessage;
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('app_settings')
            .doc('app_share')
            .get()
            .timeout(const Duration(seconds: 3));
        final settings = snapshot.data() ?? const <String, dynamic>{};
        if (settings['enabled'] == false) {
          showMessage('مشاركة التطبيق متوقفة مؤقتًا.');
          return;
        }
        final customMessage = settings['message']?.toString().trim() ?? '';
        final links = <String>[
          settings['webUrl']?.toString().trim() ?? '',
          settings['androidUrl']?.toString().trim() ?? '',
          settings['iosUrl']?.toString().trim() ?? '',
        ].where((value) => value.isNotEmpty).toSet().toList();
        final message =
            customMessage.isEmpty ? copy.shareMessage : customMessage;
        shareText = links.isEmpty ? message : '$message\n${links.join('\n')}';
      } catch (_) {
        // نستخدم النص الافتراضي إذا تعذر تحميل إعدادات الأدمن بسرعة.
      }
      try {
        await openShareSheet(shareText);
      } catch (_) {
        if (context.mounted) {
          showMessage('تعذر فتح المشاركة. حاول مرة أخرى.');
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 34),
      child: Column(children: [
        _ProfileHeroPanel(
          name: displayName,
          contact: user?.phoneNumber ?? email ?? '',
          userId: user?.uid,
          onEdit: user == null
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _EditProfileScreen(
                        user: user!,
                        data: data,
                        copy: copy,
                      ),
                    ),
                  ),
        ),
        const SizedBox(height: 14),
        _ProfileGroup(
          title: 'حسابي',
          icon: Icons.person_outline_rounded,
          child: _ProfileActionsGrid(
            actions: [
              _ProfileAction(
                icon: Icons.shopping_bag_outlined,
                title: 'طلباتي',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrdersScreen()),
                ),
              ),
              _ProfileAction(
                icon: Icons.location_on_outlined,
                title: 'عناويني',
                onTap: () => requireLogin(
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _EditProfileScreen(
                        user: user!,
                        data: data,
                        copy: copy,
                      ),
                    ),
                  ),
                ),
              ),
              _ProfileAction(
                icon: Icons.favorite_border_rounded,
                title: 'المفضلة',
                onTap: () => requireLogin(
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FavoritesScreen(user: user!),
                    ),
                  ),
                ),
              ),
              _ProfileAction(
                icon: Icons.account_balance_wallet_outlined,
                title: 'المحفظة',
                onTap: () => requireLogin(
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _LoyaltyHistoryScreen(userId: user!.uid),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ProfileGroup(
          title: 'خدماتي',
          icon: Icons.grid_view_rounded,
          child: _ProfileActionsGrid(
            actions: [
              _ProfileAction(
                icon: Icons.sports_esports_outlined,
                title: 'ألعابي',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlayHubScreen()),
                ),
              ),
              _ProfileAction(
                icon: Icons.notifications_none_rounded,
                title: 'الإشعارات',
                onTap: () => requireLogin(() async {
                  final enabled = await AdminNotificationService.instance
                      .requestPermissionForCurrentUser();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        enabled
                            ? 'تم تفعيل إشعارات بركة على هذا الجهاز ✅'
                            : AdminNotificationService
                                .instance.permissionFailureMessage,
                      ),
                      backgroundColor: enabled ? Colors.green : Colors.orange,
                    ),
                  );
                }),
              ),
              _ProfileAction(
                icon: Icons.settings_outlined,
                title: 'الإعدادات',
                onTap: () => _showLanguageSheet(context, user, copy),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ProfileGroup(
          title: 'المساعدة',
          icon: Icons.support_agent_rounded,
          child: _ProfileActionsGrid(
            actions: [
              _ProfileAction(
                icon: Icons.headset_mic_outlined,
                title: 'الدعم',
                onTap: openSupport,
              ),
              _ProfileAction(
                icon: Icons.privacy_tip_outlined,
                title: 'الخصوصية',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _PrivacyPolicyScreen(),
                  ),
                ),
              ),
              if (user != null)
                _ProfileAction(
                  icon: Icons.person_remove_outlined,
                  title: 'طلب حذف الحساب',
                  onTap: () => _requestAccountDeletion(context, user!),
                ),
              _ProfileAction(
                icon: Icons.ios_share_rounded,
                title: 'مشاركة بركة',
                onTap: shareBarakah,
              ),
            ],
          ),
        ),
        if (user != null) ...[
          const SizedBox(height: 12),
          _ProfileGroup(
            title: 'بطاقة ونقاط بركة',
            icon: Icons.workspace_premium_outlined,
            child: Column(
              children: [
                _ProfileMenuTile(
                  icon: Icons.history_rounded,
                  title: 'سجل نقاط بركة',
                  subtitle: 'عمليات الكسب والاستخدام والاسترداد',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _LoyaltyHistoryScreen(userId: user!.uid),
                    ),
                  ),
                ),
                _ProfileMenuTile(
                  icon: Icons.lock_reset_rounded,
                  title: 'تغيير PIN بطاقة بركة',
                  onTap: () => _showChangeBarakahPinDialog(context),
                ),
                _ProfileMenuTile(
                  icon: Icons.help_outline_rounded,
                  title: 'نسيت PIN؟',
                  onTap: () => _showResetBarakahPinDialog(context),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (isMerchant) ...[
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.ink,
                  foregroundColor: AppTheme.coolYellow),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MerchantDashboard())),
              icon: const Icon(Icons.storefront_rounded),
              label: const Text('إدارة متجري ومنتجاتي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (isDriver) ...[
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.ink,
                  foregroundColor: AppTheme.coolYellow),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DriverDashboard())),
              icon: const Icon(Icons.delivery_dining_rounded),
              label: const Text('لوحة السائق وطلبات التوصيل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (isCustomerService) ...[
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.ink,
                  foregroundColor: AppTheme.coolYellow),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CustomerServicePortal()),
              ),
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('بوابة موظف خدمة العملاء',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _ProfileGroup(
          title: 'المزيد',
          icon: Icons.more_horiz_rounded,
          child: Column(
            children: [
              _ProfileMenuTile(
                icon: Icons.storefront_rounded,
                title: 'الانضمام كشريك',
                subtitle: 'سجّل مطعمك أو متجرك في بركة',
                onTap: () async {
                  final uri = Uri.parse('https://barakah-new.web.app/partner');
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              if (user != null && !isDriver && !isCustomerService)
                _ProfileMenuTile(
                  icon: Icons.delivery_dining_outlined,
                  title: 'الاشتراك كسائق توصيل',
                  subtitle: 'أرسل طلبك ثم يعتمد الأدمن حسابك',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DriverRegistrationScreen())),
                ),
              if (!isCustomerService)
                _ProfileMenuTile(
                  icon: Icons.headset_mic_outlined,
                  title: 'الانضمام لخدمة عملاء بركة',
                  subtitle: 'يُفتح التقديم عندما يحتاج فريق بركة إلى موظفين',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CustomerServiceJoinScreen()),
                  ),
                ),
              _ProfileMenuTile(
                icon: Icons.forum_outlined,
                title: 'محادثة خدمة العملاء',
                subtitle: 'تواصل خاص وآمن داخل تطبيق بركة',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CustomerSupportChatScreen()),
                ),
              ),
              _ProfileMenuTile(
                icon: Icons.language_rounded,
                title: copy.language,
                subtitle: copy.languageName,
                onTap: () => _showLanguageSheet(context, user, copy),
              ),
              _ProfileMenuTile(
                icon: Icons.location_on_outlined,
                title: copy.address,
                subtitle: address.isEmpty ? copy.notAdded : address,
                onTap: user == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _EditProfileScreen(
                              user: user!,
                              data: data,
                              copy: copy,
                            ),
                          ),
                        ),
              ),
              if (agentNumber.isNotEmpty)
                _ProfileMenuTile(
                  icon: Icons.badge_outlined,
                  title: copy.agentNumber,
                  subtitle: [agentNumber, agentLocation]
                      .where((value) => value.isNotEmpty)
                      .join(' • '),
                  onTap: user == null
                      ? null
                      : () => _showAgentQr(context, user!.uid, displayName,
                          agentNumber, agentLocation),
                ),
              for (final social in [
                (Icons.facebook_rounded, 'Facebook', data['facebookUrl']),
                (Icons.camera_alt_outlined, 'Instagram', data['instagramUrl']),
                (Icons.music_note_rounded, 'TikTok', data['tiktokUrl']),
              ])
                if (social.$3?.toString().trim().isNotEmpty == true)
                  _ProfileMenuTile(
                    icon: social.$1,
                    title: social.$2,
                    subtitle: social.$3.toString(),
                    onTap: () => _openSocialLink(context, social.$3.toString()),
                  ),
              if (user != null)
                _ProfileMenuTile(
                    icon: Icons.email_outlined,
                    title: copy.email,
                    subtitle: email ?? ''),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: OutlinedButton.icon(
            onPressed: () async {
              if (user == null) {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AuthenticationScreen()));
              } else {
                await AuthService().signOut();
              }
            },
            icon: Icon(user == null ? Icons.login : Icons.logout),
            label: Text(user == null ? copy.login : copy.logout),
          ),
        ),
        if (user != null) ...[
          const SizedBox(height: 14),
          _LoyaltyCard(userId: user!.uid),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF0F0F0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18))),
            onPressed: () => onAdmin(context, user),
            icon: const Icon(Icons.admin_panel_settings, color: AppTheme.navy),
            label: Text(copy.admin,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy)),
          ),
        ),
      ]),
    );
  }

  Future<void> _requestAccountDeletion(BuildContext context, User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('طلب حذف الحساب'),
        content: const Text(
          'سيصل الطلب إلى فريق بركة لمراجعته. '
          'سيتم حذف الحساب والبيانات الشخصية المرتبطة به، '
          'مع الاحتفاظ بالسجلات المطلوبة قانونًا عند الحاجة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('account_deletion_requests')
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'email': user.email ?? '',
        'status': 'pending',
        'source': 'app',
        'requestedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await AdminSubmissionNotificationService.notify(
        type: 'account_deletion_request',
        documentId: user.uid,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب حذف الحساب بنجاح.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إرسال الطلب. حاول مرة أخرى.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openSocialLink(BuildContext context, String value) async {
    final normalized =
        value.startsWith('http://') || value.startsWith('https://')
            ? value
            : 'https://$value';
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(copy.invalidLink)),
        );
      }
    }
  }

  void _showAgentQr(BuildContext context, String uid, String name,
      String number, String location) {
    final page = 'https://barakah-new.web.app/?agent=$uid';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(name,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('$number${location.isEmpty ? '' : ' • $location'}'),
            const SizedBox(height: 18),
            QrImageView(data: page, size: 210),
            const SizedBox(height: 12),
            SelectableText(page, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Share.share(page, subject: name),
              icon: const Icon(Icons.share_rounded),
              label: const Text('مشاركة صفحة الوسيط'),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _showLanguageSheet(
      BuildContext context, User? user, _ProfileCopy copy) async {
    final current = AppLanguageService.instance.locale.value.languageCode;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(copy.chooseLanguage,
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            for (final entry in const {
              'ar': 'العربية',
              'en': 'English',
              'fr': 'Français'
            }.entries)
              RadioListTile<String>(
                value: entry.key,
                groupValue: current,
                title: Text(entry.value),
                onChanged: (value) async {
                  if (value == null) return;
                  await AppLanguageService.instance.setLanguage(value);
                  if (user != null) {
                    await UserProfileService()
                        .updateCustomerProfile(user.uid, {'language': value});
                  }
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
          ]),
        ),
      ),
    );
  }
}

Future<void> _showResetBarakahPinDialog(BuildContext context) async {
  final newPin = TextEditingController();
  final confirmPin = TextEditingController();

  var saving = false;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            final next = newPin.text.trim();
            final confirm = confirmPin.text.trim();

            if (!RegExp(r'^\d{4}$').hasMatch(next)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'PIN الجديد يجب أن يتكوّن من 4 أرقام.',
                  ),
                ),
              );
              return;
            }

            if (next != confirm) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تأكيد PIN الجديد غير مطابق.',
                  ),
                ),
              );
              return;
            }

            setDialogState(() => saving = true);

            try {
              await OrderService().resetBarakahPin(
                newPin: next,
              );

              if (!dialogContext.mounted) return;

              Navigator.pop(dialogContext);

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تم تعيين PIN جديد لبطاقة بركة بنجاح ✅',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (error) {
              if (!context.mounted) return;

              final message = error is StateError
                  ? error.message.toString()
                  : 'تعذر إعادة تعيين PIN الآن.';

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Colors.red,
                ),
              );

              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
              }
            }
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded),
                SizedBox(width: 10),
                Expanded(
                  child: Text('نسيت PIN؟'),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'يمكنك تعيين PIN جديد إذا كنت قد سجّلت الدخول إلى حسابك خلال آخر 5 دقائق.',
                      style: TextStyle(
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'إذا ظهرت رسالة تطلب تسجيل دخول حديث، سجّل الخروج ثم ادخل إلى حسابك مجددًا وحاول مباشرة.',
                      style: TextStyle(
                        color: Colors.black.withOpacity(.58),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: newPin,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'PIN الجديد',
                        prefixIcon: Icon(Icons.password_rounded),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPin,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      enabled: !saving,
                      onSubmitted: (_) {
                        if (!saving) save();
                      },
                      decoration: const InputDecoration(
                        labelText: 'تأكيد PIN الجديد',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                        counterText: '',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  saving ? 'جارٍ الحفظ...' : 'تعيين PIN جديد',
                ),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    newPin.dispose();
    confirmPin.dispose();
  }
}

Future<void> _showChangeBarakahPinDialog(BuildContext context) async {
  final currentPin = TextEditingController();
  final newPin = TextEditingController();
  final confirmPin = TextEditingController();

  var saving = false;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            final current = currentPin.text.trim();
            final next = newPin.text.trim();
            final confirm = confirmPin.text.trim();

            if (!RegExp(r'^\d{4}$').hasMatch(current)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('أدخل PIN الحالي المكوّن من 4 أرقام.'),
                ),
              );
              return;
            }

            if (!RegExp(r'^\d{4}$').hasMatch(next)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PIN الجديد يجب أن يتكوّن من 4 أرقام.'),
                ),
              );
              return;
            }

            if (next != confirm) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تأكيد PIN الجديد غير مطابق.'),
                ),
              );
              return;
            }

            if (current == next) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('اختر PIN جديدًا مختلفًا عن الحالي.'),
                ),
              );
              return;
            }

            setDialogState(() => saving = true);

            try {
              await OrderService().changeBarakahPin(
                currentPin: current,
                newPin: next,
              );

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تغيير الرقم السري لبطاقة بركة بنجاح ✅'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (error) {
              if (!context.mounted) return;

              final message = error is StateError
                  ? error.message.toString()
                  : 'تعذر تغيير الرقم السري الآن.';

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Colors.red,
                ),
              );

              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
              }
            }
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded),
                SizedBox(width: 10),
                Expanded(
                  child: Text('تغيير PIN بطاقة بركة'),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'لأمان بطاقتك، أدخل الرقم السري الحالي ثم اختر رقمًا جديدًا من 4 أرقام.',
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: currentPin,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'PIN الحالي',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPin,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'PIN الجديد',
                        prefixIcon: Icon(Icons.password_rounded),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPin,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      enabled: !saving,
                      onSubmitted: (_) {
                        if (!saving) save();
                      },
                      decoration: const InputDecoration(
                        labelText: 'تأكيد PIN الجديد',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                        counterText: '',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  saving ? 'جارٍ الحفظ...' : 'تغيير PIN',
                ),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    currentPin.dispose();
    newPin.dispose();
    confirmPin.dispose();
  }
}

class _LoyaltyHistoryScreen extends StatelessWidget {
  const _LoyaltyHistoryScreen({
    required this.userId,
  });

  final String userId;

  String _typeLabel(String type) {
    switch (type) {
      case 'earn':
        return 'مكافأة شراء';
      case 'redeem':
        return 'استخدام نقاط';
      case 'refund':
        return 'استرداد نقاط';
      case 'game_reward':
        return 'مكافأة لعبة';
      case 'admin_adjustment':
        return 'تعديل إداري';
      default:
        return 'حركة نقاط';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'earn':
        return Icons.add_circle_rounded;
      case 'redeem':
        return Icons.shopping_bag_rounded;
      case 'refund':
        return Icons.restore_rounded;
      case 'game_reward':
        return Icons.sports_esports_rounded;
      case 'admin_adjustment':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  String _dateText(Object? value) {
    if (value is! Timestamp) return '';

    final date = value.toDate();

    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'سجل نقاط بركة',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: BarakahBrandBackdrop(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: LoyaltyService().transactions(userId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'تعذر تحميل سجل النقاط حالياً.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final docs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final aDate = a.data()['createdAt'];
                final bDate = b.data()['createdAt'];

                final aMillis =
                    aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;

                final bMillis =
                    bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;

                return bMillis.compareTo(aMillis);
              });

            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: AppTheme.coolYellow.withOpacity(.20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.history_rounded,
                          size: 46,
                          color: AppTheme.deepYellow,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'لا توجد حركات نقاط بعد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ستظهر هنا عمليات كسب النقاط واستخدامها واستردادها والمكافآت الجديدة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.ink.withOpacity(.60),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                16,
                18,
                16,
                32,
              ),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final data = docs[index].data();

                final type = data['type']?.toString() ?? '';

                final delta = (data['pointsDelta'] as num?)?.toInt() ?? 0;

                final balanceAfter =
                    (data['balanceAfter'] as num?)?.toInt() ?? 0;

                final description =
                    data['description']?.toString() ?? _typeLabel(type);

                final orderNumber =
                    data['orderNumber']?.toString().trim() ?? '';

                final positive = delta >= 0;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.90),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.coolYellow.withOpacity(.35),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.coolYellow.withOpacity(.22),
                        child: Icon(
                          _typeIcon(type),
                          color: AppTheme.deepYellow,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _typeLabel(type),
                              style: const TextStyle(
                                color: AppTheme.navy,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            if (orderNumber.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'الطلب: $orderNumber',
                                style: TextStyle(
                                  color: AppTheme.ink.withOpacity(.55),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              _dateText(data['createdAt']),
                              style: TextStyle(
                                color: AppTheme.ink.withOpacity(.45),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${positive ? '+' : ''}$delta',
                            style: TextStyle(
                              color: positive
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'نقطة',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'الرصيد $balanceAfter',
                            style: TextStyle(
                              color: AppTheme.ink.withOpacity(.55),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeroPanel extends StatelessWidget {
  const _ProfileHeroPanel({
    required this.name,
    required this.contact,
    required this.userId,
    required this.onEdit,
  });

  final String name;
  final String contact;
  final String? userId;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    Widget card(int points) {
      final progress = math.max(.12, (points % 500) / 500).toDouble();
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 190),
        padding: const EdgeInsets.fromLTRB(16, 18, 12, 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF2),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: AppTheme.deepYellow.withOpacity(.34),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0E071B3C),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 112,
              height: 156,
              child: Image.asset(
                'assets/images/splash/barakah_standing_bunny_v2.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.navy,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (onEdit != null)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'تعديل الملف الشخصي',
                          onPressed: onEdit,
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: AppTheme.deepYellow,
                          ),
                        ),
                    ],
                  ),
                  if (contact.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      contact,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: AppTheme.ink.withOpacity(.58),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: AppTheme.deepYellow,
                        size: 22,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'نقاط بركة $points',
                        style: const TextStyle(
                          color: AppTheme.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFECE5D5),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.deepYellow,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'استمر بالطلب واجمع نقاطاً أكثر',
                    style: TextStyle(
                      color: AppTheme.ink.withOpacity(.50),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (userId == null) return card(0);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: LoyaltyService().profile(userId!),
      builder: (context, snapshot) {
        final points =
            (snapshot.data?.data()?['loyaltyPoints'] as num?)?.toInt() ?? 0;
        return card(points);
      },
    );
  }
}

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0xFFEDE5D4)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x09071B3C),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.deepYellow),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.deepYellow,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _ProfileAction {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
}

class _ProfileActionsGrid extends StatelessWidget {
  const _ProfileActionsGrid({required this.actions});

  final List<_ProfileAction> actions;

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
          childAspectRatio: .86,
        ),
        itemBuilder: (context, index) {
          final action = actions[index];
          return Material(
            color: const Color(0xFFFFFEFB),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: const BorderSide(color: Color(0xFFE9DDBF)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: action.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(action.icon, color: AppTheme.navy, size: 27),
                    const SizedBox(height: 7),
                    Text(
                      action.title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile(
      {required this.icon, required this.title, this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFFFEFB),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE9DDBF)),
        ),
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
              backgroundColor: AppTheme.coolYellow.withOpacity(.28),
              child: Icon(icon, color: AppTheme.deepYellow)),
          title: Text(title,
              style: const TextStyle(
                  color: AppTheme.navy, fontWeight: FontWeight.w900)),
          subtitle: subtitle == null || subtitle!.isEmpty
              ? null
              : Text(
                  subtitle!,
                  style: TextStyle(color: AppTheme.ink.withOpacity(.55)),
                ),
          trailing: onTap == null
              ? null
              : const Icon(Icons.chevron_left_rounded,
                  color: AppTheme.deepYellow),
        ),
      );
}

class _LoyaltyCard extends StatelessWidget {
  const _LoyaltyCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: LoyaltyService().profile(userId),
        builder: (context, profileSnapshot) {
          final profileData = profileSnapshot.data?.data();
          final barakahCardNumber =
              (profileData?['barakahCardNumber'] ?? 'BRK-••••-••••-••••')
                  .toString();
          final points = (profileData?['loyaltyPoints'] as num?)?.toInt() ?? 0;

          final memberName = (profileData?['displayName'] ??
                  profileData?['name'] ??
                  'BARAKAH MEMBER')
              .toString()
              .trim();

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('app_settings')
                .doc('loyalty')
                .snapshots(),
            builder: (context, settingsSnapshot) {
              final settings = settingsSnapshot.data?.data();

              final rawPointsPerCoupon =
                  (settings?['pointsPerCoupon'] as num?)?.toInt() ?? 100;

              final rawDiscountPercent =
                  (settings?['discountPercent'] as num?)?.toInt() ?? 10;

              final pointsPerCoupon =
                  rawPointsPerCoupon <= 0 ? 100 : rawPointsPerCoupon;

              final discountPercent =
                  rawDiscountPercent <= 0 ? 10 : rawDiscountPercent;

              final pointsIntoCurrentCoupon = points % pointsPerCoupon;
              final remaining = pointsPerCoupon - pointsIntoCurrentCoupon;

              final hasNewCoupon =
                  points >= pointsPerCoupon && pointsIntoCurrentCoupon == 0;

              final progress = pointsIntoCurrentCoupon / pointsPerCoupon;

              const navy = Color(0xFF050505);
              const navy2 = Color(0xFF191919);
              const gold = Color(0xFFD6A83A);
              const lightGold = Color(0xFFFFD978);

              return AspectRatio(
                aspectRatio: 1.586,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        navy2,
                        navy,
                        Color(0xFF03101F),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: gold,
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.28),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _BarakahCardPatternPainter(),
                          ),
                        ),
                      ),
                      const Positioned(
                        top: 2,
                        left: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'VISA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'BARAKAH',
                                  style: TextStyle(
                                    color: lightGold,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              'MEMBERSHIP • REWARDS',
                              style: TextStyle(
                                color: lightGold,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 230,
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: Image.asset(
                            'assets/images/barakah_card_bunny_v2.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 92,
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF7DE8E),
                                    gold,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: const Color(0xFF8D6B22),
                                  width: .7,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 19,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 1,
                                      color: const Color(0xFF8D6B22),
                                    ),
                                  ),
                                  Positioned(
                                    right: 19,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 1,
                                      color: const Color(0xFF8D6B22),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: 14,
                                    child: Container(
                                      height: 1,
                                      color: const Color(0xFF8D6B22),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 14,
                                    child: Container(
                                      height: 1,
                                      color: const Color(0xFF8D6B22),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.contactless_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 154,
                        child: Text(
                          barakahCardNumber,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: lightGold,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 0,
                        top: 197,
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VALID',
                                  style: TextStyle(
                                    color: lightGold,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'THRU',
                                  style: TextStyle(
                                    color: lightGold,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 6),
                            Text(
                              '12/28',
                              style: TextStyle(
                                color: lightGold,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        bottom: 0,
                        child: Text(
                          memberName.isEmpty
                              ? 'BARAKAH MEMBER'
                              : memberName.toUpperCase(),
                          style: const TextStyle(
                            color: lightGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 78,
                        width: 265,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'نقاط بركة',
                              style: TextStyle(
                                color: lightGold,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$points نقطة',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hasNewCoupon
                                  ? 'لديك كوبون خصم جديد 🎁'
                                  : 'بقي $remaining نقطة لتحصل على كوبون خصم $discountPercent٪',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                value: hasNewCoupon ? 1 : progress,
                                minHeight: 8,
                                color: lightGold,
                                backgroundColor: Colors.white.withOpacity(.14),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: gold.withOpacity(.75),
                                ),
                              ),
                              child: Text(
                                '$pointsPerCoupon نقطة = خصم $discountPercent٪',
                                style: const TextStyle(
                                  color: lightGold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Positioned(
                        right: 0,
                        bottom: 48,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'VISA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Gold',
                              style: TextStyle(
                                color: lightGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: OutlinedButton.icon(
                          onPressed: () => _showCoupons(context),
                          icon: const Icon(
                            Icons.confirmation_number_outlined,
                            size: 17,
                          ),
                          label: const Text('عرض كوبونات الخصم'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: lightGold,
                            side: const BorderSide(color: gold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

  void _showCoupons(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: LoyaltyService().activeCoupons(userId),
          builder: (context, snapshot) {
            final coupons = snapshot.data?.docs ?? [];
            if (coupons.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Text('لا يوجد كوبونات خصم حالياً.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700)),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
              itemCount: coupons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final data = coupons[index].data();
                final expiresAt = data['expiresAt'];
                final expiryDate = expiresAt is Timestamp
                    ? expiresAt.toDate().toLocal()
                    : null;

                String expiryText;

                if (expiryDate == null) {
                  expiryText = 'بدون تاريخ انتهاء';
                } else {
                  expiryText =
                      'صالح حتى: ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}';
                }

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: AppTheme.coolYellow,
                        child:
                            Icon(Icons.discount_rounded, color: AppTheme.ink)),
                    title: Text(data['code']?.toString() ?? 'كوبون بركة',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(
                      'خصم ${data['discountPercent'] ?? 10}% على طلبك\n'
                      '$expiryText',
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BarakahCardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;

    for (double y = 18; y < size.height; y += 16) {
      final path = Path()..moveTo(0, y);

      for (double x = 0; x <= size.width; x += 18) {
        path.lineTo(
          x,
          y + 5 * math.sin(x / 35),
        );
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WebPreviewProfile extends StatelessWidget {
  const _WebPreviewProfile();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('صفحتي'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/barakah_profile_heart_bunny.png',
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              const SizedBox(height: 16),
              const Text('معاينة بركة على الويب',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'الحسابات ولوحة الأدمن تعملان على iPhone وAndroid بعد تسجيل الدخول.'),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          'نسخة Chrome للعرض فقط إلى أن نضيف إعداد Firebase Web.'))
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _EditProfileScreen extends StatefulWidget {
  const _EditProfileScreen(
      {required this.user, required this.data, required this.copy});
  final User user;
  final Map<String, dynamic> data;
  final _ProfileCopy copy;

  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _agentNumber;
  late final TextEditingController _agentLocation;
  late final TextEditingController _facebookUrl;
  late final TextEditingController _instagramUrl;
  late final TextEditingController _tiktokUrl;
  String _gender = '';
  double? _agentLatitude;
  double? _agentLongitude;
  bool _saving = false;

  bool get _isCustomer =>
      (widget.data['role']?.toString().trim().isEmpty ?? true) ||
      widget.data['role']?.toString() == 'customer';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
        text: widget.data['displayName']?.toString() ??
            widget.user.displayName ??
            '');
    _address =
        TextEditingController(text: widget.data['address']?.toString() ?? '');
    _phone =
        TextEditingController(text: widget.data['phone']?.toString() ?? '');
    _agentNumber = TextEditingController(
        text: widget.data['agentNumber']?.toString() ?? '');
    _agentLocation = TextEditingController(
        text: widget.data['agentLocation']?.toString() ?? '');
    _agentLatitude = (widget.data['agentLatitude'] as num?)?.toDouble();
    _agentLongitude = (widget.data['agentLongitude'] as num?)?.toDouble();
    _facebookUrl = TextEditingController(
        text: widget.data['facebookUrl']?.toString() ?? '');
    _instagramUrl = TextEditingController(
        text: widget.data['instagramUrl']?.toString() ?? '');
    _tiktokUrl =
        TextEditingController(text: widget.data['tiktokUrl']?.toString() ?? '');
    _gender = widget.data['gender']?.toString() ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _agentNumber.dispose();
    _agentLocation.dispose();
    _facebookUrl.dispose();
    _instagramUrl.dispose();
    _tiktokUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final name = _name.text.trim();
      final changes = <String, dynamic>{
        'displayName': name,
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
        'agentLocation': _agentLocation.text.trim(),
        'agentLatitude': _agentLatitude,
        'agentLongitude': _agentLongitude,
      };

      if (!_isCustomer) {
        changes.addAll({
          'agentNumber': _agentNumber.text.trim(),
          'facebookUrl': _facebookUrl.text.trim(),
          'instagramUrl': _instagramUrl.text.trim(),
          'tiktokUrl': _tiktokUrl.text.trim(),
          'gender': _gender,
        });
      }
      await UserProfileService()
          .updateCustomerProfile(widget.user.uid, changes);
      await widget.user.updateDisplayName(name);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(widget.copy.saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.copy.editProfile), centerTitle: true),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                    labelText: widget.copy.fullName,
                    prefixIcon: const Icon(Icons.person_outline)),
                validator: (value) => value == null || value.trim().isEmpty
                    ? widget.copy.nameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: widget.user.email,
                readOnly: true,
                decoration: InputDecoration(
                    labelText: widget.copy.email,
                    prefixIcon: const Icon(Icons.lock_outline_rounded)),
              ),
              const SizedBox(height: 16),
              if (_isCustomer) ...[
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: widget.copy.phone,
                    prefixIcon: const Icon(Icons.phone_outlined),
                    helperText: 'رقم الهاتف المستخدم للتواصل بخصوص الطلب',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'أدخل رقم الهاتف للتوصيل'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _address,
                  decoration: InputDecoration(
                    labelText: widget.copy.address,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    helperText: 'العنوان الذي سيظهر في طلبات التوصيل',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'أدخل عنوان التوصيل'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _agentLocation,
                  decoration: const InputDecoration(
                    labelText: 'وصف موقع التوصيل',
                    prefixIcon: Icon(Icons.place_outlined),
                    helperText: 'مثال: بجانب البلدية أو خلف المستشفى',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final location = await Navigator.push<Map<String, double>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocationPickerScreen(
                          latitude: _agentLatitude,
                          longitude: _agentLongitude,
                        ),
                      ),
                    );

                    if (location != null && mounted) {
                      setState(() {
                        _agentLatitude = location['latitude'];
                        _agentLongitude = location['longitude'];
                      });
                    }
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    _agentLatitude == null || _agentLongitude == null
                        ? 'تحديد موقع التوصيل على الخريطة'
                        : 'تم تحديد موقع التوصيل — اضغط للتعديل',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!_isCustomer) ...[
                TextFormField(
                  controller: _address,
                  decoration: InputDecoration(
                      labelText: widget.copy.address,
                      prefixIcon: const Icon(Icons.location_on_outlined)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                      labelText: widget.copy.phone,
                      prefixIcon: const Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _agentNumber,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: widget.copy.agentNumber,
                      prefixIcon: const Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _agentLocation,
                  decoration: const InputDecoration(
                      labelText: 'موقع الوسيط أو الوسيطة',
                      prefixIcon: Icon(Icons.location_on_outlined)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final location = await Navigator.push<Map<String, double>>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => LocationPickerScreen(
                                latitude: _agentLatitude,
                                longitude: _agentLongitude)));
                    if (location != null && mounted) {
                      setState(() {
                        _agentLatitude = location['latitude'];
                        _agentLongitude = location['longitude'];
                      });
                    }
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: Text(_agentLatitude == null
                      ? 'تحديد موقع الوسيط على الخريطة'
                      : 'تم تحديد الموقع — اضغط للتعديل'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _facebookUrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                      labelText: widget.copy.facebookLink,
                      prefixIcon: const Icon(Icons.facebook_rounded)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instagramUrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                      labelText: widget.copy.instagramLink,
                      prefixIcon: const Icon(Icons.camera_alt_outlined)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tiktokUrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                      labelText: widget.copy.tiktokLink,
                      prefixIcon: const Icon(Icons.music_note_rounded)),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: const ['', 'female', 'male', 'prefer_not_to_say']
                          .contains(_gender)
                      ? _gender
                      : '',
                  decoration: InputDecoration(
                      labelText: widget.copy.gender,
                      prefixIcon: const Icon(Icons.wc_rounded)),
                  items: [
                    DropdownMenuItem(
                        value: '', child: Text(widget.copy.notSelected)),
                    DropdownMenuItem(
                        value: 'female', child: Text(widget.copy.female)),
                    DropdownMenuItem(
                        value: 'male', child: Text(widget.copy.male)),
                    DropdownMenuItem(
                        value: 'prefer_not_to_say',
                        child: Text(widget.copy.notSay)),
                  ],
                  onChanged: (value) => setState(() => _gender = value ?? ''),
                ),
              ],
              const SizedBox(height: 30),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54)),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? widget.copy.saving : widget.copy.save),
              ),
            ]),
          ),
        ),
      );
}

class _ProfileCopy {
  const _ProfileCopy(this.code);
  final String code;
  bool get _en => code == 'en';
  bool get _fr => code == 'fr';
  String get myPage => _en
      ? 'My profile'
      : _fr
          ? 'Mon profil'
          : 'صفحتي';
  String get profile => _en
      ? 'Profile'
      : _fr
          ? 'Profil'
          : 'الملف الشخصي';
  String get editProfile => _en
      ? 'Edit profile'
      : _fr
          ? 'Modifier le profil'
          : 'تعديل الملف الشخصي';
  String get fullName => _en
      ? 'Full name'
      : _fr
          ? 'Nom complet'
          : 'الاسم الكامل';
  String get email => _en
      ? 'Email'
      : _fr
          ? 'E-mail'
          : 'البريد الإلكتروني';
  String get address => _en
      ? 'Address'
      : _fr
          ? 'Adresse'
          : 'العنوان';
  String get phone => _en
      ? 'Phone number'
      : _fr
          ? 'Téléphone'
          : 'رقم الهاتف';
  String get agentNumber => _en
      ? 'Agent number'
      : _fr
          ? 'Numéro de l’agent'
          : 'رقم الوسيط أو الوسيطة';
  String get facebookLink => _en
      ? 'Facebook page link'
      : _fr
          ? 'Lien Facebook'
          : 'رابط صفحة Facebook';
  String get instagramLink => _en
      ? 'Instagram page link'
      : _fr
          ? 'Lien Instagram'
          : 'رابط صفحة Instagram';
  String get tiktokLink => _en
      ? 'TikTok page link'
      : _fr
          ? 'Lien TikTok'
          : 'رابط صفحة TikTok';
  String get invalidLink => _en
      ? 'Could not open this link.'
      : _fr
          ? 'Impossible d’ouvrir ce lien.'
          : 'تعذر فتح هذا الرابط.';
  String get gender => _en
      ? 'Gender'
      : _fr
          ? 'Genre'
          : 'الجنس';
  String get language => _en
      ? 'Language'
      : _fr
          ? 'Langue'
          : 'اللغة';
  String get shareApp => _en
      ? 'Share Barakah'
      : _fr
          ? 'Partager Barakah'
          : 'مشاركة تطبيق بركة';
  String get shareAppSubtitle => _en
      ? 'Send the app to your friends'
      : _fr
          ? 'Envoyez l’application à vos amis'
          : 'أرسل التطبيق إلى أصدقائك';
  String get shareMessage => _en
      ? 'Discover restaurants, shops and offers in Barakah: https://barakah-new.web.app'
      : _fr
          ? 'Découvrez les restaurants, magasins et offres sur Barakah : https://barakah-new.web.app'
          : 'اكتشف المطاعم والمحلات والعروض في تطبيق بركة: https://barakah-new.web.app';
  String get languageName => _en
      ? 'English'
      : _fr
          ? 'Français'
          : 'العربية';
  String get chooseLanguage => _en
      ? 'Choose language'
      : _fr
          ? 'Choisir la langue'
          : 'اختر اللغة';
  String get notAdded => _en
      ? 'Not added yet'
      : _fr
          ? 'Non ajouté'
          : 'لم تتم الإضافة بعد';
  String get login => _en
      ? 'Log in or create an account'
      : _fr
          ? 'Connexion ou créer un compte'
          : 'تسجيل الدخول أو إنشاء حساب';
  String get logout => _en
      ? 'Log out'
      : _fr
          ? 'Déconnexion'
          : 'تسجيل الخروج';
  String get admin => _en
      ? 'Admin login'
      : _fr
          ? 'Accès administrateur'
          : 'دخول الأدمن';
  String get save => _en
      ? 'Save changes'
      : _fr
          ? 'Enregistrer'
          : 'حفظ التعديلات';
  String get saving => _en
      ? 'Saving...'
      : _fr
          ? 'Enregistrement...'
          : 'جارٍ الحفظ...';
  String get saveFailed => _en
      ? 'Could not save profile. Try again.'
      : _fr
          ? 'Impossible d’enregistrer le profil.'
          : 'تعذر حفظ الملف الشخصي. حاول مرة أخرى.';
  String get nameRequired => _en
      ? 'Enter your name'
      : _fr
          ? 'Saisissez votre nom'
          : 'أدخل الاسم';
  String get notSelected => _en
      ? 'Not selected'
      : _fr
          ? 'Non sélectionné'
          : 'غير محدد';
  String get female => _en
      ? 'Female'
      : _fr
          ? 'Femme'
          : 'أنثى';
  String get male => _en
      ? 'Male'
      : _fr
          ? 'Homme'
          : 'ذكر';
  String get notSay => _en
      ? 'Prefer not to say'
      : _fr
          ? 'Je préfère ne pas répondre'
          : 'أفضل عدم الإجابة';
  String genderLabel(String value) => switch (value) {
        'female' => female,
        'male' => male,
        'prefer_not_to_say' => notSay,
        _ => value,
      };
}

class _PrivacyPolicyScreen extends StatelessWidget {
  const _PrivacyPolicyScreen();

  @override
  Widget build(BuildContext context) {
    const sections = <(String, String)>[
      (
        'مقدمة',
        'نحترم في بركة خصوصيتك ونعمل على حماية بياناتك واستخدامها فقط لتقديم خدمات التطبيق وتحسينها.',
      ),
      (
        'المعلومات التي نجمعها',
        'قد نجمع الاسم، البريد الإلكتروني، رقم الهاتف، بيانات الملف الشخصي، العنوان، بيانات الطلبات والسلة والنقاط والقسائم، والصور أو المحتوى الذي ترسله طوعًا في الميزات المرتبطة بحسابك.',
      ),
      (
        'كيفية استخدام المعلومات',
        'نستخدم البيانات لتشغيل التطبيق، إدارة الحسابات، معالجة الطلبات، خدمة العملاء، تشغيل نظام نقاط ومكافآت بركة، تحسين الأداء، وإرسال التنبيهات المتعلقة بالخدمة.',
      ),
      (
        'الموقع الجغرافي',
        'عند منح التطبيق إذن الموقع، قد نستخدم موقعك لتقديم ميزات مثل الأماكن القريبة منك وتحديد نطاق التوصيل. يمكنك إيقاف إذن الموقع من إعدادات الجهاز.',
      ),
      (
        'الطلبات والدفع',
        'نستخدم بيانات الطلب والعناوين والمبالغ لإتمام الخدمة. إذا تم استخدام مزود دفع إلكتروني، فقد تتم معالجة معلومات الدفع لديه وفق سياسته.',
      ),
      (
        'الحجوزات والاستشارات الصحية',
        'عند حجز موعد صحي أو إرسال استشارة، نجمع تفاصيل الموعد ونص الرسالة الذي تكتبه، وقد تتضمن الرسالة معلومات صحية تختار تقديمها. تظهر هذه البيانات للطبيب أو العيادة التي اخترتها ولإدارة بركة عند الحاجة للتشغيل والدعم. بركة منصة للحجز والتواصل وليست جهازًا طبيًا ولا تقدم تشخيصًا أو علاجًا.',
      ),
      (
        'الإشعارات',
        'قد نرسل إشعارات تتعلق بالطلبات والعروض والمكافآت وتحديثات الخدمة. يمكنك التحكم في الإشعارات من إعدادات الجهاز.',
      ),
      (
        'مشاركة البيانات',
        'قد نشارك الحد الأدنى اللازم من المعلومات مع المتاجر المشاركة، مقدمي التوصيل، ومزودي البنية التحتية لتشغيل الخدمة. بركة لا تبيع البيانات الشخصية للمستخدمين.',
      ),
      (
        'حماية البيانات',
        'نتخذ إجراءات تقنية وتنظيمية معقولة لحماية بيانات المستخدمين من الوصول أو الاستخدام غير المصرح به.',
      ),
      (
        'حقوق المستخدم',
        'يمكنك طلب الاطلاع على بيانات حسابك أو تصحيحها أو طلب حذف الحساب من صفحة «صفحتي». يشمل الحذف الملف الشخصي والبيانات المرتبطة التي لا يلزم الاحتفاظ بها، مع جواز الاحتفاظ بسجلات المعاملات الضرورية للالتزامات القانونية وتسوية النزاعات.',
      ),
      (
        'بيانات الأطفال',
        'الخدمة ليست موجهة لجمع بيانات الأطفال بشكل مقصود.',
      ),
      (
        'التعديلات على السياسة',
        'قد نقوم بتحديث سياسة الخصوصية من وقت لآخر. النسخة الأحدث المعروضة داخل التطبيق هي النسخة المعتمدة.',
      ),
      (
        'التواصل معنا',
        'لأي استفسار يتعلق بالخصوصية أو بيانات الحساب، استخدم خيار «تواصل مع بركة» الموجود داخل التطبيق.',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('سياسة الخصوصية'),
        centerTitle: true,
      ),
      body: BarakahBrandBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 34),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(.12),
                      const Color(0xFF0D2948).withOpacity(.92),
                      const Color(0xFF06172C).withOpacity(.96),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: AppTheme.coolYellow.withOpacity(.55),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.privacy_tip_rounded,
                      color: AppTheme.coolYellow,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'سياسة خصوصية بركة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'آخر تحديث: 2 سبتمبر 2026',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...sections.expand(
                      (section) => [
                        Text(
                          section.$1,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppTheme.coolYellow,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          section.$2,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.8,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
