import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:negoo_super_admin/theme/app_theme.dart';
import 'package:negoo_super_admin/widgets/image_preview_dialog.dart';
import 'package:negoo_super_admin/widgets/realtime_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminHotelPipelineScreen extends StatefulWidget {
  const AdminHotelPipelineScreen({super.key});

  @override
  State<AdminHotelPipelineScreen> createState() =>
      _AdminHotelPipelineScreenState();
}

class _AdminHotelPipelineScreenState extends State<AdminHotelPipelineScreen> {
  late final SupabaseClient _supabase;
  bool _processing = false;
  Map<String, dynamic>? _selectedHotelWeb;
  int _streamKey = 0;

  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  int _selectedFilterTab = 0; // 0 = Pending, 1 = Approved, 2 = Rejected, 3 = All Pipeline

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleManualRefresh() async {
    setState(() {
      _streamKey++;
    });
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _processApplication(String id, bool approve, {String? reason}) async {
    setState(() => _processing = true);
    try {
      if (approve) {
        await _supabase
            .from('hotels')
            .update({
              'is_approved': true,
              'status': 'approved',
            })
            .eq('id', id);
        _notify("Venue activated and published to live inventory!", AppColors.emerald);
      } else {
        await _supabase
            .from('hotels')
            .update({
              'status': 'rejected',
              'is_approved': false,
              'document_url': null,
              'image_url': null,
              'owner_cnic_url': null,
              'owner_image_url': null,
              'reg_no': reason ?? 'REJECTED - PLEASE RESUBMIT CREDENTIALS',
            })
            .eq('id', id);
        _notify("Application rejected. Credentials flagged for resubmission.", AppColors.rose);
      }

      setState(() {
        _streamKey++;
        _selectedHotelWeb = null;
      });
    } catch (e) {
      _notify("Action execution failure: $e", AppColors.rose);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _restoreToPending(String id, String hotelName) async {
    setState(() => _processing = true);
    try {
      await _supabase
          .from('hotels')
          .update({
            'status': 'pending',
            'is_approved': false,
          })
          .eq('id', id);

      _notify("$hotelName restored to Pending Review queue.", AppColors.amber);
      setState(() {
        _streamKey++;
        _selectedHotelWeb = null;
      });
    } catch (e) {
      _notify("Restore error: $e", AppColors.rose);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _deleteHotelPermanently(String id, String hotelName) async {
    setState(() => _processing = true);
    try {
      // 1. Delete associated rooms first
      await _supabase.from('rooms').delete().eq('hotel_id', id);
      // 2. Delete hotel record permanently
      await _supabase.from('hotels').delete().eq('id', id);

      _notify("$hotelName was permanently deleted from database.", AppColors.rose);
      setState(() {
        _streamKey++;
        _selectedHotelWeb = null;
      });
    } catch (e) {
      _notify("Failed to delete hotel: $e", AppColors.rose);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showDeleteConfirmationDialog(String hotelId, String hotelName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.rose, width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: AppColors.rose, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Delete Hotel Permanently?",
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Are you sure you want to completely remove $hotelName from the database?",
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.rose, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "WARNING: This will permanently delete the hotel record and all associated room listings from Supabase. This action CANNOT be undone.",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.roseLight,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Hotel ID: $hotelId",
                style: GoogleFonts.jetBrainsMono(color: AppColors.textMuted, fontSize: 10.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteHotelPermanently(hotelId, hotelName);
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text("DELETE FROM DATABASE", style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String hotelId, String hotelName) {
    final TextEditingController reasonController = TextEditingController();
    String selectedPreset = "Document illegible or blurred";

    final presets = [
      "Document illegible or blurred",
      "CNIC expired or details mismatched",
      "Invalid commercial trade license",
      "Exterior venue photo does not meet quality standards",
      "Owner identity portrait unverified",
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.surfaceBorder),
            ),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.rose),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Reject Compliance: $hotelName",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Select regulatory violation or specify resubmission requirements:",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPreset,
                        isExpanded: true,
                        dropdownColor: AppColors.surfaceElevated,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        items: presets
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedPreset = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Optional custom notes for venue management...",
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.surfaceBorder),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("CANCEL", style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: () {
                  final finalReason = reasonController.text.trim().isNotEmpty
                      ? reasonController.text.trim()
                      : selectedPreset;
                  Navigator.pop(ctx);
                  _processApplication(hotelId, false, reason: finalReason);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("CONFIRM REJECTION", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _notify(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  "VALIDATION PIPELINE",
                  style: GoogleFonts.cinzel(
                    color: AppColors.goldPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  "LEGAL & COMPLIANCE VERIFICATION QUEUE",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Center(
            child: RealtimeStatusBadge(
              label: "AUDIT QUEUE LIVE",
              onRefresh: _handleManualRefresh,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.goldPrimary),
            tooltip: "Force Reload Streams",
            onPressed: _handleManualRefresh,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth > 950;

          return StreamBuilder<List<Map<String, dynamic>>>(
            key: ValueKey('audit_stream_$_streamKey'),
            stream: _supabase
                .from('hotels')
                .stream(primaryKey: ['id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.goldPrimary),
                );
              }

              final rawHotels = snapshot.data ?? [];

              // Calculate Status Counts
              final pendingHotelsList = rawHotels.where((item) {
                final s = (item['status'] ?? '').toString().toLowerCase().trim();
                if (s == 'rejected') return false;
                if (s == 'approved' || item['is_approved'] == true) return false;
                return s == 'pending' || item['is_approved'] == false;
              }).toList();

              final approvedHotelsList = rawHotels.where((item) {
                final s = (item['status'] ?? '').toString().toLowerCase().trim();
                return s == 'approved' || item['is_approved'] == true;
              }).toList();

              final rejectedHotelsList = rawHotels.where((item) {
                final s = (item['status'] ?? '').toString().toLowerCase().trim();
                return s == 'rejected';
              }).toList();

              final allPipelineList = rawHotels;

              // Filter based on selected tab
              final List<Map<String, dynamic>> tabFiltered;
              if (_selectedFilterTab == 0) {
                tabFiltered = pendingHotelsList;
              } else if (_selectedFilterTab == 1) {
                tabFiltered = approvedHotelsList;
              } else if (_selectedFilterTab == 2) {
                tabFiltered = rejectedHotelsList;
              } else {
                tabFiltered = allPipelineList;
              }

              // Apply Search Query Filter
              final queue = tabFiltered.where((item) {
                if (_searchQuery.isEmpty) return true;
                final name = (item['hotel_name'] ?? '').toString().toLowerCase();
                final regNo = (item['reg_no'] ?? '').toString().toLowerCase();
                final phone = (item['phone_number'] ?? '').toString().toLowerCase();
                final id = (item['id'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) ||
                    regNo.contains(_searchQuery) ||
                    phone.contains(_searchQuery) ||
                    id.contains(_searchQuery);
              }).toList();

              // Auto-select first item on desktop
              if (isDesktop && _selectedHotelWeb == null && queue.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedHotelWeb == null) {
                    setState(() => _selectedHotelWeb = queue.first);
                  }
                });
              }

              Widget mainListView = Column(
                children: [
                  // Filter Tabs
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        _buildFilterTab(
                          index: 0,
                          label: "Pending",
                          count: pendingHotelsList.length,
                          color: AppColors.amber,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterTab(
                          index: 1,
                          label: "Approved",
                          count: approvedHotelsList.length,
                          color: AppColors.emerald,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterTab(
                          index: 2,
                          label: "Rejected",
                          count: rejectedHotelsList.length,
                          color: AppColors.rose,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterTab(
                          index: 3,
                          label: "All Pipeline",
                          count: allPipelineList.length,
                          color: AppColors.goldPrimary,
                        ),
                      ],
                    ),
                  ),

                  // Search & Counter Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "Search queue by venue name, reg ID, phone...",
                              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 18),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                                      onPressed: () => _searchController.clear(),
                                    )
                                  : null,
                              filled: true,
                              fillColor: AppColors.surfaceCard,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.surfaceBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.goldPrimary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Text(
                            "${queue.length} SHOWN",
                            style: const TextStyle(
                              color: AppColors.goldPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // List Content
                  Expanded(
                    child: queue.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceCard,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.surfaceBorder),
                                  ),
                                  child: Icon(
                                    _selectedFilterTab == 0
                                        ? Icons.pending_actions_rounded
                                        : (_selectedFilterTab == 1
                                            ? Icons.check_circle_outline_rounded
                                            : (_selectedFilterTab == 2
                                                ? Icons.cancel_outlined
                                                : Icons.account_balance_rounded)),
                                    size: 40,
                                    color: _selectedFilterTab == 1
                                        ? AppColors.emerald
                                        : (_selectedFilterTab == 0
                                            ? AppColors.amber
                                            : (_selectedFilterTab == 2
                                                ? AppColors.rose
                                                : AppColors.goldPrimary)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedFilterTab == 0
                                      ? "Pending audit queue is clear!"
                                      : (_selectedFilterTab == 1
                                          ? "No approved hotel properties found."
                                          : (_selectedFilterTab == 2
                                              ? "No rejected applications found."
                                              : "Pipeline has zero hotel entries.")),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _selectedFilterTab == 0
                                      ? "All venue submissions have been reviewed."
                                      : (_selectedFilterTab == 1
                                          ? "Approved properties will show here once audited."
                                          : "No hotel listings meet this criteria."),
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.goldPrimary,
                            backgroundColor: AppColors.surface,
                            onRefresh: _handleManualRefresh,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: queue.length,
                              itemBuilder: (context, index) {
                                final hotel = queue[index];
                                final hotelId = hotel['id'].toString();
                                final hotelName = hotel['hotel_name'] ?? hotel['name'] ?? 'Verification Node';
                                final bool isSelectedOnWeb =
                                    isDesktop && _selectedHotelWeb?['id'] == hotel['id'];

                                final status = (hotel['status'] ?? 'pending').toString().toLowerCase().trim();
                                final bool isApproved = status == 'approved' || hotel['is_approved'] == true;
                                final bool isRejected = status == 'rejected';

                                final Color statusColor = isApproved
                                    ? AppColors.emerald
                                    : (isRejected ? AppColors.rose : AppColors.amber);
                                final String statusLabel = isApproved
                                    ? "APPROVED"
                                    : (isRejected ? "REJECTED" : "PENDING AUDIT");

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isSelectedOnWeb
                                        ? AppColors.surfaceElevated
                                        : AppColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSelectedOnWeb
                                          ? statusColor.withValues(alpha: 0.6)
                                          : AppColors.surfaceBorder,
                                      width: isSelectedOnWeb ? 1.5 : 1.0,
                                    ),
                                    boxShadow: [
                                      if (isSelectedOnWeb)
                                        BoxShadow(
                                          color: statusColor.withValues(alpha: 0.1),
                                          blurRadius: 16,
                                        ),
                                    ],
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () {
                                      if (isDesktop) {
                                        setState(() => _selectedHotelWeb = hotel);
                                      } else {
                                        _openComplianceInspectionSheet(hotel);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: AppColors.surfaceBorder),
                                              image: hotel['image_url'] != null
                                                  ? DecorationImage(
                                                      image: NetworkImage(hotel['image_url']),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                            child: hotel['image_url'] == null
                                                ? Icon(
                                                    Icons.hotel_rounded,
                                                    color: statusColor,
                                                    size: 24,
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        hotelName,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                          color: AppColors.textPrimary,
                                                          fontSize: 14,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: statusColor.withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: statusColor.withValues(alpha: 0.3),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        statusLabel,
                                                        style: TextStyle(
                                                          color: statusColor,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  isRejected
                                                      ? "Reason: ${hotel['reg_no'] ?? 'Credentials rejected'}"
                                                      : (isApproved
                                                          ? "Active Partner • Reg: ${hotel['reg_no'] ?? 'Verified'}"
                                                          : "License: ${hotel['reg_no'] ?? 'Unspecified'}"),
                                                  style: TextStyle(
                                                    color: isRejected
                                                        ? AppColors.roseLight.withValues(alpha: 0.8)
                                                        : (isApproved ? AppColors.emeraldLight : AppColors.textMuted),
                                                    fontSize: 11,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  isDesktop
                                                      ? "Click to audit compliance suite"
                                                      : "Tap to review complete document bundle",
                                                  style: TextStyle(
                                                    color: AppColors.goldPrimary.withValues(alpha: 0.8),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rose, size: 20),
                                            tooltip: "Delete Hotel from Database",
                                            onPressed: () => _showDeleteConfirmationDialog(hotelId, hotelName),
                                          ),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: AppColors.textMuted,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              );

              // Web Split View Return Tree
              if (isDesktop) {
                return Row(
                  children: [
                    Expanded(flex: 4, child: mainListView),
                    const VerticalDivider(width: 1, color: AppColors.surfaceBorder),
                    Expanded(
                      flex: 6,
                      child: _selectedHotelWeb != null
                          ? Container(
                              color: AppColors.surface,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(32),
                                child: _buildComplianceInspectionContent(
                                  _selectedHotelWeb!,
                                ),
                              ),
                            )
                          : const Center(
                              child: Text(
                                "Select a venue from the pipeline queue to inspect details.",
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                    ),
                  ],
                );
              }

              return mainListView;
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterTab({
    required int index,
    required String label,
    required int count,
    required Color color,
  }) {
    final isSelected = _selectedFilterTab == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedFilterTab = index;
              _selectedHotelWeb = null;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.12) : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color.withValues(alpha: 0.6) : AppColors.surfaceBorder,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.25) : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "$count",
                    style: TextStyle(
                      color: isSelected ? color : AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComplianceInspectionContent(Map<String, dynamic> hotel) {
    final String hotelId = hotel['id'].toString();
    final String hotelName = hotel['hotel_name'] ?? 'Verification Overview';
    final status = (hotel['status'] ?? 'pending').toString().toLowerCase().trim();
    final bool isApproved = status == 'approved' || hotel['is_approved'] == true;
    final bool isRejected = status == 'rejected';

    final Color statusColor = isApproved
        ? AppColors.emerald
        : (isRejected ? AppColors.rose : AppColors.amber);
    final String statusLabel = isApproved
        ? "APPROVED"
        : (isRejected ? "REJECTED" : "PENDING AUDIT");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotelName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isApproved
                        ? "Property is actively approved and published to live inventory on customer apps."
                        : (isRejected
                            ? "Application has been marked as rejected. Hoteliers prompted to resubmit."
                            : "Verify submitted legal credentials and identity cards before activating inventory."),
                    style: GoogleFonts.plusJakartaSans(
                      color: isApproved ? AppColors.emeraldLight : AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),

        if (isRejected) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.rose.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cancel_rounded, color: AppColors.rose, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "REJECTION REASON ON RECORD",
                        style: TextStyle(
                          color: AppColors.rose,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hotel['reg_no'] ?? "Credentials rejected by system administrator.",
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Divider(color: AppColors.surfaceBorder, height: 1),
        ),

        // Key Identifiers
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            children: [
              _buildIdentityField(
                "Corporate License / Reg Number",
                hotel['reg_no'] ?? 'Unspecified',
                Icons.gavel_rounded,
              ),
              const Divider(height: 16, color: AppColors.surfaceBorder),
              _buildIdentityField(
                "Registered Supabase Entity ID",
                hotelId,
                Icons.fingerprint_rounded,
              ),
              if (hotel['phone_number'] != null) ...[
                const Divider(height: 16, color: AppColors.surfaceBorder),
                _buildIdentityField(
                  "Operational Contact Phone",
                  hotel['phone_number'].toString(),
                  Icons.phone_rounded,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "LEGAL COMPLIANCE DIGITAL ASSETS",
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.goldPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              "Tap any asset to zoom & inspect",
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildImageFilePreviewBlock(
          "Property Branding Logo / Facade Cover",
          hotel['image_url'],
          Icons.hotel_rounded,
        ),
        _buildImageFilePreviewBlock(
          "Commercial Registration / Tax Business License",
          hotel['document_url'],
          Icons.description_rounded,
        ),
        _buildImageFilePreviewBlock(
          "Managing Partner National CNIC Identity Stack",
          hotel['owner_cnic_url'],
          Icons.badge_rounded,
        ),
        _buildImageFilePreviewBlock(
          "Managing Partner Facial Portrait Verification",
          hotel['owner_image_url'],
          Icons.face_rounded,
        ),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(color: AppColors.surfaceBorder),
        ),

        // Decision Action Suite
        if (isApproved)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing
                      ? null
                      : () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          _showRejectDialog(hotelId, hotelName);
                        },
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text(
                    "REVOKE / REJECT",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rose,
                    side: const BorderSide(color: AppColors.rose),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing
                      ? null
                      : () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          _restoreToPending(hotelId, hotelName);
                        },
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text(
                    "MOVE TO PENDING",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amber,
                    side: const BorderSide(color: AppColors.amber),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          )
        else if (isRejected)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing
                      ? null
                      : () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          _restoreToPending(hotelId, hotelName);
                        },
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text(
                    "RESTORE TO PENDING REVIEW",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amber,
                    side: const BorderSide(color: AppColors.amber),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processing
                      ? null
                      : () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          _processApplication(hotelId, true);
                        },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text(
                    "FORCE OVERRIDE & APPROVE",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldPrimary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _processing
                      ? null
                      : () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          _showRejectDialog(hotelId, hotelName);
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rose,
                    side: const BorderSide(color: AppColors.rose),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "REJECT APPLICATION",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton(
                  onPressed: _processing
                      ? null
                      : () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          _processApplication(hotelId, true);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldPrimary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          "APPROVE & ACTIVATE",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
            ],
          ),

        const SizedBox(height: 14),

        // Permanent Deletion from Database Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _processing
                ? null
                : () {
                    _showDeleteConfirmationDialog(hotelId, hotelName);
                  },
            icon: const Icon(Icons.delete_forever_rounded, color: AppColors.rose, size: 18),
            label: const Text(
              "REMOVE HOTEL / DELETE FROM DATABASE",
              style: TextStyle(
                color: AppColors.rose,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                fontSize: 12,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.rose,
              side: BorderSide(color: AppColors.rose.withValues(alpha: 0.6), width: 1.2),
              backgroundColor: AppColors.rose.withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _openComplianceInspectionSheet(Map<String, dynamic> hotel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      constraints: const BoxConstraints(maxWidth: 680),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildComplianceInspectionContent(hotel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityField(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.goldPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.goldPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageFilePreviewBlock(String label, String? url, IconData fallbackIcon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (url != null && url.isNotEmpty)
              TextButton.icon(
                onPressed: () => ImagePreviewDialog.show(
                  context,
                  title: label,
                  imageUrl: url,
                ),
                icon: const Icon(Icons.fullscreen_rounded, size: 16, color: AppColors.goldPrimary),
                label: const Text(
                  "INSPECT FULLSCREEN",
                  style: TextStyle(color: AppColors.goldPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: (url != null && url.isNotEmpty)
              ? () => ImagePreviewDialog.show(context, title: label, imageUrl: url)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            height: 200,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: url != null && url.isNotEmpty
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.goldPrimary),
                        );
                      },
                      errorBuilder: (c, e, s) => const Center(
                        child: Text(
                          "Document asset image unreachable",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(fallbackIcon, color: AppColors.textMuted, size: 28),
                          const SizedBox(height: 8),
                          const Text(
                            "No document uploaded for this container",
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
