/// Centralized Role-Based Access Control (RBAC) helper.
///
/// Usage:
///   final perms = PermissionHelper(authProvider.userType);
///   if (perms.canEditInventory) { ... }
///
/// Designed for scalability — add future roles (manager, cashier, etc.)
/// by extending the [_rolePermissions] map.
class PermissionHelper {
  final String role;

  const PermissionHelper(this.role);

  // ─── Role Checks ───
  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff';

  // ─── Inventory Permissions ───
  bool get canAddInventory => _check('inventory.add');
  bool get canEditInventory => _check('inventory.edit');
  bool get canDeleteInventory => _check('inventory.delete');
  bool get canViewInventory => _check('inventory.view');

  // ─── Purchase Permissions ───
  bool get canAddPurchase => _check('purchase.add');
  bool get canEditPurchase => _check('purchase.edit');

  // ─── Settings Permissions ───
  bool get canAccessSettings => _check('settings.access');
  bool get canManageStaff => _check('staff.manage');
  bool get canManageCategories => _check('categories.manage');
  bool get canExportData => _check('data.export');

  // ─── Customer & Vendor Permissions ───
  bool get canManageCustomers => _check('customers.manage');
  bool get canManageVendors => _check('vendors.manage');

  // ─── Sales Permissions ───
  bool get canProcessSales => _check('sales.process');
  bool get canViewReports => _check('reports.view');
  bool get canProcessReturns => _check('returns.process');

  // ─── Clearance Stock ───
  bool get canManageClearance => _check('clearance.manage');

  // ─── Internal Permission Lookup ───
  bool _check(String permission) {
    final rolePerms = _rolePermissions[role];
    if (rolePerms == null) return false;
    return rolePerms.contains(permission) || rolePerms.contains('*');
  }

  /// Permission matrix — single source of truth.
  /// '*' = all permissions (superadmin).
  /// Add new roles here as the system scales.
  static const Map<String, Set<String>> _rolePermissions = {
    'admin': {'*'}, // Full access
    'staff': {
      // View-only inventory
      'inventory.view',
      // Sales & POS
      'sales.process',
      'returns.process',
      // Read-only reports
      'reports.view',
    },
    // ─── Future roles (uncomment when needed) ───
    // 'manager': {
    //   'inventory.view', 'inventory.edit',
    //   'purchase.add', 'purchase.edit',
    //   'sales.process', 'returns.process',
    //   'reports.view',
    //   'customers.manage',
    //   'staff.manage',
    // },
    // 'cashier': {
    //   'sales.process',
    //   'inventory.view',
    //   'returns.process',
    // },
    // 'warehouse': {
    //   'inventory.view', 'inventory.edit',
    //   'purchase.add',
    // },
  };

  /// Human-readable denial message
  String get deniedMessage => 'Access denied. Admin permission required.';
}
