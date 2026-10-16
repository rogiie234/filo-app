import 'package:drift/drift.dart';

import '../../../data/local/app_database.dart';
import 'class_repository.dart';

class ClassStudent {
  const ClassStudent({required this.membership, required this.name});
  final CacheClassMember membership;
  final String name;
}

class ClassMemberRepository {
  ClassMemberRepository(this.classes);
  final ClassRepository classes;

  Stream<List<ClassStudent>> watchStudents(String classId) {
    final db = classes.database;
    final members = db.cacheClassMembers;
    final profiles = db.cacheProfiles;
    final query =
        db.select(members).join([
            leftOuterJoin(profiles, profiles.id.equalsExp(members.studentId)),
          ])
          ..where(
            members.classId.equals(classId) &
                members.status.isIn(['pending', 'active']),
          )
          ..orderBy([OrderingTerm.asc(members.requestedAt)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ClassStudent(
              membership: row.readTable(members),
              name: row.readTableOrNull(profiles)?.displayName ?? 'Student',
            ),
          )
          .toList(),
    );
  }

  // Membership rows are RLS-scoped: students see their own; owners see theirs.
  // The classmates roster must use list_classmates, not synthetic memberships.
  Stream<List<CacheClassMember>> watchMembers(String classId) =>
      (classes.database.select(classes.database.cacheClassMembers)
            ..where((m) => m.classId.equals(classId))
            ..orderBy([(m) => OrderingTerm.asc(m.requestedAt)]))
          .watch();

  Future<dynamic> classmates(String classId) =>
      classes.remote.call('list_classmates', {'p_class': classId});
  Future<dynamic> decide(String memberId, bool approve) => classes.mutate(
    'decide_join',
    {'p_member': memberId, 'p_approve': approve},
  );
  Future<dynamic> approveAll(String classId) =>
      classes.mutate('approve_all_pending', {'p_class': classId});
  Future<dynamic> remove(String classId, String studentId) => classes.mutate(
    'remove_member',
    {'p_class': classId, 'p_student': studentId},
  );
}
