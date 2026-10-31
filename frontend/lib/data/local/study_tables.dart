import 'package:drift/drift.dart';

@DataClassName('StudyNotebook')
@TableIndex.sql(
  'CREATE INDEX study_idx_notebooks_opened ON notebooks(last_opened_at)',
)
class Notebooks extends Table {
  TextColumn get id => text()();
  TextColumn get name =>
      text().check(name.trim().length.isBiggerThanValue(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StudySource')
class NotebookSources extends Table {
  TextColumn get id => text()();
  TextColumn get notebookId =>
      text().references(Notebooks, #id, onDelete: KeyAction.cascade)();
  // This is a reference only: removing a file must preserve the source snapshot.
  TextColumn get fileId => text()();
  TextColumn get name => text()();
  TextColumn get sourceKey => text()();
  TextColumn get extractedText => text()();
  IntColumn get extractorRevision => integer()();
  DateTimeColumn get extractedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {notebookId, sourceKey},
  ];
}

@DataClassName('StudyChat')
@TableIndex.sql(
  'CREATE INDEX study_idx_chats_notebook ON chats(notebook_id, last_message_at)',
)
@TableIndex.sql('CREATE INDEX study_idx_chats_expiry ON chats(expires_at)')
class Chats extends Table {
  TextColumn get id => text()();
  TextColumn get notebookId =>
      text().references(Notebooks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastMessageAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StudyMessage')
@TableIndex.sql(
  'CREATE INDEX study_idx_messages_chat ON chat_messages(chat_id, created_at, position)',
)
class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get chatId =>
      text().references(Chats, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  TextColumn get mode => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get position => integer()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {chatId, position},
  ];
  @override
  List<String> get customConstraints => [
    "CHECK (role IN ('user','assistant'))",
    "CHECK (mode IN ('files','general'))",
    'CHECK (position >= 0)',
  ];
}

@DataClassName('StudySummary')
class Summaries extends Table {
  TextColumn get notebookId =>
      text().references(Notebooks, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text()();
  TextColumn get usageJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {notebookId};
}

@DataClassName('StudyDeck')
@TableIndex.sql(
  'CREATE INDEX study_idx_decks_notebook ON flashcard_decks(notebook_id, created_at)',
)
class FlashcardDecks extends Table {
  TextColumn get id => text()();
  TextColumn get notebookId =>
      text().references(Notebooks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get settings => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StudyCard')
class Flashcards extends Table {
  TextColumn get id => text()();
  TextColumn get deckId =>
      text().references(FlashcardDecks, #id, onDelete: KeyAction.cascade)();
  TextColumn get front => text()();
  TextColumn get back => text()();
  TextColumn get status => text().withDefault(const Constant('new'))();
  IntColumn get position => integer()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {deckId, position},
  ];
  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('new','learning','known'))",
    'CHECK (position >= 0)',
  ];
}

@DataClassName('StudyQuiz')
@TableIndex.sql(
  'CREATE INDEX study_idx_quizzes_notebook ON practice_quizzes(notebook_id, created_at)',
)
class PracticeQuizzes extends Table {
  TextColumn get id => text()();
  TextColumn get notebookId =>
      text().references(Notebooks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get settings => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StudyQuestion')
class PracticeQuestions extends Table {
  TextColumn get id => text()();
  TextColumn get quizId =>
      text().references(PracticeQuizzes, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()();
  TextColumn get prompt => text()();
  TextColumn get options => text().nullable()();
  IntColumn get correctIndex => integer().nullable()();
  BoolColumn get correctBoolean => boolean().nullable()();
  TextColumn get acceptedAnswers => text().nullable()();
  TextColumn get explanation => text()();
  IntColumn get position => integer()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {quizId, position},
  ];
  @override
  List<String> get customConstraints => [
    'CHECK (position >= 0)',
    "CHECK ((type='multiple_choice' AND options IS NOT NULL AND correct_index BETWEEN 0 AND 3 AND correct_index IS NOT NULL AND correct_boolean IS NULL AND accepted_answers IS NULL) OR (type='true_false' AND correct_boolean IS NOT NULL AND options IS NULL AND correct_index IS NULL AND accepted_answers IS NULL) OR (type='identification' AND accepted_answers IS NOT NULL AND options IS NULL AND correct_index IS NULL AND correct_boolean IS NULL))",
  ];
}

@DataClassName('StudyAttempt')
@TableIndex.sql(
  'CREATE INDEX study_idx_attempts_quiz ON practice_attempts(quiz_id, attempted_at)',
)
class PracticeAttempts extends Table {
  TextColumn get id => text()();
  TextColumn get quizId =>
      text().references(PracticeQuizzes, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get attemptedAt => dateTime()();
  IntColumn get score => integer()();
  IntColumn get total => integer()();
  TextColumn get results => text()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'CHECK (total > 0 AND score >= 0 AND score <= total)',
  ];
}
