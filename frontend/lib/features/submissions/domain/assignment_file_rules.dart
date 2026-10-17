import '../../../data/local/app_database.dart';

/// Existing draft files are retained when assignment settings change. The
/// student must remove disallowed files before the draft can be turned in.
String? submissionFileRestriction(CachePost post, int fileCount) {
  if (fileCount == 0) return null;
  if (!post.allowFiles) {
    return 'File uploads are turned off for this assignment. Remove the saved files before turning in. You can add a link or text instead.';
  }
  if (fileCount > post.maxFiles) {
    return 'The file limit changed. Remove extra files before turning in. This assignment allows up to ${post.maxFiles} files.';
  }
  return null;
}
