import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';

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
    const fallback = FiloIcon(
      FiloIcons.person,
      size: 32,
      color: FiloColors.primary,
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
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(40),
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
                        child: ColoredBox(color: FiloColors.mint, child: image),
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
                          color: FiloColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: FiloColors.background,
                            width: 3,
                          ),
                        ),
                        child:
                            photoBusy &&
                                !MediaQuery.disableAnimationsOf(context)
                            ? const Padding(
                                padding: EdgeInsets.all(7),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const FiloIcon(
                                FiloIcons.camera,
                                size: 16,
                                color: Colors.white,
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

  Widget _readOnlyValue(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: FiloColors.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const ExcludeSemantics(
            child: FiloIcon(
              FiloIcons.lock,
              size: 16,
              color: FiloColors.secondary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(
          color: FiloColors.ink,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _photoPicker(context),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: const Text(
                                  'Your details',
                                  style: TextStyle(
                                    fontSize: 28,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: FiloColors.ink,
                                  ),
                                ),
                              ),
                            ),
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
                          const SizedBox(height: 8),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              photoError!,
                              style: const TextStyle(
                                color: FiloColors.error,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        TextField(
                          controller: name,
                          enabled: !busy,
                          maxLength: 80,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Name'),
                          onChanged: (_) => onEdited(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: school,
                          enabled: !busy,
                          maxLength: 120,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          decoration: const InputDecoration(
                            labelText: 'School (optional)',
                          ),
                          onChanged: (_) => onEdited(),
                        ),
                        const SizedBox(height: 16),
                        FiloPanel(
                          color: FiloColors.tint,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _readOnlyValue('Email', email),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Divider(
                                  height: 1,
                                  color: FiloColors.border,
                                ),
                              ),
                              _readOnlyValue('Role', role),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        FiloPanel(
                          padding: const EdgeInsets.fromLTRB(12, 8, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Material(
                                color: FiloColors.tint,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  onTap: onPrivacy,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        const ExcludeSemantics(
                                          child: FiloIcon(
                                            FiloIcons.document,
                                            color: FiloColors.primary,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Semantics(
                                            hint: 'Opens the Privacy Notice',
                                            child: const Text(
                                              'Read Privacy Notice',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: FiloColors.primary,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const ExcludeSemantics(
                                          child: FiloIcon(
                                            FiloIcons.chevronRight,
                                            color: FiloColors.primary,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: consent,
                                onChanged: busy
                                    ? null
                                    : (value) =>
                                          onConsentChanged(value ?? false),
                                title: const Text(
                                  'I have read and agree to the Privacy Notice. I understand that using AI features sends my requests and relevant text to Google for processing.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: FiloColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: FiloPanel(
                              color: FiloColors.warning,
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const FiloIcon(
                                    FiloIcons.info,
                                    size: 20,
                                    color: FiloColors.warningInk,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      error!,
                                      style: const TextStyle(
                                        color: FiloColors.ink,
                                        height: 1.4,
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
                MediaQuery.viewInsetsOf(context).bottom > 0 ? 16 : 40,
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
    ),
  );
}
