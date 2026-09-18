import { documentId, requireValue } from './store.js';

const ACTIVE_STATES = [
  'pending',
  'dispatched',
  'awaiting_customer_confirmation',
];
const STATES = [
  'pending',
  'dispatched',
  'awaiting_customer_confirmation',
  'completed',
  'cancelled',
];

function ownsBusiness(user, actor, business) {
  return actor?.role === 'merchant' &&
    (business.ownerId === user.uid ||
      (Array.isArray(business.managerIds) &&
        business.managerIds.includes(user.uid)));
}

function isAdmin(user, actor, primaryAdminUid) {
  return user?.uid === primaryAdminUid && actor?.role === 'admin';
}

function cleanText(value, field, maxLength, { minLength = 1 } = {}) {
  requireValue(
    typeof value === 'string' &&
      value.trim().length >= minLength &&
      value.trim().length <= maxLength,
    `invalid-${field}`,
    'بيانات طلب التاكسي غير مكتملة أو غير صالحة.',
  );
  return value.trim();
}

function optionalText(value, maxLength) {
  if (value == null || value === '') return '';
  requireValue(
    typeof value === 'string' && value.trim().length <= maxLength,
    'invalid-text',
    'إحدى البيانات المدخلة غير صالحة.',
  );
  return value.trim();
}

function optionalCoordinate(value, min, max) {
  if (value == null) return null;
  requireValue(
    typeof value === 'number' &&
      Number.isFinite(value) &&
      value >= min &&
      value <= max,
    'invalid-location',
    'إحداثيات موقع الركوب غير صالحة.',
  );
  return value;
}

function taxiBusinessAvailable(business) {
  const type = String(business?.type || '').toLowerCase().trim();
  const merchantType =
    String(business?.merchantType || '').toLowerCase().trim();
  const category = String(business?.category || '').toLowerCase();
  const activity = String(business?.activityType || '').toLowerCase();
  const title = String(business?.title || '').toLowerCase();

  const taxi =
    type === 'taxi' ||
    merchantType === 'taxi' ||
    category.includes('تكسي') ||
    category.includes('تاكسي') ||
    category.includes('taxi') ||
    activity.includes('تكسي') ||
    activity.includes('تاكسي') ||
    title.includes('تكسي') ||
    title.includes('تاكسي');

  return taxi &&
    business?.kind !== 'product' &&
    business?.isActive !== false &&
    business?.status !== 'closed' &&
    business?.status !== 'coming_soon' &&
    business?.businessStatus !== 'closed' &&
    business?.businessStatus !== 'coming_soon';
}

function taxiCommissionRate(business) {
  const configured = Number(business?.commissionRate);
  const rate =
    Number.isFinite(configured) &&
    configured >= 0 &&
    configured <= 100
      ? configured
      : 10;

  return rate;
}

function calculateTaxiFinance(business, fareAmount) {
  requireValue(
    typeof fareAmount === 'number' &&
      Number.isFinite(fareAmount) &&
      fareAmount > 0 &&
      fareAmount <= 100000,
    'invalid-taxi-fare',
    'أجرة الرحلة غير صالحة.',
  );

  const fare = Number(fareAmount.toFixed(2));
  const commissionRate = taxiCommissionRate(business);
  const commissionAmount = Number(
    (fare * commissionRate / 100).toFixed(2),
  );
  const businessNet = Number(
    (fare - commissionAmount).toFixed(2),
  );

  return {
    fareAmount: fare,
    commissionRate,
    commissionAmount,
    businessNet,
  };
}

