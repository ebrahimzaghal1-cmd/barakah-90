import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum LegalDocumentType {
  privacy,
  generalTerms,
  partnerAgreement,
  driverTerms,
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.type,
  });

  final LegalDocumentType type;

  static const agreementVersion = '2026-08-17-v1';

  String get _title => switch (type) {
        LegalDocumentType.privacy => 'سياسة الخصوصية',
        LegalDocumentType.generalTerms => 'شروط استخدام بركة',
        LegalDocumentType.partnerAgreement => 'اتفاقية الشريك',
        LegalDocumentType.driverTerms => 'شروط سائق بركة',
      };

  List<(String, String)> get _sections => switch (type) {
        LegalDocumentType.privacy => const [
            (
              'البيانات التي نجمعها',
              'قد تجمع بركة بيانات الحساب والاسم ورقم الهاتف والبريد الإلكتروني والموقع عند استخدام الميزات التي تحتاج الموقع، وبيانات الطلبات، وبيانات التجار والسائقين والوثائق المقدمة للتحقق.'
            ),
            (
              'استخدام البيانات',
              'تستخدم البيانات لتشغيل التطبيق وتنفيذ الطلبات والتوصيل وإدارة الحسابات والمحاسبة والدعم والتحقق من الهوية والنشاط ومكافحة إساءة الاستخدام.'
            ),
            (
              'بيانات التوثيق',
              'بيانات الهوية والحسابات المالية ووثائق النشاط مخصصة للتحقق الإداري ولا يجوز عرضها للمستخدمين الآخرين.'
            ),
            (
              'الموقع',
              'قد يستخدم الموقع لتقديم خدمات التوصيل والأماكن القريبة وتتبع حالة السائق وفق الصلاحيات الممنوحة من الجهاز.'
            ),
            (
              'مشاركة البيانات',
              'قد تتم مشاركة الحد الأدنى اللازم من البيانات مع أطراف تنفيذ الطلب ومزودي الخدمات التقنية والدفع والتوصيل وفق الحاجة التشغيلية والقانونية.'
            ),
            (
              'الاحتفاظ والأمان',
              'تحتفظ بركة بالبيانات للمدة اللازمة لتشغيل الخدمة والمحاسبة وتسوية النزاعات والالتزامات القانونية، مع اتخاذ وسائل حماية مناسبة.'
            ),
          ],
        LegalDocumentType.generalTerms => const [
            (
              'استخدام التطبيق',
              'يلتزم المستخدم بتقديم بيانات صحيحة وعدم إساءة استخدام الخدمة أو محاولة الوصول غير المصرح به إلى حسابات الآخرين.'
            ),
            (
              'الطلبات',
              'تخضع الطلبات لتوفر المنتجات وقبول المتجر وإمكانية التوصيل، وقد يتم إلغاء الطلب عند تعذر التنفيذ.'
            ),
            (
              'الأسعار',
              'تعرض الأسعار والعروض وفق البيانات المتاحة من المتاجر ويجب بيان الرسوم الإضافية للمستخدم قبل تأكيد الطلب متى كانت مطبقة.'
            ),
          ],
        LegalDocumentType.partnerAgreement => const [
            (
              'لا توجد رسوم اشتراك',
              'لا تفرض بركة رسوم اشتراك دورية لمجرد فتح حساب التاجر وفق النموذج الحالي.'
            ),
            (
              'عمولة بركة',
              'العمولة الافتراضية هي 10% من قيمة المنتجات في الطلب المكتمل فقط.'
            ),
            (
              'رسوم التوصيل',
              'لا تدخل رسوم التوصيل في أساس عمولة بركة ما لم يتم الاتفاق كتابة على غير ذلك.'
            ),
            (
              'الطلبات الملغاة',
              'لا تستحق عمولة بركة على الطلب الملغى الذي لم يكتمل.'
            ),
            (
              'إثبات اكتمال الطلب',
              'تثبت العمولة عند اكتمال الطلب وفق حالة النظام وآلية إثبات التسليم المعتمدة في بركة.'
            ),
            (
              'التسويات',
              'تظهر للتاجر والأدمن كشوف المبيعات والعمولة والمستحقات ويلتزم التاجر بتسوية المبالغ المستحقة وفق الدورة المتفق عليها.'
            ),
            (
              'صحة البيانات',
              'يلتزم التاجر بصحة بيانات هويته ونشاطه وحسابه المالي ووسائل الاتصال والمستندات المقدمة للتحقق.'
            ),
            (
              'مسؤولية المنتجات',
              'يتحمل التاجر مسؤولية صحة وصف المنتجات والأسعار والجودة والسلامة والصلاحية والالتزام بمتطلبات نشاطه.'
            ),
            (
              'تعليق الحساب',
              'يجوز تعليق حساب التاجر عند وجود مخالفات جوهرية أو بيانات غير صحيحة أو مستحقات مالية متأخرة وفق الإجراءات المعتمدة.'
            ),
          ],
        LegalDocumentType.driverTerms => const [
            (
              'صحة البيانات',
              'يلتزم السائق بتقديم بيانات صحيحة عن الهوية ورقم الهاتف والبريد الإلكتروني ووسيلة التوصيل والرخص المطلوبة.'
            ),
            (
              'المركبة والرخص',
              'عند استخدام مركبة تتطلب رخصة قيادة أو تسجيلًا أو تأمينًا، يجب أن تكون الوثائق سارية وفق المتطلبات المطبقة.'
            ),
            (
              'استلام الطلب',
              'يلتزم السائق بالمحافظة على الطلب منذ استلامه وحتى تسليمه للعميل.'
            ),
            (
              'إثبات التسليم',
              'لا يجوز تسجيل الطلب كمكتمل قبل تسليمه فعليًا باستخدام آلية الإثبات المعتمدة في بركة.'
            ),
            (
              'الأموال',
              'إذا استلم السائق مبالغ نقدية لحساب الطلب، يلتزم بإجراءات التسوية المالية المعتمدة لدى بركة.'
            ),
            (
              'السلامة',
              'يلتزم السائق بقواعد السير والسلامة والمتطلبات النظامية المتعلقة بوسيلة التوصيل.'
            ),
          ],
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: Text(
          _title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.coolYellow.withOpacity(.22),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'هذه صياغة تشغيلية داخل التطبيق ويجب مراجعتها قانونيًا قبل الإطلاق التجاري النهائي.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.navy,
                fontWeight: FontWeight.w900,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'الإصدار: $agreementVersion',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ..._sections.map(
            (section) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.$1,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      section.$2,
                      style: const TextStyle(
                        height: 1.65,
                        color: Colors.black87,
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
}
