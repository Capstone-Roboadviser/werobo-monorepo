import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../services/mobile_backend_api.dart';
import '../home/home_shell.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isLogin = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  String? _errorMessage;
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _navigateToComparison() {
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

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeShell(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (_) => false,
    );
  }

  Future<void> _navigateAfterAuthenticated() async {
    final state = PortfolioStateProvider.of(context);
    try {
      await state.refreshAccountDashboard(notify: true);
    } catch (_) {}
    if (!mounted) {
      return;
    }
    if (state.hasPrototypeAccount) {
      logAction('skip onboarding after login', {
        'reason': 'existing_account',
      });
      _navigateToHome();
      return;
    }
    _navigateToComparison();
  }

  void _onSocialLogin(String provider) {
    logAction('tap social login', {
      'provider': provider,
      'mode': _isLogin ? 'login' : 'signup',
    });
    final providerType = authProviderTypeFromApi(provider);
    final providerLabel = switch (providerType) {
      AuthProviderType.google => 'Google',
      AuthProviderType.kakao => '카카오',
      AuthProviderType.naver => '네이버',
      AuthProviderType.apple => 'Apple',
      _ => provider,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$providerLabel 간편로그인은 다음 단계에서 연결할 예정입니다.'),
      ),
    );
  }

  Future<void> _continueWithCurrentSession() async {
    final state = PortfolioStateProvider.of(context);
    final user = state.currentUser;
    if (user == null) {
      return;
    }
    logAction('continue with current session', {
      'userId': user.id,
      'provider': authProviderTypeToApi(user.provider),
    });
    await _navigateAfterAuthenticated();
  }

  Future<void> _submitDirectAuth() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (!_isLogin &&
        _passwordController.text != _passwordConfirmController.text) {
      setState(() {
        _errorMessage = '비밀번호 확인이 일치하지 않습니다.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    logAction('submit direct auth', {
      'mode': _isLogin ? 'login' : 'signup',
      'email': _emailController.text.trim(),
    });

    try {
      final session = _isLogin
          ? await MobileBackendApi.instance.login(
              email: _emailController.text,
              password: _passwordController.text,
            )
          : await MobileBackendApi.instance.signup(
              name: _nameController.text,
              email: _emailController.text,
              password: _passwordController.text,
            );
      if (!mounted) {
        return;
      }
      await PortfolioStateProvider.of(context).setAuthSession(session);
      if (!mounted) {
        return;
      }
      logAction('success direct auth', {
        'mode': _isLogin ? 'login' : 'signup',
        'userId': session.user.id,
      });
      await _navigateAfterAuthenticated();
    } catch (error) {
      if (!mounted) {
        return;
      }
      logAction('fail direct auth', {
        'mode': _isLogin ? 'login' : 'signup',
        'error': error.toString(),
      });
      setState(() {
        _errorMessage = error is MobileBackendException
            ? error.message
            : '로그인 처리 중 오류가 발생했습니다.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _setMode(bool isLogin) {
    setState(() {
      _isLogin = isLogin;
      _errorMessage = null;
    });
  }

  String? _validateEmail(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return '이메일을 입력해 주세요.';
    }
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(normalized)) {
      return '올바른 이메일 형식을 입력해 주세요.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return '비밀번호를 입력해 주세요.';
    }
    if (password.length < 8) {
      return '비밀번호는 8자 이상이어야 합니다.';
    }
    return null;
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return '이름을 입력해 주세요.';
    }
    if (name.length < 2) {
      return '이름은 2자 이상 입력해 주세요.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final currentUser = state.currentUser;
    final hasActiveSession = currentUser != null;
    return Scaffold(
      backgroundColor: tc.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
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
                      const SizedBox(height: 32),
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
                                onTap: () => _setMode(true),
                              ),
                            ),
                            Expanded(
                              child: _TabButton(
                                label: '회원가입',
                                isActive: !_isLogin,
                                onTap: () => _setMode(false),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: tc.card,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: WeRoboElevation.subtle,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasActiveSession) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: WeRoboColors.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '이미 로그인된 계정이 있어요',
                                        style: WeRoboTypography.heading3
                                            .themed(context),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${currentUser.name} · ${currentUser.email}',
                                        style:
                                            WeRoboTypography.bodySmall.copyWith(
                                          color: tc.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '현재 세션으로 바로 다음 단계로 진행하거나, 다른 계정으로 다시 로그인할 수 있습니다.',
                                        style:
                                            WeRoboTypography.caption.copyWith(
                                          color: tc.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed:
                                              _continueWithCurrentSession,
                                          child: const Text('이 계정으로 계속'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              Text(
                                _isLogin ? '이메일로 로그인' : '이메일로 회원가입',
                                style:
                                    WeRoboTypography.heading3.themed(context),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isLogin
                                    ? '비밀번호 로그인과 세션 자동 복원을 함께 지원합니다.'
                                    : '간편로그인 없이 사용할 기본 계정을 먼저 만듭니다.',
                                style: WeRoboTypography.caption.themed(context),
                              ),
                              const SizedBox(height: 20),
                              if (!_isLogin) ...[
                                _AuthTextField(
                                  controller: _nameController,
                                  label: '이름',
                                  hintText: '이름을 입력해 주세요',
                                  textInputAction: TextInputAction.next,
                                  validator: _validateName,
                                ),
                                const SizedBox(height: 14),
                              ],
                              _AuthTextField(
                                controller: _emailController,
                                label: '이메일',
                                hintText: 'name@example.com',
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 14),
                              _AuthTextField(
                                controller: _passwordController,
                                label: '비밀번호',
                                hintText: '8자 이상 입력',
                                obscureText: _obscurePassword,
                                textInputAction: _isLogin
                                    ? TextInputAction.done
                                    : TextInputAction.next,
                                validator: _validatePassword,
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  }),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              if (!_isLogin) ...[
                                const SizedBox(height: 14),
                                _AuthTextField(
                                  controller: _passwordConfirmController,
                                  label: '비밀번호 확인',
                                  hintText: '비밀번호를 다시 입력해 주세요',
                                  obscureText: _obscurePasswordConfirm,
                                  textInputAction: TextInputAction.done,
                                  validator: _validatePassword,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() {
                                      _obscurePasswordConfirm =
                                          !_obscurePasswordConfirm;
                                    }),
                                    icon: Icon(
                                      _obscurePasswordConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                              ],
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  _errorMessage!,
                                  style: WeRoboTypography.caption.copyWith(
                                    color: WeRoboColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      _isSubmitting ? null : _submitDirectAuth,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: WeRoboColors.white,
                                            ),
                                          )
                                        : Text(_isLogin ? '로그인' : '회원가입'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: Divider(color: tc.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '또는 간편 로그인',
                              style: WeRoboTypography.caption.copyWith(
                                color: tc.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: tc.border)),
                        ],
                      ),
                      const SizedBox(height: 24),
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
                        onTap: () {
                          logAction('continue without login');
                          _navigateToComparison();
                        },
                        child: Text(
                          '로그인 없이 둘러보기',
                          style: WeRoboTypography.caption.copyWith(
                            color: tc.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: WeRoboTypography.caption.copyWith(
            color: tc.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: tc.surface,
            suffixIcon: suffixIcon,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tc.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: WeRoboColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: WeRoboColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: WeRoboColors.error,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
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
