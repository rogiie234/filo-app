class AppConfig {
  AppConfig._();

  static const environment = String.fromEnvironment('ENV');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void validate() {
    if (environment.trim().isEmpty ||
        supabaseUrl.trim().isEmpty ||
        supabaseAnonKey.trim().isEmpty) {
      throw StateError(
        'Provide ENV, SUPABASE_URL, and SUPABASE_ANON_KEY '
        'through --dart-define.',
      );
    }

    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('SUPABASE_URL must be a valid HTTPS URL.');
    }
  }
}
