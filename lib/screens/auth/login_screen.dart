import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/cash_till_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/clearance_provider.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/local/db_helper.dart';
import '../shell/app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Admin fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Staff fields
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _obscurePin = true;

  // Tab state: 0 = Admin, 1 = Staff
  int _loginMode = 0;
  bool _isSubmitting = false;
  bool _rememberMe = false;
  String _syncStatus = ''; // Detailed loading status for staff login

  // Slideshow
  late final PageController _pageController;
  late final Timer _slideshowTimer;
  int _currentSlide = 0;
  bool _isPaused = false;

  static const _slideImages = [
    'assets/images/login/slide_1.jpg',
    'assets/images/login/slide_2.jpg',
    'assets/images/login/slide_3.jpg',
    'assets/images/login/slide_4.jpg',
  ];

  static const _slideTexts = [
    {'title': 'Modern Retail POS', 'sub': 'Fast checkout, thermal printing, and smart barcode billing.'},
    {'title': 'Intelligent Inventory', 'sub': 'Real-time stock tracking, low stock alerts, and vendor purchases.'},
    {'title': 'Customer & Credit Care', 'sub': 'Automated Udhar ledgers, loyalty rewards, and WhatsApp bills.'},
    {'title': 'AI Business Analytics', 'sub': 'Live sales trends, profit margins, and growth insights.'},
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _slideshowTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _isPaused) return;
      _currentSlide = (_currentSlide + 1) % _slideImages.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentSlide,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _slideshowTimer.cancel();
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submitAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final success = await auth.signIn(email, password);

    // Tell the browser to save credentials (triggers 'Save Password' prompt)
    if (success) TextInput.finishAutofillContext();

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  /// PRODUCTION-SAFE STAFF LOGIN
  /// Golden Rule: NO login validation until FULL data sync is complete.
  /// Flow: Session → Pull ALL data → Load ALL providers → Validate → Navigate
  Future<void> _submitStaff() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _syncStatus = 'Connecting...';
    });

    final auth = context.read<AuthProvider>();
    final staff = context.read<StaffProvider>();
    final username = _usernameController.text.trim();
    final pin = _pinController.text.trim();

    // ──────────────────────────────────────────────────────────
    // STEP 1: Recover admin Supabase session (REQUIRED)
    // Staff is a sub-account — admin's session provides data access.
    // ──────────────────────────────────────────────────────────
    if (!auth.isAuthenticated) {
      if (mounted) setState(() => _syncStatus = 'Recovering session...');
      try {
        await auth.checkSession();
      } catch (_) {
        debugPrint('⚠️ No Supabase session found');
      }
    }

    final supabase = SupabaseService.instance;
    if (!supabase.isLoggedIn) {
      // HARD BLOCK: Admin must have logged in at least once on this device
      auth.setError('Admin must log in first to enable staff access');
      if (mounted) setState(() { _isSubmitting = false; _syncStatus = ''; });
      return;
    }

    // ──────────────────────────────────────────────────────────
    // STEP 2: Pull ALL data from Supabase (FULL sync)
    // On web, local DB is in-memory — starts empty every restart.
    // We pull EVERYTHING before validation to prevent:
    //   - Empty credential table (login fails)
    //   - Partial data after navigation (empty screens)
    //   - Race conditions between login and data load
    // ──────────────────────────────────────────────────────────
    try {
      if (mounted) setState(() => _syncStatus = 'Clearing local data...');
      final db = DBHelper.instance;
      await db.clearAllData();

      if (mounted) setState(() => _syncStatus = 'Syncing data from cloud...');
      debugPrint('📥 Staff login: pulling ALL data for user ${supabase.userId}...');
      await supabase.pullAllData();
      debugPrint('✅ Full data pull complete');
    } catch (e) {
      debugPrint('⚠️ Data sync failed: $e');
      auth.setError('Data sync failed. Check your internet and try again.');
      if (mounted) setState(() { _isSubmitting = false; _syncStatus = ''; });
      return;
    }

    // ──────────────────────────────────────────────────────────
    // STEP 3: Load ALL providers from now-populated local DB
    // This ensures every screen has data BEFORE we navigate.
    // ──────────────────────────────────────────────────────────
    if (!mounted) return;
    if (mounted) setState(() => _syncStatus = 'Loading inventory & sales...');
    try {
      await Future.wait([
        staff.loadStaff(),
        context.read<InventoryProvider>().loadItems(),
        context.read<SalesProvider>().loadSales(),
        context.read<CustomerProvider>().loadCustomers(),
        context.read<ExpenseProvider>().loadExpenses(),
        context.read<CashTillProvider>().loadToday(),
        context.read<VendorProvider>().loadVendors(),
        context.read<PurchaseProvider>().loadPurchases(),
        context.read<CategoryProvider>().loadCategories(),
        context.read<ClearanceProvider>().loadClearanceRecords(),
        staff.loadTodayAttendance(),
      ]);
      debugPrint('✅ All providers loaded — ${staff.staff.length} staff, '
          '${context.read<InventoryProvider>().items.length} items');
    } catch (e) {
      debugPrint('⚠️ Provider load failed: $e');
      auth.setError('Failed to load data. Please try again.');
      if (mounted) setState(() { _isSubmitting = false; _syncStatus = ''; });
      return;
    }

    // ──────────────────────────────────────────────────────────
    // STEP 4: Validate staff credentials (data is now guaranteed)
    // ──────────────────────────────────────────────────────────
    if (mounted) setState(() => _syncStatus = 'Verifying credentials...');
    final error = await staff.loginStaff(username, pin);
    if (error != null) {
      auth.setError(error);
      if (mounted) setState(() { _isSubmitting = false; _syncStatus = ''; });
      return;
    }

    // ──────────────────────────────────────────────────────────
    // STEP 5: Mark auth as staff session + tell AppShell to skip re-pull
    // ──────────────────────────────────────────────────────────
    await auth.staffLogin();
    AppShell.dataPreloaded = true; // Skip redundant pull in AppShell
    if (mounted) setState(() => _syncStatus = 'Starting shift...');

    debugPrint('🚀 Staff login complete — navigating to home');
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
    if (mounted) setState(() { _isSubmitting = false; _syncStatus = ''; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          // ─── Left Panel: Image Slideshow (hidden on narrow screens) ───
          if (isWide)
            Expanded(
              flex: 5,
              child: _buildLeftPanel(),
            ),

          // ─── Right Panel: Login Form ───
          Expanded(
            flex: isWide ? 5 : 1,
            child: _buildRightPanel(auth),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LEFT PANEL — Image slideshow with Billova Retail branding
  // ═══════════════════════════════════════════════════════════════
  Widget _buildLeftPanel() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Slideshow images
        PageView.builder(
          controller: _pageController,
          onPageChanged: (i) => setState(() => _currentSlide = i),
          itemCount: _slideImages.length,
          itemBuilder: (context, index) {
            return Image.asset(
              _slideImages[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF060D1B),
                child: const Center(
                  child: Icon(Icons.image_outlined, color: Colors.white24, size: 64),
                ),
              ),
            );
          },
        ),

        // Dark gradient overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // BILLOVA Logo — top left
        Positioned(
          top: 40,
          left: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 12),
              const Text(
                'BILLOVA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 5,
                ),
              ),
              const Text(
                '~ RETAIL POS SYSTEM ~',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),

        // Slide text — bottom left
        Positioned(
          bottom: 80,
          left: 40,
          right: 40,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: Column(
              key: ValueKey(_currentSlide),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _slideTexts[_currentSlide]['title']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _slideTexts[_currentSlide]['sub']!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Slide indicators + pause button — bottom
        Positioned(
          bottom: 30,
          left: 40,
          right: 40,
          child: Row(
            children: [
              ...List.generate(_slideImages.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 8),
                  width: _currentSlide == i ? 32 : 10,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: _currentSlide == i
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                );
              }),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _isPaused = !_isPaused),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Icon(
                      _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RIGHT PANEL — Login form
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRightPanel(AuthProvider auth) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: Stack(
        children: [
          // "Secure Access" badge — top right
          Positioned(
            top: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Secure Access',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Centered form
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Welcome heading
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loginMode == 0
                          ? 'Sign in to your Billova Retail account'
                          : 'Clock in with your staff credentials',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Login Mode Toggle ───
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EDF2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _modeTab(0, 'Admin', Icons.admin_panel_settings_rounded),
                          _modeTab(1, 'Staff', Icons.badge_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ─── Form ───
                    AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_loginMode == 0) ...[
                            // ─── ADMIN: Email + Password ───
                            _buildLabel('Your Email'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email, AutofillHints.username],
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                              decoration: _lightInputDecoration(
                                hint: 'admin@billova.com',
                                icon: Icons.email_outlined,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Enter your email';
                                if (!v.contains('@')) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildLabel('Password'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                              decoration: _lightInputDecoration(
                                hint: '••••••••',
                                icon: Icons.lock_outlined,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Enter your password';
                                if (v.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                            ),
                          ] else ...[
                            // ─── STAFF: Username + PIN ───
                            _buildLabel('Username'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _usernameController,
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                              decoration: _lightInputDecoration(
                                hint: 'Enter your username',
                                icon: Icons.person_outline_rounded,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Enter your username';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildLabel('PIN'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _pinController,
                              obscureText: _obscurePin,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              style: TextStyle(
                                color: const Color(0xFF0F172A),
                                letterSpacing: _obscurePin ? 8 : 4,
                                fontSize: 18,
                              ),
                              decoration: _lightInputDecoration(
                                hint: '••••',
                                icon: Icons.pin_rounded,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePin = !_obscurePin),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Enter your PIN';
                                if (v.length < 4) return 'PIN must be 4-6 digits';
                                return null;
                              },
                            ),
                          ],

                          // Remember me + Forgot
                          if (_loginMode == 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                    activeColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Remember Me',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Error Message
                          if (auth.errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: AppColors.error, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      auth.errorMessage,
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : (_loginMode == 0 ? _submitAdmin : _submitStaff),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isSubmitting
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (_syncStatus.isNotEmpty) ...[
                                          const SizedBox(width: 10),
                                          Text(
                                            _syncStatus,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  : Text(
                                      _loginMode == 0 ? 'Login' : 'Clock In & Start',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ─── Developed by Barakah Tech ───
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => launchUrl(
                                Uri.parse('https://www.barakahtechnologies.com/'),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: Opacity(
                                opacity: 0.7,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Developed by',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.asset(
                                        'assets/images/barakah_logo.jpg',
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'BARAKAH TECH',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Restricted notice
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 16, color: const Color(0xFF64748B)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _loginMode == 0
                                        ? 'This system is restricted to authorized Billova Retail personnel only. Unauthorized access is prohibited.'
                                        : 'Enter the username and PIN provided by your admin. You will be automatically clocked in.',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ],
                        ),
                      ),
                    ),


                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Label ───
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
    );
  }

  // ─── Mode Tab ───
  Widget _modeTab(int index, String label, IconData icon) {
    final isActive = _loginMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _loginMode = index);
          context.read<AuthProvider>().clearError();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                  color: isActive ? AppColors.primary : const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Light Theme Input Decoration ───
  InputDecoration _lightInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
      ),
    );
  }
}
