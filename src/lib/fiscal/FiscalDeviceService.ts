import { randomUUID } from "node:crypto";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import { CertificateManager } from "@/lib/fiscal/CertificateManager";
import { ConfigurationManager } from "@/lib/fiscal/ConfigurationManager";
import { CsrGenerator } from "@/lib/fiscal/CsrGenerator";
import {
  getDeviceConfig,
  issueDeviceCertificate,
  registerDevice,
  verifyTaxpayer,
  type FdmsEnv,
} from "@/lib/fiscal/zimra.server";

export type TaxpayerVerificationInput = {
  env: FdmsEnv;
  taxpayerTin: string;
  vatNumber?: string | null;
};

export type DeviceRegistrationInput = TaxpayerVerificationInput & {
  orgId: string;
  deviceSerialNo: string;
  deviceModelName?: string;
  deviceModelVersion?: string;
  deviceBranchName?: string | null;
};

export class FiscalDeviceService {
  constructor(
    private readonly csrGenerator = new CsrGenerator(),
    private readonly certificateManager = new CertificateManager(),
    private readonly configurationManager = new ConfigurationManager(),
  ) {}

  async verifyTaxpayer(input: TaxpayerVerificationInput) {
    return verifyTaxpayer(input.env, { taxpayerTin: input.taxpayerTin, vatNumber: input.vatNumber });
  }

  async registerDevice(input: DeviceRegistrationInput) {
    const verification = await this.verifyTaxpayer(input);
    if (!verification.ok) return verification;

    const registration = await registerDevice(input.env, {
      taxpayerTin: input.taxpayerTin,
      vatNumber: input.vatNumber,
      deviceSerialNo: input.deviceSerialNo,
      deviceModelName: input.deviceModelName ?? "Server",
      deviceModelVersion: input.deviceModelVersion ?? "v1",
      deviceBranchName: input.deviceBranchName,
    });
    if (!registration.ok) return registration;

    const registrationData = registration.data as Record<string, unknown>;
    const fdmsDeviceId = String(registration.data.deviceId ?? registrationData.deviceID ?? "");
    const activationKey = String(registration.data.activationKey ?? registrationData.deviceActivationKey ?? "");
    if (!fdmsDeviceId || !activationKey) throw new Error("FDMS registration response did not include a device id and activation key");

    const deviceUuid = randomUUID();
    const { error } = await supabaseAdmin.from("devices").insert({
      id: deviceUuid,
      org_id: input.orgId,
      environment: input.env,
      fdms_device_id: fdmsDeviceId,
      device_serial_no: input.deviceSerialNo,
      device_model_name: input.deviceModelName ?? "Server",
      device_model_version: input.deviceModelVersion ?? "v1",
      activation_key: activationKey,
      taxpayer_tin: input.taxpayerTin,
      vat_number: input.vatNumber,
      registration_response: registration.data as never,
    } as never);
    if (error) throw new Error(error.message);

    return { ok: true as const, data: { deviceUuid, fdmsDeviceId, activationKey, verification: verification.data } };
  }

  async issueCertificate(input: {
    orgId: string;
    deviceUuid: string;
    env: FdmsEnv;
    fdmsDeviceId: string;
    activationKey: string;
    commonName: string;
    encryptedPrivateKeyRef: string;
  }) {
    const csr = this.csrGenerator.generate({ commonName: input.commonName, serialNumber: input.fdmsDeviceId });

    const { error: keyError } = await supabaseAdmin.from("device_keys").insert({
      org_id: input.orgId,
      device_id: input.deviceUuid,
      key_algorithm: csr.keyAlgorithm,
      key_size: csr.keySize,
      public_key_pem: csr.publicKeyPem,
      encrypted_private_key_ref: input.encryptedPrivateKeyRef,
      csr_pem: csr.csrPem,
      csr_fingerprint: csr.csrFingerprint,
    } as never);
    if (keyError) throw new Error(keyError.message);

    const issued = await issueDeviceCertificate(input.env, {
      deviceId: input.fdmsDeviceId,
      activationKey: input.activationKey,
      csr: csr.csrPem,
    });
    if (!issued.ok) return issued;

    const certificatePem = String(issued.data.certificatePem ?? issued.data.certificate ?? "");
    if (!certificatePem) throw new Error("FDMS certificate response did not include certificate PEM");

    const certificate = await this.certificateManager.storeIssuedCertificate({
      orgId: input.orgId,
      deviceUuid: input.deviceUuid,
      fdmsDeviceId: input.fdmsDeviceId,
      environment: input.env,
      certificatePem,
      csrPem: csr.csrPem,
      issuedBy: "zimra-fdms",
      response: issued.data,
    });

    return { ok: true as const, data: { certificate, csrFingerprint: csr.csrFingerprint } };
  }

  async refreshConfiguration(input: { orgId: string; deviceUuid: string; env: FdmsEnv; fdmsDeviceId: string; activationKey: string }) {
    const result = await getDeviceConfig(input.env, {
      deviceId: input.fdmsDeviceId,
      deviceSerialNo: null,
      activationKey: input.activationKey,
      certificatePem: null,
      privateKeyPem: null,
    });
    if (!result.ok) return result;
    const snapshot = await this.configurationManager.storeSnapshot({
      orgId: input.orgId,
      deviceUuid: input.deviceUuid,
      fdmsDeviceId: input.fdmsDeviceId,
      environment: input.env,
      source: "fdms",
      configuration: result.data,
    });
    return { ok: true as const, data: snapshot };
  }
}
