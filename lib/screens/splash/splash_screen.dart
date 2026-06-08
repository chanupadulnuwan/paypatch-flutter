import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/onboarding_prefs.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _mottoCtrl;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );

    _mottoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoCtrl.forward();

    // show motto slightly later
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      _mottoCtrl.forward();
    });

    // go to login or home after ~4 seconds (visible)
    Future.delayed(const Duration(milliseconds: 4000), () async {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Widget target = const LoginScreen();
      if (auth.isAuthenticated) {
        final hasSeenOnboarding = await OnboardingPrefs.hasSeenForUser(
          auth.user,
        );
        if (!mounted) return;
        target = hasSeenOnboarding
            ? const HomeScreen()
            : const OnboardingScreen();
      }
      Navigator.of(context).pushReplacement(_slowFadeRoute(target));
    });
  }

  PageRouteBuilder _slowFadeRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 900),
      reverseTransitionDuration: const Duration(milliseconds: 900),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _mottoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Each char pops in one-by-one
    Widget animatedWord(String word, Color color, {required int startIndex}) {
      final chars = word.split('');

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(chars.length, (i) {
          final charIndex = startIndex + i;

          // Stagger timing for each letter
          final start = (charIndex * 0.08).clamp(0.0, 0.95);
          final end = (start + 0.35).clamp(0.0, 1.0);

          final anim = CurvedAnimation(
            parent: _logoCtrl,
            curve: Interval(start, end, curve: Curves.elasticOut),
          );

          return AnimatedBuilder(
            animation: anim,
            builder: (_, _) {
              final scale = 0.2 + (0.8 * anim.value); // pop effect
              final opacity = anim.value.clamp(0.0, 1.0);

              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.5),
                    child: Text(
                      chars[i],
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                        color: color,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PayPatch logo (animated letter by letter)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                animatedWord('Pay', cs.primary, startIndex: 0),
                const SizedBox(width: 6),
                animatedWord('Patch', cs.secondary, startIndex: 3),
              ],
            ),

            const SizedBox(height: 14),

            // Motto fades in later
            FadeTransition(
              opacity: CurvedAnimation(parent: _mottoCtrl, curve: Curves.easeOut),
              child: Text(
                'Split smart. Settle fast.',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.65),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // small loading indicator (subtle)
            FadeTransition(
              opacity: CurvedAnimation(
                parent: _logoCtrl,
                curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
              ),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
