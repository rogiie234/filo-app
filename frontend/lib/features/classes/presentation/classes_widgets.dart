import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_icon.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/supabase/session_gate.dart';
import '../domain/prototype_models.dart';

// Private Storage URLs are scoped to the current account and renewed on reconnect.
final classImageProvider = FutureProvider.autoDispose
    .family<String?, (String, String)>((ref, key) async {
      if (ref.watch(connectivityProvider).asData?.value != true) {
        return null;
      }
      final client = ref.watch(supabaseClientProvider);
      final userId = await ref.watch(verifiedUserIdProvider.future);
      if (userId == null || !ref.mounted) {
        return null;
      }
      final renewal = Timer(const Duration(minutes: 50), ref.invalidateSelf);
      ref.onDispose(renewal.cancel);
      return await client.storage.from(key.$1).createSignedUrl(key.$2, 3600);
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
    if (resolved == null || resolved.isEmpty) {
      return fallback;
    }
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: FiloColors.warning,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        ExcludeSemantics(
          child: FiloIcon(
            FiloIcons.pending,
            size: 18,
            color: FiloColors.warningInk,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Waiting for approval',
            style: TextStyle(
              color: FiloColors.warningInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
        FiloIcon(FiloIcons.offline, color: FiloColors.ink),
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
            Container(height: 148, color: FiloColors.mint),
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
  Widget build(BuildContext context) {
    final enabled = !room.pending && onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1014423A),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: room.pending ? FiloColors.tint : FiloColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: FiloColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: Color(room.color),
                        child: ClassImage(
                          path: room.bannerPath,
                          bucket: 'banners',
                          fallback: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    // Keep text readable on custom colors and bright photos.
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  room.section,
                                  style: const TextStyle(
                                    color: FiloColors.onBanner,
                                    fontSize: 26,
                                    height: 1.25,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ExcludeSemantics(
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0x1FFFFFFF),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: const Color(0x33FFFFFF),
                                    ),
                                  ),
                                  child: const FiloIcon(
                                    FiloIcons.book,
                                    size: 25,
                                    color: FiloColors.onBanner,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0x66FFFFFF),
                                  shape: BoxShape.circle,
                                ),
                                child: FiloAvatar(
                                  name: room.instructor,
                                  url: room.instructorPhotoUrl,
                                  path: room.instructorAvatarPath,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  room.instructor,
                                  style: const TextStyle(
                                    color: FiloColors.onBanner,
                                    fontSize: 14,
                                    height: 1.4,
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
                      ExcludeSemantics(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: FiloColors.tint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const FiloIcon(
                            FiloIcons.book,
                            size: 22,
                            color: FiloColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          room.course,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                            color: FiloColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Semantics(
                        label: pendingRequests > 0
                            ? 'Pending join requests'
                            : null,
                        child: RedDotBadge(
                          visible: pendingRequests > 0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: FiloColors.selected,
                              shape: BoxShape.circle,
                            ),
                            child: FiloIcon(
                              room.pending ? FiloIcons.lock : FiloIcons.forward,
                              size: 20,
                              color: FiloColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (room.pending)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: ApprovalChip(),
                  ),
                if (room.archived)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: FiloColors.tint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          ExcludeSemantics(
                            child: FiloIcon(
                              FiloIcons.archive,
                              size: 18,
                              color: FiloColors.secondary,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Archived \u00b7 Read only',
                              style: TextStyle(
                                color: FiloColors.secondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
