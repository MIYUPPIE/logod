enum LevyFrequency { daily, weekly, monthly, oneOff;

  static LevyFrequency fromJson(String value) => switch (value) {
        'daily' => LevyFrequency.daily,
        'weekly' => LevyFrequency.weekly,
        'monthly' => LevyFrequency.monthly,
        'one_off' => LevyFrequency.oneOff,
        _ => LevyFrequency.oneOff,
      };

  String toJson() => switch (this) {
        LevyFrequency.daily => 'daily',
        LevyFrequency.weekly => 'weekly',
        LevyFrequency.monthly => 'monthly',
        LevyFrequency.oneOff => 'one_off',
      };

  String get label => switch (this) {
        LevyFrequency.daily => 'Daily',
        LevyFrequency.weekly => 'Weekly',
        LevyFrequency.monthly => 'Monthly',
        LevyFrequency.oneOff => 'One-off',
      };
}

class LevyType {
  final int id;
  final int lgaId;
  final String name;
  final double amount;
  final LevyFrequency frequency;

  const LevyType({
    required this.id,
    required this.lgaId,
    required this.name,
    required this.amount,
    required this.frequency,
  });

  factory LevyType.fromJson(Map<String, dynamic> json) => LevyType(
        id: json['id'] as int,
        lgaId: json['lga_id'] as int,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        frequency: LevyFrequency.fromJson(json['frequency'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'lga_id': lgaId,
        'name': name,
        'amount': amount,
        'frequency': frequency.toJson(),
      };

  factory LevyType.fromDb(Map<String, dynamic> row) => LevyType(
        id: row['id'] as int,
        lgaId: row['lga_id'] as int,
        name: row['name'] as String,
        amount: (row['amount'] as num).toDouble(),
        frequency: LevyFrequency.fromJson(row['frequency'] as String),
      );

  Map<String, dynamic> toDb() => toJson();
}
