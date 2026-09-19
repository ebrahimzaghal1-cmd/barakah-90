import { describe, expect, it } from "vitest";
import {
  createTaxiOrder,
  updateTaxiOrder,
} from "../src/security/taxi.js";

type RecordData = Record<string, any>;

function clone<T>(value: T): T {
  return structuredClone(value);
}

function memoryStore(initial: Record<string, RecordData>) {
  const docs = new Map<string, RecordData>(
    Object.entries(initial).map(([path, data]) => [path, clone(data)]),
  );

  const reader = {
    async get(path: string) {
      const data = docs.get(path);
      return data ? { id: path.split("/").pop(), data: clone(data) } : null;
    },

    async query(collection: string, equals: Record<string, any> = {}) {
      const prefix = `${collection}/`;

      return [...docs.entries()]
        .filter(([path]) => path.startsWith(prefix))
        .filter(([path]) => path.slice(prefix.length).indexOf("/") === -1)
        .filter(([, data]) =>
          Object.entries(equals).every(([key, value]) => data[key] === value),
        )
        .map(([path, data]) => ({
          id: path.split("/").pop(),
          data: clone(data),
        }));
    },
  };

  return {
    ...reader,

    async runTransaction(work: (tx: any) => Promise<any>) {
      const writes: Array<{
        path: string;
        data: RecordData;
        merge: boolean;
      }> = [];

      const tx = {
        ...reader,

        set(
          path: string,
          data: RecordData,
          { merge = false }: { merge?: boolean } = {},
        ) {
          writes.push({
            path,
            data: clone(data),
            merge,
          });
        },

        delete(path: string) {
          docs.delete(path);
        },
      };

      const result = await work(tx);

      for (const write of writes) {
        if (write.merge) {
          docs.set(write.path, {
            ...(docs.get(write.path) || {}),
            ...clone(write.data),
          });
        } else {
          docs.set(write.path, clone(write.data));
        }
      }

      return result;
    },

    read(path: string) {
      const data = docs.get(path);
      return data ? clone(data) : null;
    },
  };
}

const businessId = "taxiOffice001";
const customerId = "customer001";
const merchantId = "merchant001";
const otherMerchantId = "merchant002";
const otherCustomerId = "customer002";
const driverId = "driver001";
const otherDriverId = "driver002";
const adminId = "admin001";

function baseStore(commissionRate = 10) {
  return memoryStore({
    [`items/${businessId}`]: {
      title: "تكسي بركة للاختبار",
      type: "taxi",
      isActive: true,
      businessStatus: "open",
      ownerId: merchantId,
      managerIds: [],
      commissionRate,
    },

    [`users/${customerId}`]: {
      role: "customer",
      name: "عميل الاختبار",
      phone: "0590000000",
    },

    [`users/${otherCustomerId}`]: {
      role: "customer",
      name: "عميل آخر",
    },

    [`users/${merchantId}`]: {
      role: "merchant",
      merchantEnabled: true,
    },

    [`users/${otherMerchantId}`]: {
      role: "merchant",
      merchantEnabled: true,
    },

    [`users/${driverId}`]: {
      role: "driver",
      name: "سائق الاختبار",
      taxiDriverEnabled: true,
      taxiBusinessId: businessId,
    },

    [`users/${otherDriverId}`]: {
      role: "driver",
      name: "سائق آخر",
      taxiDriverEnabled: true,
      taxiBusinessId: businessId,
    },

    [`users/${adminId}`]: {
      role: "admin",
    },
  });
}

async function createAndDispatch(store: ReturnType<typeof baseStore>) {
  const created = await createTaxiOrder(
    store as any,
    { uid: customerId },
    {
      requestId: "request001",
      businessId,
      pickupAddress: "طولكرم - المركز",
      destination: "ذنابة",
      notes: "",
    },
  );

  await updateTaxiOrder(
    store as any,
    { uid: merchantId },
    created.orderId,
    {
      action: "dispatch",
      driverUid: driverId,
      vehicleInfo: "سيارة اختبار",
      etaMinutes: 5,
    },
  );

  return created.orderId;
}

