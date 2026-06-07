import '../models/group.dart';

const sampleGroups = [
  Group(
    id: 'g1',
    name: 'Roommates',
    members: 4,
    balance: -120.00,
    description: 'Monthly rent, groceries, and utility bills shared between roommates.',
    currency: 'LKR',
  ),
  Group(
    id: 'g2',
    name: 'Trip to Bali',
    members: 6,
    balance: 200.50,
    description: 'Flights, hotel, and food expenses from the Bali vacation.',
    currency: 'USD',
  ),
  Group(
    id: 'g3',
    name: 'Office Lunch',
    members: 8,
    balance: -50.00,
    description: 'Team lunch contributions and shared restaurant payments.',
    currency: 'LKR',
  ),
  Group(
    id: 'g4',
    name: 'Weekend Getaway',
    members: 5,
    balance: -30.00,
    description: 'Transport and Airbnb costs from weekend trip.',
    currency: 'LKR',
  ),
];
