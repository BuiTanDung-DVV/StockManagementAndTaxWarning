class InvoiceDataQuality {
  final int checkedInvoices;
  final int missingItemInvoices;
  final int headerTotalMismatchInvoices;
  final int headerSubtotalMismatchInvoices;
  final int unallocatedDiscountInvoices;
  final int headerTaxMismatchInvoices;
  final int invalidLineItems;
  final int lineSubtotalMismatchItems;
  final int lineTaxMismatchItems;
  final int issueCount;
  final bool hasIssues;

  const InvoiceDataQuality({
    required this.checkedInvoices,
    required this.missingItemInvoices,
    required this.headerTotalMismatchInvoices,
    required this.headerSubtotalMismatchInvoices,
    required this.unallocatedDiscountInvoices,
    required this.headerTaxMismatchInvoices,
    required this.invalidLineItems,
    required this.lineSubtotalMismatchItems,
    required this.lineTaxMismatchItems,
    required this.issueCount,
    required this.hasIssues,
  });

  factory InvoiceDataQuality.fromResponse(Map<String, dynamic> response) {
    final raw = response['quality'];
    final quality = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    int count(String key) {
      final value = quality[key];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final missingItemInvoices = count('missingItemInvoices');
    final headerTotalMismatchInvoices = count('headerTotalMismatchInvoices');
    final headerSubtotalMismatchInvoices = count(
      'headerSubtotalMismatchInvoices',
    );
    final unallocatedDiscountInvoices = count('unallocatedDiscountInvoices');
    final headerTaxMismatchInvoices = count('headerTaxMismatchInvoices');
    final invalidLineItems = count('invalidLineItems');
    final lineSubtotalMismatchItems = count('lineSubtotalMismatchItems');
    final lineTaxMismatchItems = count('lineTaxMismatchItems');
    final calculatedIssues =
        missingItemInvoices +
        headerTotalMismatchInvoices +
        headerSubtotalMismatchInvoices +
        unallocatedDiscountInvoices +
        headerTaxMismatchInvoices +
        invalidLineItems +
        lineSubtotalMismatchItems +
        lineTaxMismatchItems;

    return InvoiceDataQuality(
      checkedInvoices: count('checkedInvoices'),
      missingItemInvoices: missingItemInvoices,
      headerTotalMismatchInvoices: headerTotalMismatchInvoices,
      headerSubtotalMismatchInvoices: headerSubtotalMismatchInvoices,
      unallocatedDiscountInvoices: unallocatedDiscountInvoices,
      headerTaxMismatchInvoices: headerTaxMismatchInvoices,
      invalidLineItems: invalidLineItems,
      lineSubtotalMismatchItems: lineSubtotalMismatchItems,
      lineTaxMismatchItems: lineTaxMismatchItems,
      issueCount: calculatedIssues,
      hasIssues: calculatedIssues > 0,
    );
  }
}
