import 'package:intl/intl.dart';
import '../models/document.dart';

double round2(double n) {
  return (n * 100).roundToDouble() / 100;
}

double rowTotal(LineItem item) {
  return round2(item.quantity * item.unitPrice);
}

class Totals {
  final double subtotal;
  final double taxAmount;
  final double total;

  Totals({
    required this.subtotal,
    required this.taxAmount,
    required this.total,
  });
}

Totals computeTotals(List<LineItem> items, double taxRate, double discount) {
  final subtotal = round2(items.fold<double>(0, (sum, i) => sum + rowTotal(i)));
  final taxAmount = round2(subtotal * (taxRate / 100));
  final total = round2(subtotal + taxAmount - discount);
  return Totals(subtotal: subtotal, taxAmount: taxAmount, total: total);
}

String formatMoney(double amount, [String currency = 'USD']) {
  try {
    final format = NumberFormat.currency(
      locale: 'en_US',
      symbol: _currencySymbol(currency),
      decimalDigits: 2,
    );
    return format.format(amount);
  } catch (_) {
    return '$currency ${amount.toStringAsFixed(2)}';
  }
}

/// All supported currencies as (code, name, symbol) tuples.
const List<Map<String, String>> kCurrencies = [
  {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
  {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
  {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
  {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
  {'code': 'CNY', 'name': 'Chinese Yuan', 'symbol': '¥'},
  {'code': 'ZAR', 'name': 'South African Rand', 'symbol': 'R'},
  {'code': 'ZWL', 'name': 'Zimbabwean Dollar', 'symbol': 'Z\$'},
  {'code': 'ZWG', 'name': 'Zimbabwean Gold (ZiG)', 'symbol': 'ZiG'},
  {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
  {'code': 'NGN', 'name': 'Nigerian Naira', 'symbol': '₦'},
  {'code': 'KES', 'name': 'Kenyan Shilling', 'symbol': 'KSh'},
  {'code': 'BRL', 'name': 'Brazilian Real', 'symbol': 'R\$'},
  {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'CA\$'},
  {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$'},
  {'code': 'SGD', 'name': 'Singapore Dollar', 'symbol': 'S\$'},
  {'code': 'HKD', 'name': 'Hong Kong Dollar', 'symbol': 'HK\$'},
  {'code': 'KRW', 'name': 'South Korean Won', 'symbol': '₩'},
  {'code': 'TRY', 'name': 'Turkish Lira', 'symbol': '₺'},
  {'code': 'RUB', 'name': 'Russian Ruble', 'symbol': '₽'},
  {'code': 'PHP', 'name': 'Philippine Peso', 'symbol': '₱'},
  {'code': 'THB', 'name': 'Thai Baht', 'symbol': '฿'},
  {'code': 'IDR', 'name': 'Indonesian Rupiah', 'symbol': 'Rp'},
  {'code': 'MYR', 'name': 'Malaysian Ringgit', 'symbol': 'RM'},
  {'code': 'VND', 'name': 'Vietnamese Dong', 'symbol': '₫'},
  {'code': 'ILS', 'name': 'Israeli Shekel', 'symbol': '₪'},
  {'code': 'PKR', 'name': 'Pakistani Rupee', 'symbol': 'Rs'},
  {'code': 'BDT', 'name': 'Bangladeshi Taka', 'symbol': '৳'},
  {'code': 'LKR', 'name': 'Sri Lankan Rupee', 'symbol': 'Rs'},
  {'code': 'ARS', 'name': 'Argentine Peso', 'symbol': '\$'},
  {'code': 'CLP', 'name': 'Chilean Peso', 'symbol': '\$'},
  {'code': 'COP', 'name': 'Colombian Peso', 'symbol': '\$'},
  {'code': 'PEN', 'name': 'Peruvian Sol', 'symbol': 'S/'},
  {'code': 'MXN', 'name': 'Mexican Peso', 'symbol': '\$'},
  {'code': 'PLN', 'name': 'Polish Zloty', 'symbol': 'zł'},
  {'code': 'CZK', 'name': 'Czech Koruna', 'symbol': 'Kč'},
  {'code': 'HUF', 'name': 'Hungarian Forint', 'symbol': 'Ft'},
  {'code': 'RON', 'name': 'Romanian Leu', 'symbol': 'lei'},
  {'code': 'UAH', 'name': 'Ukrainian Hryvnia', 'symbol': '₴'},
  {'code': 'SEK', 'name': 'Swedish Krona', 'symbol': 'kr'},
  {'code': 'NOK', 'name': 'Norwegian Krone', 'symbol': 'kr'},
  {'code': 'DKK', 'name': 'Danish Krone', 'symbol': 'kr'},
  {'code': 'CHF', 'name': 'Swiss Franc', 'symbol': 'CHF'},
  {'code': 'NZD', 'name': 'New Zealand Dollar', 'symbol': 'NZ\$'},
];

String _currencySymbol(String code) {
  const symbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CNY': '¥',
    'ZAR': 'R',
    'ZWL': 'Z\$',
    'ZWG': 'ZiG',
    'INR': '₹',
    'NGN': '₦',
    'KES': 'KSh',
    'BRL': 'R\$',
    'CAD': 'CA\$',
    'AUD': 'A\$',
    'SGD': 'S\$',
    'HKD': 'HK\$',
    'KRW': '₩',
    'TRY': '₺',
    'RUB': '₽',
    'PHP': '₱',
    'THB': '฿',
    'IDR': 'Rp',
    'MYR': 'RM',
    'VND': '₫',
    'ILS': '₪',
    'PKR': 'Rs',
    'BDT': '৳',
    'LKR': 'Rs',
    'ARS': '\$',
    'CLP': '\$',
    'COP': '\$',
    'PEN': 'S/',
    'MXN': '\$',
    'PLN': 'zł',
    'CZK': 'Kč',
    'HUF': 'Ft',
    'RON': 'lei',
    'UAH': '₴',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr',
    'CHF': 'CHF',
    'NZD': 'NZ\$',
  };
  return symbols[code] ?? '$code ';
}

String formatDate(String dateStr) {
  try {
    final date = DateTime.parse(dateStr);
    return DateFormat.yMMMMd('en_US').format(date);
  } catch (_) {
    return dateStr;
  }
}

String todayISO() {
  return DateTime.now().toIso8601String().slice(0, 10);
}

String plusDaysISO(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return d.toIso8601String().slice(0, 10);
}

extension StringSlice on String {
  String slice(int start, [int? end]) {
    final e = end ?? length;
    return substring(start, e > length ? length : e);
  }
}

String generateDocNumberPrefix(DocumentType type, String year, int seq) {
  final prefix = type.prefix;
  return '$prefix-$year-${seq.toString().padLeft(4, '0')}';
}
