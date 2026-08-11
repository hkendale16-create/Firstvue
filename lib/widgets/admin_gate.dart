import 'package:flutter/material.dart';

import '../services/admin_auth_service.dart';

class AdminGate extends StatelessWidget {
  final Widget child;
  final String restrictedMessage;

  const AdminGate({
    super.key,
    required this.child,
    this.restrictedMessage =
        'This area is restricted to FIRSTVUE administrators.',
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AdminAuthService.isAdmin(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!AdminAuthService.isSignedIn || snapshot.data != true) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Colors.white38,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    restrictedMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}
