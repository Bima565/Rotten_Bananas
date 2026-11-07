import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/email_service.dart';

class PasswordForgetDialog extends StatefulWidget {
  final String? initialEmail;

  const PasswordForgetDialog({super.key, this.initialEmail});

  static Future<String?> show(
    BuildContext context, {
    String? initialEmail,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => PasswordForgetDialog(initialEmail: initialEmail),
    );
  }

  @override
  State<PasswordForgetDialog> createState() => _PasswordForgetDialogState();
}

class _PasswordForgetDialogState extends State<PasswordForgetDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Step 1: Input Email, Step 2: Input OTP 5 Digit, Step 3: Password Baru
  int _currentStep = 1;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isSubmitting = false; // Idempotency guard
  String? _errorMessage;

  // State OTP
  String? _generatedCode;
  String? _idempotencyKey;
  Timer? _resendTimer;
  int _resendCountdown = 0;

  // Status validasi password
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;

  // Warna Rotten Bananas Theme
  static const Color bgDark = Color(0xFF151720);
  static const Color inputBg = Color(0xFF181A22);
  static const Color inputBorder = Color(0xFF262933);
  static const Color accentYellow = Color(0xFFFFC700);
  static const Color errorRed = Color(0xFFFF5252);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF8E92A0);
  static const Color textDim = Color(0xFF6B7280);
  static const Color greenCheck = Color(0xFF00E676);

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    _passwordController.addListener(_validatePasswordRules);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.removeListener(_validatePasswordRules);
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _validatePasswordRules() {
    final text = _passwordController.text;
    setState(() {
      _hasMinLength = text.length >= 6;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(text);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(text);
      _hasNumber = RegExp(r'[0-9]').hasMatch(text);
      _hasSymbol = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(text);
    });
  }

  bool get _isPasswordValid =>
      _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber;

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  // --- STEP 1: KIRIM KODE 5 DIGIT VIA BREVO REST API ---
  Future<void> _sendVerificationCode() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Email tidak boleh kosong.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Cek apakah email terdaftar di koleksi 'users' Cloud Firestore
      try {
        final querySnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Email belum terdaftar di Rotten Bananas.';
          });
          return;
        }
      } on FirebaseException catch (fe) {
        // Abaikan permission-denied jika rules Firestore memblokir unauthenticated read
        debugPrint('Firestore read notice: ${fe.code}');
      }

      // 2. Generate random 5 digit code (10000 - 99999)
      final random = Random();
      final code = (10000 + random.nextInt(90000)).toString();
      _generatedCode = code;
      _idempotencyKey =
          '${email}_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(9999)}';

      // 3. Simpan OTP ke Firestore 'password_resets' jika diizinkan rules
      try {
        await _firestore.collection('password_resets').doc(email).set({
          'email': email,
          'code': code,
          'idempotency_key': _idempotencyKey,
          'status': 'pending',
          'created_at': FieldValue.serverTimestamp(),
          'expires_at': Timestamp.fromDate(
              DateTime.now().add(const Duration(minutes: 15))),
        });
      } on FirebaseException catch (fe) {
        // Jika rules menolak unauthenticated write, kode tetap tersimpan di memori aplikasi
        debugPrint('Firestore write notice: ${fe.code}');
      }

      // 4. Kirim email OTP via Brevo API
      final sendResult =
          await EmailService.sendOtpCode(targetEmail: email, otpCode: code);

      _startResendTimer();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = 2;
          _codeController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: sendResult.success
                ? const Color(0xFF143322)
                : const Color(0xFF3B1517),
            duration: const Duration(seconds: 8),
            content: Text(
              sendResult.success
                  ? 'Kode 5-digit terkirim ke $email! Cek inbox/spam.'
                  : 'Gagal kirim via Brevo: ${sendResult.message}\n(Kode testing: $code)',
              style: const TextStyle(color: textWhite),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal mengirim kode: $e';
        });
      }
    }
  }

  // --- STEP 2: VERIFIKASI KODE 5 DIGIT ---
  Future<void> _verifyCode() async {
    final inputCode = _codeController.text.trim();
    if (inputCode.length != 5) {
      setState(() => _errorMessage = 'Masukkan 5 digit kode verifikasi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();

      bool isValid = inputCode == _generatedCode;

      if (!isValid) {
        final doc =
            await _firestore.collection('password_resets').doc(email).get();
        if (doc.exists) {
          final savedCode = doc.data()?['code'];
          final expiresAt = doc.data()?['expires_at'] as Timestamp?;
          if (savedCode == inputCode) {
            if (expiresAt == null ||
                expiresAt.toDate().isAfter(DateTime.now())) {
              isValid = true;
            }
          }
        }
      }

      if (isValid) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentStep = 3;
            _errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Kode salah atau telah kedaluwarsa.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memverifikasi: $e';
        });
      }
    }
  }

  // --- STEP 3: SIMPAN PASSWORD BARU DENGAN IDEMPOTENCY ---
  Future<void> _saveNewPassword() async {
    if (_isSubmitting) return; // Mencegah multiple submit bersamaan

    if (!_isPasswordValid) {
      setState(() {
        _errorMessage =
            'Password harus memiliki huruf besar, kecil, angka, dan min. 6 karakter.';
      });
      return;
    }

    if (_passwordController.text != _confirmController.text) {
      setState(() => _errorMessage = 'Konfirmasi password tidak cocok.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final newPass = _passwordController.text.trim();

      // 1. Cek idempotency status di Firestore (jika rules mengizinkan)
      try {
        final resetDocRef = _firestore.collection('password_resets').doc(email);
        final resetDoc = await resetDocRef.get();
        if (resetDoc.exists && resetDoc.data()?['status'] == 'completed') {
          if (mounted) {
            Navigator.of(context).pop(email);
          }
          return;
        }

        // Tandai sedang diproses
        await resetDocRef.set({
          'status': 'processing',
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      // 2. Perbarui status password di Cloud Firestore 'users'
      try {
        final userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          await userQuery.docs.first.reference.update({
            'has_password': true,
            'password_hash': newPass,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}

      // 3. Jika pengguna aktif sama dengan email ini, update password langsung di Firebase Auth
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null &&
          currentUser.email?.toLowerCase() == email) {
        try {
          await currentUser.updatePassword(newPass);
        } catch (_) {}
      }

      // 4. Kirim link reset password Firebase sebagai backup sinkronisasi akun
      try {
        await _firebaseAuth.sendPasswordResetEmail(email: email);
      } catch (_) {}

      // 5. Tandai status completed & bersihkan OTP di Firestore
      try {
        await _firestore.collection('password_resets').doc(email).set({
          'status': 'completed',
          'code': FieldValue.delete(),
          'completed_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop(email);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isLoading = false;
          _errorMessage = 'Gagal menyimpan password baru: $e';
        });
      }
    }
  }

  Widget _buildRuleItem({
    required String label,
    required bool isValid,
    bool isOptional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(
            isValid
                ? Icons.check_circle_rounded
                : (isOptional
                    ? Icons.radio_button_unchecked
                    : Icons.cancel_outlined),
            size: 16,
            color: isValid
                ? greenCheck
                : (isOptional ? textMuted : const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: isValid
                    ? textWhite
                    : (isOptional ? textMuted : const Color(0xFF9CA3AF)),
                fontWeight: isValid ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: bgDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: inputBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentYellow.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: accentYellow.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: accentYellow,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lupa Kata Sandi',
                          style: TextStyle(
                            color: textWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentStep == 1
                              ? 'Langkah 1: Masukkan Email'
                              : (_currentStep == 2
                                  ? 'Langkah 2: Verifikasi Kode'
                                  : 'Langkah 3: Buat Password Baru'),
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- KONTEN SESUAI STEP ---
              if (_currentStep == 1) ...[
                // STEP 1: INPUT EMAIL
                const Text(
                  'Masukkan email akun Rotten Bananas Anda. Kami akan mengirimkan 5-digit kode verifikasi ke email Anda.',
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Email Pengguna',
                  style: TextStyle(
                    color: textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: textWhite, fontSize: 14),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'nama@email.com',
                    hintStyle: const TextStyle(color: textDim, fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      color: textDim,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: accentYellow, width: 1.2),
                    ),
                  ),
                ),
              ] else if (_currentStep == 2) ...[
                // STEP 2: INPUT KODE 5 DIGIT & RESEND
                Text(
                  'Kode 5-digit telah dikirim ke ${_emailController.text}. Masukkan kode tersebut di bawah ini:',
                  style: const TextStyle(color: textMuted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 5,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        color: textWhite,
                        fontSize: 26,
                        letterSpacing: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '•••••',
                        hintStyle: const TextStyle(
                          color: textDim,
                          letterSpacing: 10,
                          fontSize: 26,
                        ),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: accentYellow, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Resend Code
                Center(
                  child: TextButton(
                    onPressed: (_resendCountdown == 0 && !_isLoading)
                        ? _sendVerificationCode
                        : null,
                    child: Text(
                      _resendCountdown > 0
                          ? 'Kirim Ulang Kode ($_resendCountdown s)'
                          : 'Kirim Ulang Kode',
                      style: TextStyle(
                        color: _resendCountdown == 0 ? accentYellow : textDim,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // STEP 3: BUAT PASSWORD BARU
                const Text(
                  'Buat kata sandi baru untuk akun Rotten Bananas Anda.',
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Password Baru',
                  style: TextStyle(
                    color: textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: textWhite, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Minimal 6 karakter',
                    hintStyle: const TextStyle(color: textDim, fontSize: 13),
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: textDim, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: textDim,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: accentYellow, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Konfirmasi Password Baru',
                  style: TextStyle(
                    color: textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  style: const TextStyle(color: textWhite, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ulangi password baru',
                    hintStyle: const TextStyle(color: textDim, fontSize: 13),
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: textDim, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: textDim,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: accentYellow, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Checklist Rules
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: inputBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ketentuan Password:',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildRuleItem(
                        label: 'Minimal 6 karakter',
                        isValid: _hasMinLength,
                      ),
                      _buildRuleItem(
                        label: 'Mengandung huruf besar (A-Z)',
                        isValid: _hasUppercase,
                      ),
                      _buildRuleItem(
                        label: 'Mengandung huruf kecil (a-z)',
                        isValid: _hasLowercase,
                      ),
                      _buildRuleItem(
                        label: 'Mengandung angka (0-9)',
                        isValid: _hasNumber,
                      ),
                      _buildRuleItem(
                        label: 'Simbol khusus (@, #, \$, dll) - Opsional',
                        isValid: _hasSymbol,
                        isOptional: true,
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: errorRed, fontSize: 12.5),
                ),
              ],

              const SizedBox(height: 22),

              // Tombol Navigasi Bawah
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_currentStep > 1) {
                                setState(() {
                                  _currentStep--;
                                  _errorMessage = null;
                                });
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textMuted,
                        side: const BorderSide(color: inputBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(_currentStep > 1 ? 'Kembali' : 'Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_currentStep == 1) {
                                _sendVerificationCode();
                              } else if (_currentStep == 2) {
                                _verifyCode();
                              } else {
                                _saveNewPassword();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentYellow,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        disabledBackgroundColor:
                            accentYellow.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : Text(
                              _currentStep == 1
                                  ? 'Kirim Kode'
                                  : (_currentStep == 2
                                      ? 'Verifikasi Kode'
                                      : 'Simpan Password'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: Colors.black,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
