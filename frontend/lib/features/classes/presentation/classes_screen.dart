import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../application/preview_controller.dart';
import '../domain/prototype_models.dart';

class ClassesScreen extends ConsumerStatefulWidget {
  const ClassesScreen({super.key});
  @override
  ConsumerState<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends ConsumerState<ClassesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(previewProvider);
    final rooms = state.classes
        .where(
          (room) => '${room.section} ${room.course} ${room.instructor}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Brand(),
        toolbarHeight: 76,
        actions: [
          IconButton(
            tooltip: 'Preview information',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showMessage(
              context,
              'Sample classrooms. Changes stay in this preview session.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.filledTonal(
              tooltip: 'Change preview role',
              onPressed: _roleMenu,
              icon: Icon(
                state.role == PreviewRole.student
                    ? Icons.school_rounded
                    : Icons.auto_stories_rounded,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              const Chip(
                label: Text('Preview · sample data'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(
                  state.role == PreviewRole.student ? 'Student' : 'Instructor',
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your classes',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A good place to grow.',
                      style: TextStyle(
                        color: FiloColors.secondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Mascot(size: 92),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Find a class',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 24),
          if (rooms.isEmpty)
            const EmptyState(
              title: 'No classes found.',
              message: 'Try another course, section, or instructor.',
            ),
          for (final room in rooms)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ClassCard(
                room: room,
                onTap: room.pending
                    ? null
                    : () => context.push('/classes/${room.id}'),
              ),
            ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.eco_outlined, size: 18, color: FiloColors.secondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'One class. A world of possibilities.',
                  style: TextStyle(color: FiloColors.secondary),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: state.role == PreviewRole.student
              ? FiloButton(
                  label: 'Join class',
                  icon: Icons.add_rounded,
                  onPressed: _join,
                )
              : FiloButton(
                  label: 'Explore a class',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => context.push('/classes/it119'),
                ),
        ),
      ),
    );
  }

  Future<void> _roleMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Student preview'),
              leading: const Icon(Icons.school_rounded),
              onTap: () {
                ref
                    .read(previewProvider.notifier)
                    .chooseRole(PreviewRole.student);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Instructor preview'),
              leading: const Icon(Icons.auto_stories_rounded),
              onTap: () {
                ref
                    .read(previewProvider.notifier)
                    .chooseRole(PreviewRole.instructor);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Back to welcome'),
              leading: const Icon(Icons.logout_rounded),
              onTap: () {
                Navigator.pop(context);
                this.context.go('/sign-in');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _join() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _JoinSheet(
        submit: (code) => ref.read(previewProvider.notifier).joinClass(code),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.room, required this.onTap});
  final ClassRoom room;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Color(room.color),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.section,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        room.course,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: FiloColors.tint,
                  child: Text(
                    room.instructor.split(' ')[1][0],
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    room.instructor,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  room.pending
                      ? Icons.hourglass_top_rounded
                      : Icons.arrow_forward_rounded,
                  color: FiloColors.primary,
                  size: 20,
                ),
              ],
            ),
          ),
          if (room.pending)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Waiting for approval',
                style: TextStyle(color: Color(0xFF8A5200)),
              ),
            ),
        ],
      ),
    ),
  );
}

class _JoinSheet extends StatefulWidget {
  const _JoinSheet({required this.submit});
  final String Function(String) submit;
  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  final _code = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find your classroom.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the code from your instructor.\nPreview code: FILO26',
            style: TextStyle(color: FiloColors.secondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'Class code',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          FiloButton(
            label: 'Request to join',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {
              final result = widget.submit(_code.text.trim().toUpperCase());
              if (result.startsWith('Class code not found')) {
                setState(() => _error = result);
                return;
              }
              Navigator.pop(context);
              showMessage(context, result);
            },
          ),
        ],
      ),
    ),
  );
}