describe("Barakah taxi security and finance", () => {
  it("creates taxi orders without trusting client financial fields", async () => {
    const store = baseStore();

    const created = await createTaxiOrder(
      store as any,
      { uid: customerId },
      {
        requestId: "request001",
        businessId,
        pickupAddress: "طولكرم - المركز",
        destination: "ذنابة",
        commissionAmount: 9999,
        commissionRate: 0,
        fareAmount: 1,
      },
    );

    const order = store.read(`taxi_orders/${created.orderId}`);

    expect(order.status).toBe("pending");
    expect(order.fareAmount).toBeNull();
    expect(order.commissionRate).toBeNull();
    expect(order.commissionAmount).toBeNull();
    expect(order.businessNet).toBeNull();
    expect(order.commissionStatus).toBe("pending");
  });

  it("rejects dispatch by another merchant", async () => {
    const store = baseStore();

    const created = await createTaxiOrder(
      store as any,
      { uid: customerId },
      {
        requestId: "request001",
        businessId,
        pickupAddress: "طولكرم",
        destination: "ذنابة",
      },
    );

    await expect(
      updateTaxiOrder(
        store as any,
        { uid: otherMerchantId },
        created.orderId,
        {
          action: "dispatch",
          vehicleInfo: "سيارة غير مصرح بها",
          etaMinutes: 5,
        },
      ),
    ).rejects.toMatchObject({
      code: "taxi-permission-denied",
      status: 403,
    });
  });

  it("calculates 10 percent server-side and keeps it pending until customer confirmation", async () => {
    const store = baseStore(10);
    const orderId = await createAndDispatch(store);

    const completedByOffice = await updateTaxiOrder(
      store as any,
      { uid: merchantId },
      orderId,
      {
        action: "complete",
        fareAmount: 50,
        commissionAmount: 999,
      },
    );

    expect(completedByOffice).toMatchObject({
      status: "awaiting_customer_confirmation",
      commissionStatus: "pending",
    });

    const order = store.read(`taxi_orders/${orderId}`);

    expect(order.fareAmount).toBe(50);
    expect(order.commissionRate).toBe(10);
    expect(order.commissionAmount).toBe(5);
    expect(order.businessNet).toBe(45);
    expect(order.commissionStatus).toBe("pending");
    expect(order.commissionEarnedAt).toBeNull();
  });

  it("uses the commission rate configured for that taxi office", async () => {
    const store = baseStore(12.5);
    const orderId = await createAndDispatch(store);

    await updateTaxiOrder(
      store as any,
      { uid: merchantId },
      orderId,
      {
        action: "complete",
        fareAmount: 80,
      },
    );

    const order = store.read(`taxi_orders/${orderId}`);

    expect(order.fareAmount).toBe(80);
    expect(order.commissionRate).toBe(12.5);
    expect(order.commissionAmount).toBe(10);
    expect(order.businessNet).toBe(70);
  });

  it("does not allow the office to confirm arrival for the customer", async () => {
    const store = baseStore();
    const orderId = await createAndDispatch(store);

    await updateTaxiOrder(
      store as any,
      { uid: merchantId },
      orderId,
      {
        action: "complete",
        fareAmount: 50,
      },
    );

    await expect(
      updateTaxiOrder(
        store as any,
        { uid: merchantId },
        orderId,
        { action: "confirm" },
      ),
    ).rejects.toMatchObject({
      code: "taxi-permission-denied",
      status: 403,
    });
  });

  it("does not allow another customer to confirm the trip", async () => {
    const store = baseStore();
    const orderId = await createAndDispatch(store);

    await updateTaxiOrder(
      store as any,
      { uid: merchantId },
      orderId,
      {
        action: "complete",
        fareAmount: 50,
      },
    );

    await expect(
      updateTaxiOrder(
        store as any,
        { uid: otherCustomerId },
        orderId,
        { action: "confirm" },
      ),
    ).rejects.toMatchObject({
      code: "taxi-permission-denied",
      status: 403,
    });
  });

  it("earns commission only after the trip customer confirms arrival", async () => {
    const store = baseStore(10);
    const orderId = await createAndDispatch(store);

    await updateTaxiOrder(
      store as any,
      { uid: merchantId },
      orderId,
      {
        action: "complete",
        fareAmount: 50,
      },
    );

    const result = await updateTaxiOrder(
      store as any,
      { uid: customerId },
      orderId,
      { action: "confirm" },
    );

    expect(result).toMatchObject({
      status: "completed",
      commissionStatus: "earned",
    });

    const order = store.read(`taxi_orders/${orderId}`);

    expect(order.status).toBe("completed");
    expect(order.fareAmount).toBe(50);
    expect(order.commissionRate).toBe(10);
    expect(order.commissionAmount).toBe(5);
    expect(order.businessNet).toBe(45);
    expect(order.commissionStatus).toBe("earned");
    expect(order.commissionEarnedAt).toBeTruthy();
    expect(order.confirmedByCustomerAt).toBeTruthy();
    expect(order.commissionEntryId).toBe(orderId);

    const entry = store.read(
      `taxi_commission_entries/${orderId}`,
    );

    expect(entry).toBeTruthy();
    expect(entry.orderId).toBe(orderId);
    expect(entry.businessId).toBe(businessId);
    expect(entry.customerId).toBe(customerId);
    expect(entry.source).toBe("taxi");
    expect(entry.fareAmount).toBe(50);
    expect(entry.commissionRate).toBe(10);
    expect(entry.commissionAmount).toBe(5);
    expect(entry.businessNet).toBe(45);
    expect(entry.status).toBe("earned");
    expect(entry.earnedAt).toBeTruthy();
    expect(entry.customerConfirmedAt).toBeTruthy();
  });

  it("rejects an invalid or missing final fare", async () => {
    const store = baseStore();
    const orderId = await createAndDispatch(store);

    await expect(
      updateTaxiOrder(
        store as any,
        { uid: merchantId },
        orderId,
        {
          action: "complete",
        },
      ),
    ).rejects.toMatchObject({
      code: "invalid-taxi-fare",
    });
  });
});

