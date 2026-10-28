import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/app_shell.dart';
import '../models/auth_session.dart';
import '../providers/auth_provider.dart';
import '../providers/pekerjaan_provider.dart';
import '../services/session_sync_controller.dart';
import 'login_desktop_screen.dart';

class AuthStartupGate extends ConsumerWidget {
  const AuthStartupGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    switch (auth.status) {
      case AuthStatus.loading:
      case AuthStatus.authenticating:
        return const _StartupLoadingScreen();
      case AuthStatus.unauthenticated:
        return LoginDesktopScreen(errorMessage: auth.errorMessage);
      case AuthStatus.authenticated:
        return _AuthenticatedShell(
          session: auth.session!,
          onLogout: () => ref.read(authControllerProvider.notifier).logout(),
        );
    }
  }
}

class _AuthenticatedShell extends ConsumerStatefulWidget {
  const _AuthenticatedShell({required this.session, required this.onLogout});

  final AuthSession session;
  final VoidCallback onLogout;

  @override
  ConsumerState<_AuthenticatedShell> createState() =>
      _AuthenticatedShellState();
}

class _AuthenticatedShellState extends ConsumerState<_AuthenticatedShell>
    with WidgetsBindingObserver {
  late final SessionSyncController _sessionSyncController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionSyncController = SessionSyncController(
      synchronize: () => ref.read(syncCoordinatorProvider).synchronizeNow(),
    );
    _sessionSyncController.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sessionSyncController.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionSyncController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(session: widget.session, onLogout: widget.onLogout);
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo_notaris_ppat.png',
                  height: 88,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                const Text(
                  'SIM Notaris & PPAT',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Memeriksa sesi dan memuat hak akses...',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
