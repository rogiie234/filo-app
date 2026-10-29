import 'package:supabase_flutter/supabase_flutter.dart';

class UnusedAssessmentClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Assessment widget fixtures must not use the SDK client.',
  );
}
