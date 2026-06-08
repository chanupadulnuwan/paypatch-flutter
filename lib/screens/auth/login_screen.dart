import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/auth_provider.dart';
import '../../utils/onboarding_prefs.dart';
import '../../widgets/custom_alert.dart';
import '../../widgets/google_logo.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      showCustomAlert(context, 'Please fill in all fields.');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      final success = await auth.login(email, password);
      if (success && mounted) {
        final hasSeenOnboarding = await OnboardingPrefs.hasSeenForUser(
          auth.user,
        );
        if (!mounted) {
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => hasSeenOnboarding
                ? const HomeScreen()
                : const OnboardingScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCustomAlert(
          context,
          e.toString().replaceAll('Exception: ', '').trim(),
        );
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    showBlockingStatusDialog(
      context,
      title: 'Connecting Google',
      message: 'Signing you in with the PayPatch Google demo profile...',
    );

    try {
      final success = await auth.loginWithGoogle();
      if (mounted) {
        Navigator.pop(context);
        if (success) {
          final hasSeenOnboarding = await OnboardingPrefs.hasSeenForUser(
            auth.user,
          );
          if (!mounted) {
            return;
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => hasSeenOnboarding
                  ? const HomeScreen()
                  : const OnboardingScreen(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        showCustomAlert(
          context,
          e.toString().replaceAll('Exception: ', '').trim(),
        );
      }
    }
  }

  void _showIpConfigDialog(BuildContext context) {
    final urlCtrl = TextEditingController(text: AppConfig.baseUrl);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.settings_ethernet, color: Color(0xFF4F7D6A)),
            SizedBox(width: 8),
            Text(
              'Server API URL Config',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure the full API URL of your Laravel server. Make sure your phone and computer are on the same Wi-Fi.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'Examples:\n'
                '- XAMPP Apache: http://<computer-ip>/CB016173/paypatch-laravel/public/api\n'
                '- php artisan serve: http://<computer-ip>:8000/api',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Laravel API Base URL',
                  hintText:
                      'http://192.168.1.88/CB016173/paypatch-laravel/public/api',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F7D6A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final newUrl = urlCtrl.text.trim();
              if (newUrl.isNotEmpty) {
                await AppConfig.saveIp(newUrl);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  showCustomAlert(
                    context,
                    'Server Base URL updated successfully to:\n${AppConfig.baseUrl}',
                    isSuccess: true,
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final auth = Provider.of<AuthProvider>(context);

    final panelColor = theme.brightness == Brightness.dark
        ? cs.primary.withValues(alpha: 0.35)
        : cs.primary.withValues(alpha: 0.92);

    return Scaffold(
      backgroundColor: panelColor,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                Widget buildTopImage({BoxFit fit = BoxFit.cover}) {
                  return Image.asset(
                    'assets/images/cover.jpg',
                    fit: fit,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: cs.primary.withValues(alpha: 0.25),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          size: 48,
                        ),
                      );
                    },
                  );
                }

                Widget buildForm({required bool isWide}) {
                  final contentMaxW = isWide ? 520.0 : double.infinity;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxW),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWide ? 40 : 18,
                          vertical: isWide ? 40 : 0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              'Welcome!',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: cs.onSurface.withValues(alpha: 0.7),
                                ),
                                hintText: 'Email or Username',
                                filled: true,
                                fillColor: cs.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: cs.onSurface.withValues(alpha: 0.7),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: cs.onSurface.withValues(alpha: 0.7),
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                                hintText: 'Password',
                                filled: true,
                                fillColor: cs.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: cs.secondary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed:
                                    auth.isLoading ? null : _handleLogin,
                                child: auth.isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text('Login'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: cs.onPrimary.withValues(alpha: 0.3),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    'OR',
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          cs.onPrimary.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: cs.onPrimary.withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1F1F1F),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                minimumSize: const Size(double.infinity, 52),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                              icon: const GoogleLogo(size: 20),
                              label: const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              onPressed:
                                  auth.isLoading ? null : _handleGoogleLogin,
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Wrap(
                                crossAxisAlignment:
                                    WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    "If you don't have an account ",
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          cs.onPrimary.withValues(alpha: 0.9),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'sign up',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: cs.secondary,
                                        fontWeight: FontWeight.w800,
                                        decoration: TextDecoration.underline,
                                        decorationColor: cs.secondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                if (isDesktop) {
                  return Row(
                    children: [
                      Expanded(
                        child: Container(
                          color: panelColor,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: buildForm(isWide: true),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: panelColor,
                          child: buildTopImage(fit: BoxFit.cover),
                        ),
                      ),
                    ],
                  );
                }

                const headerH = 260.0;
                const overlap = 60.0;

                return Column(
                  children: [
                    SizedBox(
                      height: headerH,
                      width: double.infinity,
                      child: buildTopImage(),
                    ),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(0, -overlap),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: panelColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(34),
                              topRight: Radius.circular(34),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(0, 22, 0, 24),
                            child: buildForm(isWide: false),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            Positioned(
              top: 12,
              right: 12,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () => _showIpConfigDialog(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
