import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/trip_provider.dart';
import '../../utils/app_colors.dart';
import '../widgets/shimmer_widgets.dart'; // Contient ton ShimmerBlock

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().loadUserBookings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context);
    final bookings = tripProvider.myBookings;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text("MES RÉSERVATIONS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryDark,
      ),
      body: tripProvider.isLoading && bookings.isEmpty
          ? _buildBookingShimmerList() // 🟢 Appel de ta nouvelle liste de ShimmerBlocks
          : bookings.isEmpty
          ? _buildEmptyState()
          : Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) => _buildBookingTicket(bookings[index]),
          ),
          if (tripProvider.isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 🟢 NOUVELLE MÉTHODE OPTIMISÉE AVEC TES SHIMMERBLOCKS
  Widget _buildBookingShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3, // Simule 3 tickets en attente
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Faux ID + Faux Statut Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBlock(width: 60, height: 12),
                ShimmerBlock(width: 70, height: 18, borderRadius: BorderRadius.all(Radius.circular(20))),
              ],
            ),
            const SizedBox(height: 18),

            // Fausse Date de calendrier
            Row(
              children: const [
                Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey),
                SizedBox(width: 6),
                ShimmerBlock(width: 120, height: 12),
              ],
            ),
            const SizedBox(height: 20),

            // Fausses Stations (Départ -> Arrivée)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBlock(width: 45, height: 16),
                    SizedBox(height: 6),
                    ShimmerBlock(width: 70, height: 12),
                  ],
                ),
                const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBlock(width: 45, height: 16),
                    SizedBox(height: 6),
                    ShimmerBlock(width: 70, height: 12),
                  ],
                ),
              ],
            ),
            const Divider(height: 40, color: Colors.transparent),

            // Faux Détails du bas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBlock(width: 40, height: 14),
                ShimmerBlock(width: 60, height: 14),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBookingTicket(dynamic booking) {
    final trip = booking['trip'];
    final departureDate = DateTime.parse(trip['departure_at'] ?? DateTime.now().toIso8601String());
    final bool isPast = departureDate.isBefore(DateTime.now());
    final bool isCancelled = booking['status'] == 'Cancelled';

    return Opacity(
      opacity: (isPast || isCancelled) ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPast ? Colors.grey[100] : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: AbsorbPointer(
          absorbing: isPast,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("MTD-${booking['id']}",
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                  _statusBadge(isCancelled ? 'ANNULÉ' : (isPast ? 'TERMINÉ' : booking['status'])),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textGrey.withOpacity(0.7)),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEEE dd MMMM', 'fr_FR').format(departureDate).toUpperCase(),
                    style: const TextStyle(color: AppColors.textGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stationInfo(trip['origin_city'] ?? 'Départ', DateFormat('HH:mm').format(departureDate)),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, color: AppColors.accentBlue, size: 16),
                    ),
                  ),
                  _stationInfo(trip['destination_city'] ?? 'Arrivée', "--:--"),
                ],
              ),
              const Divider(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _detailItem("Places", "${booking['seats_booked']}"),
                  _detailItem("Total", "${booking['amount_total']} CFA"),

                  if (!isPast && booking['status'] == 'confirmed')
                    TextButton(
                      onPressed: () => _handleCancel(booking['id'], departureDate),
                      child: const Text("ANNULER",
                          style: TextStyle(color: AppColors.errorRed, fontSize: 11, fontWeight: FontWeight.w900)),
                    )
                  else if (isCancelled)
                    const Text("ANNULÉ PAR CHAUFFEUR",
                        style: TextStyle(color: AppColors.errorRed, fontSize: 10, fontWeight: FontWeight.bold))
                  else if (isPast)
                      const Text("ARCHIVÉ",
                          style: TextStyle(color: AppColors.textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    bool isConfirmed = status == 'confirmed' || status == 'PUBLISHED';
    bool isCancelled = status == 'Cancelled' || status == 'ANNULÉ';
    Color color = isConfirmed ? AppColors.successGreen : AppColors.errorRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _stationInfo(String city, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(time, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        Text(city, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
      ],
    );
  }

  Widget _detailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 10)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  void _handleCancel(int bookingId, DateTime departureAt) async {
    final error = await context.read<TripProvider>().handlePassengerCancel(bookingId, departureAt);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.errorRed));
    }
  }

  Widget _buildEmptyState() => const Center(child: Text("Aucune réservation trouvée."));
}