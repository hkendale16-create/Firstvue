import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_media_service.dart';

/// Clears this account's photos/videos and signs out. Does not delete Auth users.
Future<bool> confirmAndStartOver(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Start over?'),
      content: const Text(
        'This clears the photos and videos on this account, then signs you out. '
        'You can create a new profile. The app itself is not deleted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Start over'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  await ProfileMediaService.clearMyMedia();
  await Supabase.instance.client.auth.signOut();
  return true;
}
