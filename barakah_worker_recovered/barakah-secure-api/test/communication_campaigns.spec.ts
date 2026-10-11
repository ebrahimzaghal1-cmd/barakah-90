import { describe, expect, it } from "vitest";

import {
  communicationAudienceMatches,
  communicationCampaignProgress,
  normalizeCommunicationCampaignInput,
  createCommunicationCampaign,
  processCommunicationCampaign,
} from "../src/index.js";

describe("Barakah communication campaigns", () => {
  it("exports the secure server handlers", () => {
    expect(typeof createCommunicationCampaign).toBe("function");
    expect(typeof processCommunicationCampaign).toBe("function");
  });

  it("accepts valid campaign input", () => {
    const result = normalizeCommunicationCampaignInput({
      title: "أهلًا بكم في بركة",
      body: "رسالة اختبار",
      audience: "all",
      type: "message",
    });

    expect(result.title).toBe("أهلًا بكم في بركة");
    expect(result.body).toBe("رسالة اختبار");
    expect(result.audience).toBe("all");
    expect(result.type).toBe("message");
  });

  it("rejects unsupported audiences", () => {
    expect(() =>
      normalizeCommunicationCampaignInput({
        title: "اختبار",
        body: "رسالة",
        audience: "unknown_group",
        type: "message",
      }),
    ).toThrow();
  });

  it("rejects unsupported campaign types", () => {
    expect(() =>
      normalizeCommunicationCampaignInput({
        title: "اختبار",
        body: "رسالة",
        audience: "all",
        type: "dangerous_type",
      }),
    ).toThrow();
  });

  it("keeps normal customers separate from agents", () => {
    expect(
      communicationAudienceMatches(
        {
          id: "customer1",
          role: "customer",
          agentNumber: "",
        },
        "customers",
      ),
    ).toBe(true);

    expect(
      communicationAudienceMatches(
        {
          id: "agent1",
          role: "customer",
          agentNumber: "A-001",
        },
        "customers",
      ),
    ).toBe(false);
  });

  it("targets only the primary admin for admin test campaigns", () => {
    expect(
      communicationAudienceMatches(
        {
          id: "Y3YeLin9gYTbqN4if72o3iTrUSn2",
          role: "admin",
        },
        "admin_only",
      ),
    ).toBe(true);

    expect(
      communicationAudienceMatches(
        {
          id: "anotherAdmin",
          role: "admin",
        },
        "admin_only",
      ),
    ).toBe(false);
  });

  it("targets merchants correctly", () => {
    expect(
      communicationAudienceMatches(
        {
          id: "merchant1",
          role: "merchant",
        },
        "merchants",
      ),
    ).toBe(true);
  });

  it("keeps delivery drivers separate from taxi drivers", () => {
    expect(
      communicationAudienceMatches(
        {
          id: "driver1",
          role: "driver",
          taxiDriverEnabled: false,
        },
        "delivery_drivers",
      ),
    ).toBe(true);

    expect(
      communicationAudienceMatches(
        {
          id: "taxi1",
          role: "customer",
          taxiDriverEnabled: true,
          taxiBusinessId: "office1",
        },
        "taxi_drivers",
      ),
    ).toBe(true);

    expect(
      communicationAudienceMatches(
        {
          id: "taxi1",
          role: "driver",
          taxiDriverEnabled: true,
        },
        "delivery_drivers",
      ),
    ).toBe(false);
  });

  it("requires active customer-service status", () => {
    expect(
      communicationAudienceMatches(
        {
          id: "support1",
          role: "customer_service",
          customerServiceEnabled: true,
        },
        "customer_service",
      ),
    ).toBe(true);

    expect(
      communicationAudienceMatches(
        {
          id: "support2",
          role: "customer_service",
          customerServiceEnabled: false,
        },
        "customer_service",
      ),
    ).toBe(false);
  });

  it("returns safe progress defaults", () => {
    const progress = communicationCampaignProgress({
      id: "cmp_test",
      complete: false,
    });

    expect(progress.campaignId).toBe("cmp_test");
    expect(progress.complete).toBe(false);
    expect(progress.recipientCount).toBe(0);
    expect(progress.scannedCount).toBe(0);
    expect(progress.pushTargetCount).toBe(0);
    expect(progress.pushSuccessCount).toBe(0);
    expect(progress.pushFailureCount).toBe(0);
    expect(progress.pushUnknownCount).toBe(0);
  });
});
