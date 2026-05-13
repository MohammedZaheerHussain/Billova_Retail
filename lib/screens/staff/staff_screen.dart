import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/date_filter.dart';
import '../../widgets/date_filter_bar.dart';
import '../../providers/staff_provider.dart';
import '../../data/models/staff_model.dart';
import '../../data/models/attendance_model.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  DateFilterType _dateFilter = DateFilterType.today;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _selectedStaffId; // null = All Staff

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StaffProvider>();
      provider.loadStaff();
      _loadAttendance(provider);
    });
  }

  void _loadAttendance(StaffProvider provider) {
    final range = DateFilterHelper.getRange(
      _dateFilter,
      customStart: _customStart,
      customEnd: _customEnd,
    );
    // For "today" use the dedicated loader (faster, uses _todayDate)
    if (_dateFilter == DateFilterType.today) {
      provider.loadTodayAttendance();
    } else {
      provider.loadAttendanceHistory(from: range.start, to: range.end);
    }
  }

  Future<void> _pickCustomRange(StaffProvider provider) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _customStart ?? now.subtract(const Duration(days: 7)),
        end: _customEnd ?? now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.card(context),
              onSurface: AppColors.textPrimary(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _dateFilter = DateFilterType.custom;
      });
      provider.loadAttendanceHistory(from: picked.start, to: picked.end);
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
    // Merge today + history, deduplicate by id
    final historyIds = provider.attendanceHistory.map((r) => r.id).toSet();
    var all = [
      ...provider.attendanceHistory,
      ...provider.todayAttendance.where((r) => !historyIds.contains(r.id)),
    ];
    all.sort((a, b) {
      final d = b.date.compareTo(a.date);
      return d != 0 ? d : b.clockInTime.compareTo(a.clockInTime);
    });

    // Staff filter
    if (_selectedStaffId != null) {
      all = all.where((r) => r.staffId == _selectedStaffId).toList();
    }

    // Summary stats
    final totalShifts = all.length;
    final completedShifts = all.where((r) => r.clockOutTime != null).toList();
    final totalHours = completedShifts.fold<double>(0, (s, r) => s + (r.totalHours ?? 0));
    final uniqueDays = all.map((r) => r.date).toSet().length;

    // Group by date
    final Map<String, List<AttendanceModel>> grouped = {};
    for (final r in all) {
      grouped.putIfAbsent(r.date, () => []).add(r);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ───
          Row(children: [
            Icon(Icons.fact_check_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text('Attendance Log',
                style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
            const Spacer(),
            IconButton(
              onPressed: () => _loadAttendance(provider),
              icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary(context), size: 20),
              tooltip: 'Refresh',
            ),
          ]),
          const SizedBox(height: 12),

          // ─── Date Filter Bar ───
          DateFilterBar(
            selected: _dateFilter,
            onChanged: (type) {
              setState(() => _dateFilter = type);
              _loadAttendance(provider);
            },
            onCustomTap: () => _pickCustomRange(provider),
          ),
          const SizedBox(height: 10),

          // ─── Staff Filter Dropdown ───
          if (provider.staff.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedStaffId,
                  isExpanded: true,
                  dropdownColor: AppColors.card(context),
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary(context)),
                  hint: Text('All Staff',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Staff',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary(context))),
                    ),
                    ...provider.staff.map((s) => DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(s.name,
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary(context))),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedStaffId = v),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ─── Summary Stats ───
          if (all.isNotEmpty) ...[
            Row(children: [
              _statBadge(Icons.access_time_rounded, '${totalHours.toStringAsFixed(1)}h',
                  'Total Hours', AppColors.accent, AppColors.infoBg),
              const SizedBox(width: 8),
              _statBadge(Icons.calendar_today_rounded, '$uniqueDays',
                  uniqueDays == 1 ? 'Day' : 'Days', AppColors.success, AppColors.successBg),
              const SizedBox(width: 8),
              _statBadge(Icons.swap_horiz_rounded, '$totalShifts',
                  totalShifts == 1 ? 'Shift' : 'Shifts', AppColors.warning, AppColors.warningBg),
            ]),
            const SizedBox(height: 10),
            Divider(color: AppColors.cardBorder(context), height: 1),
            const SizedBox(height: 8),
          ],

          // ─── Records List ───
          Expanded(
            child: all.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.event_busy_rounded, size: 48,
                          color: AppColors.textTertiary(context).withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        _dateFilter == DateFilterType.today
                            ? 'No attendance records today'
                            : 'No records for this period',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textTertiary(context)),
                      ),
                    ]),
                  )
                : ListView.builder(
                    itemCount: grouped.keys.length,
                    itemBuilder: (_, i) {
                      final date = grouped.keys.elementAt(i);
                      return _dateGroup(date, grouped[date]!);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(IconData icon, String value, String label, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: AppTypography.mono
                    .copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
            Text(label,
                style: AppTypography.labelSmall
                    .copyWith(color: color.withValues(alpha: 0.7), fontSize: 9)),
          ]),
        ]),
      ),
    );
  }

  Widget _dateGroup(String date, List<AttendanceModel> records) {
    DateTime? parsed;
    try { parsed = DateTime.parse(date); } catch (_) {}
    final label = parsed != null ? DateFilterHelper.groupLabel(parsed) : date;
    final dayHours = records
        .where((r) => r.clockOutTime != null)
        .fold<double>(0, (s, r) => s + (r.totalHours ?? 0));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          if (dayHours > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4)),
              child: Text('${dayHours.toStringAsFixed(1)}h',
                  style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 10)),
            ),
          const Spacer(),
          Text('${records.length} shift${records.length != 1 ? 's' : ''}',
              style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
        ]),
      ),
      ...records.map((r) => _attendanceCard(r)),
      Divider(color: AppColors.cardBorder(context), height: 16),
    ]);
  }

  Widget _attendanceCard(AttendanceModel record) {
    final hasClockOut = record.clockOutTime != null;
    final hours = record.totalHours ?? 0;
    final isOpen = !hasClockOut;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isOpen
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.cardBorder(context)),
      ),
      child: Row(children: [
        Stack(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              record.staffName.isNotEmpty ? record.staffName[0].toUpperCase() : '?',
              style: AppTypography.mono
                  .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          if (isOpen)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.card(context), width: 1.5)),
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(record.staffName,
                  style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const Spacer(),
              if (isOpen)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('ACTIVE',
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 9)),
                ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.login_rounded, size: 12, color: AppColors.success),
              const SizedBox(width: 4),
              Text(Formatters.time(record.clockInTime),
                  style: AppTypography.mono
                      .copyWith(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
              if (hasClockOut) ...[
                const SizedBox(width: 10),
                Icon(Icons.logout_rounded, size: 12, color: AppColors.error),
                const SizedBox(width: 4),
                Text(Formatters.time(record.clockOutTime!),
                    style: AppTypography.mono
                        .copyWith(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Icon(Icons.timer_outlined, size: 12, color: AppColors.textTertiary(context)),
                const SizedBox(width: 4),
                Text('${hours.toStringAsFixed(1)}h',
                    style: AppTypography.mono
                        .copyWith(color: AppColors.textSecondary(context), fontSize: 12)),
              ] else ...[
                const SizedBox(width: 10),
                Text('Still clocked in',
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.success.withValues(alpha: 0.7))),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

