import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/filo_motion.dart';
import 'core/widgets/component_gallery.dart';

Future<void> main() async {
  if (!kDebugMode)
    throw UnsupportedError('The component gallery is development only.');
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Nunito',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'Phosphor Icons',
    ], await rootBundle.loadString('assets/fonts/phosphor/LICENSE'));
  });
  runApp(const ComponentGalleryApp());
}

class ComponentGalleryApp extends StatefulWidget {
  const ComponentGalleryApp({super.key});
  @override
  State<ComponentGalleryApp> createState() => _ComponentGalleryAppState();
}

class _ComponentGalleryAppState extends State<ComponentGalleryApp> {
  ThemeMode _mode = ThemeMode.system;
  double? _scale;
  bool _reduced = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: _mode,
    themeAnimationDuration: Duration.zero,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: _reduced || MediaQuery.disableAnimationsOf(context),
        textScaler: _scale == null
            ? MediaQuery.textScalerOf(context)
            : TextScaler.linear(_scale!),
      ),
      child: FiloMotionScope(child: FiloTextScale(child: child!)),
    ),
    home: ComponentGallery(
      mode: _mode,
      scale: _scale,
      onMode: (mode) => setState(() => _mode = mode),
      reduced: _reduced,
      onReduced: (value) => setState(() => _reduced = value),
      onScale: (scale) => setState(() => _scale = scale),
    ),
  );
}
