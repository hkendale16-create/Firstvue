import 'package:flutter/material.dart';

class FacebookStyleProfileHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? statusLabel;
  final Color statusColor;
  final IconData avatarIcon;
  final String? coverImageUrl;
  final List<Color> coverGradient;
  final List<Widget>? actionButtons;

  const FacebookStyleProfileHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.statusLabel,
    this.statusColor = const Color(0xFFE5C16F),
    this.avatarIcon = Icons.person_outline,
    this.coverImageUrl,
    this.coverGradient = const [
      Color(0xFF1A2530),
      Color(0xFF243540),
      Color(0xFF78B9BE),
    ],
    this.actionButtons,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: 160,
              width: double.infinity,
              child: coverImageUrl != null && coverImageUrl!.isNotEmpty
                  ? Image.network(
                      coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _coverGradient(),
                    )
                  : _coverGradient(),
            ),
            Positioned(
              left: 20,
              bottom: -40,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF080B0F),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: const Color(0xFF10151B),
                  backgroundImage: coverImageUrl != null && coverImageUrl!.isNotEmpty
                      ? NetworkImage(coverImageUrl!)
                      : null,
                  child: coverImageUrl == null || coverImageUrl!.isEmpty
                      ? Icon(avatarIcon, color: const Color(0xFFD8B56A), size: 42)
                      : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 52),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(color: Colors.white54)),
              ],
              if (statusLabel != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: .5)),
                  ),
                  child: Text(
                    statusLabel!,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: .8,
                    ),
                  ),
                ),
              ],
              if (actionButtons != null && actionButtons!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, children: actionButtons!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverGradient() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: coverGradient,
        ),
      ),
    );
  }
}

class ProfileViewSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const ProfileViewSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF10151B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: .07)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      color: Colors.white.withValues(alpha: .08),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileViewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const ProfileViewRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFD8B56A), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
