import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'dashboard_shell.dart';
import 'api_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _hero = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  final ScrollController _scroll = ScrollController();
  bool _hoverEnter = false;
  Offset _pointer = Offset.zero;

  void _enterCampus() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 850),
        pageBuilder: (_, animation, __) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: .96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  void _discover() {
    _scroll.animateTo(
      MediaQuery.sizeOf(context).height * .92,
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _hero.dispose();
    _motion.dispose();
    _pulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF07142E),
      body: MouseRegion(
        onHover: (event) => setState(() => _pointer = event.localPosition),
        child: AnimatedBuilder(
          animation: Listenable.merge([_hero, _motion, _pulse]),
          builder: (context, _) {
            final entrance = Curves.easeOutCubic.transform(_hero.value);
            final drift = _motion.value * math.pi * 2;
            final px = wide ? ((_pointer.dx / size.width) - .5) : 0.0;
            final py = wide ? ((_pointer.dy / size.height) - .5) : 0.0;

            return Stack(
              children: [
                SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    children: [
                      SizedBox(
                        height: size.height,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0B1F3A),
                                    Color(0xFF172B63),
                                    Color(0xFF07142E),
                                  ],
                                ),
                              ),
                            ),
                            CustomPaint(
                              painter: _ParticleFieldPainter(
                                progress: drift,
                                pointer: Offset(px, py),
                              ),
                            ),
                            Positioned(
                              top: -170 + 35 * math.sin(drift),
                              right: -120,
                              child: _MegaGlow(
                                size: wide ? 520 : 360,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                            Positioned(
                              bottom: -220 + 28 * math.cos(drift),
                              left: -160,
                              child: _MegaGlow(
                                size: wide ? 520 : 390,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                            SafeArea(
                              child: Column(
                                children: [
                                  _EnterpriseNav(
                                    onSignIn: _enterCampus,
                                    onDiscover: _discover,
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: wide ? 54 : 22,
                                      ),
                                      child: Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 1280,
                                          ),
                                          child: wide
                                              ? Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 53,
                                                      child: Transform.translate(
                                                        offset: Offset(
                                                          -px * 14,
                                                          28 * (1 - entrance) - py * 5,
                                                        ),
                                                        child: _CinematicHero(
                                                          entrance: entrance,
                                                          hover: _hoverEnter,
                                                          onHover: (v) => setState(() => _hoverEnter = v),
                                                          onEnter: _enterCampus,
                                                          onDiscover: _discover,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 30),
                                                    Expanded(
                                                      flex: 47,
                                                      child: Transform.translate(
                                                        offset: Offset(
                                                          px * 20,
                                                          py * 12,
                                                        ),
                                                        child: _HolographicCampus(
                                                          progress: drift,
                                                          pulse: _pulse.value,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : SingleChildScrollView(
                                                  padding: const EdgeInsets.only(top: 12, bottom: 30),
                                                  child: Column(
                                                    children: [
                                                      _HolographicCampus(progress: drift, pulse: _pulse.value),
                                                      const SizedBox(height: 32),
                                                      _CinematicHero(
                                                        entrance: entrance,
                                                        hover: _hoverEnter,
                                                        onHover: (v) => setState(() => _hoverEnter = v),
                                                        onEnter: _enterCampus,
                                                        onDiscover: _discover,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _discover,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 18),
                                      child: Column(
                                        children: [
                                          const Text(
                                            'SCROLL TO EXPLORE',
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 2.4,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: Colors.white.withOpacity(.65),
                                            size: 22,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const _ExperienceSection(),
                      _FinalCTA(onEnter: _enterCampus),
                    ],
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: _LiveBadge(pulse: _pulse.value),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EnterpriseNav extends StatelessWidget {
  final VoidCallback onSignIn;
  final VoidCallback onDiscover;
  const _EnterpriseNav({required this.onSignIn, required this.onDiscover});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 16, wide ? 28 : 16, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20)],
            ),
            child: const Icon(Icons.account_balance_rounded, color: navy),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GNITS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.8)),
              Text('SMART CAMPUS', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, fontSize: 8, letterSpacing: 1.5)),
            ],
          ),
          const Spacer(),
          if (wide) ...[
            _NavLink('Experience', onDiscover),
            const SizedBox(width: 8),
            _NavLink('Campus Intelligence', onDiscover),
            const SizedBox(width: 18),
          ],
          OutlinedButton(
            onPressed: onSignIn,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(.22)),
              backgroundColor: Colors.white.withOpacity(.06),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
            child: const Text('SIGN IN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, this.onTap);
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

class _CinematicHero extends StatelessWidget {
  final double entrance;
  final bool hover;
  final ValueChanged<bool> onHover;
  final VoidCallback onEnter;
  final VoidCallback onDiscover;
  const _CinematicHero({required this.entrance, required this.hover, required this.onHover, required this.onEnter, required this.onDiscover});

  @override
  Widget build(BuildContext context) {
    final t1 = Curves.easeOutCubic.transform((entrance * 1.15).clamp(0.0, 1.0).toDouble());
    final t2 = Curves.easeOutCubic.transform(((entrance - .16) / .84).clamp(0.0, 1.0).toDouble());
    final t3 = Curves.easeOutCubic.transform(((entrance - .32) / .68).clamp(0.0, 1.0).toDouble());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: t1,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - t1)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF67E8F9).withOpacity(.10),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0xFF67E8F9).withOpacity(.25)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                _PulsingDot(),
                SizedBox(width: 8),
                Text('GNITS DIGITAL CAMPUS', style: TextStyle(color: Color(0xFFBAE6FD), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.7)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Opacity(
          opacity: t2,
          child: Transform.translate(
            offset: Offset(0, 42 * (1 - t2)),
            child: Text(
              'One campus.\nOne connected\nexperience.',
              style: TextStyle(color: Colors.white, fontSize: MediaQuery.sizeOf(context).width < 520 ? 36 : 48, height: .99, fontWeight: FontWeight.w900, letterSpacing: -1.6),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Opacity(
          opacity: t3,
          child: Transform.translate(
            offset: Offset(0, 35 * (1 - t3)),
            child: Text(
              'A connected workspace for classrooms, timetables, live occupancy, bookings and campus operations — designed around the way GNITS works.',
              style: TextStyle(color: Colors.white60, fontSize: MediaQuery.sizeOf(context).width < 520 ? 12.5 : 14, height: 1.7),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Opacity(
          opacity: t3,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => onHover(true),
                onExit: (_) => onHover(false),
                child: AnimatedScale(
                  scale: hover ? 1.035 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: FilledButton.icon(
                    onPressed: onEnter,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 3),
                      child: Text('ENTER SMART CAMPUS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .8)),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: navy,
                      elevation: hover ? 22 : 8,
                      shadowColor: const Color(0x997C3AED),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onDiscover,
                icon: const Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 19),
                label: const Text('Explore the experience', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Opacity(
          opacity: t3,
          child: const Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _FeatureChip(icon: Icons.meeting_room_outlined, text: 'Live occupancy'),
              _FeatureChip(icon: Icons.table_view_outlined, text: 'Smart timetable'),
              _FeatureChip(icon: Icons.event_available_outlined, text: 'Room booking'),
              _FeatureChip(icon: Icons.analytics_outlined, text: 'Campus analytics'),
            ],
          ),
        ),
      ],
    );
  }
}

class _HolographicCampus extends StatelessWidget {
  final double progress;
  final double pulse;
  const _HolographicCampus({required this.progress, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return SizedBox(
      height: wide ? 500 : 285,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: progress * .15,
            child: CustomPaint(
              size: Size(wide ? 540 : 300, wide ? 500 : 285),
              painter: _Campus3DPainter(progress: progress, pulse: pulse),
            ),
          ),
          Positioned(
            top: wide ? 22 : 4,
            right: wide ? 8 : 0,
            child: _FloatingGlassCard(icon: Icons.wifi_rounded, title: 'CAMPUS NETWORK', value: 'CONNECTED'),
          ),
          Positioned(
            bottom: wide ? 28 : 2,
            left: wide ? 4 : 0,
            child: _FloatingGlassCard(icon: Icons.bolt_rounded, title: 'CAMPUS PULSE', value: 'LIVE'),
          ),
          Positioned(
            top: wide ? 110 : 72,
            left: wide ? 10 : 0,
            child: _MetricOrb(label: 'ROOMS', value: 'LIVE', progress: pulse),
          ),
          Positioned(
            bottom: wide ? 105 : 68,
            right: wide ? 18 : 0,
            child: _MetricOrb(label: 'TIMETABLE', value: 'SYNC', progress: 1 - pulse),
          ),
        ],
      ),
    );
  }
}

class _Campus3DPainter extends CustomPainter {
  final double progress;
  final double pulse;
  const _Campus3DPainter({required this.progress, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 18);
    final scale = math.min(size.width, size.height) / 430;
    final grid = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = const Color(0x225FA8FF);
    final glow = Paint()..style = PaintingStyle.fill..color = const Color(0x102563EB);

    for (int i = 0; i < 9; i++) {
      final y = center.dy + (i - 4) * 24 * scale;
      canvas.drawLine(Offset(0, y), Offset(size.width, y + (i - 4) * 9), grid);
    }
    for (int i = -8; i <= 8; i++) {
      canvas.drawLine(center + Offset(i * 25 * scale, -180 * scale), center + Offset(i * 25 * scale, 180 * scale), grid);
    }

    canvas.drawCircle(center, 190 * scale, glow);
    canvas.drawCircle(center, 145 * scale, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = const Color(0x335BA8FF));
    canvas.drawCircle(center, 95 * scale, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = const Color(0x2240C9FF));

    final buildings = <_IsoBuilding>[
      _IsoBuilding(Offset(-105, -75), 1.0, 118, 88, const Color(0xFF4F46E5)),
      _IsoBuilding(Offset(15, -108), .92, 135, 105, const Color(0xFF2563EB)),
      _IsoBuilding(Offset(105, -15), .82, 92, 120, const Color(0xFF06B6D4)),
      _IsoBuilding(Offset(-70, 35), .74, 150, 72, const Color(0xFF1D4ED8)),
      _IsoBuilding(Offset(65, 70), .68, 118, 70, const Color(0xFF0E7490)),
    ];

    for (final b in buildings) {
      _drawBuilding(canvas, center + b.position * scale, b, scale);
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xAA60A5FA);
    final r = 178 * scale + 5 * math.sin(progress * 2);
    canvas.drawOval(Rect.fromCenter(center: center, width: r * 2, height: r * .56), ring);
    final angle = progress * math.pi * 2;
    final point = Offset(center.dx + r * math.cos(angle), center.dy + r * .28 * math.sin(angle));
    canvas.drawCircle(point, 6 + pulse * 4, Paint()..color = const Color(0xFFBAE6FD));
    canvas.drawCircle(point, 16 + pulse * 8, Paint()..color = const Color(0x2260A5FA));
  }

  void _drawBuilding(Canvas canvas, Offset base, _IsoBuilding b, double scale) {
    final w = b.width * scale;
    final h = b.height * scale;
    final d = 25 * scale;
    final top = Path()
      ..moveTo(base.dx, base.dy - h)
      ..lineTo(base.dx + w * .5, base.dy - h - d * .45)
      ..lineTo(base.dx + w, base.dy - h)
      ..lineTo(base.dx + w * .5, base.dy - h + d * .45)
      ..close();
    final left = Path()
      ..moveTo(base.dx, base.dy - h)
      ..lineTo(base.dx + w * .5, base.dy - h + d * .45)
      ..lineTo(base.dx + w * .5, base.dy + d * .45)
      ..lineTo(base.dx, base.dy)
      ..close();
    final right = Path()
      ..moveTo(base.dx + w * .5, base.dy - h + d * .45)
      ..lineTo(base.dx + w, base.dy - h)
      ..lineTo(base.dx + w, base.dy)
      ..lineTo(base.dx + w * .5, base.dy + d * .45)
      ..close();
    canvas.drawPath(left, Paint()..color = b.color.withOpacity(.62));
    canvas.drawPath(right, Paint()..color = b.color.withOpacity(.36));
    canvas.drawPath(top, Paint()..color = b.color.withOpacity(.90));

    final windows = Paint()..color = const Color(0x8893C5FD);
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        final x = base.dx + 12 * scale + col * 18 * scale;
        final y = base.dy - 20 * scale - row * 19 * scale;
        canvas.drawRect(Rect.fromLTWH(x, y, 7 * scale, 8 * scale), windows);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Campus3DPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.pulse != pulse;
}

class _IsoBuilding {
  final Offset position;
  final double depth;
  final double width;
  final double height;
  final Color color;
  const _IsoBuilding(this.position, this.depth, this.width, this.height, this.color);
}

class _FloatingGlassCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _FloatingGlassCard({required this.icon, required this.title, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.075),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(.13)),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 22)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: const Color(0x2260A5FA), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFFBAE6FD), size: 16)),
          const SizedBox(width: 9),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white38, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
          ]),
        ]),
      );
}

class _MetricOrb extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  const _MetricOrb({required this.label, required this.value, required this.progress});
  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: (progress - .5) * .12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xAA07142E),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0x335FA8FF)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Color(0xFFBAE6FD), fontSize: 10, fontWeight: FontWeight.w900)),
          ]),
        ),
      );
}

