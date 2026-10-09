import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/searchable_dropdown.dart';
import '../database/app_database.dart';
import '../providers/people_provider.dart';
import '../providers/pekerjaan_provider.dart';
import '../providers/transaction_provider.dart';
import '../repositories/transaction_repository.dart';

enum TransactionType { notaris, ppat }

/// Formats numeric currency input using Indonesian thousands separators.
class _CurrencyInputFormatter extends TextInputFormatter {
  const _CurrencyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final normalized = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final formatted = _formatCurrencyDigits(normalized);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatCurrencyDigits(String digits) {
  if (digits.isEmpty) return '';
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

double _parseCurrency(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  return double.tryParse(digits) ?? 0;
}
class DummyCategory {
  final String id;
  final String name;

  const DummyCategory({
    required this.id,
    required this.name,
  });
}

class DummyProcess {
  final String id;
  final String name;
  final String status;

  const DummyProcess({
    required this.id,
    required this.name,
    this.status = 'Belum Valid',
  });
}

class DummyApplicant {
  final String id, nik, name, phone, address, gender;
  final int? localId;
  final String? uuid;

  const DummyApplicant({
    required this.id,
    required this.nik,
    required this.name,
    required this.phone,
    required this.address,
    required this.gender,
    this.localId,
    this.uuid,
  });
}

class DummyOfficer {
  final String id, nik, name, email, phone, gender;
  final int? localId;
  final String? uuid;

  const DummyOfficer({
    required this.id,
    required this.nik,
    required this.name,
    required this.email,
    required this.phone,
    required this.gender,
    this.localId,
    this.uuid,
  });
}

/// Pekerjaan yang dipasang ke sebuah transaksi.
/// Satu pekerjaan dapat memiliki banyak kategori dan proses.
class DummyTransactionJob {
  final String id;
  final String jobCode;
  final String name;
  final List<DummyCategory> categories;
  final String estimatedTime;
  final double serviceCost;
  final double otherCost;
  final List<DummyProcess> processes;
  final int? masterNotarisId;
  final int? masterPpatId;
  final int? masterPriceId;
  final int? masterCategoryId;

  const DummyTransactionJob({
    required this.id,
    required this.jobCode,
    required this.name,
    required this.categories,
    required this.estimatedTime,
    required this.serviceCost,
    required this.otherCost,
    required this.processes,
    this.masterNotarisId,
    this.masterPpatId,
    this.masterPriceId,
    this.masterCategoryId,
  });

  double get totalCost => serviceCost + otherCost;
}

class DummyTransaction {
  final String id;
  final String number;
  final TransactionType type;
  final DummyApplicant applicant;
  final DummyOfficer officer;
  final List<DummyTransactionJob> jobs;
  final String registrationDate;
  final String deadline;
  final String status;
  final int materai;
  final String paymentType;
  final double discount;
  final double currentPayment;
  final String note;

  const DummyTransaction({
    required this.id,
    required this.number,
    required this.type,
    required this.applicant,
    required this.officer,
    required this.jobs,
    required this.registrationDate,
    required this.deadline,
    required this.status,
    required this.materai,
    required this.paymentType,
    required this.discount,
    required this.currentPayment,
    required this.note,
  });

  double get totalCost =>
      jobs.fold(0, (sum, job) => sum + job.totalCost);

  double get netTotal => totalCost - discount;
}

class TransactionDesktopScreen extends ConsumerStatefulWidget {
  const TransactionDesktopScreen({super.key});

  @override
  ConsumerState<TransactionDesktopScreen> createState() =>
      _TransactionDesktopScreenState();
}

class _TransactionDesktopScreenState
    extends ConsumerState<TransactionDesktopScreen> {
  TransactionType selectedType = TransactionType.notaris;

  DummyApplicant? selectedApplicant;
  DummyOfficer? selectedOfficer;

  List<DummyTransactionJob> selectedJobs = [];

  String transactionNumber = '10122092641342';
  String registrationDate = '22/09/2026';
  String deadline = '22/09/2026';
  String transactionStatus = 'Baru';
  String paymentType = 'Cash';
  int materai = 0;
  double discount = 0;
  double currentPayment = 0;
  String note = '';
  bool _isSaving = false;
  int _currentStep = 0;
  String? _editingTransactionId;

  final discountController = TextEditingController();
  final currentPaymentController = TextEditingController();
  final noteController = TextEditingController();
  final materaiController = TextEditingController();

  List<DummyApplicant> applicants = [];
  List<DummyOfficer> officers = [];

  // Temporary fixtures remain only for the legacy transaction search list.
  // The applicant/officer pickers above are populated from SQLite Master data.
  final _demoApplicants = const [
    DummyApplicant(id: 'A001', nik: '3505225803800002', name: 'Rita Tri Widayah', phone: '081222333444', address: 'Dusun Mronjo, Blitar', gender: 'Perempuan'),
    DummyApplicant(id: 'A002', nik: '3505010101000002', name: 'Siti Aminah', phone: '081234567890', address: 'Jl. Diponegoro No. 20, Blitar', gender: 'Perempuan'),
    DummyApplicant(id: 'A003', nik: '3505010101000003', name: 'Andi Pratama', phone: '082233445566', address: 'Jl. Sudirman No. 15, Blitar', gender: 'Laki-laki'),
  ];

  final _demoOfficers = const [
    DummyOfficer(id: 'P001', nik: '3505010101000011', name: 'Rina Wulandari', email: 'rina@notaris.test', phone: '081111222333', gender: 'Perempuan'),
    DummyOfficer(id: 'P002', nik: '3505010101000012', name: 'Dimas Saputra', email: 'dimas@notaris.test', phone: '082222333444', gender: 'Laki-laki'),
    DummyOfficer(id: 'P003', nik: '3505010101000013', name: 'Sari Anggraini', email: 'sari@notaris.test', phone: '083333444555', gender: 'Perempuan'),
  ];

  final notarisCategories = const [
    DummyCategory(id: 'K001', name: 'Akta Jual Beli'),
    DummyCategory(id: 'K002', name: 'Akta Hibah'),
    DummyCategory(id: 'K003', name: 'UMK'),
    DummyCategory(id: 'K004', name: 'Akta Kuasa'),
    DummyCategory(id: 'K005', name: 'Waris'),
    DummyCategory(id: 'K006', name: 'Perusahaan'),
  ];

  final ppatCategories = const [
    DummyCategory(id: 'K101', name: 'Jual Beli'),
    DummyCategory(id: 'K102', name: 'Hibah'),
    DummyCategory(id: 'K103', name: 'Pembagian Hak Bersama'),
    DummyCategory(id: 'K104', name: 'Hak Tanggungan'),
    DummyCategory(id: 'K105', name: 'Warisan'),
    DummyCategory(id: 'K106', name: 'Roya'),
  ];

  final notarisProcesses = const [
    DummyProcess(id: 'PR001', name: 'Pendalaman berkas dan kelengkapan berkas'),
    DummyProcess(id: 'PR002', name: 'Pendaftaran dan pemesanan nama perseroan'),
    DummyProcess(id: 'PR003', name: 'Pembuatan draft akta dan penandatanganan akta'),
    DummyProcess(id: 'PR004', name: 'Pembuatan salinan akta dan pendaftaran AHU'),
    DummyProcess(id: 'PR005', name: 'Pencetakan salinan dan pengesahan AHU'),
    DummyProcess(id: 'PR006', name: 'Pengambilan dan pelunasan'),
  ];

  final ppatProcesses = const [
    DummyProcess(id: 'PR101', name: 'Pengecekan dokumen'),
    DummyProcess(id: 'PR102', name: 'Pengecekan sertifikat'),
    DummyProcess(id: 'PR103', name: 'Pembuatan akta'),
    DummyProcess(id: 'PR104', name: 'Penandatanganan'),
    DummyProcess(id: 'PR105', name: 'Pendaftaran'),
  ];

  late final transactions = <DummyTransaction>[
    DummyTransaction(
      id: 'TRX001',
      number: 'NTRX-2026-0001',
      type: TransactionType.notaris,
      applicant: _demoApplicants[0],
      officer: _demoOfficers[0],
      jobs: [
        DummyTransactionJob(
          id: 'TJ001',
          jobCode: 'N001',
          name: 'Pendirian Perusahaan Terbatas (PT)',
          categories: const [
            DummyCategory(id: 'K003', name: 'UMK'),
            DummyCategory(id: 'K006', name: 'Perusahaan'),
          ],
          estimatedTime: '4-7 Hari setelah berkas dinyatakan lengkap',
          serviceCost: 5000000,
          otherCost: 0,
          processes: notarisProcesses,
        ),
      ],
      registrationDate: '22/09/2026',
      deadline: '22/09/2026',
      status: 'Dalam Proses',
      materai: 0,
      paymentType: 'Cash',
      discount: 0,
      currentPayment: 5000000,
      note: '',
    ),
    DummyTransaction(
      id: 'TRX002',
      number: 'NTRX-2026-0002',
      type: TransactionType.notaris,
      applicant: _demoApplicants[1],
      officer: _demoOfficers[1],
      jobs: [
        DummyTransactionJob(
          id: 'TJ002',
          jobCode: 'N002',
          name: 'Akta Kuasa',
          categories: const [
            DummyCategory(id: 'K004', name: 'Akta Kuasa'),
          ],
          estimatedTime: '3 Hari',
          serviceCost: 750000,
          otherCost: 0,
          processes: [
            notarisProcesses[0],
            notarisProcesses[2],
            notarisProcesses[5],
          ],
        ),
      ],
      registrationDate: '20/09/2026',
      deadline: '25/09/2026',
      status: 'Baru',
      materai: 0,
      paymentType: 'Cash',
      discount: 0,
      currentPayment: 0,
      note: '',
    ),
    DummyTransaction(
      id: 'TRX003',
      number: 'PTRX-2026-0001',
      type: TransactionType.ppat,
      applicant: _demoApplicants[2],
      officer: _demoOfficers[2],
      jobs: [
        DummyTransactionJob(
          id: 'TJ003',
          jobCode: 'P001',
          name: 'Akta Jual Beli Tanah',
          categories: const [
            DummyCategory(id: 'K101', name: 'Jual Beli'),
            DummyCategory(id: 'K105', name: 'Warisan'),
          ],
          estimatedTime: '7 Hari',
          serviceCost: 2500000,
          otherCost: 250000,
          processes: ppatProcesses,
        ),
      ],
      registrationDate: '21/09/2026',
      deadline: '28/09/2026',
      status: 'Dalam Proses',
      materai: 1,
      paymentType: 'Cash',
      discount: 0,
      currentPayment: 1000000,
      note: '',
    ),
  ];

  @override
  void initState() {
    super.initState();
    registrationDate = _formatTransactionDate(DateTime.now());
    deadline = '';
    _syncEditableControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshTransactionNumber();
    });
  }

