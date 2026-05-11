import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color? backgroundColor;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor = Colors.white,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox(); // Implemented inline in dashboard for now
  }
}
