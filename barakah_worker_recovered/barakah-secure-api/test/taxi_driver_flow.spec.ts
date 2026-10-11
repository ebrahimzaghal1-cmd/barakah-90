import { describe, expect, it } from "vitest";
import source from "../src/index.js?raw";
import taxiSecuritySource from "../src/security/taxi.js?raw";

function functionBlock(name: string) {
  const startMarker = `async function ${name}(`;
  const endMarker = `__name(${name}, "${name}");`;

  const start = source.indexOf(startMarker);
  const end = source.indexOf(endMarker, start);

  expect(start).toBeGreaterThanOrEqual(0);
  expect(end).toBeGreaterThan(start);

  return source.slice(start, end + endMarker.length);
}

describe("Barakah taxi driver onboarding regression", () => {
  it("supports taxi driver applications in admin notifications", () => {
    expect(source).toContain("taxi_driver_application: {");
    expect(source).toContain('collection: "taxi_driver_applications"');
    expect(source).toContain('expectedStatus: "pending"');
  });

  it("assigns taxi drivers from taxi_driver_applications", () => {
    const block = functionBlock("assignTaxiDriver");

    expect(block).toContain(
      "taxi_driver_applications/${encodeURIComponent(driverUid)}",
    );

    expect(block).not.toContain(
      "`driver_applications/${encodeURIComponent(driverUid)}`",
    );
  });

  it("does not require the delivery-driver role for taxi assignment", () => {
    const block = functionBlock("assignTaxiDriver");

    expect(block).not.toContain('driver.role !== "driver"');
    expect(block).toContain("if (!driver)");
  });

  it("still requires a fully approved taxi driver application", () => {
    const block = functionBlock("assignTaxiDriver");

    expect(block).toContain('driverApplication.status !== "approved"');
    expect(block).toContain(
      "driverApplication.identityVerified !== true",
    );
    expect(block).toContain(
      "driverApplication.driverLicenseVerified !== true",
    );
    expect(block).toContain(
      "driverApplication.vehicleDocumentsVerified !== true",
    );
    expect(block).toContain(
      "driverApplication.payoutVerified !== true",
    );
    expect(block).toContain(
      "driverApplication.acceptedDriverTerms !== true",
    );
    expect(block).toContain(
      "driverApplication.acceptedPrivacyPolicy !== true",
    );
  });

  it("authorizes taxi-only drivers without delivery-driver role", () => {
    expect(taxiSecuritySource).not.toContain(
      "actor.role === 'driver'",
    );
    expect(taxiSecuritySource).not.toContain(
      "driver.role === 'driver'",
    );

    expect(taxiSecuritySource).toContain(
      "actor.taxiDriverEnabled === true",
    );
    expect(taxiSecuritySource).toContain(
      "actor.taxiBusinessId === businessId",
    );

    expect(taxiSecuritySource).toContain(
      "driver.taxiDriverEnabled === true",
    );
    expect(taxiSecuritySource).toContain(
      "documentId(driver.taxiBusinessId) === businessId",
    );
  });

});
