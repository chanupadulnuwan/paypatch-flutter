import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:battery_plus/battery_plus.dart';

import '../../theme/theme_controller.dart';
import 'announcements_screen.dart';
import 'insights_screen.dart';
import 'security_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.unknown;
  StreamSubscription<BatteryState>? _batterySubscription;

  @override
  void initState() {
    super.initState();
    _getBatteryState();
    _batterySubscription = _battery.onBatteryStateChanged.listen((state) {
      if (mounted) {
        setState(() => _batteryState = state);
      }
    });
  }

  Future<void> _getBatteryState() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() => _batteryLevel = level);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _batterySubscription?.cancel();
    super.dispose();
  }

  String _getBatteryStateString() {
    switch (_batteryState) {
      case BatteryState.charging:
        return 'Charging';
      case BatteryState.discharging:
        return 'Discharging';
      case BatteryState.full:
        return 'Full';
      case BatteryState.unknown:
      default:
        return 'Not Charging';
    }
  }

  IconData _getBatteryIcon() {
    if (_batteryState == BatteryState.charging) return Icons.battery_charging_full;
    if (_batteryLevel > 80) return Icons.battery_full;
    if (_batteryLevel > 50) return Icons.battery_5_bar;
    if (_batteryLevel > 20) return Icons.battery_3_bar;
    return Icons.battery_alert;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final themeCtrl = Provider.of<ThemeController>(context);

    final pageBg = isDark ? cs.surface : Colors.white;
    final cardBg = isDark ? cs.surfaceContainerHighest : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: isDark ? cs.surface : null,
        foregroundColor: isDark ? cs.onSurface : null,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Config Card
          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: SwitchListTile(
              secondary: Icon(
                themeCtrl.isDark ? Icons.dark_mode : Icons.light_mode,
                color: themeCtrl.isDark ? cs.secondary : cs.primary,
              ),
              title: const Text(
                'Dark Theme',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Toggle between light and dark modes'),
              value: themeCtrl.isDark,
              onChanged: (bool val) {
                themeCtrl.toggleTheme();
              },
            ),
          ),
          const SizedBox(height: 10),

          // Battery Status Card (Mobile Capability)
          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ListTile(
              leading: Icon(
                _getBatteryIcon(),
                color: cs.primary,
              ),
              title: const Text(
                'Battery Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Level: $_batteryLevel% • ${_getBatteryStateString()}'),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _getBatteryState,
                tooltip: 'Check Battery Level',
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Insights Card
          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ListTile(
              leading: Icon(
                Icons.bar_chart_rounded,
                color: cs.primary,
              ),
              title: const Text(
                'Insights',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Charts and spending breakdown'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InsightsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Security Card
          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ListTile(
              leading: Icon(
                Icons.security_outlined,
                color: cs.primary,
              ),
              title: const Text(
                'Security',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Password, privacy and account security'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SecurityScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Announcements Card (Master/Detail from External JSON)
          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ListTile(
              leading: Icon(
                Icons.campaign_outlined,
                color: cs.primary,
              ),
              title: const Text(
                'System Announcements',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('View system logs and latest updates'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // About Card
          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(
                'About',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('PayPatch v1.0.0 • Split wise smart client'),
            ),
          ),
        ],
      ),
    );
  }
}
