import '../../../core/widgets/filo_motion_widgets.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_icon.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/supabase/session_gate.dart';
import '../domain/prototype_models.dart';
import '../domain/class_banner.dart';
import 'class_banner.dart';
import '../../settings/application/profile_settings.dart';

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
      final url = await client.storage
          .from(key.$1)
          .createSignedUrl(key.$2, 3600);
      if (!ref.mounted) {
        await NetworkImage(url).evict();
        return null;
      }
      ref.onDispose(() => unawaited(NetworkImage(url).evict()));
      return url;
    });

final _avatarUrlCache = Provider.autoDispose.family<void, String>((ref, url) {
  ref.onDispose(() => unawaited(NetworkImage(url).evict()));
});
final _avatarMemoryCache = Provider.autoDispose.family<void, Uint8List>((
  ref,
  bytes,
) {
  ref.onDispose(() => unawaited(MemoryImage(bytes).evict()));
});

class ClassImage extends ConsumerWidget {
  const ClassImage({
    super.key,
    this.url,
    this.path,
    required this.bucket,
    this.evictOnDispose = false,
    required this.fallback,
  });
  final String? url, path;
  final String bucket;
  final bool evictOnDispose;
  final Widget fallback;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = path != null && path!.isNotEmpty
        ? ref.watch(classImageProvider((bucket, path!))).asData?.value ?? url
        : url;
    if (resolved == null || resolved.isEmpty) {
      return fallback;
    }
    if (evictOnDispose) ref.watch(_avatarUrlCache(resolved));
    return Image.network(
      resolved,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, error, stack) => fallback,
    );
  }
}

class FiloAvatar extends ConsumerWidget {
  const FiloAvatar({
    super.key,
    required this.name,
    this.url,
    this.path,
    this.size = 40,
    this.userId,
  });
  final String name;
  final String? url, path;
  final double size;
  final String? userId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = userId == null ? null : ref.watch(confirmedProfileProvider);
    final photo =
        saved?.profile.id == userId && saved?.profile.avatarPath == path
        ? saved?.photo
        : null;
    if (photo != null) ref.watch(_avatarMemoryCache(photo.bytes));
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: photo != null
              ? Image.memory(
                  photo.bytes,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                )
              : ClassImage(
                  url: url,
                  path: path,
                  bucket: 'avatars',
                  evictOnDispose: true,
                  fallback: ColoredBox(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.primaryContainer
                        : FiloThemeTokens.of(context).mint,
                    child: Center(
                      child: Text(
                        name.trim().isEmpty
                            ? '?'
                            : name.trim().characters.first.toUpperCase(),
                        style: FiloTypography.strongLabel(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class RedDotBadge extends StatelessWidget {
  const RedDotBadge({super.key, required this.visible, required this.child});
  final bool visible;
  final Widget child;
  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: visible,
    backgroundColor: Theme.of(context).colorScheme.error,
    child: child,
  );
}

class ApprovalChip extends StatelessWidget {
  const ApprovalChip({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: FiloSpacing.s12,
      vertical: FiloSpacing.s12,
    ),
    decoration: BoxDecoration(
      color: FiloThemeTokens.of(context).warningTint,
      borderRadius: BorderRadius.circular(FiloRadii.small),
    ),
    child: Row(
      children: [
        ExcludeSemantics(
          child: FiloIcon(
            FiloIcons.pending,
            size: 18,
            color: FiloThemeTokens.of(context).warning,
          ),
        ),
        SizedBox(width: FiloSpacing.s8),
        Expanded(
          child: Text(
            'Waiting for approval',
            style: Theme.of(context).textTheme.labelMedium!
                .copyWith(color: FiloThemeTokens.of(context).warning),
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
    margin: const EdgeInsets.only(bottom: FiloSpacing.s16),
    padding: const EdgeInsets.all(FiloSpacing.s16),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(FiloRadii.medium),
    ),
    child: Row(
      children: [
        FiloIcon(
          FiloIcons.offline,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        SizedBox(width: FiloSpacing.s12),
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
        margin: const EdgeInsets.only(bottom: FiloSpacing.s16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(FiloRadii.large),
        ),
        child: Column(
          children: [
            Container(height: 148, color: FiloThemeTokens.of(context).mint),
            Padding(
              padding: const EdgeInsets.all(FiloSpacing.s20),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainer,
                  ),
                  const SizedBox(width: FiloSpacing.s16),
                  Expanded(
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(FiloRadii.small),
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

class ClassCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final path = room.bannerPath;
    final hasImage = path != null && path.isNotEmpty;
    final url = hasImage
        ? ref.watch(classImageProvider(('banners', path))).asData?.value
        : null;
    final enabled = !room.pending && onTap != null;
    return FiloCardTap(
      enabled: enabled,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FiloRadii.large),
            boxShadow: const [
              BoxShadow(
                color: FiloPaint.cardShadow,
                blurRadius: FiloPaint.cardShadowBlur,
                offset: FiloPaint.cardShadowOffset,
              ),
            ],
          ),
          child: Material(
            color: room.pending
                ? Theme.of(context).colorScheme.surfaceContainer
                : Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FiloRadii.large),
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClassBanner(
                    section: room.section,
                    instructor: room.instructor,
                    color: hasImage ? classBannerColor(null) : room.color,
                    image: url == null ? null : NetworkImage(url),
                    avatar: FiloAvatar(
                      name: room.instructor,
                      url: room.instructorPhotoUrl,
                      path: room.instructorAvatarPath,
                      size: 32,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(FiloSpacing.s20),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainer,
                              borderRadius: BorderRadius.circular(
                                FiloRadii.small,
                              ),
                            ),
                            child: FiloIcon(
                              FiloIcons.book,
                              size: 22,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: FiloSpacing.s12),
                        Expanded(
                          child: Text(
                            room.course,
                            style: Theme.of(context).textTheme.titleMedium!
                                .copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                          ),
                        ),
                        const SizedBox(width: FiloSpacing.s12),
                        Semantics(
                          label: pendingRequests > 0
                              ? 'Pending join requests'
                              : null,
                          child: RedDotBadge(
                            visible: pendingRequests > 0,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: FiloIcon(
                                room.pending
                                    ? FiloIcons.lock
                                    : FiloIcons.forward,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (room.pending)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                        FiloSpacing.s20,
                        0,
                        FiloSpacing.s20,
                        FiloSpacing.s20,
                      ),
                      child: ApprovalChip(),
                    ),
                  if (room.archived)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        FiloSpacing.s20,
                        0,
                        FiloSpacing.s20,
                        FiloSpacing.s20,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FiloSpacing.s12,
                          vertical: FiloSpacing.s12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(FiloRadii.small),
                        ),
                        child: Row(
                          children: [
                            ExcludeSemantics(
                              child: FiloIcon(
                                FiloIcons.archive,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            SizedBox(width: FiloSpacing.s8),
                            Expanded(
                              child: Text(
                                'Archived \u00b7 Read only',
                                style: Theme.of(context).textTheme.bodySmall!
                                    .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
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
      ),
    );
  }
}
