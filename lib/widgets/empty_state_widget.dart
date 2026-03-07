import 'package:flutter/material.dart';
import 'package:flutter_inventory/theme/app_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: AppTheme.primaryColor.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
