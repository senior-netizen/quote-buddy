import 'package:flutter_test/flutter_test.dart';

import 'package:quoteflow/models/document.dart';

String _daysFromNow(int days) {
  final d = DateTime.now().add(Duration(days: days));
  final s = d.toIso8601String();
  return s.substring(0, 10);
}

QuoteflowDocument _doc({
  String type = 'invoice',
  String status = 'sent',
  String? dueDate,
}) =>
    QuoteflowDocument(
      id: 'd-1',
      docType: type,
      docNumber: 'INV-2026-0001',
      issueDate: _daysFromNow(-10),
      dueDate: dueDate,
      lineItems: const [],
      taxRate: 0,
      discount: 0,
      subtotal: 0,
      taxAmount: 0,
      total: 100,
      clientId: 'c-1',
      createdAt: DateTime.now().toIso8601String(),
      docStatus: status,
    );

void main() {
  group('Auto-overdue derivation', () {
    test('sent invoice past its due date reads as overdue', () {
      final doc = _doc(dueDate: _daysFromNow(-3));
      expect(doc.isPastDue, isTrue);
      expect(doc.effectiveStatus, DocumentStatus.overdue);
      // The stored status is left untouched.
      expect(doc.docStatus, 'sent');
    });

    test('accepted invoice past its due date reads as overdue', () {
      final doc = _doc(status: 'accepted', dueDate: _daysFromNow(-1));
      expect(doc.effectiveStatus, DocumentStatus.overdue);
    });

    test('invoice due today is not yet overdue', () {
      final doc = _doc(dueDate: _daysFromNow(0));
      expect(doc.isPastDue, isFalse);
      expect(doc.effectiveStatus, DocumentStatus.sent);
    });

    test('invoice due in the future is not overdue', () {
      final doc = _doc(dueDate: _daysFromNow(7));
      expect(doc.isPastDue, isFalse);
      expect(doc.effectiveStatus, DocumentStatus.sent);
    });

    test('paid invoice past its due date is not overdue', () {
      final doc = _doc(status: 'paid', dueDate: _daysFromNow(-30));
      expect(doc.isPastDue, isFalse);
      expect(doc.effectiveStatus, DocumentStatus.paid);
    });

    test('declined invoice past its due date is not overdue', () {
      final doc = _doc(status: 'declined', dueDate: _daysFromNow(-5));
      expect(doc.effectiveStatus, DocumentStatus.declined);
    });

    test('draft invoice past its due date is not overdue', () {
      final doc = _doc(status: 'draft', dueDate: _daysFromNow(-5));
      expect(doc.effectiveStatus, DocumentStatus.draft);
    });

    test('invoice without a due date is never overdue', () {
      expect(_doc(dueDate: null).isPastDue, isFalse);
    });

    test('non-invoice documents are never auto-overdue', () {
      final quote = _doc(type: 'quote', dueDate: _daysFromNow(-5));
      final receipt = _doc(type: 'receipt', dueDate: _daysFromNow(-5));
      final creditNote = _doc(type: 'credit_note', dueDate: _daysFromNow(-5));
      expect(quote.isPastDue, isFalse);
      expect(receipt.isPastDue, isFalse);
      expect(creditNote.isPastDue, isFalse);
    });

    test('manually stored overdue status still reads as overdue', () {
      final doc = _doc(status: 'overdue', dueDate: _daysFromNow(-2));
      expect(doc.effectiveStatus, DocumentStatus.overdue);
    });

    test('unparseable due date is treated as not overdue', () {
      final doc = _doc(dueDate: 'not-a-date');
      expect(doc.isPastDue, isFalse);
      expect(doc.effectiveStatus, DocumentStatus.sent);
    });
  });
}
