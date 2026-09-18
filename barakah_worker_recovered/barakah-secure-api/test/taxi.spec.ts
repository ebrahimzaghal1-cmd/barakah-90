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
