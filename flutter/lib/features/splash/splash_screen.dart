// flutter/lib/features/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../map/map_screen.dart';
import '../auth/login_screen.dart';

const _neon  = Color(0xFFC8F000);
const _muted = Color(0x59FFFFFF);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _runnerCtrl;
  late AnimationController _contentCtrl;
  late AnimationController _footCtrl;

  late Animation<double> _runnerBob;
  late Animation<double> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<double> _subFade;
  late Animation<double> _dotsFade;

  @override
  void initState() {
    super.initState();

    // 🏃 통통 바운스
    _runnerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);

    _runnerBob = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _runnerCtrl, curve: Curves.easeInOut),
    );

    // 발자국 애니
    _footCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // 텍스트 페이드인
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _titleSlide = Tween<double>(begin: 14, end: 0).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _subFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );
    _dotsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // 2초 후 다음 화면으로
    Future.delayed(const Duration(milliseconds: 2200), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final isLoggedIn =
        Supabase.instance.client.auth.currentSession != null;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) =>
            isLoggedIn ? const MapScreen() : const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _runnerCtrl.dispose();
    _contentCtrl.dispose();
    _footCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A0A), Color(0xFF141414)],
          ),
        ),
        child: Stack(
          children: [
            // 속도선 배경
            Positioned.fill(child: CustomPaint(painter: _SpeedLinePainter())),

            // 중앙 콘텐츠
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🏃 바운스
                  AnimatedBuilder(
                    animation: _runnerBob,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, _runnerBob.value),
                      child: const Text('🏃',
                          style: TextStyle(fontSize: 90)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 발자국 행진
                  SizedBox(
                    height: 28,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        return AnimatedBuilder(
                          animation: _footCtrl,
                          builder: (_, __) {
                            final t = (_footCtrl.value - i * 0.16)
                                .clamp(0.0, 1.0);
                            final opacity = t < 0.3
                                ? t / 0.3
                                : t < 0.7
                                    ? 1.0
                                    : (1.0 - t) / 0.3;
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              child: Opacity(
                                opacity: opacity.clamp(0.0, 1.0),
                                child: const Text('👣',
                                    style: TextStyle(fontSize: 16)),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 앱 이름
                  AnimatedBuilder(
                    animation: _contentCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _titleFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _titleSlide.value),
                        child: const Text(
                          '내땅내밟',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: _neon,
                            letterSpacing: -2,
                            shadows: [
                              Shadow(
                                color: Color(0x60C8F000),
                                offset: Offset(0, 4),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 서브타이틀
                  AnimatedBuilder(
                    animation: _subFade,
                    builder: (_, __) => Opacity(
                      opacity: _subFade.value,
                      child: const Text(
                        'MY LAND · MY RUN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _muted,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 44),

                  // 점 3개
                  AnimatedBuilder(
                    animation: _dotsFade,
                    builder: (_, __) => Opacity(
                      opacity: _dotsFade.value,
                      child: const _LoadingDots(),
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

// 점 3개 로딩
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
            final scale = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.3);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.5),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _neon.withValues(
                    alpha: (0.3 + scale * 0.7).clamp(0.0, 1.0)),
                shape: BoxShape.circle,
              ),
              transform: Matrix4.diagonal3Values(
                  scale.toDouble(), scale.toDouble(), 1.0),
              transformAlignment: Alignment.center,
            );
          },
        );
      }),
    );
  }
}

// 배경 속도선
class _SpeedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _neon.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.44)
      ..lineTo(size.width, size.height * 0.38)
      ..lineTo(size.width, size.height * 0.46)
      ..lineTo(0, size.height * 0.52)
      ..close();
    canvas.drawPath(path1, paint);

    final paint2 = Paint()
      ..color = _neon.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    final path2 = Path()
      ..moveTo(0, size.height * 0.54)
      ..lineTo(size.width, size.height * 0.50)
      ..lineTo(size.width, size.height * 0.54)
      ..lineTo(0, size.height * 0.58)
      ..close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(_) => false;
}
