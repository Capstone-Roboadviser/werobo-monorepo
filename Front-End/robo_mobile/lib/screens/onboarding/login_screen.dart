import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import 'comparison_screen.dart';

class LoginScreen extends StatefulWidget {
  final MobileRecommendationResponse recommendation;
  final String selectedPortfolioCode;
  final MobileFrontierSelectionResponse? frontierSelection;

  const LoginScreen({
    super.key,
    required this.recommendation,
    required this.selectedPortfolioCode,
    this.frontierSelection,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    logPageEnter('LoginScreen', {
      'selected': widget.selectedPortfolioCode,
    });
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    logPageExit('LoginScreen');
    _fadeController.dispose();
    super.dispose();
  }

  void _onSocialLogin(String provider) {
    logAction('tap social login', {
      'provider': provider,
      'mode': _isLogin ? 'login' : 'signup',
    });
    // TODO: Implement actual auth for each provider
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ComparisonScreen(
          recommendation: widget.recommendation,
          selectedPortfolioCode: widget.selectedPortfolioCode,
          frontierSelection: widget.frontierSelection,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo
                Text(
                  'WeRobo',
                  style: WeRoboTypography.logo.copyWith(
                    color: WeRoboColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '당신만의 포트폴리오를 시작하세요',
                  style: WeRoboTypography.body.themed(context),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 2),

                // Login/Signup toggle
                Container(
                  decoration: BoxDecoration(
                    color: tc.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TabButton(
                          label: '로그인',
                          isActive: _isLogin,
                          onTap: () => setState(() => _isLogin = true),
                        ),
                      ),
                      Expanded(
                        child: _TabButton(
                          label: '회원가입',
                          isActive: !_isLogin,
                          onTap: () => setState(() => _isLogin = false),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Social login buttons
                _SocialButton(
                  label: 'Google로 ${_isLogin ? '로그인' : '회원가입'}',
                  icon: const _GoogleIcon(),
                  backgroundColor: WeRoboColors.white,
                  textColor: tc.textPrimary,
                  borderColor: tc.border,
                  onTap: () => _onSocialLogin('google'),
                ),
                const SizedBox(height: 16),
                _SocialButton(
                  label: '카카오로 ${_isLogin ? '로그인' : '회원가입'}',
                  icon: const Text('K',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF3C1E1E))),
                  backgroundColor: WeRoboColors.kakaoYellow,
                  textColor: WeRoboColors.kakaoBrown,
                  onTap: () => _onSocialLogin('kakao'),
                ),
                const SizedBox(height: 16),
                _SocialButton(
                  label: '네이버로 ${_isLogin ? '로그인' : '회원가입'}',
                  icon: const Text('N',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: WeRoboColors.white)),
                  backgroundColor: WeRoboColors.naverGreen,
                  textColor: WeRoboColors.white,
                  onTap: () => _onSocialLogin('naver'),
                ),
                const SizedBox(height: 16),
                _SocialButton(
                  label: 'Apple로 ${_isLogin ? '로그인' : '회원가입'}',
                  icon: const Icon(Icons.apple,
                      color: WeRoboColors.white, size: 22),
                  backgroundColor: WeRoboColors.black,
                  textColor: WeRoboColors.white,
                  onTap: () => _onSocialLogin('apple'),
                ),

                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => _onSocialLogin('preview'),
                  child: Text(
                    '로그인 없이 둘러보기',
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? WeRoboColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: WeRoboTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isActive ? WeRoboColors.white : tc.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1)
              : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            SizedBox(width: 24, height: 24, child: Center(child: icon)),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: WeRoboTypography.button.copyWith(color: textColor),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

/// Simple Google "G" icon using CustomPaint
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        foreground: null,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
