import 'package:flutter/material.dart';

import '../../classes/presentation/classes_screen.dart';
import '../../onboarding/data/profile_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.profile, super.key});
  final AccountProfile profile;

  @override
  Widget build(BuildContext context) =>
      PopScope(canPop: false, child: ClassesScreen(profile: profile));
}
