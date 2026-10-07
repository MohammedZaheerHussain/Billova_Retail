import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// A parsed section of AI insights
class _InsightSection {
  final String title;
  final String emoji;
  final List<_InsightItem> items;
  final Color accentColor;
  final IconData icon;

  _InsightSection({
    required this.title,
    required this.emoji,
    required this.items,
    required this.accentColor,
    required this.icon,
  });
}

class _InsightItem {
  final String headline;
  final String body;

  _InsightItem({required this.headline, required this.body});
}

class AIInsightsViewer extends StatelessWidget {
  final String rawText;
  final VoidCallback? onRefresh;
  final bool isLoading;

  const AIInsightsViewer({
    super.key,
    required this.rawText,
    this.onRefresh,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (rawText.trim().startsWith('⚠️')) {
      return _buildWarningView(context, rawText);
    }

    final sections = _parseSections(rawText);
    if (sections.isEmpty) {
      return _buildFallbackView(context, rawText);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderBar(context),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (!isWide) {
              return Column(
                children: sections.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSectionCard(context, s),
                )).toList(),
              );
            }

            // High-priority action section full width at bottom or top
            final actionSection = sections.where((s) => s.title.toLowerCase().contains('action')).firstOrNull;
            final regularSections = sections.where((s) => !s.title.toLowerCase().contains('action')).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2-Column grid for regular insights
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          for (int i = 0; i < regularSections.length; i += 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildSectionCard(context, regularSections[i]),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        children: [
                          for (int i = 1; i < regularSections.length; i += 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildSectionCard(context, regularSections[i]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (actionSection != null) ...[
                  const SizedBox(height: 4),
                  _buildSectionCard(context, actionSection, isFeatured: true),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeaderBar(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 5),
              Text(
                'Live AI Intelligence Report',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: rawText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Insights report copied to clipboard!'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 14),
          label: const Text('Copy Report', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary(context),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(BuildContext context, _InsightSection section, {bool isFeatured = false}) {
    final cardBg = isFeatured
        ? (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E2235)
            : const Color(0xFFF6F8FF))
        : AppColors.surface(context);

    final borderColor = isFeatured
        ? section.accentColor.withValues(alpha: 0.45)
        : AppColors.cardBorder(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor, width: isFeatured ? 1.5 : 1),
        boxShadow: isFeatured
            ? [
                BoxShadow(
                  color: section.accentColor.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: section.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(section.icon, size: 15, color: section.accentColor),
              ),
              const SizedBox(width: 9),
              Text(
                section.title,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (isFeatured) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: section.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PRIORITY',
                    style: TextStyle(
                      color: section.accentColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Items
          ...section.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5, right: 8),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: section.accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            if (item.headline.isNotEmpty)
                              TextSpan(
                                text: '${item.headline}: ',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textPrimary(context),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            TextSpan(
                              text: item.body,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary(context),
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildWarningView(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary(context),
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackView(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: SelectableText(
        text,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textPrimary(context),
          height: 1.5,
          fontSize: 12.5,
        ),
      ),
    );
  }

  List<_InsightSection> _parseSections(String text) {
    final List<_InsightSection> result = [];
    final lines = text.split('\n');

    String? currentTitle;
    String currentEmoji = '📊';
    List<_InsightItem> currentItems = [];

    void saveSection() {
      final title = currentTitle;
      if (title != null && currentItems.isNotEmpty) {
        final cleanTitle = title
            .replaceAll('#', '')
            .replaceAll('*', '')
            .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
            .trim();

        final style = _styleForSection(cleanTitle);

        result.add(_InsightSection(
          title: cleanTitle.isEmpty ? 'General Insights' : cleanTitle,
          emoji: currentEmoji,
          items: List.from(currentItems),
          accentColor: style.$1,
          icon: style.$2,
        ));
      }
      currentItems = [];
    }

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Section header detection (### Header or **Header**)
      if (line.startsWith('###') || (line.startsWith('**') && line.endsWith('**') && !line.contains(':') && line.length < 50)) {
        saveSection();
        currentTitle = line;
        final emojiMatch = RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true).firstMatch(line);
        if (emojiMatch != null) {
          currentEmoji = emojiMatch.group(0) ?? '📊';
        }
        continue;
      }

      // Check if line is a bullet item
      if (line.startsWith('•') || line.startsWith('-') || line.startsWith('*') || RegExp(r'^\d+\.').hasMatch(line)) {
        var content = line
            .replaceFirst(RegExp(r'^[•\-\*]\s*'), '')
            .replaceFirst(RegExp(r'^\d+\.\s*'), '')
            .trim();

        String headline = '';
        String body = content;

        // Extract **Headline**: or **Headline** -
        final boldMatch = RegExp(r'^\*\*(.*?)\*\*[\s:\-—]*(.*)$').firstMatch(content);
        if (boldMatch != null) {
          headline = boldMatch.group(1)?.trim() ?? '';
          body = boldMatch.group(2)?.trim() ?? '';
        } else if (content.contains(':')) {
          final parts = content.split(':');
          headline = parts[0].replaceAll('*', '').trim();
          body = parts.sublist(1).join(':').replaceAll('*', '').trim();
        } else {
          body = content.replaceAll('*', '').trim();
        }

        if (body.isNotEmpty || headline.isNotEmpty) {
          currentItems.add(_InsightItem(headline: headline, body: body));
        }
      } else if (currentTitle != null && line.length > 5) {
        // Line without bullet under active section
        final clean = line.replaceAll('*', '').trim();
        if (clean.isNotEmpty) {
          currentItems.add(_InsightItem(headline: '', body: clean));
        }
      }
    }

    saveSection();
    return result;
  }

  (Color, IconData) _styleForSection(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('financial') || lower.contains('money') || lower.contains('profit')) {
      return (const Color(0xFF2563EB), Icons.account_balance_wallet_rounded); // Blue
    } else if (lower.contains('inventory') || lower.contains('stock')) {
      return (const Color(0xFFEA580C), Icons.inventory_2_rounded); // Orange
    } else if (lower.contains('product') || lower.contains('revenue') || lower.contains('sales')) {
      return (const Color(0xFF7C3AED), Icons.emoji_events_rounded); // Purple
    } else if (lower.contains('customer') || lower.contains('growth') || lower.contains('crm')) {
      return (const Color(0xFF0D9488), Icons.people_alt_rounded); // Teal
    } else if (lower.contains('action') || lower.contains('today')) {
      return (const Color(0xFFE11D48), Icons.bolt_rounded); // Rose/Primary
    }
    return (const Color(0xFF4F46E5), Icons.lightbulb_rounded); // Indigo
  }
}
