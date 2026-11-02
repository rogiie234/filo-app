import 'package:flutter/material.dart';

/// Use viewport width rather than the space left by each page's footer.
/// Navigation never changes the artwork scale; idle motion is an opt-in wrapper.
double entryMascotSize(BuildContext context) =>
    (MediaQuery.sizeOf(context).width - 48).clamp(200.0, 240.0).toDouble();
