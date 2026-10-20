import 'package:flutter/material.dart';

/// Use viewport width rather than the space left by each page's footer.
/// The artwork stays static, and navigation never changes its authored scale.
double entryMascotSize(BuildContext context) =>
    (MediaQuery.sizeOf(context).width - 48).clamp(180.0, 290.0).toDouble();
