import 'package:drift/drift.dart';

// Cloud cache definitions: migrations 0002-0005 and SCHEMA 10.1.
// UUIDs/enums map to TEXT. Server-generated IDs/join codes are supplied by the caller.

class CacheProfiles extends Table {
  @override
  String get tableName => "cache_profiles";
  TextColumn get id => text().named("id")();
  TextColumn get role => text().named("role")();
  TextColumn get displayName => text().named("display_name")();
  TextColumn get email => text().named("email").nullable()();
  TextColumn get school => text().named("school").nullable()();
  TextColumn get googlePhotoUrl =>
      text().named("google_photo_url").nullable()();
  TextColumn get avatarPath => text().named("avatar_path").nullable()();
  DateTimeColumn get privacyAcceptedAt =>
      dateTime().named("privacy_accepted_at").nullable()();
  TextColumn get privacyVersion => text().named("privacy_version").nullable()();
  DateTimeColumn get deletedAt => dateTime().named("deleted_at").nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named("created_at").withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named("updated_at").withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "CHECK (role IN ('student', 'instructor'))",
    "CHECK (length(display_name) between 1 and 80)",
    "CHECK (school is null or length(school) <= 120)",
  ];
}

@TableIndex.sql(
  "CREATE INDEX cache_idx_classes_owner ON cache_classes (owner_id) where deleted_at is null;",
)
class CacheClasses extends Table {
  @override
  String get tableName => "cache_classes";
  TextColumn get id => text().named("id")();
  TextColumn get ownerId =>
      text().named("owner_id").references(CacheProfiles, #id)();
  TextColumn get course => text().named("course")();
  TextColumn get section => text().named("section")();
  TextColumn get schoolYear => text().named("school_year")();
  TextColumn get joinCode => text().named("join_code").unique()();
  TextColumn get bannerColor => text().named("banner_color").nullable()();
  TextColumn get bannerPath => text().named("banner_path").nullable()();
  DateTimeColumn get archivedAt => dateTime().named("archived_at").nullable()();
  DateTimeColumn get deletedAt => dateTime().named("deleted_at").nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named("created_at").withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named("updated_at").withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "CHECK (length(course) between 1 and 120)",
    "CHECK (length(section) between 1 and 60)",
    "CHECK (length(school_year) between 1 and 20)",
  ];
}

