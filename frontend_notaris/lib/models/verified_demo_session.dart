import 'auth_session.dart';

class ExpiringPaymentDemoSession extends AuthSession {
  ExpiringPaymentDemoSession(
    AuthSession session,
    this.expiresAt, {
    this.expireSidebarAccess = false,
    this.profileId,
  }) : super(
         token: session.token,
         userId: session.userId,
         groupId: session.groupId,
         userName: session.userName,
         groupName: session.groupName,
         user: session.user,
         sidebars: session.sidebars,
         verifiedAt: session.verifiedAt,
         groupType: session.groupType,
         isOffline: true,
       );

  final DateTime expiresAt;
  final String? profileId;
  final bool expireSidebarAccess;

  @override
  List<Map<String, dynamic>> get sidebars =>
      expireSidebarAccess && !DateTime.now().isBefore(expiresAt)
      ? const []
      : super.sidebars;

  @override
  bool hasTransactionAccess({bool create = false, bool update = false}) =>
      DateTime.now().isBefore(expiresAt) &&
      super.hasTransactionAccess(create: create, update: update);
}
