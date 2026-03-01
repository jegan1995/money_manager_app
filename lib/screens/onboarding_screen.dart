// lib/screens/onboarding_screen.dart
// 5-page animated onboarding — shown only on first install.
// Each page has: gradient background, illustration icon,
// animated title, subtitle, and page indicator dots.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/onboarding_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';

// ── Slide data ───────────────────────────────────────────────────────────────
class _Slide {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String emoji;

  const _Slide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.emoji,
  });
}

const _slides = [
  _Slide(
    title: 'Welcome to\nMoney Manager',
    subtitle: 'Take full control of your finances.\nTrack every rupee, every day.',
    icon: Icons.account_balance_wallet_rounded,
    gradient: [Color(0xFF667eea), Color(0xFF764ba2)],
    emoji: '💰',
  ),
  _Slide(
    title: 'Track Every\nTransaction',
    subtitle: 'Log income, expenses and transfers\nin seconds. Never miss a payment.',
    icon: Icons.receipt_long_rounded,
    gradient: [Color(0xFF11998e), Color(0xFF38ef7d)],
    emoji: '📊',
  ),
  _Slide(
    title: 'Smart Budget\nPlanning',
    subtitle: 'Set monthly budgets per category.\nGet alerts before you overspend.',
    icon: Icons.pie_chart_rounded,
    gradient: [Color(0xFFf093fb), Color(0xFFf5576c)],
    emoji: '🎯',
  ),
  _Slide(
    title: 'Grow Your\nSavings & Goals',
    subtitle: 'Set financial goals and track\nyour progress month by month.',
    icon: Icons.emoji_events_rounded,
    gradient: [Color(0xFF4facfe), Color(0xFF00f2fe)],
    emoji: '🏆',
  ),
  _Slide(
    title: 'Family Finance\nTogether',
    subtitle: 'Share finances with family.\nEveryone stays on the same page.',
    icon: Icons.people_alt_rounded,
    gradient: [Color(0xFFf77062), Color(0xFFfe5196)],
    emoji: '👨‍👩‍👧‍👦',
  ),
];

// ── Main widget ──────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  // onComplete: called instead of Navigator.push — lets AuthWrapper
  // switch screens via setState (no navigator stack conflict on Android)
  final VoidCallback? onComplete;
  const OnboardingScreen({super.key, this.onComplete});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _current = 0;

  // Per-slide animation controllers
  late AnimationController _iconCtrl;
  late AnimationController _textCtrl;
  late Animation<double> _iconScale;
  late Animation<double> _iconFloat;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _textCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);

    _iconScale = CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut);
    _iconFloat = Tween<double>(begin: 0, end: 8).animate(CurvedAnimation(
        parent: _iconCtrl, curve: Curves.easeInOut));
    _textFade  = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _playAnimations();
  }

  void _playAnimations() {
    _iconCtrl.reset();
    _textCtrl.reset();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _iconCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _textCtrl.forward();
    });
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    _textCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    HapticFeedback.selectionClick();
    _pageCtrl.animateToPage(page,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut);
  }

  void _next() {
    if (_current < _slides.length - 1) {
      _goToPage(_current + 1);
    }
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await OnboardingService.markComplete();
    if (!mounted) return;
    // Use callback if AuthWrapper provided one (no navigator conflict)
    // Falls back to Navigator.pushReplacement for standalone use
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_current];
    final isLast = _current == _slides.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: slide.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            // ── Skip button (top right) ────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Skip',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),

            // ── Page view ──────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (i) {
                  setState(() => _current = i);
                  _playAnimations();
                },
                itemBuilder: (_, i) => _SlideView(
                  slide:      _slides[i],
                  iconScale:  _iconScale,
                  iconFloat:  _iconFloat,
                  textFade:   _textFade,
                  textSlide:  _textSlide,
                ),
              ),
            ),

            // ── Dots ───────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _current == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _current == i
                        ? Colors.white
                        : Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // ── Bottom buttons ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: isLast
                  ? _LastPageButtons(onFinish: _finish)
                  : SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: slide.gradient[0],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Next',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: slide.gradient[0])),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded,
                                color: slide.gradient[0], size: 20),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 36),
          ]),
        ),
      ),
    );
  }
}

// ── Individual slide ─────────────────────────────────────────────────────────
class _SlideView extends StatelessWidget {
  final _Slide slide;
  final Animation<double> iconScale;
  final Animation<double> iconFloat;
  final Animation<double> textFade;
  final Animation<Offset>  textSlide;

  const _SlideView({
    required this.slide,
    required this.iconScale,
    required this.iconFloat,
    required this.textFade,
    required this.textSlide,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Floating icon illustration ──────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([iconScale, iconFloat]),
            builder: (_, __) => Transform.translate(
              offset: Offset(0, -iconFloat.value),
              child: ScaleTransition(
                scale: iconScale,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.25), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(slide.emoji,
                          style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 4),
                      Icon(slide.icon,
                          color: Colors.white.withOpacity(0.6),
                          size: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 48),

          // ── Title & subtitle ────────────────────────────────────────────
          FadeTransition(
            opacity: textFade,
            child: SlideTransition(
              position: textSlide,
              child: Column(children: [
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  slide.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Last page: Get Started + Sign In buttons ─────────────────────────────────
class _LastPageButtons extends StatelessWidget {
  final VoidCallback onFinish;
  const _LastPageButtons({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Primary: Create account
      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: () async {
            await OnboardingService.markComplete();
            if (!context.mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFFf77062),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rocket_launch_rounded, size: 20),
              SizedBox(width: 8),
              Text('Get Started — It\'s Free',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Secondary: Already have account
      SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: () async {
            await OnboardingService.markComplete();
            if (!context.mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('I already have an account',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ),
    ]);
  }
}