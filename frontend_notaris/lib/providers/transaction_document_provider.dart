import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/transaction_document_repository.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

typedef TransactionDocumentProfile = ({
  String databasePath,
  String appDirectory,
});

final transactionDocumentProfileProvider =
    Provider<TransactionDocumentProfile?>((_) => null);

final transactionDocumentRepositoryProvider =
    Provider<TransactionDocumentRepository?>((ref) {
      final profile = ref.watch(transactionDocumentProfileProvider);
      if (profile == null) return null;
      return TransactionDocumentRepository(
        db: ref.watch(appDatabaseProvider),
        session: () => ref.read(authControllerProvider).session,
        verifiedDatabasePath: profile.databasePath,
        verifiedAppDirectory: profile.appDirectory,
      );
    });
