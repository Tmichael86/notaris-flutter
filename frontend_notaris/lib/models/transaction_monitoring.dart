import '../database/app_database.dart';

const monitoringPageSize = 10;
const monitoringExportLimit = 10000;

typedef MonitoringFilter = ({
  String domain,
  String status,
  String search,
  String job,
  String category,
  int officerId,
  DateTime? from,
  DateTime? until,
  int index,
});

typedef MonitoringRow = ({
  Transaksi transaction,
  String? nik,
  String? applicant,
  String? officer,
  String? jobs,
  String? categories,
});

typedef MonitoringPage = ({int index, int total, List<MonitoringRow> rows});

typedef MonitoringExportRow = ({
  MonitoringRow row,
  String? estimates,
  String? processes,
  int? remaining,
});

typedef MonitoringOptions = ({
  List<String> jobs,
  List<String> categories,
  Map<int, String> officers,
});
