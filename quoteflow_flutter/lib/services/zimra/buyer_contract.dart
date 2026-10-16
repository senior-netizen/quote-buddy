/// FDMS Device-v1 BuyerDto contract, checked against the ZIMRA test Swagger.
/// Kept free of Flutter dependencies so the web gateway uses the same guard.
class FiscalBuyerException implements Exception {
  final List<String> problems;
  const FiscalBuyerException(this.problems);

  /// Precise, actionable requirement-8 messages for the raw problem labels
  /// produced by [fiscalBuyerProblems]; decorated labels (e.g. "TIN (10
  /// digits, not all zeros)") are kept as-is — they already say what to fix.
  static String _message(String problem) {
    if (problem == 'TIN') {
      return 'Customer TIN is required for fiscalisation.';
    }
    if (problem == 'Registered name') {
      return 'Customer registered name is required for fiscalisation.';
    }
    if (problem == 'VAT registration number') {
      return 'Customer VAT registration number is required for fiscalisation.';
    }
    return problem;
  }

  @override
  String toString() {
    final parts = problems.map(_message).toSet().toList();
    return 'Customer fiscal details are incomplete.\n'
        '${parts.map((p) => '• $p').join('\n')}';
  }
}

String? buyerText(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

List<String> fiscalBuyerProblems(Object? value) {
  if (value is! Map) return ['Registered name', 'TIN'];
  final problems = <String>[];
  void field(
    Map map,
    String key,
    String label,
    int max, {
    bool required = false,
    int? digits,
  }) {
    final raw = map[key];
    if (raw != null && raw is! String) {
      // A corrupted row or hand-edited backup stored a non-string (e.g. a
      // number). Values must ride the wire as strings — flag it as the
      // field's problem instead of silently treating it as empty.
      problems.add('$label (must be text, not ${raw.runtimeType})');
      return;
    }
    final text = raw is String ? raw.trim() : '';
    if (text.isEmpty) {
      if (required || map.containsKey(key)) problems.add(label);
    } else if (text.length > max ||
        (digits != null &&
            (!RegExp('^[0-9]{$digits}\$').hasMatch(text) ||
                RegExp(r'^0+$').hasMatch(text)))) {
      problems.add(
        digits == null
            ? '$label (maximum $max characters)'
            : '$label ($digits digits, not all zeros)',
      );
    }
  }

  field(value, 'buyerRegisterName', 'Registered name', 250, required: true);
  field(value, 'buyerTIN', 'TIN', 10, required: true, digits: 10);
  field(value, 'buyerTradeName', 'Trade name', 250);
  field(value, 'vatNumber', 'VAT registration number', 9, digits: 9);
  const keys = {
    'buyerRegisterName',
    'buyerTIN',
    'buyerTradeName',
    'vatNumber',
    'buyerAddress',
    'buyerContacts',
  };
  if (value.keys.any((k) => !keys.contains(k)))
    problems.add('Unsupported buyer field');
  for (final key in ['buyerAddress', 'buyerContacts']) {
    if (!value.containsKey(key)) continue;
    final nested = value[key];
    final limits = key == 'buyerAddress'
        ? {
            'houseNo': 250,
            'street': 100,
            'city': 100,
            'province': 100,
            'district': 100,
          }
        : {'phoneNo': 20, 'email': 100};
    if (nested is! Map || nested.isEmpty) {
      problems.add('$key must contain details or be omitted');
      continue;
    }
    if (nested.keys.any((k) => !limits.containsKey(k)))
      problems.add('Unsupported $key field');
    for (final entry in limits.entries) {
      field(nested, entry.key, entry.key, entry.value);
    }
    final email = nested['email'];
    if (email is String &&
        email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      problems.add('Valid email');
    }
  }
  return problems;
}

void validateFiscalBuyer(Object? buyer) {
  final problems = fiscalBuyerProblems(buyer);
  if (problems.isNotEmpty) throw FiscalBuyerException(problems);
}

/// Absence is intentional; null, empty and partial buyerData are invalid.
void validateReceiptBuyer(Map receipt) {
  if (receipt.containsKey('buyerData'))
    validateFiscalBuyer(receipt['buyerData']);
}

String fiscalValidationMessage(String code, String description) =>
    code.toUpperCase() == 'RCPT043'
    ? "Buyer fiscal details are incomplete. Check the customer's registered name and TIN."
    : description;
