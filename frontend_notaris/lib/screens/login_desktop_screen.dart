import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'dashboard_desktop_screen.dart';

class LoginDesktopScreen extends StatelessWidget {
  const LoginDesktopScreen({super.key});

  // Ganti dengan lokasi asset background kamu
  static const String backgroundImage = 'assets/images/login_background.jpg';

  // Ganti dengan lokasi asset logo gabungan Notaris + PPAT
  static const String logoImage = 'assets/images/logo_notaris_ppat.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ============================================================
          // BACKGROUND
          // ============================================================
          Positioned.fill(
            child: Opacity(
              opacity: 0.1, // 0.1 sama dengan 10% opacity
              child: Image.asset(
                backgroundImage,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Overlay tipis supaya background tidak terlalu mencolok
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),

          // ============================================================
          // MAIN CONTENT
          // ============================================================
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1200,
                  maxHeight: 700,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 30,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isCompact = constraints.maxWidth < 800;

                      if (isCompact) {
                        return _buildCompactLayout(context);
                      }

                      return _buildDesktopLayout(context);
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

  // ================================================================
  // DESKTOP LAYOUT
  // ================================================================
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // ------------------------------------------------------------
        // LEFT SIDE
        // ------------------------------------------------------------
        Expanded(
          flex: 5,
          child: _buildBranding(),
        ),

        const SizedBox(width: 50),

        // ------------------------------------------------------------
        // RIGHT SIDE
        // ------------------------------------------------------------
        Expanded(
          flex: 4,
          child: Center(
            child: _buildLoginCard(context),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // COMPACT LAYOUT
  // ================================================================
Widget _buildCompactLayout(BuildContext context) {
  return Center(
    child: SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: _buildLoginCard(context),
    ),
  );
}

  // ================================================================
  // BRANDING
  // ================================================================
  Widget _buildBranding() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Image.asset(
            logoImage,
            width: 250,
            height: 130,
            fit: BoxFit.contain,
          ),

          const SizedBox(height: 20),

          // Title
          const Text(
            'SIM Notaris PPAT',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryConfirm,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Sistem Informasi Manajemen Notaris & PPAT',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // LOGIN CARD
  // ================================================================
  Widget _buildLoginCard(BuildContext context) {
    return Container(
      width: 420,
      padding: const EdgeInsets.fromLTRB(
        28,
        24,
        28,
        28,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ----------------------------------------------------------
          // TITLE
          // ----------------------------------------------------------
          const Text(
            'Login',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryConfirm,
            ),
          ),

          const SizedBox(height: 28),

          // ----------------------------------------------------------
          // USERNAME
          // ----------------------------------------------------------
          TextField(
            decoration: InputDecoration(
              hintText: 'User Name',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.grey,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.7),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryConfirm,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ----------------------------------------------------------
          // PASSWORD
          // ----------------------------------------------------------
          TextField(
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.grey,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.7),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryConfirm,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ----------------------------------------------------------
          // FORGOT PASSWORD
          // ----------------------------------------------------------
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Forgot Password'),
                      content: const Text(
                        'Fitur reset password belum tersedia.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    );
                  },
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryConfirm,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ----------------------------------------------------------
          // LOGIN BUTTON
          // ----------------------------------------------------------
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DashboardDesktopScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryConfirm,
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Login',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}