export async function createTaxiOrder(
  store,
  user,
  input,
  { now = new Date(), primaryAdminUid } = {},
) {
  const businessId = documentId(input.businessId);

  requireValue(
    /^[A-Za-z0-9_-]{8,80}$/.test(input.requestId || ''),
    'invalid-request-id',
    'معرّف الطلب غير صالح.',
  );

  const orderId = `${documentId(user.uid)}_${input.requestId}`;

  const pickupAddress = cleanText(
    input.pickupAddress,
    'pickup-address',
    300,
  );
  const destination = cleanText(
    input.destination,
    'destination',
    300,
  );
  const notes = optionalText(input.notes, 500);
  const customerName = optionalText(input.customerName, 160);
  const customerPhone = optionalText(input.customerPhone, 80);
  const pickupLatitude = optionalCoordinate(
    input.pickupLatitude,
    -90,
    90,
  );
  const pickupLongitude = optionalCoordinate(
    input.pickupLongitude,
    -180,
    180,
  );

  return store.runTransaction(async (tx) => {
    const existing = await tx.get(`taxi_orders/${orderId}`);

    if (existing) {
      requireValue(
        existing.data.customerId === user.uid &&
          existing.data.businessId === businessId,
        'request-id-reused',
        'أُعيد استخدام معرّف الطلب لطلب مختلف.',
        409,
      );

      return {
        orderId,
        orderNumber: existing.data.orderNumber,
        status: existing.data.status,
      };
    }

    const business = (await tx.get(`items/${businessId}`))?.data;
    const actor =
      (await tx.get(`users/${documentId(user.uid)}`))?.data;

    requireValue(
      !!business && !!actor,
      'business-not-found',
      'مكتب التاكسي أو الحساب غير موجود.',
      404,
    );

    requireValue(
      taxiBusinessAvailable(business),
      'taxi-unavailable',
      'خدمة التاكسي غير متاحة حاليًا.',
      409,
    );

    requireValue(
      !ownsBusiness(user, actor, business),
      'self-taxi-order',
      'لا يمكن إنشاء طلب تاكسي لمكتبك من حساب التاجر.',
      403,
    );

    const activeOrders = await tx.query('taxi_orders', {
      customerId: user.uid,
      businessId,
    });

    requireValue(
      !activeOrders.some((order) =>
        ACTIVE_STATES.includes(order.data.status)),
      'active-taxi-order-exists',
      'لديك طلب تاكسي نشط بالفعل لدى هذا المكتب.',
      409,
    );

    const orderNumber =
      `#TK-${input.requestId.slice(-6).toUpperCase()}`;

    tx.set(`taxi_orders/${orderId}`, {
      orderId,
      orderNumber,
      orderType: 'taxi',
      businessId,
      businessName:
        String(business.title || business.name || 'تكسي بركة')
          .trim()
          .slice(0, 160),
      customerId: user.uid,
      customerName:
        customerName || String(actor.name || user.name || 'عميل بركة'),
      customerPhone:
        customerPhone || String(actor.phone || user.phone_number || ''),
      pickupAddress,
      pickupLatitude,
      pickupLongitude,
      destination,
      notes,
      status: 'pending',
      dispatchedVehicle: null,
      dispatchedEtaMinutes: null,

      // Financial fields are server-authoritative.
      // The final fare is recorded when the office ends the trip.
      fareAmount: null,
      commissionRate: null,
      commissionAmount: null,
      businessNet: null,
      commissionStatus: 'pending',
      commissionEarnedAt: null,

      createdAt: now,
      updatedAt: now,
      taxiOrderVersion: 2,
    });

    return {
      orderId,
      orderNumber,
      status: 'pending',
    };
  });
}

