import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:negoo_super_admin/theme/app_theme.dart';
import 'package:negoo_super_admin/widgets/image_preview_dialog.dart';
import 'package:negoo_super_admin/widgets/realtime_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPartnerManagementScreen extends StatefulWidget {
  const AdminPartnerManagementScreen({super.key});

  @override
  State<AdminPartnerManagementScreen> createState() =>
      _AdminPartnerManagementScreenState();
}

class _AdminPartnerManagementScreenState
    extends State<AdminPartnerManagementScreen> {
  late final SupabaseClient _supabase;

  Map<String, dynamic>? _selectedPartnerWeb;
  int _managementKey = 0;

  // Search & Filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

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

  Future<void> _handleManualStreamRefresh() async {
    setState(() {
      _managementKey++;
    });
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _terminateAndKillPartnerRecord(String id) async {
    try {
      await _supabase
          .from('hotels')
          .delete()
          .eq('id', id);

      if (!mounted) return;
      _notify("Partner row completely deleted from registry!", AppColors.rose);

      if (_selectedPartnerWeb?['id']?.toString() == id) {
        setState(() => _selectedPartnerWeb = null);
      }
    } catch (e) {
      _notify("Termination Error: $e", AppColors.rose);
    }
  }

  Future<void> _suspendPartner(String id, String name) async {
    try {
      await _supabase
          .from('hotels')
          .update({
            'status': 'pending',
            'is_approved': false,
          })
          .eq('id', id);

      if (!mounted) return;
      _notify("$name access suspended. Moved to validation queue.", AppColors.amber);

      if (_selectedPartnerWeb?['id']?.toString() == id) {
        setState(() => _selectedPartnerWeb = null);
      }
    } catch (e) {
      _notify("Suspension Error: $e", AppColors.rose);
    }
  }

  Future<void> _blockPartner(String id, String name) async {
    try {
      await _supabase
          .from('hotels')
          .update({
            'status': 'blocked',
            'is_approved': false,
            'reg_no': 'BLOCKED BY HQ - PAYMENT DEFAULT / SUSPENSION',
          })
          .eq('id', id);

      if (!mounted) return;
      _notify("$name blocked from live operations & booking terminals.", AppColors.rose);

      if (_selectedPartnerWeb?['id']?.toString() == id) {
        setState(() => _selectedPartnerWeb = null);
      }
    } catch (e) {
      _notify("Block Error: $e", AppColors.rose);
    }
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
                  "ACTIVE PARTNERS REGISTER",
                  style: GoogleFonts.cinzel(
                    color: AppColors.goldPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  "COMMERCIAL HOTEL ASSET INVENTORY",
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
              label: "LIVE REGISTRY",
              onRefresh: _handleManualStreamRefresh,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.goldPrimary),
            tooltip: "Refresh Real-time Link",
            onPressed: _handleManualStreamRefresh,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth > 950;

          return StreamBuilder<List<Map<String, dynamic>>>(
            key: ValueKey('partners_$_managementKey'),
            stream: _supabase
                .from('hotels')
                .stream(primaryKey: ['id'])
                .eq('status', 'approved'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.goldPrimary),
                );
              }

              final rawPartners = snapshot.data ?? [];

              // Apply Search Filter with strict approval check
              final activePartners = rawPartners.where((p) {
                final status = (p['status'] ?? '').toString().toLowerCase().trim();
                final bool isApproved = status == 'approved' && p['is_approved'] == true;
                if (!isApproved) return false;

                if (_searchQuery.isEmpty) return true;
                final name = (p['hotel_name'] ?? p['name'] ?? '').toString().toLowerCase();
                final phone = (p['phone_number'] ?? '').toString().toLowerCase();
                final regNo = (p['reg_no'] ?? '').toString().toLowerCase();
                final id = (p['id'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) ||
                    phone.contains(_searchQuery) ||
                    regNo.contains(_searchQuery) ||
                    id.contains(_searchQuery);
              }).toList();

              // Auto-select first item on desktop, or clear if active list is empty
              if (activePartners.isEmpty && _selectedPartnerWeb != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedPartnerWeb != null) {
                    setState(() => _selectedPartnerWeb = null);
                  }
                });
              } else if (isDesktop &&
                  _selectedPartnerWeb == null &&
                  activePartners.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedPartnerWeb == null) {
                    setState(() => _selectedPartnerWeb = activePartners.first);
                  }
                });
              }

              Widget mainList = Column(
                children: [
                  // Search & Counter Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "Search approved venues by name, phone, reg...",
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
                            "${activePartners.length} ACTIVE",
                            style: const TextStyle(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Partners List
                  Expanded(
                    child: activePartners.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.domain_disabled_rounded, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 16),
                                Text(
                                  rawPartners.isEmpty
                                      ? "No commercial properties currently authorized."
                                      : "No active partners match search filter.",
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  rawPartners.isEmpty
                                      ? "Review and approve pending applications in the Validation Queue."
                                      : "Clear query to view all authorized properties.",
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.goldPrimary,
                            backgroundColor: AppColors.surface,
                            onRefresh: _handleManualStreamRefresh,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: activePartners.length,
                              itemBuilder: (context, index) {
                                final venue = activePartners[index];
                                final bool isSelectedOnWeb =
                                    isDesktop && _selectedPartnerWeb?['id'] == venue['id'];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isSelectedOnWeb
                                        ? AppColors.surfaceElevated
                                        : AppColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSelectedOnWeb
                                          ? AppColors.goldPrimary.withValues(alpha: 0.6)
                                          : AppColors.surfaceBorder,
                                      width: isSelectedOnWeb ? 1.5 : 1.0,
                                    ),
                                    boxShadow: [
                                      if (isSelectedOnWeb)
                                        BoxShadow(
                                          color: AppColors.goldPrimary.withValues(alpha: 0.1),
                                          blurRadius: 16,
                                        ),
                                    ],
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () {
                                      if (isDesktop) {
                                        setState(() => _selectedPartnerWeb = venue);
                                      } else {
                                        _displayVerificationVaultSheet(venue);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: AppColors.surfaceBorder),
                                              image: venue['image_url'] != null
                                                  ? DecorationImage(
                                                      image: NetworkImage(venue['image_url']),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                            child: venue['image_url'] == null
                                                ? const Icon(
                                                    Icons.domain_rounded,
                                                    color: AppColors.emerald,
                                                    size: 22,
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
                                                        venue['hotel_name'] ?? venue['name'] ?? "Premium Venue",
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
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.emerald.withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Text(
                                                        "LIVE",
                                                        style: TextStyle(
                                                          color: AppColors.emerald,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "Phone: ${venue['phone_number'] ?? 'N/A'}",
                                                  style: const TextStyle(
                                                    color: AppColors.textMuted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  isDesktop
                                                      ? "Click to inspect bookings & inventory"
                                                      : "Tap to inspect bookings & financials",
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
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppColors.rose,
                                              size: 19,
                                            ),
                                            tooltip: "Terminate Partner Record",
                                            onPressed: () => _showSuspensionWarning(
                                              venue['id'].toString(),
                                              venue['hotel_name'] ?? venue['name'] ?? "this property",
                                            ),
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

              if (isDesktop) {
                return Row(
                  children: [
                    Expanded(flex: 4, child: mainList),
                    const VerticalDivider(width: 1, color: AppColors.surfaceBorder),
                    Expanded(
                      flex: 6,
                      child: _selectedPartnerWeb != null
                          ? Container(
                              color: AppColors.surface,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(32),
                                child: _buildVaultInspectionContent(
                                  _selectedPartnerWeb!,
                                ),
                              ),
                            )
                          : const Center(
                              child: Text(
                                "Select a partner node from the register to view diagnostic hub.",
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                    ),
                  ],
                );
              }

              return mainList;
            },
          );
        },
      ),
    );
  }

  Widget _buildVaultInspectionContent(Map<String, dynamic> venue) {
    final String targetHotelId = venue['id'].toString();
    final String venueName = venue['hotel_name'] ?? venue['name'] ?? 'Partner Information';

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
                    venueName,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Commercial diagnostics, active suite catalog, and transaction logs.",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 14),
                  SizedBox(width: 6),
                  Text(
                    "AUTHORIZED",
                    style: TextStyle(
                      color: AppColors.emerald,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Divider(color: AppColors.surfaceBorder, height: 1),
        ),

        // Financial & Booking Performance Metrics
        Text(
          "PROPERTY TRANSACTION METRICS",
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.goldPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),

        FutureBuilder<PostgrestList>(
          future: _supabase
              .from('bookings')
              .select('*, rooms!fk_room!inner(hotel_id)')
              .eq('rooms.hotel_id', targetHotelId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.goldPrimary),
                ),
              );
            }

            final data = snapshot.data ?? [];
            int totalBookingsCount = data.length;

            double dynamicGrossTotal = 0.0;
            for (var row in data) {
              final status = row['status']?.toString().toLowerCase();
              if (status == 'confirmed' || status == 'settled_archived' || status == 'completed') {
                dynamicGrossTotal +=
                    (double.tryParse(row['total_price']?.toString() ?? '0') ?? 0.0);
              }
            }
            double negooAppShareCut = dynamicGrossTotal * 0.10;

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  _buildAnalyticalMetricsRow(
                    "Total Reservations Logged",
                    "$totalBookingsCount Bookings",
                    AppColors.textSecondary,
                  ),
                  const Divider(height: 18, color: AppColors.surfaceBorder),
                  _buildAnalyticalMetricsRow(
                    "Compound Revenue Volume",
                    "PKR ${NumberFormat('#,##0').format(dynamicGrossTotal)}",
                    AppColors.textPrimary,
                  ),
                  const Divider(height: 18, color: AppColors.surfaceBorder),
                  _buildAnalyticalMetricsRow(
                    "Negoo Platform Commission (10%)",
                    "PKR ${NumberFormat('#,##0').format(negooAppShareCut)}",
                    AppColors.goldPrimary,
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 28),

        // Active Suite Inventory Hub
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "ACTIVE SUITE & ROOM INVENTORY",
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.goldPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              "Tap room to inspect full profile",
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),

        FutureBuilder<PostgrestList>(
          future: _supabase
              .from('rooms')
              .select('*')
              .eq('hotel_id', targetHotelId),
          builder: (context, roomSnapshot) {
            if (roomSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.goldPrimary),
                ),
              );
            }

            final roomsList = roomSnapshot.data ?? [];
            if (roomsList.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: const Center(
                  child: Text(
                    "No room or suite assets mapped for this hotel venue.",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: roomsList.length,
              itemBuilder: (context, i) {
                final room = roomsList[i];
                final List<dynamic> imageUrls = room['room_images'] ?? [];
                final String? fallbackThumb = imageUrls.isNotEmpty
                    ? imageUrls.first
                    : room['image_url'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _displayDetailedRoomHub(room),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.surfaceBorder),
                              image: fallbackThumb != null
                                  ? DecorationImage(
                                      image: NetworkImage(fallbackThumb),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: fallbackThumb == null
                                ? const Icon(
                                    Icons.king_bed_rounded,
                                    color: AppColors.goldPrimary,
                                    size: 22,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room['room_type'] ?? 'Standard Suite',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "Max: ${room['max_guests'] ?? 2} Guests • ${room['bed_type'] ?? 'King Size'}",
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "PKR ${room['price'] ?? '0'}",
                            style: const TextStyle(
                              color: AppColors.goldPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
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
            );
          },
        ),

        const SizedBox(height: 28),

        // Legal Specifications
        Text(
          "LEGAL SPECIFICATIONS & CONTACT",
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.goldPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            children: [
              _buildMetaRow(
                "Registration / CNIC Reference ID",
                venue['reg_no'] ?? venue['cnic_number'] ?? 'N/A',
                Icons.pin_rounded,
              ),
              const Divider(height: 16, color: AppColors.surfaceBorder),
              _buildMetaRow(
                "Operational Contact Number",
                venue['phone_number'] ?? 'N/A',
                Icons.phone_rounded,
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Compliance Documents
        Text(
          "DIGITAL COMPLIANCE ARCHIVE",
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.goldPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 14),

        _buildDocumentAssetBlock(
          "Official Business License / Reg Document",
          venue['document_url'],
          Icons.description_rounded,
        ),
        _buildDocumentAssetBlock(
          "Owner CNIC (Identification Card Stack)",
          venue['owner_cnic_url'],
          Icons.badge_rounded,
        ),
        _buildDocumentAssetBlock(
          "Owner Verification Portrait Headshot",
          venue['owner_image_url'],
          Icons.face_rounded,
        ),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(color: AppColors.surfaceBorder),
        ),

        // Management Actions Suite
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _suspendPartner(targetHotelId, venueName),
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 16),
                label: const Text(
                  "SUSPEND",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.amber,
                  side: const BorderSide(color: AppColors.amber),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _blockPartner(targetHotelId, venueName),
                icon: const Icon(Icons.block_rounded, size: 16),
                label: const Text(
                  "BLOCK HOTEL",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rose,
                  side: const BorderSide(color: AppColors.rose),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showSuspensionWarning(targetHotelId, venueName),
                icon: const Icon(Icons.delete_forever_rounded, size: 16),
                label: const Text(
                  "TERMINATE",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _displayVerificationVaultSheet(Map<String, dynamic> venue) {
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              _buildVaultInspectionContent(venue),
            ],
          ),
        ),
      ),
    );
  }

  void _displayDetailedRoomHub(Map<String, dynamic> room) {
    final List<dynamic> imageList = room['room_images'] ?? [];
    final List<dynamic> amenities = room['amenities'] ?? [];

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.surfaceBorder),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Images Carousel / Header
                  if (imageList.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(14),
                        physics: const ClampingScrollPhysics(),
                        itemCount: imageList.length,
                        itemBuilder: (context, idx) => InkWell(
                          onTap: () => ImagePreviewDialog.show(
                            context,
                            title: "${room['room_type']} - Photo ${idx + 1}",
                            imageUrl: imageList[idx].toString(),
                          ),
                          child: Container(
                            width: 260,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.surfaceBorder),
                              image: DecorationImage(
                                image: NetworkImage(imageList[idx]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 140,
                      width: double.infinity,
                      color: AppColors.surfaceCard,
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color: AppColors.textMuted,
                        size: 36,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                room['room_type'] ?? 'Room Profile Details',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              "PKR ${room['price'] ?? '0'}",
                              style: const TextStyle(
                                color: AppColors.goldPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Divider(color: AppColors.surfaceBorder, height: 1),
                        ),
                        _buildSpecDetailText(
                          Icons.bed_rounded,
                          "Bed Configuration: ${room['bed_type'] ?? 'King Size'}",
                        ),
                        _buildSpecDetailText(
                          Icons.groups_rounded,
                          "Maximum Capacity: ${room['max_guests'] ?? 2} Persons",
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "AMENITIES REGISTERED",
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (amenities.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: amenities
                                .map(
                                  (item) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceCard,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.surfaceBorder),
                                    ),
                                    child: Text(
                                      item.toString(),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          )
                        else
                          const Text(
                            "No optional amenities listed by owner.",
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        const SizedBox(height: 18),
                        const Text(
                          "OVERVIEW & DESCRIPTION",
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          room['description'] ?? 'No room overview description provided.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.surfaceBorder),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "CLOSE INSPECTION",
                          style: TextStyle(
                            color: AppColors.goldPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecDetailText(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.goldPrimary),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticalMetricsRow(String title, String trace, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        Text(
          trace,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value, IconData icon) {
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

  Widget _buildDocumentAssetBlock(String sectionHeadline, String? assetUrl, IconData fallbackIcon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              sectionHeadline,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (assetUrl != null && assetUrl.isNotEmpty)
              TextButton.icon(
                onPressed: () => ImagePreviewDialog.show(
                  context,
                  title: sectionHeadline,
                  imageUrl: assetUrl,
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
          onTap: (assetUrl != null && assetUrl.isNotEmpty)
              ? () => ImagePreviewDialog.show(context, title: sectionHeadline, imageUrl: assetUrl)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            height: 180,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: assetUrl != null && assetUrl.isNotEmpty
                  ? Image.network(
                      assetUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.goldPrimary),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Text(
                          "Error fetching high-res document asset",
                          style: TextStyle(color: AppColors.rose, fontSize: 12),
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(fallbackIcon, color: AppColors.textMuted, size: 26),
                          const SizedBox(height: 6),
                          const Text(
                            "Asset mapping absent / skipped",
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

  void _showSuspensionWarning(String id, String name) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppColors.rose),
            const SizedBox(width: 10),
            const Text("Terminate Partner Record?"),
          ],
        ),
        content: Text(
          "Are you sure you want to permanently delete $name from the system ledger? This operation will remove their database row and cannot be undone.",
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("CANCEL", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              _terminateAndKillPartnerRecord(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              "DELETE PARTNER RECORD",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
