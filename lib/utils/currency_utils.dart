const supportedCurrencies = <Map<String, String>>[
  {'code': 'LKR', 'label': 'LKR (Rs.)'},
  {'code': 'USD', 'label': 'USD (\$)'},
  {'code': 'EUR', 'label': 'EUR'},
  {'code': 'GBP', 'label': 'GBP'},
  {'code': 'AUD', 'label': 'AUD (A\$)'},
  {'code': 'JPY', 'label': 'JPY'},
];

String currencySymbol(String currencyCode) {
  switch (currencyCode.toUpperCase()) {
    case 'LKR':
      return 'Rs. ';
    case 'USD':
      return '\$';
    case 'EUR':
      return 'EUR ';
    case 'GBP':
      return 'GBP ';
    case 'AUD':
      return 'A\$';
    case 'JPY':
      return 'JPY ';
    default:
      return '$currencyCode ';
  }
}

String formatCurrencyAmount(String currencyCode, num amount) {
  final symbol = currencySymbol(currencyCode);
  final formatted = amount.toStringAsFixed(2);
  return '$symbol$formatted';
}

double? convertUsdToLkr(num amount, double? usdToLkrRate, String currencyCode) {
  if (currencyCode.toUpperCase() != 'USD' || usdToLkrRate == null) {
    return null;
  }

  return amount.toDouble() * usdToLkrRate;
}
