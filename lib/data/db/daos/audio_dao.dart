part of '../app_database.dart';

@DriftAccessor(tables: [Audios])
class AudioDao extends DatabaseAccessor<AppDatabase> with _$AudioDaoMixin {
  AudioDao(super.db);

  Stream<List<AudioRow>> watchAll() => (select(
    audios,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<AudioRow?> getById(String id) =>
      (select(audios)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<AudioRow?> getByMd5(String md5) =>
      (select(audios)..where((t) => t.md5.equals(md5))).getSingleOrNull();

  Future<void> insertRow(AudioRow row) =>
      into(audios).insert(row, mode: InsertMode.insertOrReplace);

  Future<void> updateLanguage({
    required String id,
    required String language,
  }) async {
    await (update(audios)..where((t) => t.id.equals(id))).write(
      AudiosCompanion(
        language: Value(language),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Bumps [Audios.updatedAt] so Home "Recent media" can resurface the row.
  Future<void> touchUpdatedAt(String id) async {
    await (update(audios)..where((t) => t.id.equals(id))).write(
      AudiosCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> deleteId(String id) =>
      (delete(audios)..where((t) => t.id.equals(id))).go();

  /// Whether any row's [Audios.localUri] equals [localUri] (exact match).
  ///
  /// Uses `SELECT 1 … LIMIT 1` (EXISTS) instead of materialising full rows
  /// just to count them — paired with the `idx_audios_local_uri` index added
  /// in migration 16 (issue #469).
  Future<bool> existsByLocalUri(String localUri) async {
    final row =
        await (selectOnly(audios)
              ..addColumns([audios.id])
              ..where(audios.localUri.equals(localUri))
              ..limit(1))
            .map((r) => r.read(audios.id))
            .getSingleOrNull();
    return row != null;
  }
}
