import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../core/widgets/entry_background.dart';

/// Presentation only; AccountSetupScreen retains validation and persistence.
class AccountDetailsView extends StatelessWidget {
  const AccountDetailsView({
    super.key,
    required this.name,
    required this.school,
    required this.email,
    required this.role,
    required this.photoUrl,
    required this.consent,
    required this.valid,
    required this.busy,
    required this.error,
    required this.onEdited,
    required this.onConsentChanged,
    required this.onPrivacy,
    required this.onSave,
    this.photoBytes,
    this.photoBusy = false,
    this.photoError,
    this.onChangePhoto,
    this.onResetPhoto,
  });

  final TextEditingController name;
  final TextEditingController school;
  final String email;
  final String role;
  final String? photoUrl;
  final Uint8List? photoBytes;
  final bool photoBusy;
  final String? photoError;
  final VoidCallback? onChangePhoto;
  final VoidCallback? onResetPhoto;
  final bool consent;
  final bool valid;
  final bool busy;
  final String? error;
  final VoidCallback onEdited;
  final ValueChanged<bool> onConsentChanged;
  final VoidCallback onPrivacy;
  final VoidCallback onSave;

  Widget _photoPicker(BuildContext context) {
    final fallback = FiloIcon(
      FiloIcons.person,
      size: 32,
      color: Theme.of(context).colorScheme.primary,
    );
    final Widget image = photoBytes != null
        ? Image.memory(
            photoBytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, error, stack) => fallback,
          )
        : photoUrl != null
        ? Image.network(
            photoUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : fallback,
            errorBuilder: (_, error, stack) => fallback,
          )
        : fallback;
    return Semantics(
      label: 'Change profile photo',
      button: true,
      enabled: !busy && !photoBusy && onChangePhoto != null,
      child: Tooltip(
        message: 'Change profile photo',
        child: Material(
          color: FiloPaint.transparent,
          borderRadius: BorderRadius.circular(FiloRadii.pill),
          // Clip only the photo below; the edit badge must keep its full circle.
          clipBehavior: Clip.none,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: busy || photoBusy ? null : onChangePhoto,
            child: SizedBox.square(
              dimension: 80,
              child: ExcludeSemantics(
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 8,
                      bottom: 8,
                      child: ClipOval(
                        child: ColoredBox(
                          color: FiloThemeTokens.of(context).mint,
                          child: image,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 3,
                          ),
                        ),
                        child:
                            photoBusy &&
                                !MediaQuery.disableAnimationsOf(context)
                            ? Padding(
                                padding: EdgeInsets.all(FiloSpacing.s8),
                                child: FiloCircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary,
                                ),
                              )
                            : FiloIcon(
                                FiloIcons.camera,
                                size: 16,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _readOnlyValue(BuildContext context, String label, String value) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ExcludeSemantics(
                child: FiloIcon(
                  FiloIcons.lock,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: FiloSpacing.s8),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge!
                .copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Keep decoration anchored while Scaffold resizes the form for typing.
            bottom: -MediaQuery.viewInsetsOf(context).bottom,
            child: const EntryBackground(verification: true),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      FiloSpacing.screen,
                      FiloSpacing.s16,
                      FiloSpacing.screen,
                      FiloSpacing.screen,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Brand(),
                            ),
                            const SizedBox(height: FiloSpacing.screen),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Semantics(
                                        header: true,
                                        child: Text(
                                          'Your details',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium,
                                        ),
                                      ),
                                      const SizedBox(height: FiloSpacing.s8),
                                      Text(
                                        'Tell us a little about yourself.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: FiloSpacing.s16),
                                _photoPicker(context),
                              ],
                            ),
                            if (photoBytes != null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: busy || photoBusy
                                      ? null
                                      : onResetPhoto,
                                  child: const Text('Use Google photo'),
                                ),
                              ),
                            if (photoError != null) ...[
                              const SizedBox(height: FiloSpacing.s8),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  photoError!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: FiloSpacing.s32),
                            TextField(
                              controller: name,
                              enabled: !busy,
                              maxLength: 80,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                              ),
                              onChanged: (_) => onEdited(),
                            ),
                            const SizedBox(height: FiloSpacing.s12),
                            TextField(
                              controller: school,
                              enabled: !busy,
                              maxLength: 120,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                              decoration: const InputDecoration(
                                labelText: 'School (optional)',
                              ),
                              onChanged: (_) => onEdited(),
                            ),
                            const SizedBox(height: FiloSpacing.s16),
                            FiloPanel(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainer,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _readOnlyValue(context, 'Email', email),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: FiloSpacing.s16,
                                    ),
                                    child: Divider(
                                      height: 1,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline,
                                    ),
                                  ),
                                  _readOnlyValue(context, 'Role', role),
                                ],
                              ),
                            ),
                            const SizedBox(height: FiloSpacing.s20),
                            FiloPanel(
                              padding: const EdgeInsets.fromLTRB(
                                FiloSpacing.s12,
                                FiloSpacing.s8,
                                FiloSpacing.s16,
                                FiloSpacing.s16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Material(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainer,
                                    borderRadius: BorderRadius.circular(
                                      FiloRadii.medium,
                                    ),
                                    child: InkWell(
                                      onTap: onPrivacy,
                                      borderRadius: BorderRadius.circular(
                                        FiloRadii.medium,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(
                                          FiloSpacing.s12,
                                        ),
                                        child: Row(
                                          children: [
                                            ExcludeSemantics(
                                              child: FiloIcon(
                                                FiloIcons.document,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: FiloSpacing.s12,
                                            ),
                                            Expanded(
                                              child: Semantics(
                                                hint:
                                                    'Opens the Privacy Notice',
                                                child: Text(
                                                  'Read Privacy Notice',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge!
                                                      .copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: FiloSpacing.s8,
                                            ),
                                            ExcludeSemantics(
                                              child: FiloIcon(
                                                FiloIcons.chevronRight,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: FiloSpacing.s8),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    value: consent,
                                    onChanged: busy
                                        ? null
                                        : (value) =>
                                              onConsentChanged(value ?? false),
                                    title: Text(
                                      'I have read and agree to the Privacy Notice. I understand that using AI features sends my requests and relevant text to Google for processing.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: FiloSpacing.s16),
                              Semantics(
                                liveRegion: true,
                                child: FiloPanel(
                                  color: FiloThemeTokens.of(context)
                                      .warningTint,
                                  padding: const EdgeInsets.all(
                                    FiloSpacing.s16,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      FiloIcon(
                                        FiloIcons.info,
                                        size: 20,
                                        color: FiloThemeTokens.of(context)
                                            .warning,
                                      ),
                                      const SizedBox(width: FiloSpacing.s12),
                                      Expanded(
                                        child: Text(
                                          error!,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    12,
                    24,
                    MediaQuery.viewInsetsOf(context).bottom > 0 ? 16 : 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: FiloButton(
                        label: busy
                            ? 'Creating account\u2026'
                            : error != null
                            ? 'Retry'
                            : 'Create account',
                        busy: busy,
                        minHeight: 64,
                        icon: busy ? null : FiloIcons.forward,
                        animateArrow: true,
                        labelVariants: const [
                          'Create account',
                          'Creating account\u2026',
                          'Retry',
                        ],
                        onPressed: valid && !busy
                            ? () {
                                FocusScope.of(context).unfocus();
                                onSave();
                              }
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
