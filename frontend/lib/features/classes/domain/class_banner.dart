import '../../../core/theme/filo_banner_palette.dart';

const classBannerColors = filoBannerPalette;

int classBannerColor(String? key) =>
    classBannerColors[key] ?? filoDefaultBanner;
