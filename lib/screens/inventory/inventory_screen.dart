import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/inventory_provider.dart';
import '../../data/models/item_model.dart';
import 'item_form_screen.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header ───
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Inventory',
                        style: AppTypography.h1.copyWith(color: AppColors.textPrimaryDark),
                      ),
                    ),
                    // Stats
                    _statChip('${provider.totalItems}', 'Items', AppColors.primary),
                    const SizedBox(width: 8),
                    if (provider.lowStockCount > 0)
                      _statChip('${provider.lowStockCount}', 'Low', AppColors.warning),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showItemForm(context),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Add Item'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ─── Search ───
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorderDark),
                  ),
                  child: TextField(
                    onChanged: provider.search,
                    style: const TextStyle(color: AppColors.textPrimaryDark),
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      hintStyle: const TextStyle(color: AppColors.textTertiaryDark),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiaryDark),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Error ───
                if (provider.error.isNotEmpty)
                  _errorBanner(context, provider),

                // ─── Items List ───
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : provider.items.isEmpty
                          ? _emptyState()
                          : ListView.builder(
                              itemCount: provider.items.length,
                              itemBuilder: (context, index) {
                                return _itemCard(context, provider.items[index], provider);
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppTypography.mono.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.labelSmall.copyWith(color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _errorBanner(BuildContext context, InventoryProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(provider.error, style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppColors.error),
            onPressed: provider.clearError,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textTertiaryDark.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No items yet', style: AppTypography.h3.copyWith(color: AppColors.textSecondaryDark)),
          const SizedBox(height: 8),
          Text('Add your first product to get started', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiaryDark)),
        ],
      ),
    );
  }

  Widget _itemCard(BuildContext context, ItemModel item, InventoryProvider provider) {
    Color stockColor = AppColors.success;
    String stockLabel = '${item.quantity} in stock';
    if (item.isOutOfStock) {
      stockColor = AppColors.error;
      stockLabel = 'Out of stock';
    } else if (item.isLowStock) {
      stockColor = AppColors.warning;
      stockLabel = '${item.quantity} left (low)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorderDark),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
              style: AppTypography.h3.copyWith(color: AppColors.accent),
            ),
          ),
        ),
        title: Text(
          item.name,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.vendor.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  item.vendor,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiaryDark,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            Row(
              children: [
                Text(
                  Formatters.currency(item.price),
                  style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    stockLabel,
                    style: AppTypography.labelSmall.copyWith(color: stockColor),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondaryDark),
          color: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (_) => [
            PopupMenuItem(
              onTap: () => Future.microtask(() => _showItemForm(context, item: item)),
              child: const Row(
                children: [
                  Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondaryDark),
                  SizedBox(width: 8),
                  Text('Edit', style: TextStyle(color: AppColors.textPrimaryDark)),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: () => _confirmDelete(context, provider, item),
              child: const Row(
                children: [
                  Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemForm(BuildContext context, {ItemModel? item}) {
    showDialog(
      context: context,
      builder: (ctx) => ItemFormDialog(item: item),
    );
  }

  void _confirmDelete(BuildContext context, InventoryProvider provider, ItemModel item) {
    Future.microtask(() {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Delete Item', style: AppTypography.h3.copyWith(color: AppColors.textPrimaryDark)),
          content: Text(
            'Are you sure you want to delete "${item.name}"?',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                provider.deleteItem(item.id);
                Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item.name} deleted'),
                      backgroundColor: AppColors.cardDark,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    });
  }
}
