// Integration test against the live ZIMRA test environment.
// Run with RUN_ZIMRA_LIVE_TEST=true, ZIMRA_DEVICE_ID, ZIMRA_SERIAL, and
// ZIMRA_ACTIVATION_KEY supplied as --dart-define options to flutter test.
// ZIMRA_MODEL_NAME and ZIMRA_MODEL_VERSION default to Virtual Server / v1.
// Registration happens once per device; this test requires an unregistered
// test device and submits test receipts after registration succeeds.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/services/zimra/zimra.dart';

const _deviceId = int.fromEnvironment('ZIMRA_DEVICE_ID');
const _serial = String.fromEnvironment('ZIMRA_SERIAL');
const _activationKey = String.fromEnvironment('ZIMRA_ACTIVATION_KEY');
const _modelName = String.fromEnvironment(
  'ZIMRA_MODEL_NAME',
  defaultValue: 'Virtual Server',
);
const _modelVersion = String.fromEnvironment(
  'ZIMRA_MODEL_VERSION',
  defaultValue: 'v1',
);
const _runLiveTest = bool.fromEnvironment('RUN_ZIMRA_LIVE_TEST');

void main() {
  test(
    'ZIMRA test device registration and fiscal day lifecycle',
    _runIntegrationTest,
    skip: _runLiveTest ? false : 'Set RUN_ZIMRA_LIVE_TEST=true to run live.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _runIntegrationTest() async {
  if (_deviceId <= 0 || _serial.isEmpty || _activationKey.isEmpty) {
    throw StateError(
      'Provide ZIMRA_DEVICE_ID, ZIMRA_SERIAL, and ZIMRA_ACTIVATION_KEY '
      'using --dart-define. Keep the activation key as an eight-character '
      'string, including leading zeros.',
    );
  }

  final device = ZimraDeviceIdentity(
    deviceId: _deviceId,
    serialNumber: _serial,
    modelName: _modelName,
    modelVersion: _modelVersion,
  );

  print('═══ ZIMRA FDMS Integration Test ═══\n');

  // ── Step 1: Register device ──────────────────────────────────────────
  print('1. Registering device...');
  print('   Device ID:    ${device.deviceId}');
  print('   Serial:       ${device.serialNumber}');
  print('   Common Name:  ${device.commonName}');
  print('   Model:        ${device.modelName} / ${device.modelVersion}');

  final regResult = await ZimraFiscalDevice.registerDevice(
    device: device,
    activationKey: _activationKey,
    environment: ZimraEnvironment.test,
  );

  // Preserve issued credentials before making further requests. Registration
  // cannot simply be repeated if a later test step fails. .dart_tool is ignored.
  final credentialsFile = File('.dart_tool/zimra/device-$_deviceId.json');
  await credentialsFile.parent.create(recursive: true);
  await credentialsFile.writeAsString(
    jsonEncode({
      'environment': ZimraEnvironment.test.name,
      'device': device.toJson(),
      'credentials': regResult.credentials.toJson(),
    }),
    flush: true,
  );

  print('   ✓ Registered successfully');
  print('   Operation ID: ${regResult.operationId}');
  print('   Credentials:  ${credentialsFile.path}');
  print(
    '   Certificate:  ${regResult.credentials.certificatePem.substring(0, 60)}...',
  );

  // ── Step 2: Create fiscal device and fetch config ────────────────────
  print('\n2. Creating fiscal device and fetching config...');

  final fiscalDevice = ZimraFiscalDevice(
    identity: device,
    credentials: regResult.credentials,
    environment: ZimraEnvironment.test,
  );
  addTearDown(fiscalDevice.close);

  final config = await fiscalDevice.getConfig();
  print('   ✓ Config loaded');
  print('   QR URL:       ${config.qrUrl}');
  print('   Taxes:        ${config.applicableTaxes.length} applicable');

  for (final tax in config.applicableTaxes) {
    print('     - ${tax.taxCode}: ${tax.taxName} (${tax.taxPercent}%)');
  }

  // ── Step 3: Open fiscal day ──────────────────────────────────────────
  print('\n3. Opening fiscal day...');

  await fiscalDevice.openDay();
  final state = fiscalDevice.getState();

  print('   ✓ Day opened');
  print('   Day #${state.fiscalDayNo}  (${state.fiscalDayDate})');
  print('   Global receipt # starts at: ${state.receiptGlobalNo}');

  // ── Step 4: Submit a test receipt ────────────────────────────────────
  print('\n4. Submitting test receipt...');

  final firstTax = config.applicableTaxes.isNotEmpty
      ? config.applicableTaxes.first
      : null;

  final lines = <ReceiptLineInput>[
    ReceiptLineInput(
      name: 'Consulting Services',
      price: 100.00,
      quantity: 1,
      taxId: firstTax?.taxId ?? 513,
      taxPercent: firstTax?.taxPercent ?? 0,
    ),
  ];

  final totalCents = lines.fold<int>(
    0,
    (s, l) => s + (l.price * l.quantity * 100).round(),
  );

  final payments = [ReceiptPayment(moneyType: 'Cash', amount: totalCents)];

  print('   Lines:');
  for (final l in lines) {
    final taxInfo = l.taxPercent != null && l.taxPercent! > 0
        ? ' (${l.taxPercent}% tax)'
        : ' (exempt)';
    print('     - ${l.name}: ${l.price} × ${l.quantity}$taxInfo');
  }
  print('   Total: \$${(totalCents / 100).toStringAsFixed(2)}');
  print('   Payment: Cash');

  final receipt = await fiscalDevice.submitReceipt(
    currency: 'USD',
    invoiceNo: 'TEST-001',
    lines: lines,
    payments: payments,
    notes: 'Integration test receipt',
  );

  print('   ✓ Receipt submitted');
  print('   Receipt ID:  ${receipt.response.receiptId}');
  print('   Server date: ${receipt.response.serverDate}');
  print('   Server sig:  ${receipt.response.signature?.substring(0, 40)}...');

  if (receipt.qrData != null) {
    print('   QR data:     ${receipt.qrData}');
  }

  // Show validation errors (yellow = warning, red = serious)
  if (receipt.response.validationErrors.isNotEmpty) {
    print('   Validation:');
    for (final err in receipt.response.validationErrors) {
      final icon = err.isRed ? '🔴' : '🟡';
      print('     $icon ${err.code}: ${err.description}');
    }
  } else {
    print('   ✓ No validation errors');
  }

  // Show updated state
  final updatedState = fiscalDevice.getState();
  print('   Receipts issued this day: ${updatedState.receiptCounter}');
  print('   Global receipt number:    ${updatedState.receiptGlobalNo}');
  print(
    '   Previous receipt hash:    ${updatedState.previousReceiptHash?.substring(0, 20)}...',
  );

  // ── Step 5: Submit a second receipt (tests hash chain) ───────────────
  print('\n5. Submitting second receipt (hash chain test)...');

  final receipt2 = await fiscalDevice.submitReceipt(
    currency: 'USD',
    invoiceNo: 'TEST-002',
    lines: [
      ReceiptLineInput(
        name: 'Support Services',
        price: 50.00,
        quantity: 2,
        taxId: firstTax?.taxId ?? 513,
        taxPercent: firstTax?.taxPercent ?? 0,
      ),
    ],
    payments: [ReceiptPayment(moneyType: 'Card', amount: 10000)],
  );

  print('   ✓ Second receipt submitted');
  print('   Receipt ID: ${receipt2.response.receiptId}');

  final state2 = fiscalDevice.getState();
  print('   Hash chain: ${state2.previousReceiptHash?.substring(0, 20)}...');

  // ── Step 6: Close fiscal day ─────────────────────────────────────────
  print('\n6. Closing fiscal day...');

  try {
    await fiscalDevice.closeDay();
    print('   ✓ Day close submitted (async on server)');

    // Poll for completion
    print('   Waiting for server to finalise...');
    var status = FiscalDayStatus.fiscalDayCloseInitiated;
    for (
      var i = 0;
      i < 12 && status == FiscalDayStatus.fiscalDayCloseInitiated;
      i++
    ) {
      await Future.delayed(const Duration(seconds: 3));
      status = await fiscalDevice.getStatus();
      print('   Status: ${status.name}');
    }

    if (status == FiscalDayStatus.fiscalDayClosed) {
      print('   ✓ Day closed successfully!');
    } else {
      print('   ⚠ Day status: ${status.name} — may need manual intervention');
    }
    expect(
      status,
      FiscalDayStatus.fiscalDayClosed,
      reason: 'ZIMRA did not finish closing the test fiscal day.',
    );
  } catch (e) {
    print('   ✗ Close failed: $e');
    print('   The day may need to be closed via the test portal');
    rethrow;
  }

  // ── Summary ──────────────────────────────────────────────────────────
  print('\n═══ Test Complete ═══');
  print('Device: ${device.deviceId} (${device.serialNumber})');
  print('Receipts submitted: ${updatedState.receiptCounter + 1}');
  print('Device credentials saved to ${credentialsFile.path}');
  print('');
  print('Next steps:');
  print('  - Check the test portal for your device\'s receipt history');
  print('  - Verify the QR code at: https://fdmsapitest.zimra.co.zw/...');
}
