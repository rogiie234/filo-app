import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/supabase/session_gate.dart';
import '../domain/prototype_models.dart';

// Private Storage URLs are scoped to the current account and renewed on reconnect.
final classImageProvider = FutureProvider.autoDispose
    .family<String?, (String, String)>((ref, key) async {
      if (ref.watch(connectivityProvider).asData?.value != true) return null;
      final client = ref.watch(supabaseClientProvider);
      final userId = await ref.watch(verifiedUserIdProvider.future);
      if (userId == null || !ref.mounted) return null;
      final renewal = Timer(const Duration(minutes: 50), ref.invalidateSelf);
      ref.onDispose(renewal.cancel);
      return client.storage.from(key.$1).createSignedUrl(key.$2, 3600);
    });

class ClassImage extends ConsumerWidget {
  const ClassImage({
    super.key,
    this.url,
    this.path,
    required this.bucket,
    required this.fallback,
  });
  final String? url, path;
  final String bucket;
  final Widget fallback;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = path != null && path!.isNotEmpty
        ? ref.watch(classImageProvider((bucket, path!))).asData?.value ?? url
        : url;
    if (resolved == null || resolved.isEmpty) return fallback;
    return Image.network(
      resolved,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, error, stack) => fallback,
    );
  }
}

class FiloAvatar extends StatelessWidget {
  const FiloAvatar({
    super.key,
    required this.name,
    this.url,
    this.path,
    this.size = 40,
  });
  final String name;
  final String? url, path;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: ClassImage(
          url: url,
          path: path,
          bucket: 'avatars',
          fallback: ColoredBox(
            color: FiloColors.mint,
            child: Center(
              child: Text(
                name.trim().isEmpty
                    ? '?'
                    : name.trim().characters.first.toUpperCase(),
                style: const TextStyle(
                  color: FiloColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RedDotBadge extends StatelessWidget {
  const RedDotBadge({super.key, required this.visible, required this.child});
  final bool visible;
  final Widget child;
  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: visible,
    backgroundColor: FiloColors.error,
    child: child,
  );
}

class ApprovalChip extends StatelessWidget {
  const ApprovalChip({super.key});
  @override
  Widget build(BuildContext context) => const Chip(
    backgroundColor: FiloColors.warning,
    side: BorderSide.none,
    avatar: Icon(
      Icons.hourglass_top_rounded,
      size: 18,
      color: FiloColors.warningInk,
    ),
    label: Text(
      'Waiting for approval',
      style: TextStyle(color: FiloColors.warningInk),
    ),
  );
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: FiloColors.selected,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      children: [
        Icon(Icons.cloud_off_rounded, color: FiloColors.ink),
        SizedBox(width: 12),
        Expanded(child: Text("You're offline. Showing saved content.")),
      ],
    ),
  );
}

class ClassCardSkeleton extends StatelessWidget {
  const ClassCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading classes',
    child: ExcludeSemantics(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: FiloColors.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Container(height: 140, color: FiloColors.mint),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(backgroundColor: FiloColors.tint),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: FiloColors.tint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.room,
    required this.onTap,
    this.pendingRequests = 0,
  });
  final ClassRoom room;
  final VoidCallback? onTap;
  final int pendingRequests;
  @override
  Widget build(BuildContext context) => Semantics(
    button: !room.pending,
    enabled: !room.pending,
    child: Opacity(
      opacity: room.pending ? .72 : 1,
      child: Material(
        color: FiloColors.surface,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: room.pending ? null : onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: Color(room.color),
                      child: ClassImage(
                        path: room.bannerPath,
                        bucket: 'banners',
                        fallback: const Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Icon(
                              Icons.auto_stories_rounded,
                              color: FiloColors.onBanner,
                              size: 64,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (room.bannerPath != null)
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [FiloColors.bannerOverlay, FiloColors.ink],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.section,
                          style: const TextStyle(
                            color: FiloColors.onBanner,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            FiloAvatar(
                              name: room.instructor,
                              url: room.instructorPhotoUrl,
                              path: room.instructorAvatarPath,
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                room.instructor,
                                style: const TextStyle(
                                  color: FiloColors.onBanner,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      color: FiloColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        room.course,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      label: pendingRequests > 0
                          ? 'Pending join requests'
                          : null,
                      child: RedDotBadge(
                        visible: pendingRequests > 0,
                        child: Icon(
                          room.pending
                              ? Icons.lock_outline_rounded
                              : Icons.arrow_forward_rounded,
                          color: FiloColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (room.pending)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: ApprovalChip(),
                ),
              if (room.archived)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.archive_outlined,
                        size: 18,
                        color: FiloColors.secondary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Archived ? Read only',
                        style: TextStyle(color: FiloColors.secondary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