class _PulsingDot extends StatelessWidget {
  const _PulsingDot();
  @override
  Widget build(BuildContext context) => Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF34D399), boxShadow: [BoxShadow(color: Color(0x6634D399), blurRadius: 9, spreadRadius: 2)]));
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureChip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.055), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withOpacity(.10))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white60, size: 14), const SizedBox(width: 6), Text(text, style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700))]),
      );
}

class _LiveBadge extends StatelessWidget {
  final double pulse;
  const _LiveBadge({required this.pulse});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xCC061226), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0x3360A5FA))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Transform.scale(scale: .9 + pulse * .25, child: const _PulsingDot()),
          const SizedBox(width: 7),
          const Text('GNITS CAMPUS • LIVE', style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        ]),
      );
}

class _ParticleFieldPainter extends CustomPainter {
  final double progress;
  final Offset pointer;
  const _ParticleFieldPainter({required this.progress, required this.pointer});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < 75; i++) {
      final seed = i * 17.37;
      final x = ((math.sin(seed) + 1) / 2) * size.width + pointer.dx * (i.isEven ? 22 : -14);
      final y = ((math.cos(seed * 1.7) + 1) / 2) * size.height + math.sin(progress + seed) * 7;
      final radius = .5 + ((i % 4) * .35);
      paint.color = Colors.white.withOpacity(.10 + (i % 5) * .035);
      canvas.drawCircle(Offset(x % size.width, y % size.height), radius, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _ParticleFieldPainter oldDelegate) => true;
}

