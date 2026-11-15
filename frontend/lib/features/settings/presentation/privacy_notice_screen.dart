import '../../../core/widgets/entry_background.dart';

import 'package:flutter/material.dart';

import '../../../core/privacy/privacy_notice.dart';
import '../../../core/widgets/filo_widgets.dart';

class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  Widget _section(BuildContext context, String heading, String body) => Padding(
    padding: const EdgeInsets.only(bottom: FiloSpacing.s20),
    child: FiloPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(heading, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: FiloSpacing.s12),
          Text(body),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => EntryBackground(
    verification: true,
    breeze: true,
    variation: 2,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Privacy notice'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FiloSpacing.screen),
          children: [
            _section(context, 'Summary', privacySummary),
            for (final section in privacyNoticeSections)
              _section(context, section.heading, section.body),
          ],
        ),
      ),
    ),
  );
}
