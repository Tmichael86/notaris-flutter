part of 'app_database.dart';

extension _MateraiSchema on AppDatabase {
  Future<void> _createMateraiStorage() async {
    await customStatement('''
      CREATE TABLE materai_movements (
        id INTEGER PRIMARY KEY,
        source_namespace TEXT NOT NULL CHECK(length(trim(source_namespace)) > 0),
        source_id INTEGER NOT NULL CHECK(typeof(source_id) = 'integer' AND source_id > 0),
        business_date TEXT,
        source_created_ms INTEGER,
        stock_in INTEGER CHECK(typeof(stock_in) IN ('integer','null') AND stock_in >= 0),
        stock_out INTEGER CHECK(typeof(stock_out) IN ('integer','null') AND stock_out >= 0),
        recorded_stock INTEGER CHECK(typeof(recorded_stock) IN ('integer','null') AND recorded_stock >= 0),
        description TEXT NOT NULL,
        source_officer_id INTEGER CHECK(typeof(source_officer_id) IN ('integer','null') AND source_officer_id > 0),
        officer_snapshot TEXT,
        source_status INTEGER CHECK(source_status IN (0,1)),
        provenance_json TEXT NOT NULL CHECK(json_valid(provenance_json)),
        payload_sha256 TEXT NOT NULL CHECK(length(payload_sha256) = 64),
        review_reason TEXT,
        CHECK(review_reason IS NOT NULL OR (
          source_status IS 1 AND business_date IS NOT NULL AND source_created_ms IS NOT NULL
          AND stock_in IS NOT NULL AND stock_out IS NOT NULL AND recorded_stock IS NOT NULL
          AND source_officer_id IS NOT NULL AND length(trim(coalesce(officer_snapshot,''))) > 0
        )),
        UNIQUE(source_namespace, source_id)
      )
    ''');
    await customStatement('''
      CREATE INDEX materai_movements_source_order ON materai_movements
      (source_created_ms DESC, source_id DESC, source_namespace DESC)
    ''');
  }
}
