import 'package:flutter/material.dart';
import '../core/google_logo.dart';
import '../data/services/auth_service.dart';
import 'beranda.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  final String? initialIdentifier;
  final String? initialPassword;

  const LoginPage({
    super.key,
    this.initialIdentifier,
    this.initialPassword,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  final AuthService _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: widget.initialIdentifier ?? 'demo@gmail.com',
    );
    _passwordController = TextEditingController(
      text: widget.initialPassword ?? 'password123',
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _emailController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFFF5252),
          content: Text('Email/Username dan Password tidak boleh kosong.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _authService.login(
        identifier: identifier,
        password: password,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF00E676),
          content: Text('Selamat datang kembali, ${user.fullName}!'),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BerandaPage()),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      final isUnregistered = errorMessage.contains('belum terdaftar');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF5252),
          content: Text(errorMessage),
          action: isUnregistered
              ? SnackBarAction(
                  label: 'DAFTAR',
                  textColor: Colors.white,
                  onPressed: () async {
                    final result = await Navigator.push<Map<String, String>>(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                    if (result != null && mounted) {
                      setState(() {
                        if (result['identifier'] != null) {
                          _emailController.text = result['identifier']!;
                        }
                        if (result['password'] != null) {
                          _passwordController.text = result['password']!;
                        }
                      });
                    }
                  },
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF00E676),
          content: Text('Masuk dengan Google berhasil! Halo, ${user.fullName}.'),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BerandaPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF5252),
          content: Text('Login Google gagal: ${e.toString().replaceAll('Exception: ', '')}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF0D0E12);
    const primaryYellow = Color(0xFFFFC700);
    const inputFillColor = Color(0xFF181A22);
    const inputBorderColor = Color(0xFF262933);
    const textMutedColor = Color(0xFF8E92A0);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Banner Image with Gradient Overlay
              Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF151720),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF222633),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background Image
                      Image.asset(
                        'assets/login_background.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),

                      // Gradient Overlay (Fades image into dark background)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              backgroundColor.withValues(alpha: 0.15),
                              Colors.transparent,
                              backgroundColor.withValues(alpha: 0.65),
                              backgroundColor,
                            ],
                            stops: const [0.0, 0.35, 0.75, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title Rotten Bananas with App Logo
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/logo_app.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'ROTTEN BANANAS',
                    style: TextStyle(
                      color: primaryYellow,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Subtitle
              const Text(
                'Watch Trailers. Judge the Ripeness.',
                style: TextStyle(
                  color: textMutedColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 28),

              // Email / Username Label
              const Text(
                'Email atau Username',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Email / Username TextField
              TextField(
                controller: _emailController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputFillColor,
                  hintText: 'demo@gmail.com',
                  hintStyle: const TextStyle(
                    color: textMutedColor,
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  suffixIcon: const Icon(
                    Icons.mail_outline_rounded,
                    color: textMutedColor,
                    size: 20,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: inputBorderColor,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: primaryYellow,
                      width: 1.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Password Label
              const Text(
                'Password',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Password TextField
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputFillColor,
                  hintText: '••••••••••',
                  hintStyle: const TextStyle(
                    color: textMutedColor,
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: textMutedColor,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: inputBorderColor,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: primaryYellow,
                      width: 1.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Lupa Password Button
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'Lupa Password?',
                    style: TextStyle(
                      color: primaryYellow,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Masuk ke Akun Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryYellow,
                    disabledBackgroundColor: primaryYellow.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : const Text(
                          'Masuk ke Akun',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // Login Dengan Google Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _handleGoogleLogin,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: inputFillColor,
                    side: const BorderSide(
                      color: primaryYellow,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google Original Multi-Color Logo badge
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const GoogleLogo(size: 15),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Login Dengan Google',
                        style: TextStyle(
                          color: primaryYellow,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Footer: Belum punya akun? Daftar Sekarang
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push<Map<String, String>>(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                    if (result != null && mounted) {
                      setState(() {
                        if (result['identifier'] != null) {
                          _emailController.text = result['identifier']!;
                        }
                        if (result['password'] != null) {
                          _passwordController.text = result['password']!;
                        }
                      });
                    }
                  },
                  child: RichText(
                    text: const TextSpan(
                      text: 'Belum punya akun? ',
                      style: TextStyle(
                        color: textMutedColor,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: 'Daftar Sekarang',
                          style: TextStyle(
                            color: primaryYellow,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
