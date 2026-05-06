import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../routes.dart';
import '../shared/utils/app_navigator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const Color _primary = Color(0xFF7B1FA2);
  static const Color _deep = Color(0xFF4A148C);

  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingPage> _pages = const [
    OnboardingPage(
      title: 'Create Your Story World',
      description:
          'Write magical stories, shape characters, and let your imagination lead every page.',
      animationAsset: 'assets/lottie/BOOK WALKING.json',
      accentColor: Color(0xFF7B1FA2),
    ),
    OnboardingPage(
      title: 'Speak, Listen, and Improve',
      description:
          'Use your voice to write ideas, then listen back with read-aloud support.',
      animationAsset: '',
      accentColor: Color(0xFF1565C0),
      visualType: OnboardingVisualType.voiceMagicPen,
    ),
    OnboardingPage(
      title: 'Share Safely and Shine',
      description:
          'Publish stories, earn badges, collect ratings, and build your own e-books.',
      animationAsset: 'assets/lottie/Celebrations.json',
      accentColor: Color(0xFFF57C00),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      AppNavigator.pushReplacementNamed(context, AppRoutes.signup);
    }
  }

  void _nextPage() {
    if (_currentIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/LOGOpIXIEPEN__1_-removebg-preview.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PixiePen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _deep,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Shift, Shine, Storytime',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  return _OnboardingSlide(page: _pages[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: ExpandingDotsEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 4,
                      activeDotColor: page.accentColor,
                      dotColor: const Color(0xFFE4D6EE),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _currentIndex == _pages.length - 1
                            ? 'Start Creating'
                            : 'Next',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final OnboardingPage page;

  const _OnboardingSlide({required this.page});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final visualHeight = (size.height * 0.36).clamp(220.0, 320.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            height: visualHeight,
            decoration: BoxDecoration(
              color: page.accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: page.visualType == OnboardingVisualType.voiceMagicPen
                ? const Center(child: _VoiceMagicPenVisual())
                : Lottie.asset(
                    page.animationAsset,
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
          ),
          const SizedBox(height: 28),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 16,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceMagicPenVisual extends StatefulWidget {
  const _VoiceMagicPenVisual();

  @override
  State<_VoiceMagicPenVisual> createState() => _VoiceMagicPenVisualState();
}

class _VoiceMagicPenVisualState extends State<_VoiceMagicPenVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 260,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final wave = Curves.easeInOut.transform(
            t < 0.5 ? t * 2 : (1 - t) * 2,
          );

          return Stack(
            alignment: Alignment.center,
            children: [
              _PulseRing(
                size: 210 + (wave * 16),
                color: const Color(0xFF00ACC1),
                opacity: 0.14,
              ),
              _PulseRing(
                size: 150 + (wave * 22),
                color: const Color(0xFFEC407A),
                opacity: 0.12,
              ),
              Transform.translate(
                offset: Offset(0, -6 * wave),
                child: const _VoiceBubble(),
              ),
              Transform.translate(
                offset: Offset(-44, 16 - (wave * 4)),
                child: const _MicOrb(),
              ),
              Transform.translate(
                offset: Offset(48, 18 + (wave * 4)),
                child: Transform.rotate(
                  angle: -0.55 + (wave * 0.08),
                  child: const _MagicPen(),
                ),
              ),
              Positioned(
                top: 48 + (wave * 6),
                right: 50,
                child: const _Spark(color: Color(0xFFFF9800), size: 18),
              ),
              Positioned(
                bottom: 48 - (wave * 5),
                left: 54,
                child: const _Spark(color: Color(0xFFEC407A), size: 14),
              ),
              Positioned(
                top: 76 - (wave * 5),
                left: 70,
                child: const _Spark(color: Color(0xFF00ACC1), size: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _PulseRing({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: opacity), width: 10),
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(46),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          final heights = [24.0, 42.0, 58.0, 42.0, 24.0];
          final colors = [
            const Color(0xFF7B1FA2),
            const Color(0xFF00ACC1),
            const Color(0xFFEC407A),
            const Color(0xFFFF9800),
            const Color(0xFF7B1FA2),
          ];
          return Container(
            width: 10,
            height: heights[index],
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: colors[index],
              borderRadius: BorderRadius.circular(20),
            ),
          );
        }),
      ),
    );
  }
}

class _MicOrb extends StatelessWidget {
  const _MicOrb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: const Color(0xFF7B1FA2),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(Icons.mic, color: Colors.white, size: 44),
    );
  }
}

class _MagicPen extends StatelessWidget {
  const _MagicPen();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00ACC1), Color(0xFFEC407A), Color(0xFFFF9800)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC407A).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(right: 10),
          child: Icon(Icons.edit, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  final Color color;
  final double size;

  const _Spark({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.auto_awesome, color: color, size: size);
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String animationAsset;
  final Color accentColor;
  final OnboardingVisualType visualType;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.animationAsset,
    required this.accentColor,
    this.visualType = OnboardingVisualType.lottie,
  });
}

enum OnboardingVisualType { lottie, voiceMagicPen }
