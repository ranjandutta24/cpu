import 'dart:ui';

import 'package:cpu/init.dart';
import 'package:cpu/screens/dashboard.dart';
import 'package:cpu/screens/info.dart';
import 'package:cpu/screens/live.dart';
import 'package:cpu/theme/app_theme.dart';
import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  final String username;
  final String role;
  final String email;

  const CustomDrawer({
    super.key,
    required this.username,
    required this.role,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Drawer(
      backgroundColor: bg,
      child: Column(
        children: [
          // ── Header ────────────────────────────────
          _DrawerHeader(username: username, role: role, email: email),

          // ── Divider ───────────────────────────────
          Divider(height: 1, thickness: 1, color: border),

          const SizedBox(height: 8),

          // ── Nav items ─────────────────────────────
          _DrawerItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            isDark: isDark,
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SystemStatsRow()),
            ),
          ),
          _DrawerItem(
            icon: Icons.info_outline_rounded,
            label: 'System Info',
            isDark: isDark,
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const InfoScreen()),
            ),
          ),
          _DrawerItem(
            icon: Icons.list_alt_rounded,
            label: 'Live Processes',
            isDark: isDark,
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LiveProcessScreen()),
            ),
          ),

          const Spacer(),

          Divider(height: 1, thickness: 1, color: border),

          // ── Logout at bottom ──────────────────────
          _DrawerItem(
            icon: Icons.logout_rounded,
            label: 'Disconnect',
            isDark: isDark,
            color: AppColors.error,
            onTap: () => _confirmLogout(context),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: AlertDialog(
          backgroundColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Disconnect',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text('Are you sure you want to Disconnect?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecond
                          : AppColors.lightTextSecond)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.popUntil(context, (r) => r.isFirst);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const InitScreen()),
                );
              },
              child: const Text('Disconnect'),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Drawer header
// ──────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  final String username;
  final String role;
  final String email;

  const _DrawerHeader({
    required this.username,
    required this.role,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.darkBg, AppColors.accentTealDark.withOpacity(0.55)]
              : [AppColors.accentTealDark, AppColors.accentTeal],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 2,
              ),
            ),
            child: const Icon(Icons.person_rounded,
                size: 32, color: Colors.white),
          ),
          const SizedBox(height: 14),

          // Username
          Text(
            username,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),

          // Role pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
          ),

          if (email != 'NA' && email.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              email,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Nav item
// ──────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = color ?? AppColors.accentTeal;
    final textColor = color ??
        (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: accentColor),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        onTap: onTap,
        hoverColor: accentColor.withOpacity(0.08),
        splashColor: accentColor.withOpacity(0.12),
      ),
    );
  }
}
