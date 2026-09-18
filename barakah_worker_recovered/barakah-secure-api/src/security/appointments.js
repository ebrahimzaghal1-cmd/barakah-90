import { documentId, requireValue } from './store.js';
const states = ['pending', 'confirmed', 'completed', 'cancelled', 'no_show'];
const overlap = (a, b) => a.startMinutes < b.endMinutes && b.startMinutes < a.endMinutes;
function owns(user, actor, business) {
  return actor?.role === 'merchant' && (business.ownerId === user.uid || (Array.isArray(business.managerIds) && business.managerIds.includes(user.uid)));
}
function clockMinutes(value, fallback) {
  if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) return fallback;
  const [h, m] = value.split(':').map(Number); return h * 60 + m;
}
function selectedService(business, serviceId) {
  if (business.type === 'doctor') {
    requireValue(serviceId === 'consultation', 'invalid-service', 'الخدمة غير متاحة.');
    return { title: 'استشارة طبية', price: business.consultationFee ?? business.doctorConsultationFee ?? 0, durationMinutes: business.appointmentSlotMinutes ?? 30 };
  }
  const listed = Array.isArray(business.barberServices) ? business.barberServices.filter(s => s && typeof s === 'object' && s.title != null) : [];
  const services = listed.length ? listed : [{ title: 'حلاقة', price: business.bookingPrice ?? 30, durationMinutes: business.appointmentSlotMinutes ?? 30 }];
  const match = /^service_([1-9]\d*)$/.exec(serviceId || '');
  const selected = match && services[Number(match[1]) - 1];
  requireValue(!!selected, 'invalid-service', 'الخدمة غير متاحة.');
  return { ...selected, durationMinutes: selected.durationMinutes ?? 30 };
}
function appointmentWindow(business, input, now) {
  const service = selectedService(business, input.serviceId);
  requireValue(typeof service.price === 'number' && Number.isFinite(service.price) && service.price >= 0 && service.price <= 1e6,
    'invalid-catalog-price', 'سعر الخدمة غير صالح؛ يرجى التواصل مع المتجر.');
  const duration = service.durationMinutes;
  requireValue(Number.isInteger(duration) && duration > 0 && duration <= 1440, 'invalid-duration', 'مدة الخدمة غير صالحة.');
  const start = new Date(input.scheduledAt);
  requireValue(typeof input.scheduledAt === 'string' && /Z$/.test(input.scheduledAt) && Number.isFinite(start.getTime()) && start > now && start - now <= 366 * 86400000,
    'invalid-appointment-time', 'وقت الحجز غير صالح.');
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-CA', { timeZone: business.timeZone || 'Asia/Hebron', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(start).map(p => [p.type, p.value]));
  const dateKey = `${parts.year}-${parts.month}-${parts.day}`;
  const startMinutes = Number(parts.hour) * 60 + Number(parts.minute);
  requireValue(input.dateKey === dateKey && input.startMinutes === startMinutes && start.getUTCSeconds() === 0 && start.getUTCMilliseconds() === 0,
    'appointment-timezone-mismatch', 'وقت الحجز لا يطابق توقيت المتجر.');
  const opening = clockMinutes(business.openingTime, 540), closing = clockMinutes(business.closingTime, 1260);
  const step = business.appointmentSlotMinutes ?? duration;
  requireValue(Number.isInteger(step) && step > 0 && startMinutes >= opening && startMinutes + duration <= closing && (startMinutes - opening) % step === 0,
    'outside-business-hours', 'الوقت خارج المواعيد المتاحة.');
  return { dateKey, startMinutes, endMinutes: startMinutes + duration, scheduledAt: start, service };
}
export async function createAppointment(store, user, input, { now = new Date(), primaryAdminUid } = {}) {
  const businessId = documentId(input.businessId);
  requireValue(/^[A-Za-z0-9_-]{8,80}$/.test(input.requestId || ''), 'invalid-request-id', 'معرّف الطلب غير صالح.');
  const bookingId = `${documentId(user.uid)}_${input.requestId}`;
  for (const field of ['customerName', 'customerPhone']) requireValue(typeof input[field] === 'string' && input[field].trim().length > 0 && input[field].length <= 160, 'invalid-customer-details', 'أدخل الاسم ورقم الهاتف.');
  return store.runTransaction(async tx => {
    const existing = await tx.get(`barber_bookings/${bookingId}`);
    if (existing) {
      requireValue(existing.data.customerId === user.uid && existing.data.businessId === businessId && existing.data.serviceId === input.serviceId && existing.data.dateKey === input.dateKey && existing.data.startMinutes === input.startMinutes,
        'request-id-reused', 'أُعيد استخدام معرّف الطلب لحجز مختلف.', 409);
      return { bookingId, status: existing.data.status };
    }
    const business = (await tx.get(`items/${businessId}`))?.data;
    const actor = (await tx.get(`users/${documentId(user.uid)}`))?.data;
    requireValue(!!business && !!actor, 'business-not-found', 'النشاط أو الحساب غير موجود.', 404);
    requireValue(['barber', 'doctor'].includes(business.type) && business.kind !== 'product' && business.appointmentBookingEnabled !== false && business.isActive !== false && business.status !== 'closed' && business.status !== 'coming_soon', 'booking-unavailable', 'الحجز غير متاح لهذا النشاط.');
    requireValue(!owns(user, actor, business), 'self-booking', 'لا يمكن حجز موعد لدى نشاطك.');
    const window = appointmentWindow(business, input, now);
    const dayPath = `barber_booking_days/${businessId}_${window.dateKey}`;
    // Every create/cancel/reopen reads and updates the same daily guard.
    await tx.get(dayPath);
    const bookings = await tx.query('barber_bookings', { businessId, dateKey: window.dateKey });
    const locks = await tx.query('barber_slot_locks', { businessId, dateKey: window.dateKey });
    requireValue(!bookings.some(b => b.data.status !== 'cancelled' && overlap(window, b.data)) &&
      !locks.some(l => l.data.status === 'reserved' && overlap(window, l.data)), 'slot-unavailable', 'هذا الوقت محجوز؛ اختر وقتًا آخر.', 409);
    const lockId = `${businessId}_${window.dateKey}_${window.startMinutes}`;
    const price = Number(window.service.price.toFixed(2));
    requireValue(input.expectedPrice == null || input.expectedPrice === price, 'service-price-changed', 'تغير سعر الخدمة؛ حدّث الصفحة قبل الحجز.', 409);
    const commissionAmount = Number((price * 0.1).toFixed(2));
    tx.set(dayPath, { updatedAt: now, revision: crypto.randomUUID() });
    tx.set(`barber_slot_locks/${lockId}`, { businessId, dateKey: window.dateKey, startMinutes: window.startMinutes, endMinutes: window.endMinutes, bookingId, status: 'reserved', createdAt: now });
    tx.set(`barber_bookings/${bookingId}`, { businessId, serviceId: input.serviceId, serviceTitle: String(window.service.title), customerId: user.uid,
      customerName: input.customerName.trim(), customerPhone: input.customerPhone.trim(), dateKey: window.dateKey, startMinutes: window.startMinutes, endMinutes: window.endMinutes,
      scheduledAt: window.scheduledAt, price, commissionRate: 10, commissionAmount, businessNetAmount: Number((price - commissionAmount).toFixed(2)),
      lockId, status: 'pending', orderType: 'barber_booking', createdAt: now, updatedAt: now, bookingVersion: 2 });
    return { bookingId, status: 'pending' };
  });
}
export async function updateAppointment(store, user, bookingId, status, { now = new Date(), primaryAdminUid } = {}) {
  documentId(bookingId);
  requireValue(states.includes(status), 'invalid-booking-status', 'حالة الحجز غير صالحة.');
  return store.runTransaction(async tx => {
    const booking = (await tx.get(`barber_bookings/${bookingId}`))?.data;
    requireValue(!!booking, 'booking-not-found', 'الحجز غير موجود.', 404);
    const businessId = documentId(booking.businessId);
    const actor = (await tx.get(`users/${documentId(user.uid)}`))?.data;
    const business = (await tx.get(`items/${businessId}`))?.data;
    const admin = user.uid === primaryAdminUid && actor?.role === 'admin';
    const merchant = !!business && owns(user, actor, business);
    requireValue(admin || merchant || (booking.customerId === user.uid && status === 'cancelled' && ['pending', 'confirmed', 'cancelled'].includes(booking.status)), 'booking-permission-denied', 'غير مسموح بتعديل هذا الحجز.', 403);
    if (booking.status === status) return { bookingId, status };
    requireValue(/^\d{4}-\d{2}-\d{2}$/.test(booking.dateKey) && Number.isInteger(booking.startMinutes) && Number.isInteger(booking.endMinutes), 'legacy-booking-needs-review', 'بيانات الموعد القديم تحتاج مراجعة الإدارة.', 409);
    const dayPath = `barber_booking_days/${businessId}_${booking.dateKey}`;
    await tx.get(dayPath);
    const lockId = `${businessId}_${booking.dateKey}_${booking.startMinutes}`;
    const lock = (await tx.get(`barber_slot_locks/${lockId}`))?.data;
    const bookings = await tx.query('barber_bookings', { businessId, dateKey: booking.dateKey });
    const locks = await tx.query('barber_slot_locks', { businessId, dateKey: booking.dateKey });
    // A legacy lock can be adopted only when exactly one active legacy booking fits.
    const legacyMatches = bookings.filter(b => b.data.status !== 'cancelled' && b.data.startMinutes === booking.startMinutes && b.data.endMinutes === booking.endMinutes);
    const belongs = lock?.bookingId === bookingId || (lock && !lock.bookingId && lock.endMinutes === booking.endMinutes && legacyMatches.length === 1 && legacyMatches[0].id === bookingId);
    if (status !== 'cancelled') {
      requireValue(!bookings.some(b => b.id !== bookingId && b.data.status !== 'cancelled' && overlap(booking, b.data)) &&
        !locks.some(l => l.data.status === 'reserved' && !(l.id === lockId && belongs) && overlap(booking, l.data)), 'slot-unavailable', 'الموعد يتداخل مع حجز آخر.', 409);
    }
    tx.set(dayPath, { updatedAt: now, revision: crypto.randomUUID() });
    tx.set(`barber_bookings/${bookingId}`, { status, updatedAt: now }, { merge: true });
    if (status !== 'cancelled' || belongs) tx.set(`barber_slot_locks/${lockId}`, { businessId, dateKey: booking.dateKey, startMinutes: booking.startMinutes, endMinutes: booking.endMinutes,
      bookingId, status: status === 'cancelled' ? 'cancelled' : 'reserved', createdAt: lock?.createdAt || now });
    return { bookingId, status };
  });
}
