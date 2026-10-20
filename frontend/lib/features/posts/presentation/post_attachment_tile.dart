import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import '../../files/presentation/download_file_card.dart';

class PostAttachmentTile extends StatelessWidget {
  const PostAttachmentTile({
    super.key,
    required this.classId,
    required this.postId,
    required this.attachment,
    this.onUnavailable,
  });
  final String classId, postId;
  final CachePostAttachment attachment;
  final VoidCallback? onUnavailable;
  @override
  Widget build(BuildContext context) => DownloadFileCard(
    classId: classId,
    postId: postId,
    attachment: attachment,
  );
}
