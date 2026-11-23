import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_transaction_authorization.dart';
import 'local_master_authorization_provider.dart';
export '../services/local_transaction_authorization.dart';

final localTransactionAuthorizationProvider =
    Provider<LocalTransactionAuthorization>(
      (ref) => LocalTransactionAuthorization(
        ref.watch(localMasterAuthorizationProvider),
      ),
    );
