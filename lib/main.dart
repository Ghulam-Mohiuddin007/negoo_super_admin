import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:negoo_super_admin/AdminHotelPipelineScreen.dart';
import 'package:negoo_super_admin/AdminMetricsDashboard.dart';
import 'package:negoo_super_admin/AdminPartnerManagementScreen.dart';
import 'package:negoo_super_admin/AdminPaymentSettlementScreen.dart';
import 'package:negoo_super_admin/admin_login.dart';
import 'package:negoo_super_admin/splash_screen.dart';
import 'package:negoo_super_admin/theme/app_theme.dart';
import 'package:negoo_super_admin/widgets/realtime_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ygtkveocvunfemoznrqx.supabase.co',
    publishableKey: 'sb_publishable_lcNZrPe8jt-q8wLa5z_5MQ_R-cqZ8ml',
  );

  runApp(const NegooCentralAdminApp());
}

class NegooCentralAdminApp extends StatelessWidget {
  const NegooCentralAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Negoo HQ Central Command',
      theme: AppTheme.darkTheme,
      home: const AdminSplashScreen(),
    );
  }
}

class AdminMainNavigationShell extends StatefulWidget {
  const AdminMainNavigationShell({super.key});

  @override
  State<AdminMainNavigationShell> createState() =>
      _AdminMainNavigationShellState();
}

class _AdminMainNavigationShellState extends State<AdminMainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    AdminMetricsDashboard(),
    AdminHotelPipelineScreen(),
    AdminPartnerManagementScreen(),
    AdminPaymentSettlementScreen(),
  ];

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: Text(
          "Sign Out of Console?",
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Are you sure you want to terminate the active administrative session?",
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textMuted,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("SIGN OUT", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 850;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Row(
              children: [
                // Executive Desktop Sidebar
                Container(
                  width: 260,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      right: BorderSide(color: AppColors.surfaceBorder, width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Branding Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.goldPrimary.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: AppColors.goldPrimary.withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                color: AppColors.goldPrimary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "NEGOO HQ",
                                  style: GoogleFonts.cinzel(
                                    color: AppColors.goldPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
                                Text(
                                  "CENTRAL COMMAND",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.surfaceBorder),
                      const SizedBox(height: 20),

                      // Navigation items
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _buildSidebarNavButton(
                              index: 0,
                              label: "Platform Metrics",
                              icon: Icons.dashboard_rounded,
                            ),
                            const SizedBox(height: 8),
                            _buildSidebarNavButton(
                              index: 1,
                              label: "Validation Queue",
                              icon: Icons.verified_user_rounded,
                            ),
                            const SizedBox(height: 8),
                            _buildSidebarNavButton(
                              index: 2,
                              label: "Active Partners",
                              icon: Icons.domain_rounded,
                            ),
                            const SizedBox(height: 8),
                            _buildSidebarNavButton(
                              index: 3,
                              label: "Payment Settlements",
                              icon: Icons.payments_rounded,
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Real-time Status Card & Sign-out
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "LIVE NODE",
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  RealtimeStatusBadge(label: "SYNCED"),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.goldPrimary.withValues(alpha: 0.15),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      size: 18,
                                      color: AppColors.goldPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "HQ Admin",
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          "Super Clearance",
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.rose),
                                    tooltip: "Sign Out",
                                    onPressed: _handleSignOut,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content Screen
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: _screens),
                ),
              ],
            ),
          );
        }

        // Mobile / Tablet Viewport with Sleek Bottom Navigation
        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: _screens),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.surfaceBorder, width: 1),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: AppColors.goldPrimary,
              unselectedItemColor: AppColors.textMuted,
              selectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard_rounded),
                  label: 'Metrics',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.verified_user_outlined),
                  activeIcon: Icon(Icons.verified_user_rounded),
                  label: 'Audits',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.domain_outlined),
                  activeIcon: Icon(Icons.domain_rounded),
                  label: 'Partners',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.payments_outlined),
                  activeIcon: Icon(Icons.payments_rounded),
                  label: 'Finance',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebarNavButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final bool isSelected = _currentIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.goldPrimary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.goldPrimary.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.goldPrimary : AppColors.textMuted,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.goldPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
