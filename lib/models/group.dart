class Group {
  final String id;
  final String name;
  final int members;
  final double balance;
  final String description;
  final List<dynamic> expenses;

  const Group({
    required this.id,
    required this.name,
    required this.members,
    required this.balance,
    required this.description,
    this.expenses = const [],
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      members: json['member_count'] ?? json['members'] ?? 0,
      balance: (json['your_balance'] ?? json['balance'] ?? 0.0).toDouble(),
      description: json['description'] ?? 'Currency: ${json['currency'] ?? 'LKR'}',
      expenses: json['expenses'] ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'members': members,
      'balance': balance,
      'description': description,
    };
  }
}
