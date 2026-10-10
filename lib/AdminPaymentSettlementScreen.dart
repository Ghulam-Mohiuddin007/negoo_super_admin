import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:negoo_super_admin/theme/app_theme.dart';
import 'package:negoo_super_admin/widgets/print_helper.dart';
import 'package:negoo_super_admin/widgets/realtime_badge.dart';
import 'package:negoo_super_admin/widgets/stat_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPaymentSettlementScreen extends StatefulWidget {
  const AdminPaymentSettlementScreen({super.key});

  @override
  State<AdminPaymentSettlementScreen> createState() =>
      _AdminPaymentSettlementScreenState();
}

class _AdminPaymentSettlementScreenState
    extends State<AdminPaymentSettlementScreen> {
  late final SupabaseClient _supabase;
  bool _processing = false;
  int _streamKey = 0;

  // Search & Tab state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  int _selectedTab = 0; // 0 = Pending, 1 = Received/Cleared, 2 = Partner Balances, 3 = Blocked Hotels

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

  // Action 1: Mark Commission Received
  Future<void> _markPaymentReceived(String bookingId) async {
    setState(() => _processing = true);
    try {
      await _supabase
          .from('bookings')
          .update({'status': 'payment_received'})
          .eq('id', bookingId);

      _notify("Negoo 10% commission verified and recorded as Received!", AppColors.emerald);
      setState(() {
        _streamKey++;
      });
    } catch (e) {
      _notify("Error updating payment: $e", AppColors.rose);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // Action 2: Clear & Settle Negoo Commission (Platform 10% collected)
  Future<void> _clearPayment(String bookingId, double totalAmount) async {
    setState(() => _processing = true);
    final commission = totalAmount * 0.10;

    try {
      await _supabase
          .from('bookings')
          .update({'status': 'cleared'})
          .eq('id', bookingId);

      _notify(
        "Commission Cleared! Negoo 10% cut (PKR ${NumberFormat('#,##0').format(commission)}) collected into platform treasury.",
        AppColors.emerald,
      );
      setState(() {
        _streamKey++;
      });
    } catch (e) {
      _notify("Settlement failed: $e", AppColors.rose);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // Action 3: Block Hotel Property
  Future<void> _blockHotel(String hotelId, String hotelName, {String? reason}) async {
    setState(() => _processing = true);
    try {
      await _supabase
          .from('hotels')
          .update({
            'status': 'blocked',
            'is_approved': false,
            'reg_no': reason ?? 'BLOCKED - OUTSTANDING PAYMENT DEFAULT',
          })
          .eq('id', hotelId);

      _notify("$hotelName has been BLOCKED. Live bidding and booking access revoked.", AppColors.rose);
      setState(() {
        _streamKey++;
      });
    } catch (e) {
      _notify("Failed to block hotel: $e", AppColors.rose);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // Action 4: Unblock Hotel Property
  Future<void> _unblockHotel(String hotelId, String hotelName) async {
    setState(() => _processing = true);
    try {
      await _supabase
          .from('hotels')
          .update({
            'status': 'approved',
            'is_approved': true,
          })
          .eq('id', hotelId);

      _notify("$hotelName unblocked and restored to active platform directory!", AppColors.emerald);
      setState(() {
        _streamKey++;
      });
    } catch (e) {
      _notify("Failed to unblock hotel: $e", AppColors.rose);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // Action 5: Bulk Clear All Outstanding Balance for a Hotel
  Future<void> _bulkClearHotelBalance(String hotelName, List<String> bookingIds, double totalAmount) async {
    if (bookingIds.isEmpty) return;
    setState(() => _processing = true);
    try {
      for (var id in bookingIds) {
        await _supabase
            .from('bookings')
            .update({'status': 'cleared'})
            .eq('id', id);
      }

      _notify(
        "All ${bookingIds.length} bookings for $hotelName cleared! Total settled: PKR ${NumberFormat('#,##0').format(totalAmount)}",
        AppColors.emerald,
      );
      setState(() {
        _streamKey++;
      });
    } catch (e) {
      _notify("Bulk settlement failure: $e", AppColors.rose);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showBlockDialog(String hotelId, String hotelName) {
    final TextEditingController reasonController = TextEditingController();
    String selectedReason = "Unpaid Negoo platform commission fees";
    final presets = [
      "Unpaid Negoo platform commission fees",
      "Repeated payment clearance defaults",
      "Guest reservation billing violation",
      "Regulatory compliance suspension",
      "Fraudulent transaction detection",
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.rose),
          ),
          title: Row(
            children: [
              const Icon(Icons.block_rounded, color: AppColors.rose, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Block Hotel: $hotelName",
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
                  "Blocking this venue will immediately suspend its rooms from customer searches, live bidding, and reservation checkouts.",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "SELECT SUSPENSION REASON",
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedReason,
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceElevated,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      items: presets
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedReason = val);
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
                    hintText: "Optional custom administrative notes...",
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
                final reason = reasonController.text.trim().isNotEmpty
                    ? reasonController.text.trim()
                    : selectedReason;
                Navigator.pop(ctx);
                _blockHotel(hotelId, hotelName, reason: reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("CONFIRM BLOCK", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearPaymentDialog(Map<String, dynamic> booking, String hotelName) {
    final double amount = (double.tryParse(booking['total_price']?.toString() ?? '0') ?? 0.0);
    final commission = amount * 0.10;
    final partnerCut = amount * 0.90;
    final bookingId = booking['id'].toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: AppColors.goldPrimary),
            const SizedBox(width: 10),
            Text(
              "Clear Negoo Commission (10%)",
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
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
                "Remittance clearance for $hotelName (Booking #${bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length)}):",
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  children: [
                    _buildReceiptRow("Gross Booking Value", "PKR ${NumberFormat('#,##0').format(amount)}", AppColors.textMuted),
                    const Divider(height: 16, color: AppColors.surfaceBorder),
                    _buildReceiptRow("Partner Disbursed Net (90%)", "PKR ${NumberFormat('#,##0').format(partnerCut)}", AppColors.textMuted),
                    const Divider(height: 16, color: AppColors.surfaceBorder),
                    _buildReceiptRow("Negoo Commission to Clear (10%)", "PKR ${NumberFormat('#,##0').format(commission)}", AppColors.goldPrimary),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.emerald, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "This marks only the 10% Negoo platform cut (PKR ${NumberFormat('#,##0').format(commission)}) as settled into corporate revenue.",
                      style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
                ],
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
              Navigator.pop(ctx);
              _clearPayment(bookingId, amount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("CLEAR COMMISSION (PKR ${NumberFormat('#,##0').format(commission)})", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Authentic Digital Rubber Stamp Component
  Widget _buildOfficialInvoiceStamp({
    required bool isPaid,
    String? timestamp,
  }) {
    final Color stampColor = isPaid ? AppColors.emerald : AppColors.rose;
    final String mainTitle = isPaid ? "PAID & CLEARED" : "UNPAID • PAYMENT DUE";
    final String subTitle1 = isPaid ? "★ NEGOO PLATFORM REVENUE ★" : "⚠ NEGOO FINANCE ACCOUNTS ⚠";
    final String subTitle2 = isPaid
        ? "CLEARED: ${(timestamp ?? DateFormat('dd MMM yyyy').format(DateTime.now())).toUpperCase()}"
        : "10% PLATFORM COMMISSION OUTSTANDING";
    final IconData stampIcon = isPaid ? Icons.verified_rounded : Icons.warning_amber_rounded;

    return Transform.rotate(
      angle: -0.10, // ~ -5.7 degrees authentic angled tilt
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: stampColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: stampColor.withValues(alpha: 0.9),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: stampColor.withValues(alpha: 0.18),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: stampColor.withValues(alpha: 0.45),
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(stampIcon, color: stampColor, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    mainTitle,
                    style: GoogleFonts.cinzel(
                      color: stampColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subTitle1,
                style: GoogleFonts.plusJakartaSans(
                  color: stampColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subTitle2,
                style: GoogleFonts.jetBrainsMono(
                  color: stampColor.withValues(alpha: 0.95),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Invoice Dialog for Individual Booking
  void _showInvoiceDialog({
    required Map<String, dynamic> booking,
    required Map<String, dynamic>? hotel,
    required bool isPaid,
  }) {
    final bookingId = booking['id'].toString();
    final hotelName = hotel?['hotel_name'] ?? hotel?['name'] ?? 'Partner Venue';
    final regNo = hotel?['reg_no'] ?? 'REG-REGISTERED';
    final phone = hotel?['phone_number'] ?? 'N/A';
    final guestName = booking['full_name'] ?? 'Registered Guest';
    final double grossAmount = (double.tryParse(booking['total_price']?.toString() ?? '0') ?? 0.0);
    final double commission = grossAmount * 0.10;
    final double partnerNet = grossAmount * 0.90;
    final String shortId = bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length).toUpperCase();
    final String invoiceNo = "INV-NEG-2026-$shortId";
    final String issueDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final String invoiceText = """
======================================================
NEGOO HOSPITALITY PLATFORM - OFFICIAL COMMISSION INVOICE
======================================================
Invoice Number: $invoiceNo
Date of Issuance: $issueDate
Status: ${isPaid ? 'PAID & CLEARED' : 'UNPAID - PAYMENT DUE'}

BILLED TO (PARTNER VENUE):
Hotel Name: $hotelName
Registration / License: $regNo
Contact Number: $phone
Reservation Ref: #$shortId
Guest: $guestName

COMMISSION COMPUTATION (10% PLATFORM RATE):
Gross Booking Volume: PKR ${NumberFormat('#,##0').format(grossAmount)}
Partner Disbursed Net (90%): PKR ${NumberFormat('#,##0').format(partnerNet)}
------------------------------------------------------
TOTAL NEGOO COMMISSION: PKR ${NumberFormat('#,##0').format(commission)}
------------------------------------------------------

REMITTANCE INSTRUCTIONS (IF UNPAID):
Bank: Meezan Bank Ltd
Account Title: Negoo Technologies (Pvt) Ltd
IBAN: PK36MEZN0001892830192801
Reference: $invoiceNo
======================================================
""";

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.surfaceBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Top Navigation Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: AppColors.goldPrimary, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          "Commission Invoice Preview",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Scrollable Invoice Document Paper
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090C12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Corporate Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.shield_rounded, color: AppColors.goldPrimary, size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      "NEGOO",
                                      style: GoogleFonts.cinzel(
                                        color: AppColors.goldPrimary,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Hospitality Technologies Ltd. • Platform Directorate",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  "NTN: 9482103-7 • SECP-NEG-2026 • Islamabad, PK",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textMuted,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),

                            // Dynamic Stamp!
                            _buildOfficialInvoiceStamp(isPaid: isPaid),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Divider(color: AppColors.surfaceBorder, height: 1),
                        ),

                        // Metadata Grid
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "BILLED TO (PARTNER):",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.goldPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    hotelName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "License / Reg: $regNo",
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                  Text(
                                    "Contact: $phone",
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "INVOICE METADATA:",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.goldPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  invoiceNo,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  "Date: $issueDate",
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                                Text(
                                  "Term: 10% Platform Cut on Booking",
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Itemized Table Container
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceCard,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      flex: 5,
                                      child: Text(
                                        "SERVICE / RESERVATION",
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      flex: 3,
                                      child: Text(
                                        "GROSS (PKR)",
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        "NEGOO 10% CUT",
                                        style: TextStyle(
                                          color: AppColors.goldPrimary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Platform Brokerage & Match Commission",
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            "Booking #$shortId • Guest: $guestName",
                                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        NumberFormat('#,##0').format(grossAmount),
                                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        "PKR ${NumberFormat('#,##0').format(commission)}",
                                        style: const TextStyle(
                                          color: AppColors.goldPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Totals Summary Box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? AppColors.emerald.withValues(alpha: 0.06)
                                : AppColors.amber.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (isPaid ? AppColors.emerald : AppColors.amber).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildReceiptRow(
                                "Gross Reservation Value",
                                "PKR ${NumberFormat('#,##0').format(grossAmount)}",
                                AppColors.textMuted,
                              ),
                              const SizedBox(height: 6),
                              _buildReceiptRow(
                                "Partner Retained Share (90%)",
                                "PKR ${NumberFormat('#,##0').format(partnerNet)}",
                                AppColors.textMuted,
                              ),
                              const Divider(height: 16, color: AppColors.surfaceBorder),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "TOTAL NEGOO COMMISSION (10%)",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: isPaid ? AppColors.emerald : AppColors.goldPrimary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      Text(
                                        isPaid ? "Paid & Cleared into Treasury" : "Unpaid • Payment Due from Hotel",
                                        style: TextStyle(
                                          color: isPaid ? AppColors.emerald : AppColors.rose,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "PKR ${NumberFormat('#,##0').format(commission)}",
                                    style: GoogleFonts.jetBrainsMono(
                                      color: isPaid ? AppColors.emerald : AppColors.goldPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Banking / Remittance Note
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_rounded, color: AppColors.goldPrimary, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Remittance Protocol: Meezan Bank Ltd • Title: Negoo Hospitality Technologies Ltd • IBAN: PK36MEZN0001892830192801 • Quote Ref: $invoiceNo",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
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
              ),

              // Action Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: invoiceText));
                            _notify("Invoice data copied to clipboard!", AppColors.goldPrimary);
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text("COPY TEXT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.surfaceBorder),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => triggerPrint(),
                          icon: const Icon(Icons.print_rounded, size: 14),
                          label: const Text("PRINT / PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.goldPrimary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (!isPaid)
                          ElevatedButton.icon(
                            onPressed: _processing
                                ? null
                                : () {
                                    Navigator.pop(ctx);
                                    _clearPayment(bookingId, grossAmount);
                                  },
                            icon: const Icon(Icons.check_circle_rounded, size: 14),
                            label: const Text("MARK COMMISSION PAID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("CLOSE", style: TextStyle(color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Master Consolidated Statement Invoice for Hotel
  void _showHotelStatementInvoiceDialog({
    required Map<String, dynamic> hotel,
    required List<Map<String, dynamic>> bookings,
    required double unsettledCommission,
    required double clearedCommission,
    required double totalGross,
  }) {
    final hotelId = hotel['id']?.toString() ?? 'N/A';
    final hotelName = hotel['hotel_name'] ?? hotel['name'] ?? 'Partner Venue';
    final regNo = hotel['reg_no'] ?? 'REG-REGISTERED';
    final phone = hotel['phone_number'] ?? 'N/A';
    final bool isPaid = unsettledCommission <= 0.01 && bookings.isNotEmpty;
    final String shortId = hotelId.substring(0, hotelId.length > 6 ? 6 : hotelId.length).toUpperCase();
    final String invoiceNo = "STMT-NEG-$shortId-${DateFormat('yyMMdd').format(DateTime.now())}";
    final String issueDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final double totalCommission = totalGross * 0.10;
    final double totalPartnerNet = totalGross * 0.90;

    final List<String> unsettledIds = bookings
        .where((b) {
          final s = (b['status'] ?? '').toString().toLowerCase().trim();
          return s != 'cleared' && s != 'settled_archived';
        })
        .map((b) => b['id'].toString())
        .toList();

    final StringBuffer buffer = StringBuffer();
    buffer.writeln("======================================================");
    buffer.writeln("NEGOO HOSPITALITY PLATFORM - HOTEL MASTER COMMISSION STATEMENT");
    buffer.writeln("======================================================");
    buffer.writeln("Statement Ref: $invoiceNo");
    buffer.writeln("Date of Issuance: $issueDate");
    buffer.writeln("Status: ${isPaid ? 'PAID & CLEARED' : 'UNPAID - COMMISSION OUTSTANDING'}");
    buffer.writeln("");
    buffer.writeln("BILLED TO PARTNER VENUE:");
    buffer.writeln("Hotel: $hotelName");
    buffer.writeln("License / Reg: $regNo");
    buffer.writeln("Contact: $phone");
    buffer.writeln("Venue ID: $hotelId");
    buffer.writeln("");
    buffer.writeln("COMMISSION ACCOUNTING (10% RATE):");
    buffer.writeln("Gross Reservations Total: PKR ${NumberFormat('#,##0').format(totalGross)}");
    buffer.writeln("Partner Retained Share (90%): PKR ${NumberFormat('#,##0').format(totalPartnerNet)}");
    buffer.writeln("Cumulative 10% Commission: PKR ${NumberFormat('#,##0').format(totalCommission)}");
    buffer.writeln("Cleared Commission: PKR ${NumberFormat('#,##0').format(clearedCommission)}");
    buffer.writeln("OUTSTANDING NEGOO COMMISSION DUE: PKR ${NumberFormat('#,##0').format(unsettledCommission)}");
    buffer.writeln("======================================================");
    final String statementText = buffer.toString();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.surfaceBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Top Navigation Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: AppColors.goldPrimary, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          "Hotel Commission Statement",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Scrollable Statement Document Paper
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090C12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Corporate Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.shield_rounded, color: AppColors.goldPrimary, size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      "NEGOO",
                                      style: GoogleFonts.cinzel(
                                        color: AppColors.goldPrimary,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Hospitality Technologies Ltd. • Partner Settlements Hub",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  "NTN: 9482103-7 • SECP-NEG-2026 • Islamabad, PK",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textMuted,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),

                            // Dynamic Stamp!
                            _buildOfficialInvoiceStamp(isPaid: isPaid),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Divider(color: AppColors.surfaceBorder, height: 1),
                        ),

                        // Metadata Grid
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "PARTNER VENUE LEDGER:",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.goldPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    hotelName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "License / Reg: $regNo",
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                  Text(
                                    "Contact: $phone",
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "STATEMENT IDENTIFIER:",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.goldPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  invoiceNo,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  "Generated: $issueDate",
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                                Text(
                                  "${bookings.length} Total Bookings Included",
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Itemized Bookings Table Container
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceCard,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        "RESERVATION / GUEST",
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        "GROSS (PKR)",
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        "NEGOO 10% CUT",
                                        style: TextStyle(
                                          color: AppColors.goldPrimary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (bookings.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                    child: Text(
                                      "No bookings recorded for this partner node yet.",
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                    ),
                                  ),
                                )
                              else
                                ...bookings.map((b) {
                                  final bId = b['id'].toString();
                                  final shortBId = bId.substring(0, bId.length > 8 ? 8 : bId.length).toUpperCase();
                                  final double price = (double.tryParse(b['total_price']?.toString() ?? '0') ?? 0.0);
                                  final double comm = price * 0.10;
                                  final bStatus = (b['status'] ?? 'pending').toString().toLowerCase().trim();
                                  final bool bCleared = bStatus == 'cleared' || bStatus == 'settled_archived';

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: const BoxDecoration(
                                      border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "#$shortBId • ${b['full_name'] ?? 'Guest'}",
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                bCleared ? "STATUS: CLEARED" : "STATUS: UNSETTLED",
                                                style: TextStyle(
                                                  color: bCleared ? AppColors.emerald : AppColors.amber,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            NumberFormat('#,##0').format(price),
                                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            "PKR ${NumberFormat('#,##0').format(comm)}",
                                            style: TextStyle(
                                              color: bCleared ? AppColors.emerald : AppColors.goldPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Totals Summary Box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? AppColors.emerald.withValues(alpha: 0.06)
                                : AppColors.amber.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (isPaid ? AppColors.emerald : AppColors.amber).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildReceiptRow(
                                "Total Gross Reservation Volume",
                                "PKR ${NumberFormat('#,##0').format(totalGross)}",
                                AppColors.textMuted,
                              ),
                              const SizedBox(height: 6),
                              _buildReceiptRow(
                                "Partner Retained Share (90%)",
                                "PKR ${NumberFormat('#,##0').format(totalPartnerNet)}",
                                AppColors.textMuted,
                              ),
                              const SizedBox(height: 6),
                              _buildReceiptRow(
                                "Cleared Commission (Collected)",
                                "PKR ${NumberFormat('#,##0').format(clearedCommission)}",
                                AppColors.emerald,
                              ),
                              const Divider(height: 16, color: AppColors.surfaceBorder),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "OUTSTANDING NEGOO COMMISSION DUE",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: isPaid ? AppColors.emerald : AppColors.rose,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      Text(
                                        isPaid ? "All Commissions Settled • Zero Due" : "Payment Due from Hotel Partner",
                                        style: TextStyle(
                                          color: isPaid ? AppColors.emerald : AppColors.rose,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "PKR ${NumberFormat('#,##0').format(unsettledCommission)}",
                                    style: GoogleFonts.jetBrainsMono(
                                      color: isPaid ? AppColors.emerald : AppColors.rose,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Banking Remittance Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_rounded, color: AppColors.goldPrimary, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Remittance Protocol: Meezan Bank Ltd • Title: Negoo Hospitality Technologies Ltd • IBAN: PK36MEZN0001892830192801 • Quote Ref: $invoiceNo",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
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
              ),

              // Action Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: statementText));
                            _notify("Statement details copied to clipboard!", AppColors.goldPrimary);
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text("COPY STATEMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.surfaceBorder),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => triggerPrint(),
                          icon: const Icon(Icons.print_rounded, size: 14),
                          label: const Text("PRINT / PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.goldPrimary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (!isPaid && unsettledIds.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: _processing
                                ? null
                                : () {
                                    Navigator.pop(ctx);
                                    _bulkClearHotelBalance(hotelName, unsettledIds, unsettledCommission);
                                  },
                            icon: const Icon(Icons.done_all_rounded, size: 14),
                            label: Text(
                              "COLLECT ALL COMMISSION (PKR ${NumberFormat('#,##0').format(unsettledCommission)})",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("CLOSE", style: TextStyle(color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
                  "FINANCIAL SETTLEMENT HUB",
                  style: GoogleFonts.cinzel(
                    color: AppColors.goldPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  "REALTIME COMMISSION & PAYOUT CLEARANCE TERMINAL",
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
              label: "FINANCE STREAM LIVE",
              onRefresh: _handleManualRefresh,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.goldPrimary),
            tooltip: "Force Stream Resync",
            onPressed: _handleManualRefresh,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        key: ValueKey('hotels_finance_$_streamKey'),
        stream: _supabase.from('hotels').stream(primaryKey: ['id']),
        builder: (context, hotelSnapshot) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            key: ValueKey('rooms_finance_$_streamKey'),
            stream: _supabase.from('rooms').stream(primaryKey: ['id']),
            builder: (context, roomSnapshot) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                key: ValueKey('bookings_finance_$_streamKey'),
                stream: _supabase.from('bookings').stream(primaryKey: ['id']),
                builder: (context, bookingSnapshot) {
                  if (hotelSnapshot.connectionState == ConnectionState.waiting &&
                      !hotelSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.goldPrimary),
                    );
                  }

                  final hotelsData = hotelSnapshot.data ?? [];
                  final roomsData = roomSnapshot.data ?? [];
                  final bookingsData = bookingSnapshot.data ?? [];

                  // Map room_id to hotel
                  final Map<String, Map<String, dynamic>> roomToHotelMap = {};
                  final Map<String, Map<String, dynamic>> hotelMap = {};

                  for (var h in hotelsData) {
                    hotelMap[h['id'].toString()] = h;
                  }

                  for (var r in roomsData) {
                    final hId = r['hotel_id']?.toString();
                    if (hId != null && hotelMap.containsKey(hId)) {
                      roomToHotelMap[r['id'].toString()] = hotelMap[hId]!;
                    }
                  }

                  // Compute Financial Ledger Metrics
                  double grossTotal = 0.0;
                  double unsettledGross = 0.0;
                  double clearedGross = 0.0;
                  int blockedHotelsCount = 0;

                  for (var h in hotelsData) {
                    final status = (h['status'] ?? '').toString().toLowerCase().trim();
                    if (status == 'blocked') blockedHotelsCount++;
                  }

                  final List<Map<String, dynamic>> pendingBookings = [];
                  final List<Map<String, dynamic>> clearedBookings = [];

                  for (var b in bookingsData) {
                    final double price = (double.tryParse(b['total_price']?.toString() ?? '0') ?? 0.0);
                    final status = (b['status'] ?? 'pending').toString().toLowerCase().trim();

                    grossTotal += price;

                    if (status == 'cleared' || status == 'settled_archived') {
                      clearedGross += price;
                      clearedBookings.add(b);
                    } else {
                      unsettledGross += price;
                      pendingBookings.add(b);
                    }
                  }

                  final double platformCommissionTotal = grossTotal * 0.10;
                  final double unsettledCommissionTotal = unsettledGross * 0.10;
                  final double clearedCommissionTotal = clearedGross * 0.10;

                  // Group balances by Hotel (Only active/approved partners)
                  final Map<String, Map<String, dynamic>> hotelLedgers = {};
                  for (var h in hotelsData) {
                    final status = (h['status'] ?? '').toString().toLowerCase().trim();
                    final bool isApproved = status == 'approved' && h['is_approved'] == true;
                    if (!isApproved) continue; // Exclude non-active / rejected hotels

                    final hId = h['id'].toString();
                    hotelLedgers[hId] = {
                      'hotel': h,
                      'bookings': <Map<String, dynamic>>[],
                      'totalGross': 0.0,
                      'clearedGross': 0.0,
                      'unsettledGross': 0.0,
                      'totalCommission': 0.0,
                      'clearedCommission': 0.0,
                      'unsettledCommission': 0.0,
                    };
                  }

                  for (var b in bookingsData) {
                    final roomId = b['room_id']?.toString();
                    final hotel = roomToHotelMap[roomId];
                    if (hotel != null) {
                      final hId = hotel['id'].toString();
                      if (hotelLedgers.containsKey(hId)) {
                        final price = (double.tryParse(b['total_price']?.toString() ?? '0') ?? 0.0);
                        final comm = price * 0.10;
                        final status = (b['status'] ?? 'pending').toString().toLowerCase().trim();
                        final list = hotelLedgers[hId]!['bookings'] as List<Map<String, dynamic>>;
                        list.add(b);

                        hotelLedgers[hId]!['totalGross'] = (hotelLedgers[hId]!['totalGross'] as double) + price;
                        hotelLedgers[hId]!['totalCommission'] = (hotelLedgers[hId]!['totalCommission'] as double) + comm;
                        if (status == 'cleared' || status == 'settled_archived') {
                          hotelLedgers[hId]!['clearedGross'] = (hotelLedgers[hId]!['clearedGross'] as double) + price;
                          hotelLedgers[hId]!['clearedCommission'] = (hotelLedgers[hId]!['clearedCommission'] as double) + comm;
                        } else {
                          hotelLedgers[hId]!['unsettledGross'] = (hotelLedgers[hId]!['unsettledGross'] as double) + price;
                          hotelLedgers[hId]!['unsettledCommission'] = (hotelLedgers[hId]!['unsettledCommission'] as double) + comm;
                        }
                      }
                    }
                  }

                  final blockedHotelsList = hotelsData.where((h) {
                    final status = (h['status'] ?? '').toString().toLowerCase().trim();
                    return status == 'blocked';
                  }).toList();

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isDesktop = constraints.maxWidth > 950;
                      final bool isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 950;
                      final int statCount = isDesktop ? 4 : (isTablet ? 2 : 1);

                      return RefreshIndicator(
                        color: AppColors.goldPrimary,
                        backgroundColor: AppColors.surface,
                        onRefresh: _handleManualRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 36 : 18,
                            vertical: 24,
                          ),
                          child: Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 1300),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Stats Grid
                                  GridView.count(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    crossAxisCount: statCount,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: isDesktop ? 1.5 : (isTablet ? 1.6 : 2.0),
                                    children: [
                                      StatCard(
                                        label: "Unsettled Negoo Cut (10%)",
                                        value: currencyFormat.format(unsettledCommissionTotal),
                                        icon: Icons.pending_actions_rounded,
                                        accentColor: AppColors.amber,
                                        subtitle: "${pendingBookings.length} bookings • Gross: ${currencyFormat.format(unsettledGross)}",
                                        badgeText: "OUTSTANDING",
                                      ),
                                      StatCard(
                                        label: "Collected Negoo Cut (10%)",
                                        value: currencyFormat.format(clearedCommissionTotal),
                                        icon: Icons.verified_rounded,
                                        accentColor: AppColors.emerald,
                                        subtitle: "${clearedBookings.length} cleared • Gross: ${currencyFormat.format(clearedGross)}",
                                        badgeText: "COLLECTED",
                                      ),
                                      StatCard(
                                        label: "Cumulative 10% Platform Cut",
                                        value: currencyFormat.format(platformCommissionTotal),
                                        icon: Icons.account_balance_wallet_rounded,
                                        accentColor: AppColors.goldPrimary,
                                        subtitle: "Cumulative share • Gross: ${currencyFormat.format(grossTotal)}",
                                        badgeText: "NEGOO SHARE",
                                      ),
                                      StatCard(
                                        label: "Blocked Hotel Properties",
                                        value: "$blockedHotelsCount",
                                        icon: Icons.block_rounded,
                                        accentColor: blockedHotelsCount > 0 ? AppColors.rose : AppColors.textMuted,
                                        subtitle: blockedHotelsCount > 0 ? "Suspended for commission default" : "Zero active suspensions",
                                        badgeText: blockedHotelsCount > 0 ? "FROZEN" : "CLEAR",
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 28),

                                  // Filter Navigation Tabs
                                  Row(
                                    children: [
                                      _buildTabChip(
                                        index: 0,
                                        label: "Pending Settlements",
                                        count: pendingBookings.length,
                                        color: AppColors.amber,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildTabChip(
                                        index: 1,
                                        label: "Cleared & Paid",
                                        count: clearedBookings.length,
                                        color: AppColors.emerald,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildTabChip(
                                        index: 2,
                                        label: "Partner Balances",
                                        count: hotelLedgers.length,
                                        color: AppColors.goldPrimary,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildTabChip(
                                        index: 3,
                                        label: "Blocked Hotels",
                                        count: blockedHotelsCount,
                                        color: AppColors.rose,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 18),

                                  // Search Bar
                                  TextField(
                                    controller: _searchController,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: "Search records by booking ID, hotel name, guest name, phone...",
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
                                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
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

                                  const SizedBox(height: 24),

                                  // Tab View Content
                                  if (_selectedTab == 0)
                                    _buildBookingsQueue(
                                      bookings: pendingBookings,
                                      roomToHotelMap: roomToHotelMap,
                                      isPending: true,
                                    )
                                  else if (_selectedTab == 1)
                                    _buildBookingsQueue(
                                      bookings: clearedBookings,
                                      roomToHotelMap: roomToHotelMap,
                                      isPending: false,
                                    )
                                  else if (_selectedTab == 2)
                                    _buildPartnerLedgersView(
                                      hotelLedgers: hotelLedgers,
                                    )
                                  else
                                    _buildBlockedHotelsView(
                                      blockedHotels: blockedHotelsList,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTabChip({
    required int index,
    required String label,
    required int count,
    required Color color,
  }) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() {
            _selectedTab = index;
          }),
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

  Widget _buildBookingsQueue({
    required List<Map<String, dynamic>> bookings,
    required Map<String, Map<String, dynamic>> roomToHotelMap,
    required bool isPending,
  }) {
    // Filter by search query
    final filtered = bookings.where((b) {
      if (_searchQuery.isEmpty) return true;
      final id = b['id'].toString().toLowerCase();
      final name = (b['full_name'] ?? '').toString().toLowerCase();
      final phone = (b['phone'] ?? '').toString().toLowerCase();
      final roomId = b['room_id']?.toString() ?? '';
      final hotelName = (roomToHotelMap[roomId]?['hotel_name'] ?? '').toString().toLowerCase();
      return id.contains(_searchQuery) ||
          name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          hotelName.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                isPending ? Icons.check_circle_outline_rounded : Icons.inbox_rounded,
                size: 44,
                color: isPending ? AppColors.emerald : AppColors.textMuted,
              ),
              const SizedBox(height: 14),
              Text(
                isPending
                    ? "All settlements are currently clear!"
                    : "No cleared booking records found.",
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                isPending
                    ? "New transactions will stream into this terminal in real time."
                    : "Cleared transactions will archive here once settled.",
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final b = filtered[index];
        final bookingId = b['id'].toString();
        final roomId = b['room_id']?.toString();
        final hotel = roomToHotelMap[roomId];
        final hotelName = hotel?['hotel_name'] ?? hotel?['name'] ?? 'Hotel Venue';
        final double amount = (double.tryParse(b['total_price']?.toString() ?? '0') ?? 0.0);
        final status = (b['status'] ?? 'pending').toString().toLowerCase().trim();
        final bool isReceived = status == 'payment_received';
        final bool isCleared = status == 'cleared';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCleared
                      ? AppColors.emerald.withValues(alpha: 0.12)
                      : (isReceived ? AppColors.goldPrimary.withValues(alpha: 0.12) : AppColors.amber.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCleared
                      ? Icons.verified_rounded
                      : (isReceived ? Icons.payments_rounded : Icons.pending_rounded),
                  color: isCleared
                      ? AppColors.emerald
                      : (isReceived ? AppColors.goldPrimary : AppColors.amber),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          hotelName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCleared
                                ? AppColors.emerald.withValues(alpha: 0.1)
                                : (isReceived ? AppColors.goldPrimary.withValues(alpha: 0.1) : AppColors.amber.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: isCleared
                                  ? AppColors.emerald
                                  : (isReceived ? AppColors.goldPrimary : AppColors.amber),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Guest: ${b['full_name'] ?? 'Guest'} • Ref: #${bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length)} • Method: ${(b['payment_method'] ?? 'Online').toString().toUpperCase()}",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "PKR ${NumberFormat('#,##0').format(amount * 0.10)}",
                    style: const TextStyle(
                      color: AppColors.goldPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "Negoo 10% Cut (Gross: PKR ${NumberFormat('#,##0').format(amount)})",
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              OutlinedButton.icon(
                onPressed: () => _showInvoiceDialog(
                  booking: b,
                  hotel: hotel,
                  isPaid: isCleared,
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 14),
                label: const Text("INVOICE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isCleared ? AppColors.emerald : AppColors.amber,
                  side: BorderSide(
                    color: (isCleared ? AppColors.emerald : AppColors.amber).withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              if (isPending) ...[
                if (!isReceived)
                  OutlinedButton.icon(
                    onPressed: _processing ? null : () => _markPaymentReceived(bookingId),
                    icon: const Icon(Icons.check_rounded, size: 14),
                    label: const Text("COMMISSION RECEIVED", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.goldPrimary,
                      side: const BorderSide(color: AppColors.goldPrimary),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _processing ? null : () => _showClearPaymentDialog(b, hotelName),
                  icon: const Icon(Icons.done_all_rounded, size: 14),
                  label: const Text("CLEAR COMMISSION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 14),
                      SizedBox(width: 4),
                      Text("COMMISSION CLEARED", style: TextStyle(color: AppColors.emerald, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartnerLedgersView({
    required Map<String, Map<String, dynamic>> hotelLedgers,
  }) {
    final list = hotelLedgers.values.toList();
    final filtered = list.where((entry) {
      if (_searchQuery.isEmpty) return true;
      final h = entry['hotel'] as Map<String, dynamic>;
      final name = (h['hotel_name'] ?? h['name'] ?? '').toString().toLowerCase();
      final phone = (h['phone_number'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || phone.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.domain_disabled_rounded, size: 44, color: AppColors.textMuted),
              SizedBox(height: 14),
              Text(
                "No Active Commercial Partners",
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text(
                "Authorized hotel partner properties will appear here once approved in the Validation Queue.",
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        final hotel = entry['hotel'] as Map<String, dynamic>;
        final hotelId = hotel['id'].toString();
        final hotelName = hotel['hotel_name'] ?? hotel['name'] ?? 'Hotel Venue';
        final status = (hotel['status'] ?? 'pending').toString().toLowerCase().trim();
        final bool isApproved = status == 'approved' && hotel['is_approved'] == true;
        final bool isBlocked = status == 'blocked';
        final bool isRejected = status == 'rejected';

        final String badgeLabel = isBlocked
            ? "BLOCKED PROPERTY"
            : (isRejected
                ? "REJECTED PROPERTY"
                : (isApproved ? "ACTIVE PARTNER" : "PENDING AUDIT"));
        final Color badgeColor = isBlocked
            ? AppColors.rose
            : (isRejected
                ? AppColors.rose
                : (isApproved ? AppColors.emerald : AppColors.amber));

        final double unsettledComm = entry['unsettledCommission'] as double;
        final double clearedComm = entry['clearedCommission'] as double;
        final double totalGross = entry['totalGross'] as double;
        final bookings = entry['bookings'] as List<Map<String, dynamic>>;
        final List<String> unsettledIds = bookings
            .where((b) {
              final s = (b['status'] ?? '').toString().toLowerCase().trim();
              return s != 'cleared' && s != 'settled_archived';
            })
            .map((b) => b['id'].toString())
            .toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isBlocked ? AppColors.rose.withValues(alpha: 0.5) : AppColors.surfaceBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.surface,
                        child: Icon(
                          Icons.domain_rounded,
                          color: isBlocked ? AppColors.rose : AppColors.goldPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hotelName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "Contact: ${hotel['phone_number'] ?? 'N/A'} • Reg: ${hotel['reg_no'] ?? 'N/A'}",
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.surfaceBorder),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat("Unsettled 10% Fee", "PKR ${NumberFormat('#,##0').format(unsettledComm)}", AppColors.amber),
                  _buildMiniStat("Cleared 10% Fee", "PKR ${NumberFormat('#,##0').format(clearedComm)}", AppColors.emerald),
                  _buildMiniStat("Gross Volume", "PKR ${NumberFormat('#,##0').format(totalGross)}", AppColors.cyan),
                  _buildMiniStat("Reservations", "${bookings.length} Bookings", AppColors.textPrimary),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showHotelStatementInvoiceDialog(
                      hotel: hotel,
                      bookings: bookings,
                      unsettledCommission: unsettledComm,
                      clearedCommission: clearedComm,
                      totalGross: totalGross,
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text("HOTEL INVOICE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.goldPrimary,
                      side: const BorderSide(color: AppColors.goldPrimary),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isBlocked)
                    OutlinedButton.icon(
                      onPressed: () => _showBlockDialog(hotelId, hotelName),
                      icon: const Icon(Icons.block_rounded, size: 16),
                      label: const Text("BLOCK HOTEL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rose,
                        side: const BorderSide(color: AppColors.rose),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => _unblockHotel(hotelId, hotelName),
                      icon: const Icon(Icons.lock_open_rounded, size: 16),
                      label: const Text("UNBLOCK HOTEL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (unsettledComm > 0)
                    ElevatedButton.icon(
                      onPressed: _processing
                          ? null
                          : () => _bulkClearHotelBalance(hotelName, unsettledIds, unsettledComm),
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: Text(
                        "COLLECT COMMISSION (PKR ${NumberFormat('#,##0').format(unsettledComm)})",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlockedHotelsView({
    required List<Map<String, dynamic>> blockedHotels,
  }) {
    if (blockedHotels.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.shield_rounded, size: 44, color: AppColors.emerald),
              SizedBox(height: 14),
              Text(
                "Zero Blocked Properties",
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text(
                "All partner venues are in good standing with clear operational access.",
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: blockedHotels.length,
      itemBuilder: (context, index) {
        final h = blockedHotels[index];
        final hotelId = h['id'].toString();
        final hotelName = h['hotel_name'] ?? h['name'] ?? 'Blocked Hotel';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.block_rounded, color: AppColors.rose, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotelName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Suspension Reason: ${h['reg_no'] ?? 'Defaulted payment commission / Administrative block'}",
                      style: const TextStyle(color: AppColors.roseLight, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Phone: ${h['phone_number'] ?? 'N/A'} • Hotel ID: $hotelId",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _processing ? null : () => _unblockHotel(hotelId, hotelName),
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: const Text("UNBLOCK & RESTORE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String title, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildReceiptRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
