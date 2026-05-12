import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/staff_provider.dart';
import '../../data/models/staff_model.dart';
import '../../data/models/attendance_model.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  int _attendanceFilter = 0; // 0=Today, 1=Week, 2=Month

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StaffProvider>();
      provider.loadStaff();
      provider.loadTodayAttendance();
      provider.cleanupOldAttendance();
    });
  }

  void _loadFilteredAttendance(StaffProvider provider) {
    final now = DateTime.now();
    switch (_attendanceFilter) {
      case 0: // Today
        provider.loadTodayAttendance();
        break;
      case 1: // Week
        provider.loadAttendanceHistory(
          from: now.subtract(const Duration(days: 7)),
          to: now,
        );
        break;
      case 2: // Month
        provider.loadAttendanceHistory(
          from: now.subtract(const Duration(days: 30)),
          to: now,
        );
        break;
    }
  }

  void _showStaffDialog({StaffModel? staff}) {
    final nameCtrl = TextEditingController(text: staff?.name ?? '');
    final usernameCtrl = TextEditingController(text: staff?.username ?? '');
    final pinCtrl = TextEditingController(text: staff?.pin ?? '');
    String role = staff?.role ?? 'staff';
    double monthlySaleTarget = staff?.monthlySaleTarget ?? 0;
    final formKey = GlobalKey<FormState>();
    final isEditing = staff != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                                color: Colors.white, size: 20),
                          ),
                          SizedBox(width: 12),
                          Text(isEditing ? 'Edit Staff' : 'Add Staff',
                              style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
                          Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _field('Full Name', nameCtrl, 'e.g. John Doe',
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                      const SizedBox(height: 12),
                      _field('Username', usernameCtrl, 'e.g. john',
                          enabled: !isEditing,
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                      const SizedBox(height: 12),
                      _field('PIN (4-6 digits)', pinCtrl, '••••',
                          obscure: true,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (v.length < 4 || v.length > 6) return '4-6 digits';
                            return null;
                          }),
                      SizedBox(height: 12),
                      // Role selector
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                          filled: true,
                          fillColor: AppColors.surface(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                        ),
                        dropdownColor: AppColors.surface(context),
                        style: TextStyle(color: AppColors.textPrimary(context)),
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'staff', child: Text('Staff')),
                        ],
                        onChanged: (v) => setDialogState(() => role = v ?? 'staff'),
                      ),

                      // ─── Monthly Sale Target (only for staff role) ───
                      if (role == 'staff') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.flag_rounded, size: 16, color: AppColors.accent),
                                  const SizedBox(width: 6),
                                  Text('Monthly Sale Target',
                                      style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.textSecondary(context), fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      monthlySaleTarget > 0
                                          ? '₹${Formatters.currency(monthlySaleTarget).replaceAll('₹', '')}'
                                          : 'No Target',
                                      style: AppTypography.mono.copyWith(
                                          color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: AppColors.accent,
                                  inactiveTrackColor: AppColors.cardBorder(context),
                                  thumbColor: AppColors.accent,
                                  overlayColor: AppColors.accent.withValues(alpha: 0.1),
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                ),
                                child: Slider(
                                  value: monthlySaleTarget,
                                  min: 0,
                                  max: 500000,
                                  divisions: 100,
                                  onChanged: (v) => setDialogState(() => monthlySaleTarget = v),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('₹0', style: TextStyle(color: AppColors.textTertiary(context), fontSize: 10)),
                                  Text('₹5,00,000', style: TextStyle(color: AppColors.textTertiary(context), fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final provider = context.read<StaffProvider>();
                            bool success;
                            if (isEditing) {
                              success = await provider.updateStaff(staff!.copyWith(
                                name: nameCtrl.text.trim(),
                                pin: pinCtrl.text.trim(),
                                role: role,
                                monthlySaleTarget: role == 'staff' ? monthlySaleTarget : 0,
                              ));
                            } else {
                              success = await provider.addStaff(
                                name: nameCtrl.text.trim(),
                                username: usernameCtrl.text.trim(),
                                pin: pinCtrl.text.trim(),
                                role: role,
                                monthlySaleTarget: role == 'staff' ? monthlySaleTarget : 0,
                              );
                            }
                            if (success && ctx.mounted) {
                              Navigator.pop(ctx);
                            } else if (!success && ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Username already exists'),
                                backgroundColor: AppColors.error,
                              ));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(isEditing ? 'Update Staff' : 'Add Staff',
                              style: AppTypography.button.copyWith(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, String hint, {
    bool obscure = false,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(
        color: enabled ? AppColors.textPrimary(context) : AppColors.textTertiary(context),
        letterSpacing: obscure ? 6 : 0,
      ),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
        hintStyle: TextStyle(color: AppColors.textTertiary(context)),
        filled: true,
        fillColor: enabled ? AppColors.surface(context) : AppColors.card(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StaffProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Staff & Attendance',
                        style: AppTypography.h1.copyWith(color: AppColors.textPrimary(context))),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showStaffDialog(),
                      icon: Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Left: Staff Directory ───
                      Expanded(
                        flex: 3,
                        child: _buildStaffDirectory(provider),
                      ),
                      const SizedBox(width: 20),
                      // ─── Right: Today's Attendance ───
                      Expanded(
                        flex: 2,
                        child: _buildAttendanceLog(provider),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaffDirectory(StaffProvider provider) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Staff Directory', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
          SizedBox(height: 16),
          // Header row
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('NAME', style: _headerStyle)),
                Expanded(flex: 2, child: Text('USERNAME', style: _headerStyle)),
                Expanded(flex: 1, child: Text('ROLE', style: _headerStyle)),
                Expanded(flex: 1, child: Text('TARGET', style: _headerStyle)),
                Expanded(flex: 1, child: Text('STATUS', style: _headerStyle)),
                SizedBox(width: 48, child: Text('', style: TextStyle())),
              ],
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: provider.staff.isEmpty
                ? Center(child: Text('No staff members yet',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))))
                : ListView.separated(
                    itemCount: provider.staff.length,
                    separatorBuilder: (_, __) => Divider(color: AppColors.cardBorder(context), height: 1),
                    itemBuilder: (_, i) => _staffRow(provider.staff[i], provider),
                  ),
          ),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => AppTypography.labelSmall.copyWith(
      color: AppColors.textTertiary(context), fontWeight: FontWeight.w600, letterSpacing: 0.5);

  Widget _staffRow(StaffModel staff, StaffProvider provider) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(staff.name,
                style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 2,
            child: Text(staff.username,
                style: AppTypography.mono.copyWith(color: AppColors.textSecondary(context), fontSize: 13)),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: staff.isAdmin
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                staff.role.toUpperCase(),
                style: AppTypography.labelSmall.copyWith(
                  color: staff.isAdmin ? AppColors.accent : AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              staff.monthlySaleTarget > 0
                  ? Formatters.currency(staff.monthlySaleTarget)
                  : '—',
              style: AppTypography.mono.copyWith(
                color: staff.monthlySaleTarget > 0 ? AppColors.accent : AppColors.textTertiary(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              staff.isActive ? 'Active' : 'Inactive',
              style: AppTypography.labelSmall.copyWith(
                color: staff.isActive ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: PopupMenuButton(
              icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary(context), size: 20),
              color: AppColors.surface(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () => Future.microtask(() => _showStaffDialog(staff: staff)),
                  child: const Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Edit')]),
                ),
                PopupMenuItem(
                  onTap: () async {
                    await provider.updateStaff(staff.copyWith(isActive: !staff.isActive));
                  },
                  child: Row(children: [
                    Icon(staff.isActive ? Icons.block_rounded : Icons.check_circle_rounded, size: 16),
                    const SizedBox(width: 8),
                    Text(staff.isActive ? 'Disable' : 'Enable'),
                  ]),
                ),
                PopupMenuItem(
                  onTap: () async => await provider.deleteStaff(staff.id),
                  child: Row(children: [
                    Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppColors.error)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceLog(StaffProvider provider) {
    // Get the right list based on filter
    final records = _attendanceFilter == 0
        ? provider.todayAttendance
        : provider.attendanceHistory;

    // Group by date
    final Map<String, List<AttendanceModel>> grouped = {};
    for (final r in records) {
      final dateKey = r.date;
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(r);
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Attendance Log',
                  style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
              Spacer(),
              IconButton(
                onPressed: () => _loadFilteredAttendance(provider),
                icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary(context), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ─── Filter Tabs ───
          Container(
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _filterTab(0, 'Today', provider),
                _filterTab(1, 'Week', provider),
                _filterTab(2, 'Month', provider),
              ],
            ),
          ),
          SizedBox(height: 12),

          // ─── Records ───
          Expanded(
            child: records.isEmpty
                ? Center(child: Text(
                    _attendanceFilter == 0 ? 'No attendance records today' : 'No records found',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))))
                : ListView.builder(
                    itemCount: grouped.keys.length,
                    itemBuilder: (_, i) {
                      final date = grouped.keys.elementAt(i);
                      final dayRecords = grouped[date]!;
                      return _dateGroup(date, dayRecords);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterTab(int index, String label, StaffProvider provider) {
    final isActive = _attendanceFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _attendanceFilter = index);
          _loadFilteredAttendance(provider);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive ? Border.all(color: AppColors.primary, width: 1) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(
              color: isActive ? AppColors.primary : AppColors.textTertiary(context),
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateGroup(String date, List<AttendanceModel> records) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.accent),
            const SizedBox(width: 6),
            Text('📅 $date',
                style: AppTypography.labelSmall.copyWith(
                    color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ),
        ...records.map((record) => _attendanceRow(record)),
        Divider(color: AppColors.cardBorder(context), height: 8),
      ],
    );
  }

  Widget _attendanceRow(AttendanceModel record) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        children: [
          // Clock In row
          Row(
            children: [
              Expanded(flex: 2, child: Text(record.staffName,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary(context), fontSize: 13))),
              Expanded(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('IN',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 10),
                      textAlign: TextAlign.center),
                ),
              ),
              Expanded(flex: 1, child: Text(
                Formatters.time(record.clockInTime),
                style: AppTypography.mono.copyWith(color: AppColors.textSecondary(context), fontSize: 12),
                textAlign: TextAlign.right,
              )),
            ],
          ),
          // Clock Out row (if exists)
          if (record.clockOutTime != null) ...[
            SizedBox(height: 3),
            Row(
              children: [
                Expanded(flex: 2, child: Text(record.staffName,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary(context), fontSize: 13))),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('OUT',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 10),
                        textAlign: TextAlign.center),
                  ),
                ),
                Expanded(flex: 1, child: Text(
                  Formatters.time(record.clockOutTime!),
                  style: AppTypography.mono.copyWith(color: AppColors.textSecondary(context), fontSize: 12),
                  textAlign: TextAlign.right,
                )),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

