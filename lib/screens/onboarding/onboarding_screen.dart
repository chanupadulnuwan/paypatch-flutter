import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/onboarding_prefs.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _floatController;

  static const List<_OnboardingSlideData> _slides = [
    _OnboardingSlideData(
      title: 'Create groups easily',
      subtitle:
          'Start trips, events, or shared plans\nin seconds. Keep everyone organized\nin one place.',
      imageAsset: 'assets/images/onboarding/slide_1_create_groups.png',
    ),
    _OnboardingSlideData(
      title: 'Add your friends',
      subtitle:
          'Invite friends by name, email, or username\nand build your group in just a few taps.',
      imageAsset: 'assets/images/onboarding/slide_2_add_friends.png',
    ),
    _OnboardingSlideData(
      title: 'Add expenses',
      subtitle:
          'Log bills, meals, travel, and more\nwith simple entries that everyone\ncan track clearly.',
      imageAsset: 'assets/images/onboarding/slide_3_add_expenses.png',
    ),
    _OnboardingSlideData(
      title: 'Split as you wish',
      subtitle:
          'Share costs equally, by exact amounts,\nor by percentages - whichever\nworks best for your group.',
      imageAsset: 'assets/images/onboarding/slide_4_split.png',
    ),
    _OnboardingSlideData(
      title: 'Settle up',
      subtitle:
          'Track who owes what, settle balances\nsmoothly, and enjoy your time together.\nYou\'re ready - enjoy Pay Patch!',
      imageAsset: 'assets/images/onboarding/slide_5_settle.png',
      buttonLabel: 'Get Started',
    ),
  ];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat(reverse: true);
    _pageController.addListener(_syncPageIndex);
  }

  @override
  void dispose() {
    _pageController
      ..removeListener(_syncPageIndex)
      ..dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _syncPageIndex() {
    if (!_pageController.hasClients) {
      return;
    }

    final nextIndex = (_pageController.page ?? 0).round();
    if (nextIndex != _currentIndex && mounted) {
      setState(() => _currentIndex = nextIndex);
    }
  }

  Future<void> _finishOnboarding() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await OnboardingPrefs.markSeenForUser(auth.user);
    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _goNext() async {
    if (_currentIndex == _slides.length - 1) {
      await _finishOnboarding();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 760),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  double _pageOffsetFor(int index) {
    if (!_pageController.hasClients) {
      return (index - _currentIndex).toDouble();
    }

    return index - (_pageController.page ?? _currentIndex.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final isLastSlide = _currentIndex == _slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 44),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: [
                  const _PayPatchWordmark(),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: isLastSlide
                        ? const SizedBox.shrink()
                        : TextButton(
                            key: const ValueKey('skip-onboarding'),
                            onPressed: _finishOnboarding,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0B6B45),
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return AnimatedBuilder(
                    animation: Listenable.merge([
                      _pageController,
                      _floatController,
                    ]),
                    builder: (context, child) {
                      final pageOffset = _pageOffsetFor(index);
                      final visibleAmount =
                          (1 - pageOffset.abs()).clamp(0.0, 1.0);

                      return _OnboardingSlideView(
                        slide: slide,
                        pageOffset: pageOffset,
                        visibleAmount: visibleAmount,
                        floatValue: _floatController.value,
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            const _SwipeHint(),
            const SizedBox(height: 24),
            _PageIndicatorRow(
              count: _slides.length,
              currentIndex: _currentIndex,
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B6B45),
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: const Color(0xFF0B6B45).withValues(alpha: 0.18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: _goNext,
                  child: Text(_slides[_currentIndex].buttonLabel ?? 'Next'),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({
    required this.slide,
    required this.pageOffset,
    required this.visibleAmount,
    required this.floatValue,
  });

  final _OnboardingSlideData slide;
  final double pageOffset;
  final double visibleAmount;
  final double floatValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleShift = pageOffset * 44;
    final subtitleShift = pageOffset * 28;
    final imageShift = pageOffset * 78;
    final titleOpacity = (0.24 + (visibleAmount * 0.76)).clamp(0.0, 1.0);
    final imageOpacity = (0.18 + (visibleAmount * 0.82)).clamp(0.0, 1.0);
    final imageScale = 0.92 + (visibleAmount * 0.08);
    final floatDy = math.sin(floatValue * math.pi * 2) * 6;
    final tilt = pageOffset * 0.045;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Transform.translate(
            offset: Offset(titleShift, 0),
            child: Opacity(
              opacity: titleOpacity,
              child: Text(
                slide.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: const Color(0xFF0B6B45),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Transform.translate(
            offset: Offset(subtitleShift, 0),
            child: Opacity(
              opacity: titleOpacity,
              child: Text(
                slide.subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF555555),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Transform.translate(
              offset: Offset(imageShift, floatDy),
              child: Opacity(
                opacity: imageOpacity,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateZ(tilt)
                    ..multiply(
                      Matrix4.diagonal3Values(imageScale, imageScale, 1),
                    ),
                  child: Center(
                    child: Container(
                      color: Colors.white,
                      constraints: const BoxConstraints(
                        maxWidth: 320,
                        maxHeight: 290,
                      ),
                      child: Image.asset(
                        slide.imageAsset,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayPatchWordmark extends StatelessWidget {
  const _PayPatchWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PayPatchMark(size: 34),
        const SizedBox(width: 12),
        Text(
          'Pay Patch',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF0B6B45),
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
        ),
      ],
    );
  }
}

class _PayPatchMark extends StatelessWidget {
  const _PayPatchMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.28;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: size * 0.62,
              height: size * 0.62,
              decoration: BoxDecoration(
                color: const Color(0xFFF2BF89),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(radius),
                  bottomLeft: Radius.circular(radius),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Container(
              width: size * 0.56,
              height: size * 0.56,
              decoration: BoxDecoration(
                color: const Color(0xFF0C6A48),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: size * 0.36,
              height: size * 0.36,
              decoration: BoxDecoration(
                color: const Color(0xFFAACBBC),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.west_rounded,
              color: Color(0xFF0B6B45),
              size: 40,
            ),
            SizedBox(width: 8),
            Icon(
              Icons.touch_app_rounded,
              color: Color(0xFF0B6B45),
              size: 40,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Swipe to explore',
          style: TextStyle(
            color: const Color(0xFF555555),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _PageIndicatorRow extends StatelessWidget {
  const _PageIndicatorRow({
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        final size = isActive ? 11.0 : 10.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.only(
            left: index == 0 ? 0.0 : 12.0,
          ),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? const Color(0xFF0B6B45)
                : const Color(0xFFD7E8DE),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF0B6B45).withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    this.buttonLabel,
  });

  final String title;
  final String subtitle;
  final String imageAsset;
  final String? buttonLabel;
}
