const classBannerColors = <String, int>{
  'forest': 0xFF236B57,
  'teal': 0xFF386D7A,
  'sage': 0xFFD4DACE,
  'pine': 0xFF245B4A,
  'ocean': 0xFF345E78,
  'slate': 0xFF536B78,
  'olive': 0xFFD5D8C9,
  'plum': 0xFF70576E,
};

int classBannerColor(String? key) => classBannerColors[key] ?? 0xFF236B57;