@TableIndex.sql(
  "CREATE INDEX cache_idx_members_student ON cache_class_members (student_id, status);",
)
@TableIndex.sql(
  "CREATE INDEX cache_idx_members_class ON cache_class_members (class_id, status);",
)
class CacheClassMembers extends Table {
  @override
  String get tableName => "cache_class_members";
  TextColumn get id => text().named("id")();
  TextColumn get classId => text()
      .named("class_id")
      .references(CacheClasses, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('studentMemberships')
  TextColumn get studentId =>
      text().named("student_id").references(CacheProfiles, #id)();
  TextColumn get status =>
      text().named("status").withDefault(Constant("pending"))();
  DateTimeColumn get requestedAt =>
      dateTime().named("requested_at").withDefault(currentDateAndTime)();
  DateTimeColumn get decidedAt => dateTime().named("decided_at").nullable()();
  @ReferenceName('decidedMemberships')
  TextColumn get decidedBy =>
      text().named("decided_by").nullable().references(CacheProfiles, #id)();
  DateTimeColumn get leftAt => dateTime().named("left_at").nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named("created_at").withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named("updated_at").withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('pending', 'active', 'declined', 'removed', 'left'))",
    "unique (class_id, student_id)",
  ];
}

@TableIndex.sql(
  "CREATE INDEX cache_idx_posts_class ON cache_posts (class_id, created_at desc);",
)
@TableIndex.sql(
  "CREATE INDEX cache_idx_posts_due ON cache_posts (class_id, due_at) where kind = 'assignment';",
)
class CachePosts extends Table {
  @override
  String get tableName => "cache_posts";
  TextColumn get id => text().named("id")();
  TextColumn get classId => text()
      .named("class_id")
      .references(CacheClasses, #id, onDelete: KeyAction.cascade)();
  TextColumn get authorId =>
      text().named("author_id").references(CacheProfiles, #id)();
  TextColumn get kind => text().named("kind")();
  TextColumn get title => text().named("title")();
  TextColumn get body => text().named("body").nullable()();
  IntColumn get points => integer().named("points").nullable()();
  DateTimeColumn get dueAt => dateTime().named("due_at").nullable()();
  BoolColumn get acceptLate =>
      boolean().named("accept_late").withDefault(Constant(true))();
  BoolColumn get allowFiles =>
      boolean().named("allow_files").withDefault(Constant(true))();
  IntColumn get maxFiles =>
      integer().named("max_files").withDefault(Constant(5))();
  DateTimeColumn get createdAt =>
      dateTime().named("created_at").withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named("updated_at").withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named("deleted_at").nullable()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "CHECK (kind IN ('announcement', 'material', 'assignment'))",
    "CHECK (length(title) between 1 and 120)",
    "CHECK (body is null or length(body) <= 5000)",
    "CHECK (points is null or points >= 0)",
    "CHECK (max_files between 1 and 5)",
    "check ( (kind = 'assignment' and points is not null and due_at is not null) or (kind <> 'assignment' and points is null and due_at is null) )",
  ];
}

@TableIndex.sql(
  "CREATE INDEX cache_idx_attachments_post ON cache_post_attachments (post_id);",
)
class CachePostAttachments extends Table {
  @override
  String get tableName => "cache_post_attachments";
  TextColumn get id => text().named("id")();
  TextColumn get postId => text()
      .named("post_id")
      .references(CachePosts, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text().named("kind")();
  TextColumn get name => text().named("name")();
  TextColumn get storagePath => text().named("storage_path").nullable()();
  TextColumn get url => text().named("url").nullable()();
  TextColumn get mimeType => text().named("mime_type").nullable()();
  IntColumn get sizeBytes => integer().named("size_bytes").nullable()();
  IntColumn get sortOrder =>
      integer().named("sort_order").withDefault(Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().named("created_at").withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named("updated_at").withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named("deleted_at").nullable()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "CHECK (kind IN ('file', 'link'))",
    "CHECK (length(name) <= 255)",
    "CHECK (size_bytes is null or size_bytes <= 26214400)",
    "check ( (kind = 'file' and storage_path is not null and url is null) or (kind = 'link' and url is not null and storage_path is null) )",
  ];
}

@TableIndex.sql(
  "CREATE INDEX cache_idx_submissions_post ON cache_submissions (post_id, status);",
)
@TableIndex.sql(
  "CREATE INDEX cache_idx_submissions_student ON cache_submissions (student_id);",
)
class CacheSubmissions extends Table {
  @override
  String get tableName => "cache_submissions";
  TextColumn get id => text().named("id")();
  TextColumn get postId => text()
      .named("post_id")
      .references(CachePosts, #id, onDelete: KeyAction.cascade)();
  TextColumn get studentId =>
      text().named("student_id").references(CacheProfiles, #id)();
  TextColumn get status =>
      text().named("status").withDefault(Constant("draft"))();
  TextColumn get privateComment => text().named("private_comment").nullable()();
  DateTimeColumn get submittedAt =>
      dateTime().named("submitted_at").nullable()();
  BoolColumn get isLate =>
      boolean().named("is_late").withDefault(Constant(false))();
  DateTimeColumn get unsubmitUntil =>
      dateTime().named("unsubmit_until").nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named("created_at").withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named("updated_at").withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('draft', 'turned_in'))",
    "CHECK (private_comment is null or length(private_comment) <= 1000)",
    "unique (post_id, student_id)",
  ];
}

@TableIndex.sql(
  "CREATE INDEX cache_idx_items_submission ON cache_submission_items (submission_id);",
)
class CacheSubmissionItems extends Table {
  @override
  String get tableName => "cache_submission_items";
  TextColumn get id => text().named("id")();
  TextColumn get submissionId => text()
      .named("submission_id")
      .references(CacheSubmissions, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text().named("kind")();
  TextColumn get name => text().named("name").nullable()();
  TextColumn get storagePath => text().named("storage_path").nullable()();
  TextColumn get url => text().named("url").nullable()();
  TextColumn get textContent => text().named("text_content").nullable()();
  TextColumn get mimeType => text().named("mime_type").nullable()();
  IntColumn get sizeBytes => integer().named("size_bytes").nullable()();
  IntColumn get sortOrder =>
      integer().named("sort_order").withDefault(Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().named("created_at").withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named("updated_at").withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named("deleted_at").nullable()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "CHECK (kind IN ('file', 'link', 'text'))",
    "CHECK (name is null or length(name) <= 255)",
    "CHECK (text_content is null or length(text_content) <= 10000)",
    "CHECK (size_bytes is null or size_bytes <= 26214400)",
    "check ( (kind = 'file' and storage_path is not null and url is null and text_content is null) or (kind = 'link' and url is not null and storage_path is null and text_content is null) or (kind = 'text' and text_content is not null and storage_path is null and url is null) )",
  ];
}

class CacheGrades extends Table {
  @override
  String get tableName => "cache_grades";
  TextColumn get submissionId => text()
      .named("submission_id")
      .references(CacheSubmissions, #id, onDelete: KeyAction.cascade)();
  IntColumn get score => integer().named("score").nullable()();
  TextColumn get feedback => text().named("feedback").nullable()();
  TextColumn get gradedBy =>
      text().named("graded_by").nullable().references(CacheProfiles, #id)();
  DateTimeColumn get gradedAt => dateTime().named("graded_at").nullable()();
  DateTimeColumn get returnedAt => dateTime().named("returned_at").nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named("created_at").withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named("updated_at").withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {submissionId};
  @override
  List<String> get customConstraints => [
    "CHECK (score is null or score >= 0)",
    "CHECK (feedback is null or length(feedback) <= 2000)",
  ];
}

@TableIndex.sql(
  "CREATE INDEX cache_idx_quizzes_class ON cache_quizzes (class_id, status);",
)
class CacheQuizzes extends Table {
  @override
  String get tableName => "cache_quizzes";
  TextColumn get id => text().named("id")();
  TextColumn get classId => text()
      .named("class_id")
      .references(CacheClasses, #id, onDelete: KeyAction.cascade)();
  TextColumn get authorId =>
      text().named("author_id").references(CacheProfiles, #id)();
  TextColumn get type => text().named("type").withDefault(Constant("quiz"))();
  TextColumn get title => text().named("title")();
  TextColumn get instructions => text().named("instructions").nullable()();
  IntColumn get timeLimitMinutes =>
      integer().named("time_limit_minutes").withDefault(Constant(30))();
  DateTimeColumn get opensAt => dateTime().named("opens_at").nullable()();
  DateTimeColumn get closesAt => dateTime().named("closes_at").nullable()();
  BoolColumn get shuffleQuestions =>
      boolean().named("shuffle_questions").withDefault(Constant(true))();
  BoolColumn get shuffleOptions =>
      boolean().named("shuffle_options").withDefault(Constant(true))();
  BoolColumn get showCorrectAnswers =>
      boolean().named("show_correct_answers").withDefault(Constant(true))();
  IntColumn get passingPercent =>
      integer().named("passing_percent").nullable()();
  TextColumn get status =>
      text().named("status").withDefault(Constant("draft"))();
  DateTimeColumn get publishedAt =>
      dateTime().named("published_at").nullable()();
  DateTimeColumn get resultsReleasedAt =>
      dateTime().named("results_released_at").nullable()();
  IntColumn get totalPoints =>
      integer().named("total_points").withDefault(Constant(0))();
  BoolColumn get hasEssay =>
      boolean().named("has_essay").withDefault(Constant(false))();
  DateTimeColumn get lockedAt => dateTime().named("locked_at").nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named("created_at").withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named("updated_at").withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named("deleted_at").nullable()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('quiz', 'exam'))",
    "CHECK (length(title) between 1 and 120)",
    "CHECK (instructions is null or length(instructions) <= 5000)",
    "CHECK (time_limit_minutes between 1 and 600)",
    "CHECK (passing_percent is null or passing_percent between 0 and 100)",
    "CHECK (status IN ('draft', 'published'))",
    "check (opens_at is null or closes_at is null or closes_at > opens_at)",
  ];
}

@TableIndex.sql(
  "CREATE INDEX cache_idx_notifications_inbox ON cache_notifications (recipient_id, created_at desc);",
)
@TableIndex.sql(
  "CREATE INDEX cache_idx_notifications_unread ON cache_notifications (recipient_id) where read_at is null;",
)
class CacheNotifications extends Table {
  @override
  String get tableName => "cache_notifications";
  TextColumn get id => text().named("id")();
  TextColumn get recipientId => text()
      .named("recipient_id")
      .references(CacheProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get classId => text()
      .named("class_id")
      .nullable()
      .references(CacheClasses, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text().named("type")();
  TextColumn get title => text().named("title")();
  TextColumn get body => text().named("body").nullable()();
  TextColumn get targetType => text().named("target_type").nullable()();
  TextColumn get targetId => text().named("target_id").nullable()();
  DateTimeColumn get readAt => dateTime().named("read_at").nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named("created_at").withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('announcement', 'material', 'assignment', 'quiz_published', 'grade_returned', 'results_released', 'join_request', 'join_approved', 'join_declined', 'link_report', 'second_chance', 'removed_from_class'))",
  ];
}

// Released get_result RPC fields, keyed by the requested session_id.
// review contains JSON returned by the server, including its answer visibility rules.
class CacheResults extends Table {
  @override
  String get tableName => 'cache_results';
  TextColumn get sessionId => text().named('session_id')();
  IntColumn get score => integer()();
  IntColumn get totalPoints => integer().named('total_points')();
  IntColumn get percent => integer()();
  BoolColumn get passed => boolean().nullable()();
  TextColumn get review => text().nullable()();
  @override
  Set<Column> get primaryKey => {sessionId};
}

class SyncState extends Table {
  @override
  String get tableName => 'sync_state';
  TextColumn get syncedTableName => text().named('table_name')();
  DateTimeColumn get lastSyncedAt =>
      dateTime().named('last_synced_at').nullable()();
  @override
  Set<Column> get primaryKey => {syncedTableName};
}

// SCHEMA 10.2 lists fields only. Local defaults: attempts=0, created_at=now.
// Action type and status are supplied by callers; payload is valid JSON text.
class Outbox extends Table {
  @override
  String get tableName => 'outbox';
  TextColumn get id => text()();
  TextColumn get actionType => text().named('action_type')();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().named('last_error').nullable()();
  TextColumn get status => text()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'CHECK (attempts >= 0)',
    'CHECK (json_valid(payload))',
  ];
}
