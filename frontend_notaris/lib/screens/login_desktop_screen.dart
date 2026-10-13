import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class LoginDesktopScreen extends ConsumerStatefulWidget {
  const LoginDesktopScreen({super.key, this.errorMessage});

  final String? errorMessage;

  static const String backgroundImage = 'assets/images/login_background.jpg';
  static const String logoImage = 'assets/images/logo_notaris_ppat.png';

  @override
  ConsumerState<LoginDesktopScreen> createState() => _LoginDesktopScreenState();
}

class _LoginDesktopScreenState extends ConsumerState<LoginDesktopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).login(
          username: _usernameController.text,
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = ref.watch(authControllerProvider).status ==
        AuthStatus.authenticating;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: .1,
              child: Image.asset(LoginDesktopScreen.backgroundImage,
                  fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: Colors.white.withValues(alpha: .15)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final card = _buildLoginCard(isBusy);
                      if (constraints.maxWidth < 720) {
                        return card;
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Image.asset(
                                    LoginDesktopScreen.logoImage,
                                    width: 220,
                                    height: 110,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'SIM Notaris PPAT',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryConfirm,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Sistem Informasi Manajemen Notaris & PPAT',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 36),
                          SizedBox(width: 410, child: card),
                        ],
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

  Widget _buildLoginCard(bool isBusy) {
    final errorMessage = widget.errorMessage;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: .16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Login',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryConfirm,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _usernameController,
              enabled: !isBusy,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              decoration: _inputDecoration('Username', Icons.person_outline),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Username wajib diisi.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              enabled: !isBusy,
              obscureText: _obscurePassword,
              onFieldSubmitted: (_) => _submit(),
              autofillHints: const [AutofillHints.password],
              decoration: _inputDecoration('Password', Icons.lock_outline)
                  .copyWith(
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Tampilkan password' : 'Sembunyikan password',
                  onPressed: isBusy
                      ? null
                      : () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Password wajib diisi.'
                  : null,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _rememberMe,
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Ingat saya', style: TextStyle(fontSize: 13)),
              subtitle: const Text(
                'Pulihkan sesi otomatis pada perangkat ini.',
                style: TextStyle(fontSize: 11),
              ),
              onChanged: isBusy
                  ? null
                  : (value) => setState(() => _rememberMe = value ?? false),
            ),
            if (errorMessage != null && errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  errorMessage,
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: isBusy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryConfirm,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Login',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 19),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: .7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.primaryConfirm,
          width: 1.5,
        ),
      ),
    );
  }
}
