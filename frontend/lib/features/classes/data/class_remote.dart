import 'package:supabase_flutter/supabase_flutter.dart';

typedef ClassRow = Map<String, dynamic>;

abstract class ClassRemote {
  Future<List<ClassRow>> read(
    String table, {
    DateTime? since,
    String? id,
    bool inventory = false,
  });
  Future<dynamic> call(String name, ClassRow parameters);
  Future<ClassRow> createClass(ClassRow values);
}

class SupabaseClassRemote implements ClassRemote {
  SupabaseClassRemote(this.client);
  final SupabaseClient client;

  @override
  Future<List<ClassRow>> read(
    String table, {
    DateTime? since,
    String? id,
    bool inventory = false,
  }) async {
    final rows = <ClassRow>[];
    String? after;
    while (true) {
      var query = client.from(table).select(inventory ? 'id,deleted_at' : '*');
      if (since != null) {
        query = query.gte('updated_at', since.toUtc().toIso8601String());
      }
      if (id != null) query = query.eq('id', id);
      if (after != null) query = query.gt('id', after);
      final page = await query
          .order('id')
          .limit(500)
          .timeout(const Duration(seconds: 20));
      rows.addAll(page);
      if (page.isEmpty) return rows;
      // Continue until empty, including servers configured below our page size.
      after = page.last['id'] as String;
    }
  }

  @override
  Future<dynamic> call(String name, ClassRow parameters) =>
      client.rpc(name, params: parameters);

  @override
  Future<ClassRow> createClass(ClassRow values) =>
      client.from('classes').insert(values).select().single();
}
