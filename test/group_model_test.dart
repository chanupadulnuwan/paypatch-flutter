import 'package:flutter_test/flutter_test.dart';
import 'package:paypatch/models/group.dart';

void main() {
  group('Group Model Test', () {
    test('Group.fromJson should parse correct values', () {
      final json = {
        'id': 12,
        'name': 'Test Group',
        'member_count': 5,
        'your_balance': 25.50,
        'currency': 'LKR',
        'expenses': [
          {'id': 1, 'title': 'Food', 'amount': 100.0}
        ]
      };

      final g = Group.fromJson(json);

      expect(g.id, '12');
      expect(g.name, 'Test Group');
      expect(g.members, 5);
      expect(g.balance, 25.50);
      expect(g.description, 'Currency: LKR');
      expect(g.expenses.length, 1);
      expect(g.expenses.first['title'], 'Food');
    });

    test('Group.toJson should serialize correct values', () {
      const g = Group(
        id: '12',
        name: 'Test Group',
        members: 5,
        balance: 25.50,
        description: 'Currency: LKR',
        currency: 'LKR',
      );

      final json = g.toJson();

      expect(json['id'], '12');
      expect(json['name'], 'Test Group');
      expect(json['member_count'], 5);
      expect(json['your_balance'], 25.50);
      expect(json['description'], 'Currency: LKR');
      expect(json['currency'], 'LKR');
    });
  });
}
