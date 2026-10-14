class AppConfig {
  AppConfig._();

  static const environment = String.fromEnvironment('ENV');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  static void validate() {
    if (environment.trim().isEmpty || supabaseAnonKey.trim().isEmpty) {
      throw StateError(
        'Provide ENV and SUPABASE_ANON_KEY through Dart defines.',
      );
    }
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError(
        'Provide a valid HTTPS SUPABASE_URL through Dart defines.',
      );
    }
  }
}
