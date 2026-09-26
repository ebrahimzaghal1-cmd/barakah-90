module.exports = async function mediatorAction(request, {database, FieldValue, HttpsError, hash, randomInt}) {
const fail = (message) => { throw new HttpsError('failed-precondition', message); };
const str = (v, max = 2000) => typeof v === 'string' ? v.trim().slice(0, max) : '';
const money = v => {
  if (typeof v !== 'number' || !Number.isFinite(v) || v < 0 || v > 100000) fail('قيمة مالية غير صالحة');
  return Math.round(v * 100);
};

  if (!request.auth) throw new HttpsError('unauthenticated', 'سجّل الدخول أولًا');
  const uid = request.auth.uid, d = request.data || {}, db = database;
  const admin = (await db.doc(`users/${uid}`).get()).data()?.role === 'admin';
  const action = str(d.action, 30);
  const agreementVersion = '2026-09-10-v1';
  const commissionBps = 500;
  const privacyText = 'تجمع بركة اسمك ورقمك الخاص والمنطقة والموقع المختار وبيانات طلباتك ومحادثاتها. يظهر للعملاء الاسم والمنطقة والموقع المختار فقط؛ لا يظهر رقمك. يستخدم الموقع لترتيب الوسيطات وعرضهن على الخريطة دون تتبع خلفي. تطلع الإدارة على الطلبات والمحادثات عند الدعم والتسوية والاعتراض. تحفظ سجلات العمليات للمدة اللازمة للتشغيل والمحاسبة والنزاعات وفق سياسة خصوصية بركة. يمكنك طلب تصحيح بياناتك أو حذف حسابك من داخل التطبيق مع مراعاة الالتزامات والطلبات القائمة.';
  const contractText = 'تعمل الوسيطة بعد اعتماد الإدارة بحسابها الخاص. عمولة بركة 5% من أجرة الوسيطة فقط، وصافي الوسيطة 95%؛ المشتريات ورسوم التوصيل لا تدخل في أساس العمولة. مثال توضيحي: إذا كانت أجرة الوسيطة 20 ₪، تكون عمولة بركة 1 ₪، وصافي الوسيطة 19 ₪. تثبت النسبة والقيم عند إنشاء كل طلب ولا تتغير بأثر رجعي. تقبل الوسيطة أو ترفض الطلب قبل التنفيذ، ولا تستبدل المشتريات أو ترفع القيمة دون طلب جديد متفق عليه. الدفع نقدًا عند التسليم، والبطاقة غير مفعلة. لا تطلب رمز التسليم قبل التسليم الفعلي واستلام النقد؛ الرمز إثبات إتمام ولا يلغي حق الاعتراض. يعلق الاعتراض مستحق الطلب وحده لحين قرار الإدارة المسبب. المبالغ النقدية التي استلمتها الوسيطة تخضع للمطابقة والتسوية ولا تعد مستحقًا إضافيًا يدفع مرة ثانية. تسجل الإدارة التسوية ومرجعها، والتواصل ومراجع الطلب داخل بركة. يجب حماية بيانات العميل واستخدامها لتنفيذ طلبه فقط. أي تغيير لاحق في النسبة يحتاج اتفاقًا جديدًا. لا رسوم اشتراك دورية بموجب هذه النسخة.';
  if (action === 'terms') return {agreementVersion, commissionBps, privacyText, contractText};
  if (action === 'apply') {
    if (d.agreementVersion !== agreementVersion || d.acceptPrivacy !== true || d.acceptContract !== true) fail('راجعي سياسة الخصوصية والاتفاق ووافقي عليهما');
    const name = str(d.name, 120), phone = str(d.phone, 40), area = str(d.area, 200);
    const latitude = d.latitude, longitude = d.longitude;
    if (!name || !/^[+0-9 ()-]{7,40}$/.test(phone) || !area || typeof latitude !== 'number' || typeof longitude !== 'number' || !Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) fail('أكملي الاسم والرقم والمنطقة والموقع');
    const appRef = db.doc(`mediator_applications/${uid}`);
    return db.runTransaction(async tx => {
      const previous = (await tx.get(appRef)).data();
      const profile = (await tx.get(db.doc(`users/${uid}`))).data();
      if (!profile || !['customer','merchant'].includes(profile.role)) fail('هذا الحساب غير مؤهل للانضمام كوسيطة');
      if (previous && ['pending','approved'].includes(previous.status)) return {status: previous.status};
      const now = FieldValue.serverTimestamp();
      const application = {userId: uid, name, phone, area, latitude, longitude, status: 'pending', agreementVersion, commissionBps, privacyText, contractText, acceptPrivacy: true, acceptContract: true, acceptedAt: now, createdAt: now};
      if (previous) tx.update(appRef, application); else tx.create(appRef, application);
      tx.create(appRef.collection('events').doc(), {action: 'apply', actorId: uid, createdAt: now, agreementVersion});
      return {status:'pending'};
    });
  }
  if (action === 'approve_application' || action === 'reject_application') {
    if (!admin) throw new HttpsError('permission-denied','للإدارة فقط');
    const applicant = str(d.applicantId,128);
    if (!/^[a-zA-Z0-9_-]+$/.test(applicant)) fail('معرف غير صالح');
    const appRef = db.doc(`mediator_applications/${applicant}`);
    return db.runTransaction(async tx => {
      const a = (await tx.get(appRef)).data();
      const profileRef = db.doc(`users/${applicant}`);
      const profile = (await tx.get(profileRef)).data();
      if (!a || a.status !== 'pending' || !profile || !['customer','merchant'].includes(profile.role)) fail('الطلب غير متاح للاعتماد');
      const now = FieldValue.serverTimestamp();
      const status = action === 'approve_application' ? 'approved' : 'rejected';
      const note = str(d.note);
      if (status === 'rejected' && !note) fail('أدخل سبب الرفض');
      if (status === 'approved') {
        const businessId = `mediator_${applicant}`;
        tx.create(db.doc(`items/${businessId}`), {title:a.name, description:'وسيطة معتمدة في بركة', kind:'agent', type:'agent', category:'وسيطات', ownerId:applicant, agentLocation:a.area, latitude:a.latitude, longitude:a.longitude, businessStatus:'open', rating:0, isTrending:false, image:'', commissionBps:a.commissionBps, agreementVersion:a.agreementVersion, createdAt:now});
        tx.create(db.doc(`mediator_private/${businessId}`), {phone:a.phone, updatedAt:now});
        tx.update(profileRef, {role:'merchant', merchantEnabled:true, mediatorEnabled:true, updatedAt:now});
      }
      tx.update(appRef, {status, reviewedAt:now, reviewedBy:uid, reviewNote:note});
      tx.create(appRef.collection('events').doc(), {action,actorId:uid,note,createdAt:now});
      return {status};
    });
  }
  if (action === 'create') {
    const businessId = str(d.businessId, 128), key = str(d.requestId, 80);
    if (!/^[a-zA-Z0-9_-]{16,80}$/.test(key) || !/^[a-zA-Z0-9_-]+$/.test(businessId)) fail('طلب غير صالح');
    if (d.paymentMethod !== 'cash') fail('الدفع بالبطاقة قريبًا');
    const details = str(d.details), address = str(d.address, 600);
    if (!details || !address) fail('أدخل تفاصيل الطلب والعنوان');
    const budgetCents = money(d.budget);
    const ref = db.collection('mediator_orders').doc(await hash(`${uid}:${key}`));
    return db.runTransaction(async tx => {
      const old = await tx.get(ref);
      if (old.exists) return {orderId: ref.id};
      const business = (await tx.get(db.doc(`items/${businessId}`))).data();
      if (!business || business.kind !== 'agent' || !business.ownerId || business.businessStatus === 'closed' || business.businessStatus === 'coming_soon') fail('الوسيطة غير متاحة');
      if (business.ownerId === uid) fail('لا يمكنك طلب نفسك');
      if (typeof business.mediatorFee !== 'number') fail('يجب تحديد أجرة الوسيطة أولًا');
      const feeCents = money(business.mediatorFee), deliveryCents = money(business.deliveryFee || 0);
      if (d.expectedFeeCents !== feeCents || d.expectedDeliveryCents !== deliveryCents) fail('تغيرت الرسوم؛ راجع السعر وأعد الطلب');
      const platformFeeCents = Math.round(feeCents * commissionBps / 10000);
      const netFeeCents = feeCents - platformFeeCents;
      const otp = String(randomInt(100000, 1000000));
      const now = FieldValue.serverTimestamp();
      tx.create(ref, {customerId: uid, mediatorId: business.ownerId, businessId,
        title: str(business.title, 200), orderNumber: `WS-${ref.id.slice(0, 14).toUpperCase()}`,
        details, address, budgetCents, feeCents, commissionBps, platformFeeCents, netFeeCents, deliveryCents, totalCents: budgetCents + feeCents + deliveryCents,
        paymentMethod: 'cash', paymentStatus: 'unpaid', status: 'pending', earningStatus: 'pending', createdAt: now, updatedAt: now});
      tx.create(ref.collection('private').doc('delivery'), {customerId: uid, otp, attempts: 0, lockedUntil: null});
      tx.create(ref.collection('events').doc(), {action, actorId: uid, createdAt: now});
      return {orderId: ref.id};
    });
  }
  const id = str(d.orderId, 128);
  if (!/^[a-zA-Z0-9_-]+$/.test(id)) fail('طلب غير صالح');
  const ref = db.doc(`mediator_orders/${id}`);
  const result = await db.runTransaction(async tx => {
    const o = (await tx.get(ref)).data();
    if (!o) fail('الطلب غير موجود');
    const customer = o.customerId === uid, mediator = o.mediatorId === uid;
    if (!admin && !customer && !mediator) throw new HttpsError('permission-denied', 'غير مسموح');
    const now = FieldValue.serverTimestamp(), patch = {updatedAt: now};
    let note = str(d.note);
    switch (action) {
      case 'accept': case 'reject':
        if (!mediator || o.status !== 'pending') fail('لا يمكن تغيير حالة الطلب');
        patch.status = action === 'accept' ? 'in_progress' : 'rejected';
        patch[action === 'accept' ? 'acceptedAt' : 'rejectedAt'] = now;
        if (action === 'reject') patch.earningStatus = 'cancelled';
        break;
      case 'deliver': {
        if (!mediator || o.status !== 'in_progress' || d.cashCollected !== true) fail('أكد استلام المبلغ النقدي قبل التسليم');
        const secretRef = ref.collection('private').doc('delivery');
        const secret = (await tx.get(secretRef)).data();
        if (!secret || (secret.lockedUntil && secret.lockedUntil.toMillis() > Date.now())) fail('محاولات كثيرة؛ انتظر 15 دقيقة');
        if (!/^\d{6}$/.test(String(d.otp)) || secret.otp !== String(d.otp)) {
          const attempts = (secret.attempts || 0) + 1;
          tx.update(secretRef, {attempts, lockedUntil: attempts % 5 === 0 ? new Date(Date.now() + 900000) : null});
          tx.create(ref.collection('events').doc(), {action: 'invalid_otp', actorId: uid, createdAt: now});
          return {error: 'رمز التسليم غير صحيح'};
        }
        patch.status = 'delivered'; patch.earningStatus = 'due'; patch.deliveredAt = now;
        patch.paymentStatus = 'cash_collected'; patch.cashCollectedAt = now;
        tx.delete(secretRef);
        break;
      }
      case 'dispute':
        if ((!customer && !mediator) || !['in_progress', 'delivered'].includes(o.status) || !note) fail('لا يمكن فتح الاعتراض');
        patch.previousStatus = o.status; patch.status = 'disputed'; patch.earningStatus = 'held'; patch.disputedAt = now; patch.disputeReason = note;
        break;
      case 'resolve':
        if (!admin || o.status !== 'disputed' || !note) fail('يلزم قرار الإدارة وسببه');
        patch.status = o.previousStatus; patch.earningStatus = o.previousStatus === 'delivered' ? 'due' : 'pending'; patch.resolvedAt = now; patch.resolution = note;
        break;
      case 'settle':
        if (!admin || o.status !== 'delivered' || o.earningStatus !== 'due' || !note) fail('يلزم مرجع دفع المستحق');
        patch.status = 'settled'; patch.earningStatus = 'paid'; patch.settledAt = now; patch.settlementReference = note;
        break;
      case 'message':
        if (!note || ['rejected', 'settled'].includes(o.status)) fail('لا يمكن إرسال الرسالة');
        tx.create(ref.collection('messages').doc(), {text: note, senderId: uid, createdAt: now});
        break;
      default: fail('عملية غير معروفة');
    }
    tx.update(ref, patch);
    tx.create(ref.collection('events').doc(), {action, actorId: uid, note, createdAt: now});
    return {orderId: id};
  });
  if (result.error) fail(result.error);
  return result;

};
