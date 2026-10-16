import '../models/client.dart';
import 'zimra/zimra_models.dart';
import 'zimra/buyer_contract.dart';

export 'zimra/buyer_contract.dart' show FiscalBuyerException;

/// The sole Customer -> FDMS buyer mapping. Display names are never substituted
/// for registered names. Buyer VAT status has no part in tax calculations.
class FiscalBuyerMapper {
  static BuyerData? map(Client? customer, {required bool include}) {
    if (!include) return null;
    final buyer = BuyerData(
      name: buyerText(customer?.registeredName),
      tin: buyerText(customer?.tin),
      tradeName: buyerText(customer?.tradeName),
      vatNumber: customer?.vatRegistered == true
          ? buyerText(customer?.vatNumber)
          : null,
      buyerAddress: {
        if (buyerText(customer?.houseNo) case final String v) 'houseNo': v,
        if (buyerText(customer?.street) case final String v) 'street': v,
        if (buyerText(customer?.city) case final String v) 'city': v,
        if (buyerText(customer?.province) case final String v) 'province': v,
      },
      buyerContacts: {
        if (buyerText(customer?.phone) case final String v) 'phoneNo': v,
        if (buyerText(customer?.email) case final String v) 'email': v,
      },
    );
    final problems = fiscalBuyerProblems(buyer.toJson());
    if (customer?.vatRegistered == true && buyer.vatNumber == null) {
      problems.add('VAT registration number');
    }
    if (problems.isNotEmpty) throw FiscalBuyerException(problems);
    return buyer;
  }

  static List<String> problems(Client? customer) {
    try {
      map(customer, include: true);
      return const [];
    } on FiscalBuyerException catch (e) {
      return e.problems;
    }
  }
}
