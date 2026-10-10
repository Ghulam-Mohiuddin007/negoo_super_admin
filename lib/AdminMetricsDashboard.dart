import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:negoo_super_admin/theme/app_theme.dart';
import 'package:negoo_super_admin/widgets/realtime_badge.dart';
import 'package:negoo_super_admin/widgets/stat_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminMetricsDashboard extends StatefulWidget {
  const AdminMetricsDashboard({super.key});

  @override
  State<AdminMetricsDashboard> createState() => _AdminMetricsDashboardState();
}

class _AdminMetricsDashboardState extends State<AdminMetricsDashboard> {
  late final SupabaseClient _supabase;
  List<Map<String, dynamic>> _hotelsData = [];
  List<Map<String, dynamic>> _bookingsData = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _currentTimeString = "";
  Timer? _clockTimer;
  Timer? _pollTimer;
  StreamSubscription? _hotelsSub;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _fetchDashboardData();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());

    // Hotels has realtime replication enabled
    _hotelsSub = _supabase.from('hotels').stream(primaryKey: ['id']).listen((data) {
      if (mounted) {
        setState(() {
          _hotelsData = data;
        });
      }
    }, onError: (_) {});

    // Rapid 3-second polling for bookings and live stats
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchDashboardData(silent: true);
    });
  }

  void _updateClock() {
    if (mounted) {
      setState(() {
        _currentTimeString = "${DateFormat('HH:mm:ss • dd MMM yyyy').format(DateTime.now().toUtc())} UTC";
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pollTimer?.cancel();
    _hotelsSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboardData({bool silent = false}) async {
    if (!silent && _hotelsData.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        _supabase.from('hotels').select(),
        _supabase.from('bookings').select(),
      ]);

      if (mounted) {
        setState(() {
          _hotelsData = List<Map<String, dynamic>>.from(results[0] as List);
          _bookingsData = List<Map<String, dynamic>>.from(results[1] as List);
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted && _hotelsData.isEmpty) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _triggerMetricsRefresh() async {
    await _fetchDashboardData(silent: false);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "EXECUTIVE INTELLIGENCE",
                  style: GoogleFonts.cinzel(
                    color: AppColors.goldPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  _currentTimeString,
                  style: GoogleFonts.jetBrainsMono(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Center(
            child: RealtimeStatusBadge(
              label: "LIVE REALTIME",
              onRefresh: _triggerMetricsRefresh,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppColors.goldPrimary, size: 20),
            tooltip: "Force Stream Re-Sync",
            onPressed: _triggerMetricsRefresh,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _buildDashboardBody(currencyFormat),
    );
  }

  Widget _buildDashboardBody(NumberFormat currencyFormat) {
    if (_isLoading && _hotelsData.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.goldPrimary),
      );
    }

    if (_errorMessage != null && _hotelsData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.rose, size: 48),
              const SizedBox(height: 16),
              Text(
                "Dashboard Sync Error",
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "$_errorMessage",
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _triggerMetricsRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text("RETRY LIVE CONNECTION", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldPrimary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hotelsData = _hotelsData;
    final bookingsData = _bookingsData;

    // Compute Metrics
    final int totalHotels = hotelsData.length;
    final int approvedHotels = hotelsData.where((item) {
      final s = (item['status'] ?? '').toString().toLowerCase().trim();
      return s == 'approved' && item['is_approved'] == true;
    }).length;

    final int rejectedHotels = hotelsData.where((item) {
      final s = (item['status'] ?? '').toString().toLowerCase().trim();
      return s == 'rejected';
    }).length;

    final int pendingHotels = hotelsData.where((item) {
      final s = (item['status'] ?? '').toString().toLowerCase().trim();
      if (s == 'rejected' || s == 'blocked') return false;
      if (s == 'approved' || item['is_approved'] == true) return false;
      return s == 'pending' || item['is_approved'] == false;
    }).length;

    double totalRevenue = 0.0;
    int confirmedBookings = 0;
    for (var b in bookingsData) {
      final status = (b['status'] ?? '').toString().toLowerCase().trim();
      if (status == 'confirmed' ||
          status == 'payment_received' ||
          status == 'cleared' ||
          status == 'settled_archived' ||
          status == 'completed') {
        confirmedBookings++;
        totalRevenue += (double.tryParse(b['total_price']?.toString() ?? '0') ?? 0.0);
      }
    }
    final double platformCommission = totalRevenue * 0.10;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final double maxWidth = constraints.maxWidth;
                  final bool isDesktop = maxWidth > 1000;
                  final bool isTablet = maxWidth > 680 && maxWidth <= 1000;
                  final int statCrossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 1);

                  return RefreshIndicator(
                    color: AppColors.goldPrimary,
                    backgroundColor: AppColors.surface,
                    onRefresh: _triggerMetricsRefresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 36 : 20,
                        vertical: 24,
                      ),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 1300),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Greeting / Subtitle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Platform Performance Overview",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: AppColors.textPrimary,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Real-time continuous synchronization active across all database nodes.",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: AppColors.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Key Stat Cards Grid
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: statCrossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: isDesktop ? 1.5 : (isTablet ? 1.6 : 2.0),
                                children: [
                                  StatCard(
                                    label: "Active Partner Venues",
                                    value: "$approvedHotels",
                                    icon: Icons.domain_rounded,
                                    accentColor: AppColors.emerald,
                                    subtitle: "$totalHotels Registered • $pendingHotels In Queue",
                                    badgeText: "ACTIVE",
                                  ),
                                  StatCard(
                                    label: "Gross Booking Volume",
                                    value: currencyFormat.format(totalRevenue),
                                    icon: Icons.payments_rounded,
                                    accentColor: AppColors.emerald,
                                    subtitle: "$confirmedBookings confirmed reservations",
                                    badgeText: "VOLUME",
                                  ),
                                  StatCard(
                                    label: "Negoo 10% Share",
                                    value: currencyFormat.format(platformCommission),
                                    icon: Icons.account_balance_wallet_rounded,
                                    accentColor: AppColors.cyan,
                                    subtitle: "Net platform earnings",
                                    badgeText: "COMMISSION",
                                  ),
                                  StatCard(
                                    label: "Pending Audit Queue",
                                    value: "$pendingHotels",
                                    icon: Icons.pending_actions_rounded,
                                    accentColor: pendingHotels > 0 ? AppColors.amber : AppColors.textMuted,
                                    subtitle: pendingHotels > 0 ? "Requires compliance review" : "Audit queue clear",
                                    badgeText: pendingHotels > 0 ? "ACTION REQ" : "CLEAR",
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              // Analytical Visual Charts Row
                              LayoutBuilder(
                                builder: (context, c) {
                                  final bool splitChart = c.maxWidth > 850;
                                  if (splitChart) {
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 6,
                                          child: _buildVenueStatusDistributionCard(
                                            approved: approvedHotels,
                                            pending: pendingHotels,
                                            rejected: rejectedHotels,
                                            total: totalHotels,
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          flex: 4,
                                          child: _buildSystemHealthConsole(),
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      children: [
                                        _buildVenueStatusDistributionCard(
                                          approved: approvedHotels,
                                          pending: pendingHotels,
                                          rejected: rejectedHotels,
                                          total: totalHotels,
                                        ),
                                        const SizedBox(height: 20),
                                        _buildSystemHealthConsole(),
                                      ],
                                    );
                                  }
                                },
                              ),

                              const SizedBox(height: 32),

                              // Realtime Recent Activity Feed
                              _buildLiveEventsFeed(hotelsData, bookingsData),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
  }

  Widget _buildVenueStatusDistributionCard({
    required int approved,
    required int pending,
    required int rejected,
    required int total,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PARTNER PIPELINE BREAKDOWN",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Real-time Commercial Property Distribution",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.goldPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$total Venues Logged",
                  style: const TextStyle(
                    color: AppColors.goldPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Donut / Pie Chart using fl_chart
          SizedBox(
            height: 190,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Builder(
                    builder: (context) {
                      final List<PieChartSectionData> chartSections = [
                        if (approved > 0)
                          PieChartSectionData(
                            color: AppColors.emerald,
                            value: approved.toDouble(),
                            title: "$approved",
                            radius: 26,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        if (pending > 0)
                          PieChartSectionData(
                            color: AppColors.amber,
                            value: pending.toDouble(),
                            title: "$pending",
                            radius: 26,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        if (rejected > 0)
                          PieChartSectionData(
                            color: AppColors.rose,
                            value: rejected.toDouble(),
                            title: "$rejected",
                            radius: 26,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                      ];

                      if (total == 0 || chartSections.isEmpty) {
                        return const Center(
                          child: Text(
                            "No property data registered",
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        );
                      }

                      return PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 46,
                          sections: chartSections,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(
                        color: AppColors.emerald,
                        title: "Active / Approved",
                        count: approved,
                        percentage: total > 0 ? ((approved / total) * 100).toStringAsFixed(1) : "0",
                      ),
                      const SizedBox(height: 12),
                      _buildLegendItem(
                        color: AppColors.amber,
                        title: "Pending Compliance",
                        count: pending,
                        percentage: total > 0 ? ((pending / total) * 100).toStringAsFixed(1) : "0",
                      ),
                      const SizedBox(height: 12),
                      _buildLegendItem(
                        color: AppColors.rose,
                        title: "Rejected / Inactive",
                        count: rejected,
                        percentage: total > 0 ? ((rejected / total) * 100).toStringAsFixed(1) : "0",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String title,
    required int count,
    required String percentage,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          "$count ($percentage%)",
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemHealthConsole() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "INFRASTRUCTURE TELEMETRY",
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const RealtimeStatusBadge(label: "HEALTHY"),
            ],
          ),
          const SizedBox(height: 20),
          _buildHealthRow(
            icon: Icons.wifi_tethering_rounded,
            title: "Supabase Realtime Engine",
            desc: "WebSocket Low Latency Channel",
            status: "Connected (SSL)",
            statusColor: AppColors.emerald,
          ),
          const Divider(height: 20, color: AppColors.surfaceBorder),
          _buildHealthRow(
            icon: Icons.explore_rounded,
            title: "PostGIS Spatial Terminal",
            desc: "Geo-Coordinates Query Node",
            status: "Active Cluster",
            statusColor: AppColors.goldPrimary,
          ),
          const Divider(height: 20, color: AppColors.surfaceBorder),
          _buildHealthRow(
            icon: Icons.shield_outlined,
            title: "Row Level Security (RLS)",
            desc: "Admin Master Clearance Shield",
            status: "Enforced",
            statusColor: AppColors.emerald,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRow({
    required IconData icon,
    required String title,
    required String desc,
    required String status,
    required Color statusColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: statusColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveEventsFeed(
    List<Map<String, dynamic>> hotels,
    List<Map<String, dynamic>> bookings,
  ) {
    // Generate combined live activities
    final List<Map<String, dynamic>> activities = [];

    for (var h in hotels.take(5)) {
      final status = (h['status'] ?? 'pending').toString().toLowerCase().trim();
      final Color statusColor;
      final String statusTag;

      if (status == 'rejected') {
        statusColor = AppColors.rose;
        statusTag = 'REJECTED';
      } else if (status == 'blocked') {
        statusColor = AppColors.rose;
        statusTag = 'BLOCKED';
      } else if ((status == 'approved' || h['is_approved'] == true) && status != 'pending') {
        statusColor = AppColors.emerald;
        statusTag = 'APPROVED';
      } else {
        statusColor = AppColors.amber;
        statusTag = 'PENDING AUDIT';
      }

      activities.add({
        'type': 'hotel',
        'title': h['hotel_name'] ?? 'Partner Venue',
        'subtitle': "Status: $statusTag",
        'icon': Icons.business_rounded,
        'color': statusColor,
        'tag': statusTag,
      });
    }

    for (var b in bookings.take(5)) {
      activities.add({
        'type': 'booking',
        'title': "Booking Reference #${b['id'].toString().substring(0, b['id'].toString().length > 8 ? 8 : b['id'].toString().length)}",
        'subtitle': "Gross Value: PKR ${b['total_price'] ?? '0'}",
        'icon': Icons.confirmation_number_rounded,
        'color': AppColors.goldPrimary,
        'tag': (b['status'] ?? 'NEW').toString().toUpperCase(),
      });
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "REALTIME TRANSACTION & AUDIT LOG",
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                "${activities.length} Events Logged",
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  "No transaction or partner records detected.",
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (context, _) => const Divider(
                height: 16,
                color: AppColors.surfaceBorder,
              ),
              itemBuilder: (context, index) {
                final item = activities[index];
                final Color accent = item['color'] as Color;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item['icon'] as IconData, size: 18, color: accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['subtitle'] as String,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          item['tag'] as String,
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