describe("taxi financial cancellation protection", () => {
  it("does not allow the taxi office to cancel after submitting the fare", async () => {
    const store = baseStore(10);
    const orderId = await createAndDispatch(store);

    await updateTaxiOrder(
      store as any,
      { uid: merchantId },
      orderId,
      {
        action: "complete",
        fareAmount: 50,
      },
    );

    const beforeCancel = store.read(`taxi_orders/${orderId}`);

    expect(beforeCancel.status).toBe(
      "awaiting_customer_confirmation",
    );
    expect(beforeCancel.fareAmount).toBe(50);
    expect(beforeCancel.commissionRate).toBe(10);
    expect(beforeCancel.commissionAmount).toBe(5);
    expect(beforeCancel.commissionStatus).toBe("pending");

    await expect(
      updateTaxiOrder(
        store as any,
        { uid: merchantId },
        orderId,
        {
          action: "cancel",
          reason: "محاولة إلغاء بعد تسجيل الأجرة",
        },
      ),
    ).rejects.toMatchObject({
      code: "taxi-permission-denied",
    });

    const afterCancelAttempt = store.read(
      `taxi_orders/${orderId}`,
    );

    expect(afterCancelAttempt.status).toBe(
      "awaiting_customer_confirmation",
    );
    expect(afterCancelAttempt.fareAmount).toBe(50);
    expect(afterCancelAttempt.commissionAmount).toBe(5);
    expect(afterCancelAttempt.commissionStatus).toBe("pending");
  });
});