class _MegaGlow extends StatelessWidget {
  final double size;
  final Color color;
  const _MegaGlow({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(.09), boxShadow: [BoxShadow(color: color.withOpacity(.13), blurRadius: 120, spreadRadius: 40)]));
}

class _ExperienceSection extends StatelessWidget {
  const _ExperienceSection();
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: wide ? 70 : 24, vertical: 90),
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF07142E), Color(0xFF0B1F3A)])),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('THE GNITS CAMPUS, CONNECTED.', style: TextStyle(color: Color(0xFF67E8F9), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.2)),
          const SizedBox(height: 14),
          const Text('A connected campus interface.\nBuilt for everyday operations.', style: TextStyle(color: Colors.white, fontSize: 40, height: 1.03, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
          const SizedBox(height: 18),
          const SizedBox(width: 720, child: Text('Designed to make classroom availability feel visible, immediate and alive — while keeping the operational tools your college actually needs.', style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.7))),
          const SizedBox(height: 40),
          Wrap(spacing: 16, runSpacing: 16, children: const [
            _ExperienceCard(icon: Icons.bolt_rounded, number: '01', title: 'LIVE OCCUPANCY', text: 'See which classrooms are occupied or available from timetable-aware data.'),
            _ExperienceCard(icon: Icons.table_view_rounded, number: '02', title: 'SMART TIMETABLE', text: 'Upload schedules and turn them into a visual campus availability layer.'),
            _ExperienceCard(icon: Icons.auto_awesome_rounded, number: '03', title: 'CAMPUS VISIBILITY', text: 'Give Admin, Faculty and Students a clear view of the spaces around them.'),
          ]),
          const SizedBox(height: 46),
          const Wrap(spacing: 18, runSpacing: 18, children: [
            _StatFact('12.5', 'ACRE GREEN CAMPUS'),
            _StatFact('50+', 'SMART CLASSROOMS'),
            _StatFact('50+', 'STATE-OF-THE-ART LABS'),
            _StatFact('70K+', 'LIBRARY VOLUMES'),
            _StatFact('24×7', 'SECURITY'),
          ]),
        ]),
      ),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  final IconData icon;
  final String number;
  final String title;
  final String text;
  const _ExperienceCard({required this.icon, required this.number, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        width: 365,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.045), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(.09))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0x2260A5FA), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFFBAE6FD))), const Spacer(), Text(number, style: const TextStyle(color: Colors.white24, fontSize: 22, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 28),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.6)),
        ]),
      );
}