export async function updateTaxiOrder(
  store,
  user,
  orderId,
  input,
  { now = new Date(), primaryAdminUid } = {},
) {
  documentId(orderId);

  const action = String(input?.action || '').trim();

  requireValue(
    ['dispatch', 'complete', 'confirm', 'cancel'].includes(action),
    'invalid-taxi-action',
    'إجراء طلب التاكسي غير صالح.',
  );

  return store.runTransaction(async (tx) => {
    const record = await tx.get(`taxi_orders/${orderId}`);

    requireValue(
      !!record,
      'taxi-order-not-found',
      'طلب التاكسي غير موجود.',
      404,
    );

    const order = record.data;
    const businessId = documentId(order.businessId);

    requireValue(
      STATES.includes(order.status),
      'invalid-current-taxi-status',
      'حالة طلب التاكسي الحالية تحتاج مراجعة الإدارة.',
      409,
    );

    const actor =
      (await tx.get(`users/${documentId(user.uid)}`))?.data;
    const business =
      (await tx.get(`items/${businessId}`))?.data;

    requireValue(
      !!actor && !!business,
      'taxi-account-not-found',
      'تعذر التحقق من الحساب أو مكتب التاكسي.',
      404,
    );

    const admin = isAdmin(user, actor, primaryAdminUid);
    const merchant = ownsBusiness(user, actor, business);
    const customer = order.customerId === user.uid;

    if (action === 'dispatch') {
      requireValue(
        admin || merchant,
        'taxi-permission-denied',
        'غير مسموح بإرسال سيارة لهذا الطلب.',
        403,
      );

      requireValue(
        order.status === 'pending',
        'invalid-taxi-transition',
        'لا يمكن إرسال سيارة في حالة الطلب الحالية.',
        409,
      );

      const vehicleInfo = cleanText(
        input.vehicleInfo,
        'vehicle-info',
        160,
      );

      const etaMinutes =
        input.etaMinutes == null ? 5 : input.etaMinutes;

      requireValue(
        Number.isInteger(etaMinutes) &&
          etaMinutes >= 1 &&
          etaMinutes <= 240,
        'invalid-taxi-eta',
        'وقت الوصول المتوقع غير صالح.',
      );

      tx.set(
        `taxi_orders/${orderId}`,
        {
          status: 'dispatched',
          dispatchedVehicle: vehicleInfo,
          dispatchedEtaMinutes: etaMinutes,
          dispatchedAt: now,
          dispatchedBy: user.uid,
          updatedAt: now,
        },
        { merge: true },
      );

      return { orderId, status: 'dispatched' };
    }

    if (action === 'complete') {
      requireValue(
        admin || merchant,
        'taxi-permission-denied',
        'غير مسموح بإنهاء هذه الرحلة.',
        403,
      );

      requireValue(
        order.status === 'dispatched',
        'invalid-taxi-transition',
        'لا يمكن إنهاء الرحلة قبل إرسال السيارة.',
        409,
      );

      const finance = calculateTaxiFinance(
        business,
        input.fareAmount,
      );

      tx.set(
        `taxi_orders/${orderId}`,
        {
          status: 'awaiting_customer_confirmation',
          tripEndedAt: now,
          tripEndedBy: user.uid,
          fareAmount: finance.fareAmount,
          commissionRate: finance.commissionRate,
          commissionAmount: finance.commissionAmount,
          businessNet: finance.businessNet,
          commissionStatus: 'pending',
          updatedAt: now,
        },
        { merge: true },
      );

      return {
        orderId,
        status: 'awaiting_customer_confirmation',
        commissionStatus: 'pending',
      };
    }

    if (action === 'confirm') {
      requireValue(
        customer,
        'taxi-permission-denied',
        'تأكيد الوصول متاح للعميل صاحب الرحلة فقط.',
        403,
      );

      requireValue(
        order.status === 'awaiting_customer_confirmation',
        'invalid-taxi-transition',
        'الرحلة ليست بانتظار تأكيد العميل.',
        409,
      );

      requireValue(
        typeof order.commissionAmount === 'number' &&
          Number.isFinite(order.commissionAmount) &&
          order.commissionAmount >= 0,
        'invalid-taxi-finance',
        'بيانات العمولة تحتاج مراجعة الإدارة.',
        409,
      );

      const commissionEntryPath =
        `taxi_commission_entries/${orderId}`;

      const existingCommissionEntry =
        await tx.get(commissionEntryPath);

      requireValue(
        !existingCommissionEntry,
        'taxi-commission-already-recorded',
        'تم تسجيل عمولة هذه الرحلة مسبقًا.',
        409,
      );

      tx.set(
        commissionEntryPath,
        {
          entryId: orderId,
          orderId,
          orderNumber: order.orderNumber || null,
          source: 'taxi',
          businessId,
          customerId: order.customerId,
          fareAmount: order.fareAmount,
          commissionRate: order.commissionRate,
          commissionAmount: order.commissionAmount,
          businessNet: order.businessNet,
          status: 'earned',
          earnedAt: now,
          customerConfirmedAt: now,
          createdAt: now,
        },
      );

      tx.set(
        `taxi_orders/${orderId}`,
        {
          status: 'completed',
          completedAt: now,
          confirmedByCustomerAt: now,
          commissionStatus: 'earned',
          commissionEarnedAt: now,
          commissionEntryId: orderId,
          updatedAt: now,
        },
        { merge: true },
      );

      return {
        orderId,
        status: 'completed',
        commissionStatus: 'earned',
        commissionEntryId: orderId,
      };
    }

    // Cancellation:
    // customer can cancel only while waiting;
    // merchant/admin can cancel pending or dispatched trips.
    const canCancel =
      (customer && order.status === 'pending') ||
      ((admin || merchant) &&
        (order.status === 'pending' || order.status === 'dispatched'));

    requireValue(
      canCancel,
      'taxi-permission-denied',
      'غير مسموح بإلغاء هذا الطلب في حالته الحالية.',
      403,
    );

    tx.set(
      `taxi_orders/${orderId}`,
      {
        status: 'cancelled',
        cancelReason: optionalText(input.reason, 300) ||
          (customer ? 'إلغاء من قبل العميل' : 'إلغاء من قبل مكتب التاكسي'),
        cancelledAt: now,
        cancelledBy: user.uid,
        commissionStatus: 'cancelled',
        updatedAt: now,
      },
      { merge: true },
    );

    return { orderId, status: 'cancelled' };
  });
}
