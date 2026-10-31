import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../application/study_chat_session.dart';
import '../application/study_providers.dart';
import 'study_widgets.dart';

Future<String?> showStudyChatHistory(BuildContext context, String notebookId) =>
    showFiloBottomSheet<String>(
      context: context,
      title: 'History',
      scrollBody: false,
      builder: (_) => _ChatHistory(notebookId: notebookId),
    );

class _ChatHistory extends ConsumerWidget {
  const _ChatHistory({required this.notebookId});
  final String notebookId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .55,
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Chats are kept for 30 days.'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: StudyOfflineBanner(),
        ),
        Expanded(
          child: studyAsync(ref.watch(studyChatsProvider(notebookId)), (chats) {
            final now = DateTime.now().toUtc();
            final active = chats
                .where((chat) => chat.expiresAt.isAfter(now))
                .toList();
            if (active.isEmpty)
              return const Center(child: Text('No chats yet.'));
            return ListView.builder(
              itemCount: active.length,
              itemBuilder: (_, index) {
                final chat = active[index];
                final days = chatDaysLeft(chat.expiresAt, now);
                return ListTile(
                  title: Text(chat.title),
                  subtitle: Text(
                    '${MaterialLocalizations.of(context).formatMediumDate(chat.lastMessageAt.toLocal())} · $days ${days == 1 ? 'day' : 'days'} left',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, chat.id),
                );
              },
            );
          }, retry: () => ref.invalidate(studyChatsProvider(notebookId))),
        ),
      ],
    ),
  );
}
