class Group {
  final String id;
  final String name;
  final int members;
  final double balance;
  final String description;
  final String currency;
  final List<dynamic> expenses;
  final String? coverImageUrl;
  final String? coverImagePreset;
  final String? profileImageUrl;
  final bool canEdit;
  final double totalExpenses;

  const Group({
    required this.id,
    required this.name,
    required this.members,
    required this.balance,
    required this.description,
    required this.currency,
    this.expenses = const [],
    this.coverImageUrl,
    this.coverImagePreset,
    this.profileImageUrl,
    this.canEdit = false,
    this.totalExpenses = 0,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    final balanceValue = json['your_balance'] ?? json['balance'] ?? 0.0;
    final totalExpensesValue = json['total_expenses'] ?? 0.0;

    return Group(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      members: (json['member_count'] ?? json['members'] ?? 0) is num
          ? ((json['member_count'] ?? json['members'] ?? 0) as num).toInt()
          : int.tryParse(
                  (json['member_count'] ?? json['members'] ?? 0).toString(),
                ) ??
                0,
      balance: (balanceValue as num).toDouble(),
      description: json['description']?.toString() ??
          'Currency: ${json['currency'] ?? 'LKR'}',
      currency: json['currency']?.toString() ?? 'LKR',
      expenses: (json['expenses'] as List?) ?? const [],
      coverImageUrl: json['cover_image_url']?.toString(),
      coverImagePreset: json['cover_image_preset']?.toString(),
      profileImageUrl: json['profile_image_url']?.toString(),
      canEdit: json['can_edit'] == true,
      totalExpenses: (totalExpensesValue as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'member_count': members,
      'your_balance': balance,
      'description': description,
      'currency': currency,
      'expenses': expenses,
      'cover_image_url': coverImageUrl,
      'cover_image_preset': coverImagePreset,
      'profile_image_url': profileImageUrl,
      'can_edit': canEdit,
      'total_expenses': totalExpenses,
    };
  }
}