describe("taxi live driver location", () => {
  const startedAt = new Date("2026-09-19T10:00:00.000Z");
  const updatedAt = new Date("2026-09-19T10:00:15.000Z");
  const position = { latitude: 32.31, longitude: 35.03 };

  async function startTrip(store: ReturnType<typeof baseStore>) {
    const orderId = await createAndDispatch(store);
    await updateTaxiOrder(
      store as any,
      { uid: driverId },
      orderId,
      { action: "start_trip" },
      { now: startedAt },
    );
    return orderId;
  }

  async function mergeRecord(
    store: ReturnType<typeof baseStore>,
    path: string,
    data: RecordData,
  ) {
    await store.runTransaction(async (tx) => {
      tx.set(path, data, { merge: true });
    });
  }

  it("starts an assigned trip with server time and ignores injected fields", async () => {
    const store = baseStore();
    const orderId = await createAndDispatch(store);
    const before = store.read(`taxi_orders/${orderId}`);

    await updateTaxiOrder(
      store as any,
      { uid: driverId },
      orderId,
      {
        action: "start_trip",
        tripStartedAt: "1999-01-01T00:00:00Z",
        tripStartedBy: adminId,
        updatedAt: "1999-01-01T00:00:00Z",
        driverUid: otherDriverId,
        driverLatitude: 89,
        driverLongitude: 179,
        status: "completed",
        businessName: "اسم المكتب الداخلي",
        businessId: "anotherOffice",
        fareAmount: 1,
        commissionRate: 0,
        commissionAmount: 0,
        commissionStatus: "earned",
      },
      { now: startedAt },
    );

    expect(store.read(`taxi_orders/${orderId}`)).toEqual({
      ...before,
      tripStartedAt: startedAt,
      tripStartedBy: driverId,
      updatedAt: startedAt,
    });
    expect(store.read(`taxi_orders/${orderId}`).businessName).toBe("تكسي بركة");
    expect(store.read(`taxi_commission_entries/${orderId}`)).toBeNull();
  });

  it("keeps the first trip start and location intact when start is retried", async () => {
    const store = baseStore();
    const orderId = await startTrip(store);
    await updateTaxiOrder(
      store as any,
      { uid: driverId },
      orderId,
      { action: "update_location", ...position },
      { now: updatedAt },
    );
    const before = store.read(`taxi_orders/${orderId}`);

    await updateTaxiOrder(
      store as any,
      { uid: driverId },
      orderId,
      { action: "start_trip" },
      { now: new Date("2026-09-19T10:01:00.000Z") },
    );

    expect(store.read(`taxi_orders/${orderId}`)).toEqual(before);
  });

  it("stores map-ready coordinates and server update time without changing other fields", async () => {
    const store = baseStore();
    const orderId = await startTrip(store);
    const before = store.read(`taxi_orders/${orderId}`);

    await updateTaxiOrder(
      store as any,
      { uid: driverId },
      orderId,
      {
        action: "update_location",
        ...position,
        tripStartedAt: "1999-01-01T00:00:00Z",
        driverLocationUpdatedAt: "1999-01-01T00:00:00Z",
        updatedAt: "1999-01-01T00:00:00Z",
        driverUid: otherDriverId,
        status: "completed",
        businessName: "اسم المكتب الداخلي",
        fareAmount: 10000,
        commissionAmount: 10000,
        commissionRate: 100,
        businessNet: 0,
        commissionStatus: "earned",
      },
      { now: updatedAt },
    );

    expect(store.read(`taxi_orders/${orderId}`)).toEqual({
      ...before,
      driverLatitude: position.latitude,
      driverLongitude: position.longitude,
      driverLocationUpdatedAt: updatedAt,
      updatedAt,
    });
    expect(store.read(`taxi_commission_entries/${orderId}`)).toBeNull();
  });

  for (const action of ["start_trip", "update_location"]) {
    it.each([
      ["customer", customerId],
      ["other customer", otherCustomerId],
      ["owning merchant", merchantId],
      ["primary admin", adminId],
      ["unassigned driver in the same office", otherDriverId],
    ])(`rejects ${action} from %s even with the assigned driver UID in input`, async (_, uid) => {
      const store = baseStore();
      const orderId = await startTrip(store);
      const before = store.read(`taxi_orders/${orderId}`);

      await expect(
        updateTaxiOrder(
          store as any,
          { uid },
          orderId,
          { action, ...position, driverUid: driverId },
          { primaryAdminUid: adminId },
        ),
      ).rejects.toMatchObject({ code: "taxi-permission-denied", status: 403 });

      expect(store.read(`taxi_orders/${orderId}`)).toEqual(before);
    });

    it.each([
      ["disabled", { taxiDriverEnabled: false }],
      ["non-boolean enabled", { taxiDriverEnabled: "true" }],
      ["moved to another office", { taxiBusinessId: "otherOffice" }],
      ["removed from an office", { taxiBusinessId: null }],
      ["role changed", { role: "merchant" }],
    ])(`rechecks driver authorization for ${action} when %s`, async (_, patch) => {
      const store = baseStore();
      const orderId = await startTrip(store);
      await mergeRecord(store, `users/${driverId}`, patch as RecordData);
      const before = store.read(`taxi_orders/${orderId}`);

      await expect(
        updateTaxiOrder(
          store as any,
          { uid: driverId },
          orderId,
          { action, ...position },
        ),
      ).rejects.toMatchObject({ code: "taxi-permission-denied", status: 403 });

      expect(store.read(`taxi_orders/${orderId}`)).toEqual(before);
    });

    it.each(["pending", "awaiting_customer_confirmation", "completed", "cancelled"])(
      `rejects ${action} while order is %s`,
      async (status) => {
        const store = baseStore();
        const orderId = await startTrip(store);
        await mergeRecord(store, `taxi_orders/${orderId}`, { status });
        const before = store.read(`taxi_orders/${orderId}`);

        await expect(
          updateTaxiOrder(
            store as any,
            { uid: driverId },
            orderId,
            { action, ...position },
          ),
        ).rejects.toMatchObject({ code: "invalid-taxi-transition", status: 409 });

        expect(store.read(`taxi_orders/${orderId}`)).toEqual(before);
      },
    );
  }

  it("rejects location updates before the assigned driver starts the trip", async () => {
    const store = baseStore();
    const orderId = await createAndDispatch(store);
    const before = store.read(`taxi_orders/${orderId}`);

    await expect(
      updateTaxiOrder(
        store as any,
        { uid: driverId },
        orderId,
        { action: "update_location", ...position },
      ),
    ).rejects.toMatchObject({ code: "taxi-trip-not-started", status: 409 });

    expect(store.read(`taxi_orders/${orderId}`)).toEqual(before);
  });

  it.each(["2026-09-19T10:00:00Z", 12345, new Date(NaN)])(
    "rejects a corrupted start timestamp (%s)",
    async (tripStartedAt) => {
      const store = baseStore();
      const orderId = await createAndDispatch(store);
      await mergeRecord(store, `taxi_orders/${orderId}`, { tripStartedAt });
      const before = store.read(`taxi_orders/${orderId}`);

      await expect(
        updateTaxiOrder(
          store as any,
          { uid: driverId },
          orderId,
          { action: "update_location", ...position },
        ),
      ).rejects.toMatchObject({ code: "taxi-trip-not-started", status: 409 });

      await expect(
        updateTaxiOrder(
          store as any,
          { uid: driverId },
          orderId,
          { action: "start_trip" },
        ),
      ).rejects.toMatchObject({ code: "invalid-taxi-transition", status: 409 });

      expect(store.read(`taxi_orders/${orderId}`)).toEqual(before);
    },
  );

  for (const coordinate of ["latitude", "longitude"]) {
    const limit = coordinate === "latitude" ? 90 : 180;

    it.each([
      ["above maximum", limit + 0.00001],
      ["below minimum", -limit - 0.00001],
      ["numeric string", "32.31"],
      ["null", null],
      ["missing", undefined],
      ["boolean", true],
      ["array", [32.31]],
      ["NaN", NaN],
      ["positive infinity", Infinity],
      ["negative infinity", -Infinity],
    ])(`rejects ${coordinate} that is %s`, async (_, value) => {
      const store = baseStore();
      const orderId = await startTrip(store);
      const before = store.read(`taxi_orders/${orderId}`);

      await expect(
        updateTaxiOrder(
          store as any,
          { uid: driverId },
          orderId,
          { action: "update_location", ...position, [coordinate]: value },
        ),
      ).rejects.toMatchObject({ code: "invalid-driver-location", status: 400 });

      expect(store.read(`taxi_orders/${orderId}`)).toEqual(before);
    });
  }

  it.each([
    { latitude: -90, longitude: -180 },
    { latitude: 90, longitude: 180 },
    { latitude: 0, longitude: 0 },
  ])("accepts inclusive coordinate bounds and zero ($latitude, $longitude)", async (coordinates) => {
    const store = baseStore();
    const orderId = await startTrip(store);

    await updateTaxiOrder(
      store as any,
      { uid: driverId },
      orderId,
      { action: "update_location", ...coordinates },
      { now: updatedAt },
    );

    expect(store.read(`taxi_orders/${orderId}`)).toMatchObject({
      driverLatitude: coordinates.latitude,
      driverLongitude: coordinates.longitude,
      driverLocationUpdatedAt: updatedAt,
    });
  });

  it.each(["complete", "cancel"])(
    "rejects further GPS after the office applies %s and preserves finances",
    async (action) => {
      const store = baseStore(12.5);
      const orderId = await startTrip(store);
      await updateTaxiOrder(
        store as any,
        { uid: driverId },
        orderId,
        { action: "update_location", ...position },
        { now: updatedAt },
      );
      await updateTaxiOrder(
        store as any,
        { uid: merchantId },
        orderId,
        { action, fareAmount: 80 },
      );
      const before = store.read(`taxi_orders/${orderId}`);

      await expect(
        updateTaxiOrder(
          store as any,
          { uid: driverId },
          orderId,
          { action: "update_location", latitude: 0, longitude: 0 },
        ),
      ).rejects.toMatchObject({ code: "invalid-taxi-transition", status: 409 });

      expect(store.read(`taxi_orders/${orderId}`)).toEqual(before);
      if (action === "complete") {
        expect(before).toMatchObject({
          status: "awaiting_customer_confirmation",
          fareAmount: 80,
          commissionRate: 12.5,
          commissionAmount: 10,
          businessNet: 70,
          commissionStatus: "pending",
        });
        await updateTaxiOrder(
          store as any,
          { uid: customerId },
          orderId,
          { action: "confirm" },
        );
        expect(store.read(`taxi_commission_entries/${orderId}`)).toMatchObject({
          fareAmount: 80,
          commissionAmount: 10,
          businessNet: 70,
          status: "earned",
        });
      } else {
        expect(before).toMatchObject({
          status: "cancelled",
          fareAmount: null,
          commissionAmount: null,
          commissionStatus: "cancelled",
        });
        expect(store.read(`taxi_commission_entries/${orderId}`)).toBeNull();
      }
    },
  );
});
