import 'package:dio/dio.dart';

class SidebarApiService {
  SidebarApiService(this._dio);

  final Dio _dio;

  Future<SidebarCatalogPage> catalog(SidebarCatalogQuery q) async {
    final raw = _asMap(
      (await _dio.get<Object?>(
        '/sidebars/catalog',
        queryParameters: {
          'page': q.page,
          'page_size': 10,
          'search': q.search,
          'status': q.status,
        },
      )).data,
    );
    if (raw['success'] != true || raw['data'] is! Map) {
      throw const FormatException('Katalog Sidebars tidak valid.');
    }
    return SidebarCatalogPage.fromJson(
      Map<String, dynamic>.from(raw['data'] as Map),
      q,
    );
  }

  Future<List<SidebarApiModel>> getAll() async {
    final response = await _dio.get<Map<String, dynamic>>('/sidebars');
    final envelope = _asMap(response.data);
    final data = envelope['data'];

    if (envelope['success'] != true || data is! List) {
      throw const FormatException('Format response sidebar tidak valid.');
    }

    return data
        .map(
          (item) => SidebarApiModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<SidebarTreeApiModel>> getTree() async {
    final response = await _dio.get<Map<String, dynamic>>('/sidebars/tree');
    final envelope = _asMap(response.data);
    final data = envelope['data'];

    if (envelope['success'] != true || data is! List) {
      throw const FormatException(
        'Format response struktur sidebar tidak valid.',
      );
    }

    return data
        .whereType<Map>()
        .map(
          (item) =>
              SidebarTreeApiModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<SidebarApiModel> getById(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/sidebars/$id');
    final envelope = _asMap(response.data);
    final data = _asMap(envelope['data']);

    if (envelope['success'] != true || data.isEmpty) {
      throw const FormatException('Format data sidebar tidak valid.');
    }

    return SidebarApiModel.fromJson(data);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}

class SidebarTreeApiModel {
  const SidebarTreeApiModel({required this.sidebar, this.childs = const []});

  final SidebarApiModel sidebar;
  final List<SidebarApiModel> childs;

  factory SidebarTreeApiModel.fromJson(Map<String, dynamic> json) {
    final sidebarJson = _asMap(json['sidebar']);
    final childrenJson = json['childs'];

    if (sidebarJson.isEmpty ||
        (childrenJson != null && childrenJson is! List)) {
      throw const FormatException('Struktur sidebar tidak valid.');
    }

    final children = childrenJson is List
        ? childrenJson
              .map(
                (item) =>
                    SidebarApiModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <SidebarApiModel>[];

    return SidebarTreeApiModel(
      sidebar: SidebarApiModel.fromJson(sidebarJson),
      childs: children,
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}

class SidebarApiModel {
  const SidebarApiModel({
    required this.id,
    required this.nama,
    required this.route,
    required this.kode,
    required this.icon,
    required this.index,
    this.parentId,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
  });

  final int id;
  final int? parentId;
  final String nama;
  final String route;
  final String kode;
  final String icon;
  final int index;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;

  factory SidebarApiModel.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final nama = json['sidebar_nama']?.toString().trim() ?? '';
    final kode = json['sidebar_kode']?.toString().trim() ?? '';

    final state = json['status'];
    if (id <= 0 ||
        nama.isEmpty ||
        kode.isEmpty ||
        ![0, 1, '0', '1'].contains(state)) {
      throw const FormatException('Data sidebar tidak valid.');
    }

    return SidebarApiModel(
      id: id,
      parentId: _parseNullableInt(json['sidebar_parent_id']),
      nama: nama,
      route: json['sidebar_route']?.toString() ?? '',
      kode: kode,
      icon: json['sidebar_icon']?.toString() ?? '',
      index: _parseInt(json['sidebar_index']),
      createdBy: _parseNullableInt(json['created_by']),
      updatedBy: _parseNullableInt(json['updated_by']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      status: _parseInt(state),
    );
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }
}

typedef SidebarCatalogQuery = ({int page, String search, String status});

Map<String, dynamic> _catalogMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('Metadata katalog tidak valid.');
  }
  return Map<String, dynamic>.from(value);
}

int? _catalogInt(Map<String, dynamic> m, String key, {bool nullable = false}) {
  if (!m.containsKey(key) ||
      (m[key] != null && m[key] is! int) ||
      (!nullable && m[key] == null)) {
    throw const FormatException('Angka katalog tidak valid.');
  }
  return m[key] as int?;
}

String? _catalogText(Map<String, dynamic> m, String key) {
  if (!m.containsKey(key) || (m[key] != null && m[key] is! String)) {
    throw const FormatException('Teks katalog tidak valid.');
  }
  return m[key] as String?;
}

class SidebarCatalogItem {
  SidebarCatalogItem.fromJson(Map<String, dynamic> m)
    : id = _catalogInt(m, 'id')!,
      parentId = _catalogInt(m, 'sidebar_parent_id', nullable: true),
      name = _catalogText(m, 'sidebar_nama'),
      code = _catalogText(m, 'sidebar_kode'),
      route = _catalogText(m, 'sidebar_route'),
      icon = _catalogText(m, 'sidebar_icon'),
      order = _catalogInt(m, 'sidebar_index', nullable: true),
      status = _catalogInt(m, 'status', nullable: true),
      parentName = _catalogText(m, 'parent_name'),
      parentStatus = _catalogInt(m, 'parent_status', nullable: true),
      parentExists = m['parent_exists'] == true,
      createdAtRaw = _catalogText(m, 'created_at'),
      createdAt = _catalogText(m, 'created_at') == null
          ? null
          : DateTime.tryParse(m['created_at'] as String) {
    if (id < 1 ||
        (parentId != null && parentId! < 0) ||
        m['parent_exists'] is! bool ||
        (m['created_at'] != null && createdAt == null) ||
        (parentExists && (parentId == null || parentId == 0))) {
      throw const FormatException('Identitas katalog tidak valid.');
    }
  }
  final int id;
  final int? parentId, order, status, parentStatus;
  final String? name, code, route, icon, parentName;
  final bool parentExists;
  final DateTime? createdAt;
  final String? createdAtRaw;
  String get parentLabel => parentId == null || parentId == 0
      ? 'Parent utama'
      : !parentExists
      ? 'Parent tidak ditemukan · ID $parentId'
      : '${parentName?.isNotEmpty == true ? parentName : 'Nama belum tersedia'} · ID $parentId${parentStatus == 0 ? ' · Nonaktif' : ''}';
  String get statusLabel => status == 1
      ? 'Aktif'
      : status == 0
      ? 'Nonaktif'
      : 'Tidak diketahui${status == null ? '' : ' ($status)'}';
}

class SidebarCatalogPage {
  SidebarCatalogPage.fromJson(Map<String, dynamic> m, SidebarCatalogQuery q)
    : total = _catalogInt(m, 'total')!,
      page = _catalogInt(m, 'page')!,
      pageSize = _catalogInt(m, 'page_size')!,
      totalPages = _catalogInt(m, 'total_pages')!,
      items = (m['items'] is List
          ? (m['items'] as List)
                .map((v) => SidebarCatalogItem.fromJson(_catalogMap(v)))
                .toList()
          : throw const FormatException('Baris katalog tidak valid.')) {
    final pages = total == 0 ? 1 : (total + 9) ~/ 10;
    final expected = page > pages ? 0 : (total - (page - 1) * 10).clamp(0, 10);
    if (total < 0 ||
        page != q.page ||
        page < 1 ||
        pageSize != 10 ||
        totalPages != pages ||
        items.length != expected ||
        items.map((v) => v.id).toSet().length != items.length) {
      throw const FormatException('Pagination katalog tidak valid.');
    }
  }
  final List<SidebarCatalogItem> items;
  final int total, page, pageSize, totalPages;
}

String sidebarCatalogError(Object error) {
  if (error is DioException) {
    return switch (error.response?.statusCode) {
      400 => 'Filter katalog tidak valid. Periksa pencarian dan status.',
      401 => 'Sesi berakhir atau dicabut. Silakan login kembali.',
      403 => 'Izin baca Sidebars ditolak oleh server.',
      404 => 'Endpoint katalog belum tersedia pada backend ini.',
      null =>
        'Backend offline atau tidak dapat dihubungi. Tidak ada data fallback.',
      _ => 'Katalog belum dapat dimuat. Muat ulang setelah memeriksa backend.',
    };
  }
  return 'Response katalog tidak valid. Tidak ada data yang ditampilkan.';
}
