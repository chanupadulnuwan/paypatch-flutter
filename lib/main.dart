import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'providers/auth_provider.dart';
import 'providers/groups_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/announcements_provider.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PayPatchApp());
}

class PayPatchApp extends StatefulWidget {
  const PayPatchApp({super.key});

  static _PayPatchAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_PayPatchAppState>()!;

  @override
  State<PayPatchApp> createState() => _PayPatchAppState();
}

class _PayPatchAppState extends State<PayPatchApp> {
  final ThemeController controller = ThemeController();

  @override
  void initState() {
    controller.addListener(() => setState(() {}));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: controller),
        ChangeNotifierProvider<ConnectivityProvider>(
          create: (_) => ConnectivityProvider(),
        ),
        ChangeNotifierProvider<AnnouncementsProvider>(
          create: (_) => AnnouncementsProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, GroupsProvider>(
          create: (context) => GroupsProvider(
            Provider.of<AuthProvider>(context, listen: false).token,
          ),
          update: (context, auth, previous) => GroupsProvider(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, FriendsProvider>(
          create: (context) => FriendsProvider(
            Provider.of<AuthProvider>(context, listen: false).token,
          ),
          update: (context, auth, previous) => FriendsProvider(auth.token),
        ),
      ],
      child: MaterialApp(
        title: 'PayPatch',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: controller.themeMode,
        home: const SplashScreen(),
      ),
    );
  }
}