class _StatFact extends StatelessWidget {
  final String value;
  final String label;
  const _StatFact(this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13), decoration: BoxDecoration(color: Colors.white.withOpacity(.035), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(label, style: const TextStyle(color: Colors.white38, fontSize: 7.5, fontWeight: FontWeight.w800, letterSpacing: 1))]));
}

class _FinalCTA extends StatelessWidget {
  final VoidCallback onEnter;
  const _FinalCTA({required this.onEnter});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 90, 24, 70),
        decoration: const BoxDecoration(color: Color(0xFF07142E)),
        child: Column(children: [
          const Icon(Icons.account_balance_rounded, color: Color(0xFFBAE6FD), size: 36),
          const SizedBox(height: 18),
          const Text('Ready to enter the campus?', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 10),
          const Text('Your GNITS Smart Campus workspace is waiting.', style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 26),
          FilledButton.icon(onPressed: onEnter, icon: const Icon(Icons.arrow_forward_rounded), label: const Padding(padding: EdgeInsets.symmetric(vertical: 14, horizontal: 4), child: Text('ENTER SMART CAMPUS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .8))), style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))
        ]),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..forward();
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
  final user = TextEditingController();
  final pass = TextEditingController();
  String role = 'ADMIN';
  bool hide = true;

  @override
  void dispose() {
    _entrance.dispose();
    _ambient.dispose();
    user.dispose();
    pass.dispose();
    super.dispose();
  }

  bool _loading = false;

  Future<void> login() async {
    if (_loading) return;
    final u = user.text.trim().toLowerCase();
    final p = pass.text;
    if (u.isEmpty || p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your username and password.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': u, 'password': p, 'role': role}),
      ).timeout(const Duration(seconds: 12));

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (!mounted) return;
      if (response.statusCode == 200 && data['success'] == true) {
        final actualRole = (data['role'] ?? role).toString().toUpperCase();
        final actualUsername = (data['username'] ?? u).toString();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(role: actualRole, username: actualUsername),
          ),
        );
      } else {
        final message = (data['error'] ?? 'Login failed. Please check your username, password and selected role.').toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect to the Smart Campus server. Please make sure Spring Boot is running.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void openSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  Future<void> openForgotPassword() async {
    final username = TextEditingController(text: user.text.trim());
    final name = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    bool hideNew = true;
    bool hideConfirm = true;
    bool resetting = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Forgot password?'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Verify your username and registered full name, then choose a new password.',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: username,
                      decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Registered full name', prefixIcon: Icon(Icons.badge_outlined)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPassword,
                      obscureText: hideNew,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => hideNew = !hideNew),
                          icon: Icon(hideNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPassword,
                      obscureText: hideConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => hideConfirm = !hideConfirm),
                          icon: Icon(hideConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: resetting ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: resetting
                    ? null
                    : () async {
                        final u = username.text.trim().toLowerCase();
                        final n = name.text.trim();
                        final np = newPassword.text;
                        final cp = confirmPassword.text;
                        if (u.isEmpty || n.isEmpty || np.isEmpty || cp.isEmpty) {
                          ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Please fill all password recovery fields.')));
                          return;
                        }
                        if (np.length < 6) {
                          ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('New password must contain at least 6 characters.')));
                          return;
                        }
                        if (np != cp) {
                          ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('New passwords do not match.')));
                          return;
                        }
                        setDialogState(() => resetting = true);
                        try {
                          final response = await http.post(
                            Uri.parse('${ApiConfig.baseUrl}/api/auth/forgot-password'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({'username': u, 'name': n, 'newPassword': np}),
                          ).timeout(const Duration(seconds: 12));
                          final data = _decodeAuthResponse(response.body);
                          if (!mounted) return;
                          if (response.statusCode == 200 && data['success'] == true) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Password reset successfully. You can sign in now.')));
                          } else {
                            setDialogState(() => resetting = false);
                            ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(data['error']?.toString() ?? 'Password reset failed.')));
                          }
                        } catch (_) {
                          if (!mounted) return;
                          setDialogState(() => resetting = false);
                          ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Could not connect to the Smart Campus server.')));
                        }
                      },
                icon: resetting
                    ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.lock_reset_outlined, size: 17),
                label: Text(resetting ? 'Resetting...' : 'Reset password'),
              ),
            ],
          ),
        ),
      );
    } finally {
      username.dispose();
      name.dispose();
      newPassword.dispose();
      confirmPassword.dispose();
    }
  }

  Map<String, dynamic> _decodeAuthResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;
    final compact = size.width < 520;

    return AnimatedBuilder(
      animation: Listenable.merge([_entrance, _ambient]),
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_entrance.value);
        final drift = math.sin(_ambient.value * math.pi * 2);
        return Scaffold(
          backgroundColor: canvas,
          body: wide
              ? Row(
                  children: [
                    Expanded(
                      flex: 11,
                      child: _LoginVisualPanel(t: t, drift: drift),
                    ),
                    Expanded(
                      flex: 9,
                      child: _LoginFormPanel(
                        compact: compact,
                        t: t,
                        role: role,
                        user: user,
                        pass: pass,
                        hide: hide,
                        onRoleChanged: (v) => setState(() => role = v ?? 'ADMIN'),
                        onTogglePassword: () => setState(() => hide = !hide),
                        onLogin: login,
                        onSignup: openSignup,
                        onForgotPassword: openForgotPassword,
                        loading: _loading,
                      ),
                    ),
                  ],
                )
              : _LoginMobileLayout(
                  t: t,
                  drift: drift,
                  compact: compact,
                  role: role,
                  user: user,
                  pass: pass,
                  hide: hide,
                  onRoleChanged: (v) => setState(() => role = v ?? 'ADMIN'),
                  onTogglePassword: () => setState(() => hide = !hide),
                  onLogin: login,
                  onSignup: openSignup,
                  onForgotPassword: openForgotPassword,
                  loading: _loading,
                ),
        );
      },
    );
  }
}