  static String _formatTransactionDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _refreshTransactionNumber() async {
    if (_editingTransactionId != null) return;
    try {
      final number = await ref
          .read(transactionRepositoryProvider)
          .generateNextTransactionNumber(
            jenisTransaksi: selectedType == TransactionType.notaris
                ? 'notaris'
                : 'ppat',
            date: DateTime.now(),
          );
      if (!mounted || _editingTransactionId != null) return;
      setState(() => transactionNumber = number);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat nomor transaksi: $error')),
      );
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final current = deadline.isEmpty
        ? null
        : DateTime.tryParse(
            deadline.split('/').reversed.join('-'),
          );
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 20),
      helpText: 'Pilih tanggal deadline',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked == null || !mounted) return;
    setState(() => deadline = _formatTransactionDate(picked));
  }

  void _syncEditableControllers() {
    discountController.text = discount == 0
        ? ''
        : _formatCurrencyDigits(discount.toStringAsFixed(0));
    currentPaymentController.text = currentPayment == 0
        ? ''
        : _formatCurrencyDigits(currentPayment.toStringAsFixed(0));
    noteController.text = note;
    materaiController.text = '$materai';
  }

  List<DummyCategory> get availableCategories =>
      selectedType == TransactionType.notaris
          ? notarisCategories
          : ppatCategories;

  List<DummyProcess> get availableProcesses =>
      selectedType == TransactionType.notaris
          ? notarisProcesses
          : ppatProcesses;

  String typeLabel(TransactionType type) =>
      type == TransactionType.notaris ? 'NOTARIS' : 'PPAT';

  double get totalCost =>
      selectedJobs.fold(0, (sum, job) => sum + job.totalCost);

  double get netTotal => totalCost - discount;

  double get remainingPayment =>
      (netTotal - currentPayment).clamp(0, double.infinity);

  String formatPrice(double value) {
    return 'Rp ${_formatCurrencyDigits(value.toStringAsFixed(0))}';
  }

  void changeType(TransactionType type) {
    if (type == selectedType) return;

    setState(() {
      _editingTransactionId = null;
      _currentStep = 0;
      selectedType = type;
      selectedApplicant = null;
      selectedOfficer = null;
      selectedJobs.clear();
      transactionNumber = '';
      registrationDate = _formatTransactionDate(DateTime.now());
      deadline = '';
      transactionStatus = 'Baru';
      materai = 0;
      discount = 0;
      currentPayment = 0;
      note = '';
    });

    _syncEditableControllers();
    _refreshTransactionNumber();
  }

  void resetForm() {
    setState(() {
      _editingTransactionId = null;
      _currentStep = 0;
      selectedApplicant = null;
      selectedOfficer = null;
      selectedJobs.clear();
      transactionNumber = '';
      registrationDate = _formatTransactionDate(DateTime.now());
      deadline = '';
      transactionStatus = 'Baru';
      paymentType = 'Cash';
      materai = 0;
      discount = 0;
      currentPayment = 0;
      note = '';
    });

    _syncEditableControllers();
    _refreshTransactionNumber();
  }

  void loadTransaction(DummyTransaction transaction) {
    setState(() {
      _editingTransactionId = transaction.id;
      _currentStep = 0;
      selectedType = transaction.type;
      transactionNumber = transaction.number;
      selectedApplicant = transaction.applicant;
      selectedOfficer = transaction.officer;
      selectedJobs = List.from(transaction.jobs);
      registrationDate = transaction.registrationDate;
      deadline = transaction.deadline;
      transactionStatus = transaction.status;
      materai = transaction.materai;
      paymentType = transaction.paymentType;
      discount = transaction.discount;
      currentPayment = transaction.currentPayment;
      note = transaction.note;
    });

    _syncEditableControllers();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transaksi ${transaction.number} berhasil dimuat.'),
      ),
    );
  }

  Future<void> showTransactionSearchDialog() async {
    final repository = ref.read(transactionRepositoryProvider);
    final database = repository.db;
    final jenis = selectedType == TransactionType.notaris ? 'notaris' : 'ppat';

    try {
      final rows = await (database.select(database.transaksis)
            ..where((t) =>
                t.deletedAt.isNull() & t.jenisTransaksi.equals(jenis))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

      final records = <DummyTransaction>[];
      for (final row in rows) {
        final applicantRow = row.pemohonId == null
            ? null
            : await (database.select(database.pemohons)
                  ..where((p) =>
                      p.id.equals(row.pemohonId!) & p.deletedAt.isNull()))
                .getSingleOrNull();
        final officerRow = row.petugasId == null
            ? null
            : await (database.select(database.petugasLocals)
                  ..where((p) =>
                      p.id.equals(row.petugasId!) & p.deletedAt.isNull()))
                .getSingleOrNull();

        final applicant = DummyApplicant(
          id: applicantRow?.id.toString() ?? '',
          localId: applicantRow?.id,
          uuid: applicantRow?.uuid,
          nik: applicantRow?.nik ?? '',
          name: applicantRow?.nama ?? '(Pemohon tidak ditemukan)',
          phone: applicantRow?.noTelp ?? '',
          address: applicantRow?.alamat ?? '',
          gender: '',
        );
        final officer = DummyOfficer(
          id: officerRow?.id.toString() ?? '',
          localId: officerRow?.id,
          uuid: officerRow?.uuid,
          nik: officerRow?.nik ?? '',
          name: officerRow?.nama ?? '(Petugas tidak ditemukan)',
          email: officerRow?.email ?? '',
          phone: officerRow?.noTelp ?? '',
          gender: '',
        );

        final details = await repository.watchDetailsOnce(row.id);
        final jobs = details.map((detail) {
          final categories = (detail.kategoriSnapshot ?? '')
              .split(',')
              .map((name) => name.trim())
              .where((name) => name.isNotEmpty)
              .map((name) => DummyCategory(id: name, name: name))
              .toList();
          return DummyTransactionJob(
            id: detail.id.toString(),
            jobCode: 'DB-${detail.id}',
            name: detail.namaPekerjaanSnapshot,
            categories: categories,
            estimatedTime: detail.estimasiWaktuSnapshot ?? '-',
            serviceCost: detail.biayaLayanan,
            otherCost: detail.biayaLainnya,
            processes: const [],
            masterNotarisId: detail.pekerjaanNotarisId,
            masterPpatId: detail.pekerjaanPpatId,
          );
        }).toList();

        records.add(DummyTransaction(
          id: row.id.toString(),
          number: row.noAkta,
          type: row.jenisTransaksi == 'ppat'
              ? TransactionType.ppat
              : TransactionType.notaris,
          applicant: applicant,
          officer: officer,
          jobs: jobs,
          registrationDate: row.tanggalTransaksi == null
              ? '-'
              : _formatTransactionDate(row.tanggalTransaksi!),
          deadline: row.tanggalJatuhTempo == null
              ? ''
              : _formatTransactionDate(row.tanggalJatuhTempo!),
          status: row.statusTransaksi,
          materai: row.jumlahMaterai,
          paymentType: row.metodePembayaran,
          discount: row.diskon,
          currentPayment: row.pembayaranSekarang,
          note: row.catatan ?? '',
        ));
      }

      if (!mounted) return;
      final result = await showDialog<DummyTransaction>(
        context: context,
        builder: (dialogContext) => _TransactionSearchDialog(
          title: 'Cari Transaksi ${typeLabel(selectedType)}',
          transactions: records,
          formatPrice: formatPrice,
        ),
      );

      if (result != null && mounted) {
        loadTransaction(result);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat transaksi dari SQLite: $error')),
      );
    }
  }

  Future<void> showApplicantDialog() async {
    final result = await showDialog<DummyApplicant>(
      context: context,
      builder: (dialogContext) => _ApplicantDialog(
        applicants: applicants,
      ),
    );

    if (result != null) {
      setState(() => selectedApplicant = result);
    }
  }

  Future<void> showOfficerDialog() async {
    final result = await showDialog<DummyOfficer>(
      context: context,
      builder: (dialogContext) => _OfficerDialog(
        officers: officers,
      ),
    );

    if (result != null) {
      setState(() => selectedOfficer = result);
    }
  }

  Future<void> addTransactionJob() async {
    final result = await showDialog<DummyTransactionJob>(
      context: context,
      builder: (dialogContext) => _TransactionJobDialog(
        type: selectedType,
        categories: availableCategories,
        processes: availableProcesses,
      ),
    );

    if (result != null) {
      setState(() => selectedJobs.add(result));
    }
  }

  Future<void> editTransactionJob(int index) async {
    final existing = selectedJobs[index];

    final result = await showDialog<DummyTransactionJob>(
      context: context,
      builder: (dialogContext) => _TransactionJobDialog(
        type: selectedType,
        categories: availableCategories,
        processes: availableProcesses,
        initialJob: existing,
      ),
    );

    if (result != null) {
      setState(() => selectedJobs[index] = result);
    }
  }

  void removeTransactionJob(int index) {
    setState(() => selectedJobs.removeAt(index));
  }

  InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.4,
        ),
      ),
    );
  }

  ButtonStyle outlinedButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.primary),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  ButtonStyle primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.card,
      elevation: 0,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget sectionHeader({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 21,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget emptyState({
    required IconData icon,
    required String text,
    double height = 120,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 28,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const Text(
            ':',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              softWrap: true,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget applicantCard({required bool mobile}) {
    final applicant = selectedApplicant;

    return card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.person_outline,
            title: 'Data Pemohon',
          ),
          const SizedBox(height: 18),
          if (applicant == null)
            emptyState(
              icon: Icons.person_outline,
              text: 'Belum ada pemohon dipilih.',
              height: 145,
            )
          else
            SizedBox(
              height: 145,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  infoRow('Nama', applicant.name),
                  infoRow('NIK', applicant.nik),
                  infoRow('Jenis Kelamin', applicant.gender),
                  infoRow('No. HP', applicant.phone),
                  Expanded(
                    child: infoRow('Alamat', applicant.address),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: showApplicantDialog,
              style: outlinedButtonStyle(),
              icon: const Icon(Icons.search, size: 18),
              label: Text(
                applicant == null ? 'Pilih Pemohon' : 'Ganti Pemohon',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget officerCard() {
    final officer = selectedOfficer;

    return card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.badge_outlined,
            title: 'Data Petugas',
          ),
          const SizedBox(height: 18),
          if (officer == null)
            emptyState(
              icon: Icons.badge_outlined,
              text: 'Belum ada petugas dipilih.',
              height: 145,
            )
          else
            SizedBox(
              height: 145,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  infoRow('Nama', officer.name),
                  infoRow('NIK', officer.nik),
                  infoRow('Jenis Kelamin', officer.gender),
                  infoRow('No. HP', officer.phone),
                  Expanded(
                    child: infoRow('Email', officer.email),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: showOfficerDialog,
              style: outlinedButtonStyle(),
              icon: const Icon(Icons.search, size: 18),
              label: Text(
                officer == null ? 'Pilih Petugas' : 'Ganti Petugas',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget transactionJobCard({
    required DummyTransactionJob job,
    required int index,
    required bool mobile,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.selectedMenuBg,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      job.jobCode,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit pekerjaan',
                onPressed: () => editTransactionJob(index),
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.textSecondary,
                  size: 19,
                ),
              ),
              IconButton(
                tooltip: 'Hapus pekerjaan',
                onPressed: () => removeTransactionJob(index),
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...job.categories.map(
                (category) => _Tag(
                  text: category.name,
                ),
              ),
              _Tag(
                text: '${job.processes.length} proses',
                muted: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(
            height: 1,
            color: AppColors.divider,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _SummaryItem(
                label: 'Estimasi',
                value: job.estimatedTime,
              ),
              _SummaryItem(
                label: 'Biaya Layanan',
                value: formatPrice(job.serviceCost),
              ),
              _SummaryItem(
                label: 'Biaya Lainnya',
                value: formatPrice(job.otherCost),
              ),
              _SummaryItem(
                label: 'Total',
                value: formatPrice(job.totalCost),
                emphasized: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (selectedType == TransactionType.ppat)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showSimpleInfoDialog(
                    'Kalkulator Pajak',
                    'Prototype kalkulator pajak PPAT untuk ${job.name}.',
                  ),
                  style: outlinedButtonStyle(),
                  icon: const Icon(Icons.calculate_outlined, size: 17),
                  label: const Text('Kalkulator Pajak'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showProcessDialog(job),
                  style: outlinedButtonStyle(),
                  icon: const Icon(Icons.format_list_bulleted, size: 17),
                  label: const Text('Daftar Proses'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showSimpleInfoDialog(
                    'Status PPAT',
                    'Prototype status PPAT untuk ${job.name}.',
                  ),
                  style: outlinedButtonStyle(),
                  icon: const Icon(Icons.assignment_turned_in_outlined, size: 17),
                  label: const Text('Status PPAT'),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: () => _showProcessDialog(job),
              style: outlinedButtonStyle(),
              icon: const Icon(Icons.format_list_bulleted, size: 17),
              label: const Text('Lihat Proses'),
            ),
        ],
      ),
    );
  }

  Widget jobsSection({required bool mobile}) {
    return card(
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 600;

              final header = sectionHeader(
                icon: Icons.assignment_outlined,
                title: 'Pekerjaan ${typeLabel(selectedType)}',
              );

              final addButton = ElevatedButton.icon(
                onPressed: addTransactionJob,
                style: primaryButtonStyle(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah Pekerjaan'),
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: addButton,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: header),
                  addButton,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (selectedJobs.isEmpty)
            emptyState(
              icon: Icons.assignment_outlined,
              text: 'Belum ada pekerjaan ditambahkan.',
              height: 150,
            )
          else
            Column(
              children: List.generate(
                selectedJobs.length,
                (index) => transactionJobCard(
                  job: selectedJobs[index],
                  index: index,
                  mobile: mobile,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget transactionInformation({required bool mobile}) {
    final numberField = TextFormField(
      key: ValueKey('transaction-number-$transactionNumber'),
      initialValue: transactionNumber,
      readOnly: true,
      decoration: inputDecoration(
        labelText: 'No. Transaksi',
      ),
    );

    final registrationField = TextFormField(
      key: ValueKey('registration-date-$registrationDate'),
      initialValue: registrationDate,
      readOnly: true,
      decoration: inputDecoration(
        labelText: 'Tanggal Registrasi',
        prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
    );

    final deadlineField = TextFormField(
      key: ValueKey('transaction-deadline-$deadline'),
      initialValue: deadline,
      readOnly: true,
      onTap: _pickDeadline,
      decoration: inputDecoration(
        labelText: 'Tanggal Deadline *',
        hintText: 'Pilih tanggal deadline',
        prefixIcon: const Icon(Icons.event_outlined, size: 18),
        suffixIcon: IconButton(
          tooltip: 'Pilih tanggal',
          onPressed: _pickDeadline,
          icon: const Icon(Icons.calendar_month_outlined),
        ),
      ),
    );

    final statusField = SearchableDropdown<String>(
      value: transactionStatus,
      items: const [
        'Baru',
        'Dalam Proses',
        'Selesai',
      ],
      label: 'Status Transaksi',
      onChanged: (value) {
        if (value != null) {
          setState(() => transactionStatus = value);
        }
      },
    );

    final materaiField = TextFormField(
      controller: materaiController,
      keyboardType: TextInputType.number,
      onChanged: (value) {
        setState(() => materai = int.tryParse(value) ?? 0);
      },
      decoration: inputDecoration(
        labelText: 'Jumlah Materai',
      ),
    );

    final fields = [
      numberField,
      registrationField,
      deadlineField,
      statusField,
      materaiField,
    ];

    return card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = mobile
              ? 1
              : constraints.maxWidth >= 1000
                  ? 3
                  : 2;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: fields.map((field) {
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - (columns - 1) * 16) / columns;

              return SizedBox(
                width: width,
                child: field,
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget paymentSummary({required bool mobile}) {
    final summary = card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.payments_outlined,
            title: 'Ringkasan Pembayaran',
          ),
          const SizedBox(height: 18),
          _MoneyRow(
            label: 'Total Biaya',
            value: formatPrice(totalCost),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: discountController,
            keyboardType: TextInputType.number,
            inputFormatters: const [
              _CurrencyInputFormatter(),
            ],
            decoration: inputDecoration(
              labelText: 'Potongan',
              prefixIcon: const Icon(
                Icons.remove_circle_outline,
                size: 18,
              ),
            ),
            onChanged: (value) {
              // Jangan setState di setiap ketikan.
              // Rebuild hanya bagian angka melalui ValueListenableBuilder
              // agar keyboard/focus/cursor tidak terpental.
              discount = _parseCurrency(value);
            },
          ),
          const SizedBox(height: 14),
          const Divider(
            height: 1,
            color: AppColors.divider,
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: discountController,
            builder: (context, value, child) {
              final currentDiscount = _parseCurrency(value.text);
              final currentNetTotal =
                  totalCost - currentDiscount;

              return _MoneyRow(
                label: 'Total Netto',
                value: formatPrice(currentNetTotal),
                emphasized: true,
              );
            },
          ),
          const SizedBox(height: 16),
          SearchableDropdown<String>(
            value: paymentType,
            items: const [
              'Cash',
              'Transfer',
              'Debit',
              'Kredit',
              'QRIS',
              'Lainnya',
            ],
            label: 'Jenis Pembayaran',
            onChanged: (value) {
              if (value != null) {
                setState(() => paymentType = value);
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: ValueKey('payment-deadline-$deadline'),
            initialValue: deadline,
            readOnly: true,
            onTap: _pickDeadline,
            decoration: inputDecoration(
              labelText: 'Jatuh Tempo',
              hintText: 'Pilih tanggal deadline',
              prefixIcon: const Icon(
                Icons.event_outlined,
                size: 18,
              ),
              suffixIcon: IconButton(
                tooltip: 'Pilih tanggal',
                onPressed: _pickDeadline,
                icon: const Icon(Icons.calendar_month_outlined),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showSimpleInfoDialog(
                'Riwayat Pembayaran',
                'Prototype riwayat pembayaran untuk transaksi $transactionNumber.',
              ),
              style: outlinedButtonStyle(),
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Lihat Riwayat Pembayaran'),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: Listenable.merge([
              discountController,
              currentPaymentController,
            ]),
            builder: (context, _) {
              final currentDiscount = _parseCurrency(discountController.text);
              final currentPaymentValue = _parseCurrency(currentPaymentController.text);
              final currentNetTotal = totalCost - currentDiscount;
              final remaining = (currentNetTotal - currentPaymentValue)
                  .clamp(0.0, double.infinity)
                  .toDouble();

              return _MoneyRow(
                label: 'Sisa Pembayaran',
                value: formatPrice(remaining),
              );
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: currentPaymentController,
            keyboardType: TextInputType.number,
            inputFormatters: const [
              _CurrencyInputFormatter(),
            ],
            decoration: inputDecoration(
              labelText: 'Pembayaran Sekarang',
            ),
            onChanged: (value) {
              // Simpan nilai numerik tanpa separator untuk persistence.
              currentPayment = _parseCurrency(value);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: noteController,
            maxLines: 3,
            decoration: inputDecoration(
              labelText: 'Keterangan',
              hintText: 'Tambahkan keterangan...',
            ),
            onChanged: (value) => note = value,
          ),
        ],
      ),
    );

    if (mobile) {
      return summary;
    }

    return SizedBox(
      width: 360,
      child: summary,
    );
  }

  Future<void> _saveTransaction() async {
    if (_isSaving) return;

    if (!_validateCurrentStep()) return;

    if (selectedApplicant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pemohon harus dipilih terlebih dahulu.')),
      );
      return;
    }

    if (selectedOfficer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Petugas harus dipilih terlebih dahulu.')),
      );
      return;
    }

    if (selectedJobs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal satu pekerjaan harus ditambahkan.')),
      );
      return;
    }

    if (deadline.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal deadline wajib dipilih.')),
      );
      return;
    }

    final applicant = selectedApplicant!;
    final officer = selectedOfficer!;
    if (applicant.localId == null || applicant.uuid == null ||
        officer.localId == null || officer.uuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pemohon dan petugas harus dipilih dari Master lokal.'),
        ),
      );
      return;
    }

    DateTime parseDate(String value) {
      final parts = value.split('/');
      if (parts.length != 3) {
        throw FormatException('Format tanggal tidak valid: $value');
      }
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    }

    setState(() => _isSaving = true);
    final isEditing = _editingTransactionId != null;

    try {
      final savedId = await ref.read(transactionControllerProvider.notifier).save(
        id: _editingTransactionId == null ? null : int.tryParse(_editingTransactionId!),
        nomorTransaksi: transactionNumber,
        jenisTransaksi: selectedType == TransactionType.notaris ? 'notaris' : 'ppat',
        pemohonId: applicant.localId!,
        pemohonUuid: applicant.uuid!,
        petugasId: officer.localId!,
        petugasUuid: officer.uuid!,
        status: transactionStatus,
        tanggalTransaksi: parseDate(registrationDate),
        tanggalJatuhTempo: deadline.trim().isEmpty ? null : parseDate(deadline),
        jobs: selectedJobs.map((job) => TransactionJobInput(
          jenisPekerjaan: selectedType == TransactionType.notaris ? 'notaris' : 'ppat',
          namaPekerjaan: job.name,
          pekerjaanNotarisId: job.masterNotarisId,
          pekerjaanPpatId: job.masterPpatId,
          kategoriSnapshot: job.categories.map((category) => category.name).join(', '),
          estimasiWaktuSnapshot: job.estimatedTime,
          biayaLayanan: job.serviceCost,
          biayaLainnya: job.otherCost,
        )).toList(),
        diskon: discount,
        pembayaranSekarang: isEditing ? 0 : currentPayment,
        metodePembayaran: paymentType,
        jumlahMaterai: materai,
        catatan: note,
      );

      if (!mounted) return;
      setState(() {
        _editingTransactionId = savedId.toString();
        _isSaving = false;
      });
      ref.invalidate(transactionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Transaksi $transactionNumber berhasil diperbarui.'
                : 'Transaksi $transactionNumber berhasil disimpan ke SQLite.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan transaksi: $error')),
      );
    }
  }

  Widget bottomActions({required bool mobile}) {
    final actions = [
      OutlinedButton(
        onPressed: resetForm,
        style: outlinedButtonStyle(),
        child: const Text('Reset'),
      ),
      ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveTransaction,
        style: primaryButtonStyle(),
        icon: const Icon(Icons.save_outlined, size: 18),
        label: const Text('Simpan Transaksi'),
      ),
    ];

    return Flex(
      direction: mobile ? Axis.vertical : Axis.horizontal,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment:
          mobile ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
      children: [
        actions[0],
        SizedBox(
          width: mobile ? 0 : 12,
          height: mobile ? 10 : 0,
        ),
        actions[1],
      ],
    );
  }

  Widget pageHeader({required bool mobile}) {
    return Flex(
      direction: mobile ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editingTransactionId == null
                  ? 'Transaksi Baru'
                  : 'Edit Transaksi',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 23,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 5),
            Text(
              _editingTransactionId == null
                  ? 'Transaksi  |  Form Baru'
                  : 'Transaksi  |  Edit $transactionNumber',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        if (mobile) const SizedBox(height: 14),
        SizedBox(
          width: mobile ? double.infinity : null,
          child: OutlinedButton.icon(
            onPressed: showTransactionSearchDialog,
            style: outlinedButtonStyle(),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Cari No. Transaksi'),
          ),
        ),
      ],
    );
  }

  Widget typeSwitcher({required bool mobile}) {
    Widget button(String label, TransactionType type) {
      final selected = selectedType == type;

      return SizedBox(
        width: mobile ? double.infinity : 155,
        height: 44,
        child: ElevatedButton(
          onPressed: () => changeType(type),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                selected ? AppColors.selectedMenuText : AppColors.card,
            foregroundColor:
                selected ? AppColors.card : AppColors.selectedMenuText,
            elevation: 0,
            side: const BorderSide(
              color: AppColors.selectedMenuText,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jenis Transaksi',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (mobile)
          Row(
            children: [
              Expanded(child: button('NOTARIS', TransactionType.notaris)),
              const SizedBox(width: 10),
              Expanded(child: button('PPAT', TransactionType.ppat)),
            ],
          )
        else
          Row(
            children: [
              button('NOTARIS', TransactionType.notaris),
              const SizedBox(width: 10),
              button('PPAT', TransactionType.ppat),
            ],
          ),
      ],
    );
  }

  static const _workflowSteps = [
    ('Jenis Pekerjaan', 'Tentukan layanan dan pekerjaan transaksi.'),
    ('Data Pemohon', 'Pilih pihak/pemohon transaksi.'),
    ('Petugas', 'Tentukan petugas yang menangani transaksi.'),
    ('Pembayaran', 'Atur tagihan, pembayaran, dan keterangan.'),
    ('Dokumen & Catatan', 'Periksa dokumen dan informasi tambahan.'),
    ('Selesai Transaksi', 'Tentukan status transaksi secara manual.'),
  ];

  String _stepTitle(int index) => _workflowSteps[index].$1;

  String _stepDescription(int index) => _workflowSteps[index].$2;

  void _goToStep(int step) {
    if (step < 0 || step >= _workflowSteps.length) return;

    // Navigasi workflow tidak mengubah completion state.
    // Jika transaksi sudah dimuat dari pencarian, semua step tetap
    // dianggap sudah terisi. Step aktif hanya menunjukkan posisi editor.
    setState(() => _currentStep = step);
  }

  bool _validateCurrentStep() {
    String? message;
    switch (_currentStep) {
      case 0:
        if (selectedJobs.isEmpty) {
          message = 'Minimal satu pekerjaan harus ditambahkan.';
        }
        break;
      case 1:
        if (selectedApplicant == null) {
          message = 'Pemohon harus dipilih terlebih dahulu.';
        }
        break;
      case 2:
        if (selectedOfficer == null) {
          message = 'Petugas harus dipilih terlebih dahulu.';
        }
        break;
      case 3:
        if (totalCost <= 0) {
          message = 'Total biaya transaksi harus lebih dari Rp 0.';
        }
        break;
      case 4:
      case 5:
        break;
    }

    if (message == null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    return false;
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < _workflowSteps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _saveTransaction();
    }
  }

  Widget workflowProgress() {
    return card(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_workflowSteps.length, (index) {
            final active = index == _currentStep;
            // Progress adalah state data, bukan posisi cursor.
            // Untuk transaksi yang sedang diedit, data sudah dimuat,
            // sehingga step tetap completed walaupun user berpindah
            // kembali ke step sebelumnya.
            final completed = _editingTransactionId != null
                ? true
                : index < _currentStep;
            return Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: (_editingTransactionId != null || index <= _currentStep)
                      ? () => _goToStep(index)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active || completed ? AppColors.primary : AppColors.background,
                            border: Border.all(
                              color: active || completed ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: completed
                              ? const Icon(Icons.check, size: 17, color: AppColors.card)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: active ? AppColors.card : AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 9),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _stepTitle(index),
                              style: TextStyle(
                                color: active ? AppColors.primary : AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              completed
                                  ? 'Selesai'
                                  : active
                                      ? 'Sedang diisi'
                                      : 'Belum diisi',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < _workflowSteps.length - 1)
                  Container(
                    width: 42,
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: index < _currentStep ? AppColors.primary : AppColors.divider,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget transactionBasicInformation() {
    return card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 32) / 3;
          Widget field(String label, String value, IconData icon) {
            return SizedBox(
              width: width,
              child: TextFormField(
                key: ValueKey('$label-$value'),
                initialValue: value,
                readOnly: true,
                decoration: inputDecoration(
                  labelText: label,
                  prefixIcon: Icon(icon, size: 18),
                ),
              ),
            );
          }
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              field('No. Transaksi', transactionNumber, Icons.confirmation_number_outlined),
              field('Tanggal Registrasi', registrationDate, Icons.calendar_today_outlined),
              field('Tanggal Deadline', deadline, Icons.event_outlined),
            ],
          );
        },
      ),
    );
  }

  Widget documentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeader(
                icon: Icons.folder_open_outlined,
                title: 'Dokumen',
                trailing: const _Tag(text: 'Prototype', muted: true),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: AppColors.textSecondary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Kelengkapan dokumen akan dihubungkan ke data dokumen transaksi pada tahap implementasi database.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showSimpleInfoDialog(
                  'Dokumen',
                  'Modul dokumen transaksi akan diimplementasikan setelah struktur transaksi inti selesai.',
                ),
                style: outlinedButtonStyle(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Kelola Dokumen'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeader(icon: Icons.notes_outlined, title: 'Catatan Transaksi'),
              const SizedBox(height: 16),
              TextFormField(
                controller: noteController,
                maxLines: 5,
                decoration: inputDecoration(
                  labelText: 'Catatan',
                  hintText: 'Tambahkan informasi tambahan transaksi...',
                ),
                onChanged: (value) => note = value,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget finishStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeader(icon: Icons.flag_outlined, title: 'Status Transaksi'),
              const SizedBox(height: 10),
              const Text(
                'Status tidak berubah otomatis. Pilih status transaksi secara manual sesuai kondisi pekerjaan di lapangan.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 18),
              SearchableDropdown<String>(
                value: transactionStatus,
                items: const ['Baru', 'Dalam Proses', 'Selesai'],
                label: 'Status Transaksi',
                onChanged: (value) {
                  if (value != null) setState(() => transactionStatus = value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeader(icon: Icons.fact_check_outlined, title: 'Ringkasan Transaksi'),
              const SizedBox(height: 16),
              _MoneyRow(label: 'Total Biaya', value: formatPrice(totalCost)),
              const SizedBox(height: 10),
              _MoneyRow(label: 'Total Netto', value: formatPrice(netTotal), emphasized: true),
              const SizedBox(height: 10),
              _MoneyRow(label: 'Pembayaran', value: formatPrice(currentPayment)),
              const SizedBox(height: 10),
              _MoneyRow(label: 'Sisa Tagihan', value: formatPrice(remainingPayment)),
            ],
          ),
        ),
      ],
    );
  }

  Widget currentWorkflowStep() {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            typeSwitcher(mobile: false),
            const SizedBox(height: 20),
            transactionBasicInformation(),
            const SizedBox(height: 20),
            jobsSection(mobile: false),
          ],
        );
      case 1:
        return applicantCard(mobile: false);
      case 2:
        return officerCard();
      case 3:
        return paymentSummary(mobile: false);
      case 4:
        return documentsStep();
      case 5:
        return finishStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget workflowNavigation() {
    final last = _currentStep == _workflowSteps.length - 1;
    return card(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => setState(() => _currentStep--),
              style: outlinedButtonStyle(),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Kembali'),
            ),
          const Spacer(),
          Text(
            'Langkah ${_currentStep + 1} dari ${_workflowSteps.length}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(width: 14),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _nextStep,
            style: primaryButtonStyle(),
            icon: Icon(last ? Icons.save_outlined : Icons.arrow_forward, size: 18),
            label: Text(
              last
                  ? (_editingTransactionId == null
                      ? 'Simpan Transaksi'
                      : 'Simpan Perubahan')
                  : 'Simpan & Lanjut',
            ),
          ),
        ],
      ),
    );
  }

  Widget workflowHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _stepTitle(_currentStep),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Text(
                _stepDescription(_currentStep),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        _StatusTag(text: transactionStatus),
      ],
    );
  }

  void _showSimpleInfoDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(title),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showProcessDialog(DummyTransactionJob job) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Proses ${job.name}'),
        content: SizedBox(
          width: 700,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: job.processes.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              color: AppColors.divider,
            ),
            itemBuilder: (context, index) {
              final process = job.processes[index];

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: AppColors.selectedMenuBg,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                title: Text(
                  process.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                trailing: _StatusTag(text: process.status),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pemohonAsync = ref.watch(pemohonProvider);
    final petugasAsync = ref.watch(petugasProvider);
    final jenisKelaminAsync = ref.watch(jenisKelaminProvider);
    final genders = {
      for (final item in jenisKelaminAsync.valueOrNull ?? <JenisKelamin>[])
        item.id: item.nama,
    };

    applicants = [
      for (final item in pemohonAsync.valueOrNull ?? <Pemohon>[])
        DummyApplicant(
          id: item.id.toString(),
          nik: item.nik ?? '',
          name: item.nama,
          phone: item.noTelp ?? '',
          address: item.alamat ?? '',
          gender: genders[item.jenisKelamin] ?? '',
          localId: item.id,
          uuid: item.uuid,
        ),
    ];
    officers = [
      for (final item in petugasAsync.valueOrNull ?? <PetugasLocal>[])
        DummyOfficer(
          id: item.id.toString(),
          nik: item.nik ?? '',
          name: item.nama,
          email: item.email,
          phone: item.noTelp ?? '',
          gender: genders[item.jenisKelamin] ?? '',
          localId: item.id,
          uuid: item.uuid,
        ),
    ];

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              pageHeader(mobile: false),
              const SizedBox(height: 20),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 20),
              workflowProgress(),
              const SizedBox(height: 20),
              workflowHeader(),
              const SizedBox(height: 16),
              currentWorkflowStep(),
              const SizedBox(height: 20),
              workflowNavigation(),
            ],
          ),
        ),
        if (_isSaving)
          const Positioned.fill(
            child: _TransactionLoadingOverlay(),
          ),
      ],
    );
  }
  @override
  void dispose() {
    discountController.dispose();
    currentPaymentController.dispose();
    noteController.dispose();
    materaiController.dispose();
    super.dispose();
  }
}

class _TransactionLoadingOverlay extends StatelessWidget {
  const _TransactionLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: true,
      child: Container(
        color: AppColors.textPrimary.withValues(alpha: 0.18),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 14),
              Text(
                'Menyimpan transaksi...',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionJobDialog extends ConsumerStatefulWidget {
  final TransactionType type;
  final List<DummyCategory> categories;
  final List<DummyProcess> processes;
  final DummyTransactionJob? initialJob;

  const _TransactionJobDialog({
    required this.type,
    required this.categories,
    required this.processes,
    this.initialJob,
  });

  @override
  ConsumerState<_TransactionJobDialog> createState() => _TransactionJobDialogState();
}

class _TransactionJobDialogState extends ConsumerState<_TransactionJobDialog> {
  late final TextEditingController nameController;
  late final TextEditingController codeController;
  late final TextEditingController estimatedController;
  late final TextEditingController serviceCostController;
  late final TextEditingController otherCostController;

  late List<DummyCategory> selectedCategories;
  late List<DummyProcess> selectedProcesses;
  int? selectedMasterJobId;
  int? selectedMasterPriceId;
  List<({int id, int categoryId, String name, String price, String estimate})> _masterPriceOptions = [];
  bool _loadingMasterDetails = false;
  String? _masterLoadError;

  @override
  void initState() {
    super.initState();

    final job = widget.initialJob;

    nameController = TextEditingController(
      text: job?.name ?? '',
    );
    codeController = TextEditingController(
      text: job?.jobCode ?? '',
    );
    estimatedController = TextEditingController(
      text: job?.estimatedTime ?? '',
    );
    serviceCostController = TextEditingController(
      text: job == null
          ? ''
          : _formatCurrencyDigits(job.serviceCost.toStringAsFixed(0)),
    );
    otherCostController = TextEditingController(
      text: job == null
          ? ''
          : _formatCurrencyDigits(job.otherCost.toStringAsFixed(0)),
    );

    selectedCategories = List.from(job?.categories ?? const []);
    selectedProcesses = List.from(job?.processes ?? const []);
    selectedMasterJobId = widget.type == TransactionType.notaris
        ? job?.masterNotarisId
        : job?.masterPpatId;
    if (selectedMasterJobId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectMasterJob(selectedMasterJobId!);
      });
    }
  }

  Future<void> _selectMasterJob(int? id) async {
    if (id == null) return;
    setState(() {
      selectedMasterJobId = id;
      selectedMasterPriceId = null;
      _masterPriceOptions = [];
      selectedCategories = [];
      estimatedController.clear();
      serviceCostController.clear();
      _loadingMasterDetails = true;
      _masterLoadError = null;
    });
    try {
      final aggregate = widget.type == TransactionType.notaris
          ? await ref.read(pekerjaanNotarisRepositoryProvider).getAggregate(id)
          : await ref.read(pekerjaanPpatRepositoryProvider).getAggregate(id);
      if (!mounted) return;
      if (aggregate == null) {
        setState(() {
          _loadingMasterDetails = false;
          _masterLoadError = 'Detail pekerjaan tidak ditemukan di Master.';
        });
        return;
      }
      // Wait for Master categories to finish loading before mapping price rows.
      // Reading valueOrNull here could return an empty list on the first selection.
      final categoryData = await ref.read(pekerjaanKategoriProvider.future);
      final categoryNames = {for (final item in categoryData) item.id: item.nama};
      final priceOptions = [
        for (final item in aggregate.harga)
          if (categoryNames.containsKey(item.kategoriPekerjaanId))
            (
              id: item.id,
              categoryId: item.kategoriPekerjaanId,
              name: categoryNames[item.kategoriPekerjaanId]!,
              price: item.harga,
              estimate: item.estimasiWaktu,
            ),
      ];
      setState(() {
        nameController.text = aggregate.nama;
        codeController.text = '${widget.type == TransactionType.notaris ? 'N' : 'P'}-${aggregate.id}';
        _masterPriceOptions = priceOptions;
        final currentPrice = priceOptions.where((item) =>
          item.id == widget.initialJob?.masterPriceId
        ).firstOrNull;
        selectedMasterPriceId = currentPrice?.id ?? (priceOptions.length == 1 ? priceOptions.first.id : null);
        selectedCategories = currentPrice == null
            ? []
            : [DummyCategory(id: currentPrice.categoryId.toString(), name: currentPrice.name)];
        estimatedController.text = currentPrice?.estimate ?? '';
        serviceCostController.text = currentPrice == null
            ? ''
            : _formatCurrencyDigits(_parseCurrency(currentPrice.price).toStringAsFixed(0));
        selectedProcesses = [
          for (final item in aggregate.proses)
            DummyProcess(id: item.id.toString(), name: item.nama, status: item.detail),
        ];
        _loadingMasterDetails = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMasterDetails = false;
        _masterLoadError = 'Gagal memuat detail Master: $error';
      });
    }
  }

  InputDecoration decoration({
    String? label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.4,
        ),
      ),
    );
  }

  void addCategory() {
    showDialog<DummyCategory>(
      context: context,
      builder: (dialogContext) => _CategoryPickerDialog(
        categories: widget.categories
            .where((item) => !selectedCategories.contains(item))
            .toList(),
      ),
    ).then((result) {
      if (result != null) {
        setState(() => selectedCategories.add(result));
      }
    });
  }

  void addProcess() {
    showDialog<DummyProcess>(
      context: context,
      builder: (dialogContext) => _ProcessPickerDialog(
        processes: widget.processes
            .where(
              (item) => !selectedProcesses.any(
                (selected) => selected.id == item.id,
              ),
            )
            .toList(),
      ),
    ).then((result) {
      if (result != null) {
        setState(() => selectedProcesses.add(result));
      }
    });
  }

  void save() {
    if (nameController.text.trim().isEmpty) {
      _showValidation('Nama pekerjaan wajib diisi.');
      return;
    }

    if (selectedMasterJobId == null || selectedMasterPriceId == null) {
      _showValidation('Pilih pekerjaan dan kategori/harga dari Master terlebih dahulu.');
      return;
    }

    if (selectedProcesses.isEmpty) {
      _showValidation('Minimal satu proses pekerjaan harus dipilih.');
      return;
    }

    final result = DummyTransactionJob(
      id: widget.initialJob?.id ??
          'TJ-${DateTime.now().millisecondsSinceEpoch}',
      jobCode: codeController.text.trim().isEmpty
          ? '${widget.type == TransactionType.notaris ? 'N' : 'P'}-DUMMY'
          : codeController.text.trim(),
      name: nameController.text.trim(),
      categories: List.from(selectedCategories),
      estimatedTime: estimatedController.text.trim().isEmpty
          ? 'Belum ditentukan'
          : estimatedController.text.trim(),
      serviceCost: _parseCurrency(serviceCostController.text),
      otherCost: _parseCurrency(otherCostController.text),
      processes: List.from(selectedProcesses),
      masterNotarisId: widget.type == TransactionType.notaris ? selectedMasterJobId : null,
      masterPpatId: widget.type == TransactionType.ppat ? selectedMasterJobId : null,
      masterPriceId: selectedMasterPriceId,
      masterCategoryId: selectedCategories.isEmpty ? null : int.tryParse(selectedCategories.first.id),
    );

    Navigator.pop(context, result);
  }

  void _showValidation(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initialJob == null
                          ? 'Tambah Pekerjaan ${widget.type == TransactionType.notaris ? 'Notaris' : 'PPAT'}'
                          : 'Edit Pekerjaan',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(
              height: 1,
              color: AppColors.divider,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DialogSectionTitle(
                      title: 'Pilih dari Master Pekerjaan',
                    ),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final masterAsync = widget.type == TransactionType.notaris
                          ? ref.watch(pekerjaanNotarisProvider)
                          : ref.watch(pekerjaanPpatProvider);
                      final masterItems = widget.type == TransactionType.notaris
                          ? (ref.watch(pekerjaanNotarisProvider).valueOrNull ?? [])
                              .map((item) => (id: item.id, name: item.nama))
                              .toList()
                          : (ref.watch(pekerjaanPpatProvider).valueOrNull ?? [])
                              .map((item) => (id: item.id, name: item.nama))
                              .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: masterItems.any((item) => item.id == selectedMasterJobId)
                                ? selectedMasterJobId
                                : null,
                            isExpanded: true,
                            decoration: decoration(
                              label: 'Pekerjaan ${widget.type == TransactionType.notaris ? 'Notaris' : 'PPAT'}',
                              hint: masterAsync.isLoading ? 'Memuat data Master...' : 'Pilih pekerjaan dari Master',
                            ),
                            items: [
                              for (final item in masterItems)
                                DropdownMenuItem<int>(
                                  value: item.id,
                                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: _loadingMasterDetails ? null : _selectMasterJob,
                          ),
                          if (masterAsync.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('Gagal memuat Master: ${masterAsync.error}',
                                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
                            ),
                          if (_loadingMasterDetails)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          if (_masterLoadError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(_masterLoadError!,
                                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
                            ),
                        ],
                      );
                    }),
                    const SizedBox(height: 20),
                    const _DialogSectionTitle(
                      title: 'Informasi Pekerjaan',
                    ),
                    const SizedBox(height: 12),
                    if (mobile)
                      Column(
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: decoration(
                              label: 'Nama Pekerjaan',
                              hint: 'Contoh: Pendirian PT',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: codeController,
                            decoration: decoration(
                              label: 'Kode Pekerjaan',
                              hint: 'Kode internal',
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: nameController,
                              decoration: decoration(
                                label: 'Nama Pekerjaan',
                                hint: 'Contoh: Pendirian PT',
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: codeController,
                              decoration: decoration(
                                label: 'Kode Pekerjaan',
                                hint: 'Kode internal',
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    const _DialogSectionTitle(
                      title: 'Kategori Pekerjaan',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _masterPriceOptions.any((item) => item.id == selectedMasterPriceId)
                          ? selectedMasterPriceId
                          : null,
                      isExpanded: true,
                      decoration: decoration(
                        label: 'Kategori / Harga Pekerjaan',
                        hint: _masterPriceOptions.isEmpty
                            ? 'Pilih pekerjaan terlebih dahulu'
                            : 'Pilih kategori yang tersedia untuk pekerjaan ini',
                      ),
                      items: [
                        for (final item in _masterPriceOptions)
                          DropdownMenuItem<int>(
                            value: item.id,
                            child: Text(
                              '${item.name} • Rp ${_formatCurrencyDigits(_parseCurrency(item.price).toStringAsFixed(0))} • ${item.estimate}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _loadingMasterDetails || _masterPriceOptions.isEmpty
                          ? null
                          : (id) {
                              final selected = _masterPriceOptions.where((item) => item.id == id).firstOrNull;
                              if (selected == null) return;
                              setState(() {
                                selectedMasterPriceId = selected.id;
                                selectedCategories = [
                                  DummyCategory(id: selected.categoryId.toString(), name: selected.name),
                                ];
                                estimatedController.text = selected.estimate;
                                serviceCostController.text = _formatCurrencyDigits(
                                  _parseCurrency(selected.price).toStringAsFixed(0),
                                );
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kategori, harga, dan estimasi mengikuti konfigurasi Master. Untuk mengubahnya, edit data di menu Master.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    const _DialogSectionTitle(
                      title: 'Biaya dan Estimasi',
                    ),
                    const SizedBox(height: 12),
                    if (mobile)
                      Column(
                        children: [
                          TextField(
                            controller: estimatedController,
                            readOnly: selectedMasterPriceId != null,
                            decoration: decoration(
                              label: 'Estimasi Waktu',
                              hint: 'Contoh: 4-7 Hari',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: serviceCostController,
                            readOnly: selectedMasterPriceId != null,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [
                              _CurrencyInputFormatter(),
                            ],
                            decoration: decoration(
                              label: 'Biaya Layanan',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: otherCostController,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [
                              _CurrencyInputFormatter(),
                            ],
                            decoration: decoration(
                              label: 'Biaya Lainnya',
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: estimatedController,
                              readOnly: selectedMasterPriceId != null,
                              decoration: decoration(
                                label: 'Estimasi Waktu',
                                hint: 'Contoh: 4-7 Hari',
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: serviceCostController,
                              readOnly: selectedMasterPriceId != null,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [
                                _CurrencyInputFormatter(),
                              ],
                              decoration: decoration(
                                label: 'Biaya Layanan',
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: otherCostController,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [
                                _CurrencyInputFormatter(),
                              ],
                              decoration: decoration(
                                label: 'Biaya Lainnya',
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    const _DialogSectionTitle(
                      title: 'Proses Pekerjaan',
                    ),
                    const SizedBox(height: 12),
                    if (selectedProcesses.isEmpty)
                      _DialogEmptyState(
                        text: 'Belum ada proses.',
                      )
                    else
                      Column(
                        children: List.generate(
                          selectedProcesses.length,
                          (index) {
                            final process = selectedProcesses[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor:
                                        AppColors.selectedMenuBg,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      process.name,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  _StatusTag(text: process.status),
                                  IconButton(
                                    tooltip: 'Hapus proses',
                                    onPressed: () {
                                      setState(
                                        () => selectedProcesses.removeAt(
                                          index,
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: addProcess,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                          color: AppColors.primary,
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah Proses'),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(
              height: 1,
              color: AppColors.divider,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.card,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Simpan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    estimatedController.dispose();
    serviceCostController.dispose();
    otherCostController.dispose();
    super.dispose();
  }
}

class _TransactionSearchDialog extends StatefulWidget {
  final String title;
  final List<DummyTransaction> transactions;
  final String Function(double) formatPrice;

  const _TransactionSearchDialog({
    required this.title,
    required this.transactions,
    required this.formatPrice,
  });

  @override
  State<_TransactionSearchDialog> createState() =>
      _TransactionSearchDialogState();
}

class _TransactionSearchDialogState
    extends State<_TransactionSearchDialog> {
  final controller = TextEditingController();

  List<DummyTransaction> get filtered {
    final query = controller.text.trim().toLowerCase();

    if (query.isEmpty) {
      return widget.transactions;
    }

    return widget.transactions.where((item) {
      return [
        item.number,
        item.applicant.name,
        item.officer.name,
        item.status,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(widget.title),
      content: SizedBox(
        width: 950,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: controller,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari nomor, pemohon, petugas, atau status...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Tidak ada transaksi yang sesuai.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        color: AppColors.divider,
                      ),
                      itemBuilder: (context, index) {
                        final item = filtered[index];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          title: Text(
                            item.number,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${item.applicant.name} • ${item.officer.name} • ${item.registrationDate}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: _StatusTag(text: item.status),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _ApplicantDialog extends StatelessWidget {
  final List<DummyApplicant> applicants;

  const _ApplicantDialog({
    required this.applicants,
  });

  @override
  Widget build(BuildContext context) {
    return _SimpleSelectionDialog<DummyApplicant>(
      title: 'Pilih Pemohon',
      items: applicants,
      searchText: (item) => [
        item.nik,
        item.name,
        item.phone,
        item.address,
      ].join(' '),
      titleText: (item) => item.name,
      subtitleText: (item) =>
          '${item.nik} • ${item.gender} • ${item.phone}',
      onSelected: (item) => Navigator.pop(context, item),
    );
  }
}

class _OfficerDialog extends StatelessWidget {
  final List<DummyOfficer> officers;

  const _OfficerDialog({
    required this.officers,
  });

  @override
  Widget build(BuildContext context) {
    return _SimpleSelectionDialog<DummyOfficer>(
      title: 'Pilih Petugas',
      items: officers,
      searchText: (item) => [
        item.nik,
        item.name,
        item.email,
        item.phone,
      ].join(' '),
      titleText: (item) => item.name,
      subtitleText: (item) =>
          '${item.nik} • ${item.email} • ${item.phone}',
      onSelected: (item) => Navigator.pop(context, item),
    );
  }
}

class _SimpleSelectionDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) searchText;
  final String Function(T) titleText;
  final String Function(T) subtitleText;
  final ValueChanged<T> onSelected;

  const _SimpleSelectionDialog({
    required this.title,
    required this.items,
    required this.searchText,
    required this.titleText,
    required this.subtitleText,
    required this.onSelected,
  });

  @override
  State<_SimpleSelectionDialog<T>> createState() =>
      _SimpleSelectionDialogState<T>();
}

class _SimpleSelectionDialogState<T>
    extends State<_SimpleSelectionDialog<T>> {
  final controller = TextEditingController();

  List<T> get filtered {
    final query = controller.text.trim().toLowerCase();

    if (query.isEmpty) {
      return widget.items;
    }

    return widget.items
        .where(
          (item) => widget.searchText(item).toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(widget.title),
      content: SizedBox(
        width: 800,
        height: 450,
        child: Column(
          children: [
            TextField(
              controller: controller,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Tidak ada data.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        color: AppColors.divider,
                      ),
                      itemBuilder: (context, index) {
                        final item = filtered[index];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          title: Text(
                            widget.titleText(item),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            widget.subtitleText(item),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => widget.onSelected(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _CategoryPickerDialog extends StatelessWidget {
  final List<DummyCategory> categories;

  const _CategoryPickerDialog({
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return _SimpleSelectionDialog<DummyCategory>(
      title: 'Pilih Kategori',
      items: categories,
      searchText: (item) => item.name,
      titleText: (item) => item.name,
      subtitleText: (item) => item.id,
      onSelected: (item) => Navigator.pop(context, item),
    );
  }
}

class _ProcessPickerDialog extends StatelessWidget {
  final List<DummyProcess> processes;

  const _ProcessPickerDialog({
    required this.processes,
  });

  @override
  Widget build(BuildContext context) {
    return _SimpleSelectionDialog<DummyProcess>(
      title: 'Pilih Proses',
      items: processes,
      searchText: (item) => item.name,
      titleText: (item) => item.name,
      subtitleText: (item) => item.status,
      onSelected: (item) => Navigator.pop(context, item),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final bool muted;

  const _Tag({
    required this.text,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: muted
            ? AppColors.background
            : AppColors.selectedMenuBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: muted
              ? AppColors.textSecondary
              : AppColors.selectedMenuText,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String text;

  const _StatusTag({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: text == 'Selesai'
            ? AppColors.success.withValues(alpha: .10)
            : AppColors.warning.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: text == 'Selesai'
              ? AppColors.success
              : AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _MoneyRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasized
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: emphasized
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasized
                ? AppColors.primary
                : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: emphasized
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: emphasized
                  ? AppColors.primary
                  : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: emphasized
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogSectionTitle extends StatelessWidget {
  final String title;

  const _DialogSectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DialogEmptyState extends StatelessWidget {
  final String text;

  const _DialogEmptyState({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }
}
