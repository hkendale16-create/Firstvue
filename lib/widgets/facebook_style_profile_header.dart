import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';
import 'signed_media_viewer.dart';

class ProfileStatItem {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const ProfileStatItem({
    required this.label,
    required this.value,
    this.onTap,
  });
}

class FacebookStyleProfileHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? statusLabel;
  final Color statusColor;
  final IconData avatarIcon;
  final String? coverImageUrl;
  final String? avatarImageUrl;
  final bool coverIsVideo;
  final bool avatarIsVideo;
  final List<Color> coverGradient;
  final List<Widget>? actionButtons;
  final List<ProfileStatItem>? stats;
  final VoidCallback? onCoverTap;
  final VoidCallback? onAvatarTap;
  final bool showImageLoading;

  const FacebookStyleProfileHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.statusLabel,
    this.statusColor = FirstVueColors.gold,
    this.avatarIcon = Icons.person_outline,
    this.coverImageUrl,
    this.avatarImageUrl,
    this.coverIsVideo = false,
    this.avatarIsVideo = false,
    this.coverGradient = const [
      Color(0xFFE5C16F),
      Color(0xFF3DD9C9),
      Color(0xFFF7F5F2),
    ],
    this.actionButtons,
    this.stats,
    this.onCoverTap,
    this.onAvatarTap,
    this.showImageLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasCover = coverImageUrl != null && coverImageUrl!.isNotEmpty;
    final hasAvatar = avatarImageUrl != null && avatarImageUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onCoverTap,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: hasCover
                    ? SignedMediaThumbnail(
                        url: coverImageUrl!,
                        isVideo: coverIsVideo,
                        fit: BoxFit.cover,
                        height: 180,
                      )
                    : _coverGradient(),
              ),
            ),
            if (!hasCover && onCoverTap != null)
              Positioned(
                bottom: 12,
                right: 12,
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: Colors.white.withValues(alpha: .45),
                  size: 22,
                ),
              ),
            if (showImageLoading)
              const Positioned(
                top: 12,
                right: 12,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Positioned(
              left: 20,
              bottom: -44,
              child: GestureDetector(
                onTap: onAvatarTap,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: FirstVueColors.gold,
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: context.fv.elevatedSurface,
                      child: hasAvatar
                          ? ClipOval(
                              child: SignedMediaThumbnail(
                                url: avatarImageUrl!,
                                isVideo: avatarIsVideo,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(avatarIcon, color: FirstVueColors.teal, size: 42),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 56),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.fv.primaryText,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(color: context.fv.secondaryText),
                ),
              ],
              if (statusLabel != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              if (stats != null && stats!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var i = 0; i < stats!.length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 1,
                          height: 28,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: context.fv.divider,
                        ),
                      _StatColumn(stat: stats![i]),
                    ],
                  ],
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

class _StatColumn extends StatelessWidget {
  final ProfileStatItem stat;

  const _StatColumn({required this.stat});

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.value,
          style: TextStyle(
            color: context.fv.primaryText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          stat.label,
          style: TextStyle(
            color: context.fv.tertiaryText,
            fontSize: 12,
          ),
        ),
      ],
    );

    if (stat.onTap == null) return column;

    return InkWell(
      onTap: stat.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: column,
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
              style: TextStyle(
                color: context.fv.secondaryText,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.fv.borderSubtle),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      color: context.fv.divider,
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
          Icon(icon, color: FirstVueColors.gold, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.fv.secondaryText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: context.fv.primaryText,
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
