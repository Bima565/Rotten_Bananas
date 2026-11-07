import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/services/auth_service.dart';

class CreatePasswordDialog extends StatefulWidget {
  final String email;
  final bool isChangePassword;

  const CreatePasswordDialog({
    super.key,
    required this.email,
    this.isChangePassword = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String email,
    bool isChangePassword = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: isChangePassword,
      builder: (context) => CreatePasswordDialog(
        email: email,
        isChangePassword: isChangePassword,
      ),
    );
  }

  @override
  State<CreatePasswordDialog> createState() => _CreatePasswordDialogState();
}

class _CreatePasswordDialogState extends State<CreatePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _obscureCurrentPassword = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;

  static const Color bgDark = Color(0xFF151720);
  static const Color inputBg = Color(0xFF181A22);
  static const Color inputBorder = Color(0xFF262933);
  static const Color accentYellow = Color(0xFFFFC700);
  static const Color errorRed = Color(0xFFFF5252);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF8E92A0);
  static const Color greenCheck = Color(0xFF00E676);

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordRules);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePasswordRules);
    _currentPasswordController.dispose();
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

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isChangePassword) {
      if (_currentPasswordController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Password saat ini wajib diisi.';
        });
        return;
      }
      if (_currentPasswordController.text.trim() ==
          _passwordController.text.trim()) {
        setState(() {
          _errorMessage =
              'Password baru tidak boleh sama dengan password saat ini.';
        });
        return;
      }
    }

    if (!_isPasswordValid) {
      setState(() {
        _errorMessage =
            'Password harus memiliki huruf besar, huruf kecil, angka, dan minimal 6 karakter.';
      });
      return;
    }

    if (_passwordController.text != _confirmController.text) {
      setState(() {
        _errorMessage = 'Konfirmasi password tidak cocok.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.setAccountPassword(
        _passwordController.text.trim(),
        currentPassword: widget.isChangePassword
            ? _currentPasswordController.text.trim()
            : null,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = 'Gagal menyimpan password: ${e.message}';
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          msg = 'Password saat ini salah. Silakan periksa kembali.';
        } else if (e.code == 'requires-recent-login') {
          msg = 'Sesi telah kedaluwarsa. Silakan keluar dan login kembali.';
        }
        setState(() {
          _isLoading = false;
          _errorMessage = msg;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal menyimpan password: $e';
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Icon & Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentYellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: accentYellow.withValues(alpha: 0.4)),
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
                          Text(
                            widget.isChangePassword
                                ? 'Ubah Password Akun'
                                : 'Buat Password Baru',
                            style: const TextStyle(
                              color: textWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.email,
                            style: const TextStyle(
                              color: textMuted,
                              fontSize: 12.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Text(
                  widget.isChangePassword
                      ? 'Masukkan password saat ini dan password baru untuk akun Anda.'
                      : 'Kaitkan password ke akun Google Anda agar bisa login via email dan password native secara fleksibel.',
                  style: const TextStyle(color: textMuted, fontSize: 13),
                ),
                const SizedBox(height: 18),

                if (widget.isChangePassword) ...[
                  const Text(
                    'Password Saat Ini',
                    style: TextStyle(
                      color: textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: _obscureCurrentPassword,
                    style: const TextStyle(color: textWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Masukkan password saat ini',
                      hintStyle:
                          const TextStyle(color: textMuted, fontSize: 13),
                      prefixIcon: const Icon(
                        Icons.lock_clock_outlined,
                        color: textMuted,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrentPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: textMuted,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _obscureCurrentPassword =
                              !_obscureCurrentPassword);
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
                        borderSide: const BorderSide(
                            color: accentYellow, width: 1.2),
                      ),
                    ),
                    validator: (value) {
                      if (widget.isChangePassword &&
                          (value == null || value.isEmpty)) {
                        return 'Password saat ini tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],

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
                    hintStyle:
                        const TextStyle(color: textMuted, fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: textMuted,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: textMuted,
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
                      borderSide: const BorderSide(
                          color: accentYellow, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Konfirmasi Password',
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
                    hintStyle:
                        const TextStyle(color: textMuted, fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: textMuted,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: textMuted,
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
                      borderSide: const BorderSide(
                          color: accentYellow, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Rules checklist box
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

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: errorRed, fontSize: 12.5),
                  ),
                ],

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textMuted,
                          side: const BorderSide(color: inputBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
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
                            : const Text(
                                'Simpan Password',
                                style: TextStyle(
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
      ),
    );
  }
}
