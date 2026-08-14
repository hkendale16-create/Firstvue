import 'package:flutter/material.dart';

import '../messaging/screens/messaging_shell_screen.dart';

/// Legacy inbox route. The unified web messaging shell is the product UI.
class MessagesInboxScreen extends StatelessWidget {
  const MessagesInboxScreen({super.key});

  @override
  Widget build(BuildContext context) => const MessagingShellScreen();
}
