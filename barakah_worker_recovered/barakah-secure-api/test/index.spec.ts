import { describe, it, expect } from "vitest";
import worker, {
	canUploadMedia,
	canTransitionOrderStatus,
	createImageKitSignature,
} from "../src/index.js";

describe("Barakah secure API", () => {
	it("reports service health", async () => {
		const response = await worker.fetch(
			new Request("http://example.com/health"),
			{},
		);

		expect(response.status).toBe(200);
		expect(await response.json()).toEqual({
			ok: true,
			service: "barakah-secure-api",
		});
	});

	it("rejects upload authorization without a Firebase session", async () => {
		const response = await worker.fetch(
			new Request("http://example.com/v1/media/upload-auth", {
				method: "POST",
			}),
			{},
		);

		expect(response.status).toBe(401);
		expect(await response.json()).toMatchObject({
			error: "unauthenticated",
		});
	});

	it("allows every registered app role needed by media features", () => {
		expect(canUploadMedia({ role: "customer" })).toBe(true);
		expect(canUploadMedia({ role: "merchant", merchantEnabled: true })).toBe(true);
		expect(canUploadMedia({ role: "admin" })).toBe(true);
		expect(canUploadMedia({ role: "driver" })).toBe(true);
		expect(canUploadMedia(null)).toBe(false);
		expect(canUploadMedia({})).toBe(false);
	});

	it("generates the HMAC-SHA1 signature required by ImageKit", async () => {
		const signature = await createImageKitSignature(
			"private-key",
			"upload-token",
			1893456000,
		);

		expect(signature).toBe("261aae1a788cf629dacfc179cbfd35d2200daaf2");
	});

	it("allows a merchant to complete a prepared pickup order only", () => {
		expect(
			canTransitionOrderStatus("ready", "delivered", {
				isPickupMerchant: true,
				isPickupOrder: true,
			}),
		).toBe(true);
		expect(
			canTransitionOrderStatus("ready", "delivered", {
				isPickupMerchant: true,
				isPickupOrder: false,
			}),
		).toBe(false);
		expect(
			canTransitionOrderStatus("preparing", "delivered", {
				isPickupMerchant: true,
				isPickupOrder: true,
			}),
		).toBe(false);
	});

	it("keeps delivery orders on the driver path", () => {
		expect(
			canTransitionOrderStatus("driver_assigned", "picked_up"),
		).toBe(true);
		expect(
			canTransitionOrderStatus("ready", "delivered", { isAdmin: true }),
		).toBe(false);
	});
});