class _LoginVisualPanel extends StatelessWidget {
  final double t;
  final double drift;
  const _LoginVisualPanel({required this.t, required this.drift});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07142E), Color(0xFF122C68), Color(0xFF0B1738)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -180 + drift * 18,
            right: -120,
            child: _GlowCircle(size: 480, color: const Color(0xFF4F46E5)),
          ),
          Positioned(
            bottom: -220 - drift * 14,
            left: -150,
            child: _GlowCircle(size: 520, color: const Color(0xFF06B6D4)),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _LoginParticlePainter(progress: drift),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(54, 48, 44, 42),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CampusBrand(white: true),
                const Spacer(),
                Transform.translate(
                  offset: Offset(0, 24 * (1 - t) + drift * 3),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 11,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0x2267E8F9),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: const Color(0x4467E8F9)),
                              ),
                              child: const Text(
                                'GNITS DIGITAL CAMPUS',
                                style: TextStyle(
                                  color: Color(0xFFBAE6FD),
                                  fontSize: 9,
                                  letterSpacing: 1.7,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Your campus,\nconnected in 3D.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 46,
                                height: 1.02,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.7,
                              ),
                            ),
                            const SizedBox(height: 17),
                            const Text(
                              'Live classrooms, intelligent timetables, bookings and campus operations in one focused workspace.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13.5,
                                height: 1.65,
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FeatureChip(icon: Icons.meeting_room_outlined, text: 'Live occupancy'),
                                FeatureChip(icon: Icons.table_view_outlined, text: 'Timetables'),
                                FeatureChip(icon: Icons.event_available_outlined, text: 'Bookings'),
                                FeatureChip(icon: Icons.analytics_outlined, text: 'Analytics'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        flex: 9,
                        child: SizedBox(
                          height: 400,
                          child: _Login3DScene(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Color(0xFF67E8F9), size: 17),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Creating Future Leaders Through Innovation and Excellence',
                        style: TextStyle(color: Colors.white54, fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginMobileLayout extends StatelessWidget {
  final double t;
  final double drift;
  final bool compact;
  final String role;
  final TextEditingController user;
  final TextEditingController pass;
  final bool hide;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final VoidCallback onSignup;
  final VoidCallback onForgotPassword;
  final bool loading;

  const _LoginMobileLayout({
    required this.t,
    required this.drift,
    required this.compact,
    required this.role,
    required this.user,
    required this.pass,
    required this.hide,
    required this.onRoleChanged,
    required this.onTogglePassword,
    required this.onLogin,
    required this.onSignup,
    required this.onForgotPassword,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF07142E), Color(0xFFF5F7FC)],
          stops: [0.0, 0.48],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(compact ? 14 : 22, 16, compact ? 14 : 22, 28),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: CampusBrand(white: true),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: compact ? 210 : 245,
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - t)),
                  child: _Login3DScene(drift: drift),
                ),
              ),
              const SizedBox(height: 2),
              _LoginFormCard(
                compact: compact,
                t: t,
                role: role,
                user: user,
                pass: pass,
                hide: hide,
                onRoleChanged: onRoleChanged,
                onTogglePassword: onTogglePassword,
                onLogin: onLogin,
                onSignup: onSignup,
                onForgotPassword: onForgotPassword,
                loading: loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginFormPanel extends StatelessWidget {
  final bool compact;
  final double t;
  final String role;
  final TextEditingController user;
  final TextEditingController pass;
  final bool hide;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final VoidCallback onSignup;
  final VoidCallback onForgotPassword;
  final bool loading;

  const _LoginFormPanel({
    required this.compact,
    required this.t,
    required this.role,
    required this.user,
    required this.pass,
    required this.hide,
    required this.onRoleChanged,
    required this.onTogglePassword,
    required this.onLogin,
    required this.onSignup,
    required this.onForgotPassword,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: canvas,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: _LoginFormCard(
            compact: compact,
            t: t,
            role: role,
            user: user,
            pass: pass,
            hide: hide,
            onRoleChanged: onRoleChanged,
            onTogglePassword: onTogglePassword,
            onLogin: onLogin,
            onSignup: onSignup,
            onForgotPassword: onForgotPassword,
            loading: loading,
          ),
        ),
      ),
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  final bool compact;
  final double t;
  final String role;
  final TextEditingController user;
  final TextEditingController pass;
  final bool hide;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final VoidCallback onSignup;
  final VoidCallback onForgotPassword;
  final bool loading;

  const _LoginFormCard({
    required this.compact,
    required this.t,
    required this.role,
    required this.user,
    required this.pass,
    required this.hide,
    required this.onRoleChanged,
    required this.onTogglePassword,
    required this.onLogin,
    required this.onSignup,
    required this.onForgotPassword,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 455),
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - t)),
        child: Opacity(
          opacity: .25 + .75 * t,
          child: Container(
            padding: EdgeInsets.all(compact ? 20 : 30),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.98),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(color: Color(0x180B1533), blurRadius: 40, offset: Offset(0, 18)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compact) const CampusBrand(),
                if (!compact) const SizedBox(height: 24),
                Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: compact ? 24 : 28,
                    fontWeight: FontWeight.w900,
                    color: navy,
                    letterSpacing: -.7,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  width: 58,
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [purple, academicBlue]),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Sign in to your GNITS campus workspace.',
                  style: TextStyle(color: muted, fontSize: 12.5),
                ),
                const SizedBox(height: 22),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('Administrator')),
                    DropdownMenuItem(value: 'FACULTY', child: Text('Faculty')),
                    DropdownMenuItem(value: 'STUDENT', child: Text('Student')),
                  ],
                  onChanged: onRoleChanged,
                ),
                const SizedBox(height: 13),
                TextField(
                  controller: user,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 13),
                TextField(
                  controller: pass,
                  obscureText: hide,
                  onSubmitted: (_) => onLogin(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: onTogglePassword,
                      icon: Icon(
                        hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: loading ? null : onForgotPassword,
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2)),
                    child: const Text('Forgot password?', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: loading ? null : onLogin,
                    icon: loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      loading ? 'Signing in...' : 'Enter GNITS Smart Campus',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('New to Smart Campus? ', style: TextStyle(fontSize: 10.5, color: muted)),
                      TextButton(
                        onPressed: loading ? null : onSignup,
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2)),
                        child: const Text('Create an account', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Secure campus workspace • GNITS',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();
  final name = TextEditingController();
  final user = TextEditingController();
  final pass = TextEditingController();
  final confirm = TextEditingController();
  String role = 'STUDENT';
  bool hide = true;
  bool hideConfirm = true;
  bool loading = false;

  @override
  void dispose() {
    _entrance.dispose();
    name.dispose();
    user.dispose();
    pass.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> signup() async {
    if (loading) return;
    final fullName = name.text.trim();
    final username = user.text.trim().toLowerCase();
    final password = pass.text;
    final confirmation = confirm.text;
    if (fullName.isEmpty || username.isEmpty || password.isEmpty || confirmation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields.')));
      return;
    }
    if (password != confirmation) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must contain at least 6 characters.')));
      return;
    }

    setState(() => loading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': fullName,
          'username': username,
          'password': password,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 12));

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (!mounted) return;
      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created successfully. Please sign in.')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((data['error'] ?? 'Could not create account.').toString())));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not connect to the Smart Campus server. Please make sure Spring Boot is running.')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 520;
    return Scaffold(
      backgroundColor: canvas,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF07142E), Color(0xFF122C68), Color(0xFFF5F7FC)],
                stops: [0.0, 0.28, 0.75],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 28, vertical: 22),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AnimatedBuilder(
                    animation: _entrance,
                    builder: (context, _) {
                      final t = Curves.easeOutCubic.transform(_entrance.value);
                      return Opacity(
                        opacity: .25 + .75 * t,
                        child: Transform.translate(
                          offset: Offset(0, 22 * (1 - t)),
                          child: Column(
                            children: [
                              const Align(alignment: Alignment.centerLeft, child: CampusBrand(white: true)),
                              const SizedBox(height: 34),
                              Container(
                                padding: EdgeInsets.all(compact ? 20 : 30),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.98),
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(color: border),
                                  boxShadow: const [BoxShadow(color: Color(0x220B1533), blurRadius: 42, offset: Offset(0, 20))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Create your account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: navy, letterSpacing: -.7)),
                                    const SizedBox(height: 7),
                                    Container(width: 58, height: 4, decoration: BoxDecoration(gradient: const LinearGradient(colors: [purple, academicBlue]), borderRadius: BorderRadius.circular(99))),
                                    const SizedBox(height: 9),
                                    const Text('Create your personal GNITS Smart Campus workspace.', style: TextStyle(color: muted, fontSize: 12.5)),
                                    const SizedBox(height: 22),
                                    TextField(controller: name, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline))),
                                    const SizedBox(height: 13),
                                    DropdownButtonFormField<String>(
                                      value: role,
                                      decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.badge_outlined)),
                                      items: const [
                                        DropdownMenuItem(value: 'ADMIN', child: Text('Administrator')),
                                        DropdownMenuItem(value: 'FACULTY', child: Text('Faculty')),
                                        DropdownMenuItem(value: 'STUDENT', child: Text('Student')),
                                      ],
                                      onChanged: loading ? null : (v) => setState(() => role = v ?? 'STUDENT'),
                                    ),
                                    const SizedBox(height: 13),
                                    TextField(controller: user, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email_rounded))),
                                    const SizedBox(height: 13),
                                    TextField(controller: pass, obscureText: hide, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                                    const SizedBox(height: 13),
                                    TextField(controller: confirm, obscureText: hideConfirm, onSubmitted: (_) => signup(), decoration: InputDecoration(labelText: 'Confirm Password', prefixIcon: const Icon(Icons.verified_user_outlined), suffixIcon: IconButton(onPressed: () => setState(() => hideConfirm = !hideConfirm), icon: Icon(hideConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: FilledButton.icon(
                                        onPressed: loading ? null : signup,
                                        icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)) : const Icon(Icons.person_add_alt_1_rounded),
                                        label: Text(loading ? 'Creating account...' : 'Create Account', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Center(child: TextButton.icon(onPressed: loading ? null : () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, size: 16), label: const Text('Already have an account? Sign in'))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

class _Login3DScene extends StatefulWidget {
  final double drift;
  const _Login3DScene({this.drift = 0});

  @override
  State<_Login3DScene> createState() => _Login3DSceneState();
}

class _Login3DSceneState extends State<_Login3DScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final p = _controller.value * math.pi * 2;
        return CustomPaint(
          painter: _Login3DPainter(progress: p, externalDrift: widget.drift),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _Login3DPainter extends CustomPainter {
  final double progress;
  final double externalDrift;
  const _Login3DPainter({required this.progress, this.externalDrift = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final minSide = math.min(size.width, size.height);
    final center = Offset(size.width * .52, size.height * .53);
    final scale = (minSide / 330).clamp(.58, 1.18);

    final glow = Paint()..color = const Color(0x1838BDF8);
    canvas.drawCircle(center, 120 * scale, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0x7767E8F9);
    final ring2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x444F46E5);

    final tilt = externalDrift * .05;
    canvas.save();
    canvas.translate(tilt * 20, externalDrift * 5);
    canvas.rotate(math.sin(progress) * .025);

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: 245 * scale,
        height: 72 * scale,
      ),
      ring,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: 190 * scale,
        height: 55 * scale,
      ),
      ring2,
    );

    final nodes = <_LoginNode>[
      _LoginNode(Offset(-68, -46), 92, const Color(0xFF4F46E5)),
      _LoginNode(Offset(22, -72), 122, const Color(0xFF2563EB)),
      _LoginNode(Offset(74, 10), 82, const Color(0xFF06B6D4)),
      _LoginNode(Offset(-52, 55), 66, const Color(0xFF0EA5E9)),
      _LoginNode(Offset(22, 70), 54, const Color(0xFF4338CA)),
    ];

    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final wobble = math.sin(progress * 1.4 + i) * 5;
      _drawNode(canvas, center + Offset(n.position.dx * scale, (n.position.dy + wobble) * scale), n, scale);
    }

    final orbitAngle = progress;
    final orbit = Offset(
      center.dx + math.cos(orbitAngle) * 132 * scale,
      center.dy + math.sin(orbitAngle) * 40 * scale,
    );
    canvas.drawCircle(orbit, 5.5 * scale, Paint()..color = const Color(0xFF67E8F9));
    canvas.drawCircle(orbit, 14 * scale, Paint()..color = const Color(0x2267E8F9));
    canvas.restore();

    final pulse = .5 + .5 * math.sin(progress * 2);
    final centerPaint = Paint()..color = const Color(0xFF0EA5E9);
    canvas.drawCircle(center, 24 * scale, centerPaint);
    canvas.drawCircle(center, (35 + pulse * 10) * scale, Paint()..color = const Color(0x2217D9FF));
  }

  void _drawNode(Canvas canvas, Offset base, _LoginNode node, double scale) {
    final w = 54 * scale;
    final h = node.height * .65 * scale;
    final depth = 18 * scale;
    final top = Path()
      ..moveTo(base.dx, base.dy - h)
      ..lineTo(base.dx + w * .5, base.dy - h - depth * .55)
      ..lineTo(base.dx + w, base.dy - h)
      ..lineTo(base.dx + w * .5, base.dy - h + depth * .55)
      ..close();
    final left = Path()
      ..moveTo(base.dx, base.dy - h)
      ..lineTo(base.dx + w * .5, base.dy - h + depth * .55)
      ..lineTo(base.dx + w * .5, base.dy + depth * .35)
      ..lineTo(base.dx, base.dy)
      ..close();
    final right = Path()
      ..moveTo(base.dx + w * .5, base.dy - h + depth * .55)
      ..lineTo(base.dx + w, base.dy - h)
      ..lineTo(base.dx + w, base.dy)
      ..lineTo(base.dx + w * .5, base.dy + depth * .35)
      ..close();

    canvas.drawPath(left, Paint()..color = node.color.withOpacity(.72));
    canvas.drawPath(right, Paint()..color = node.color.withOpacity(.42));
    canvas.drawPath(top, Paint()..color = node.color.withOpacity(.98));

    final window = Paint()..color = const Color(0xAAE0F2FE);
    for (int i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          base.dx + 11 * scale + i * 12 * scale,
          base.dy - 20 * scale,
          6 * scale,
          7 * scale,
        ),
        window,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Login3DPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.externalDrift != externalDrift;
}

class _LoginNode {
  final Offset position;
  final double height;
  final Color color;
  const _LoginNode(this.position, this.height, this.color);
}

class _LoginParticlePainter extends CustomPainter {
  final double progress;
  const _LoginParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < 55; i++) {
      final seed = i * 19.73;
      final x = ((math.sin(seed) + 1) / 2) * size.width;
      final y = ((math.cos(seed * 1.31) + 1) / 2) * size.height + math.sin(seed + progress) * 8;
      paint.color = Colors.white.withOpacity(.06 + (i % 5) * .018);
      canvas.drawCircle(Offset(x, y % size.height), .7 + (i % 3) * .35, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LoginParticlePainter oldDelegate) => true;
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(.12),
          boxShadow: [
            BoxShadow(color: color.withOpacity(.20), blurRadius: 120, spreadRadius: 30),
          ],
        ),
      );
}
