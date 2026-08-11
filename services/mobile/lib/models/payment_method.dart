enum PaymentMethod { cash, pos, transfer;

  static PaymentMethod fromDb(String value) => PaymentMethod.values.firstWhere(
        (m) => m.name == value,
        orElse: () => PaymentMethod.cash,
      );

  String toDb() => name;

  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.pos => 'POS',
        PaymentMethod.transfer => 'Transfer',
      };
}
