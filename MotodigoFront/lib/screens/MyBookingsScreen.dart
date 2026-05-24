import 'dart:async'; // Pour le Timer temps réel
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/trip_provider.dart';
import '../../utils/app_colors.dart';
import '../widgets/shimmer_widgets.dart';
import '../widgets/review_bottom_sheet.dart'; // Import du BottomSheet créé ci-dessus

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  Timer? _refreshTimer; // Met à jour le statut en tâche de fond

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Premier chargement complet (avec Shimmer)
      context.read<TripProvider>().loadUserBookings();

      // Polling fluide toutes les 5 secondes
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted) {
          context.read<TripProvider>().loadUserBookings(silent: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // Coupe le timer à la fermeture de l'écran
    super.dispose();
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
          ? _buildBookingShimmerList()
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

  Widget _buildBookingShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBlock(width: 60, height: 12),
                ShimmerBlock(width: 70, height: 18, borderRadius: BorderRadius.all(Radius.circular(20))),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: const [
                Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey),
                SizedBox(width: 6),
                ShimmerBlock(width: 120, height: 12),
              ],
            ),
            const SizedBox(height: 20),
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
    // On considère ici comme terminé si la date est passée OU si le statut côté API indique complété/terminé
    final bool isPast = departureDate.isBefore(DateTime.now()) || trip['status'] == 'completed';
    final bool isCancelled = booking['status'] == 'Cancelled';

    return Opacity(
      opacity: (isPast || isCancelled) ? 0.8 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPast ? Colors.grey[50] : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: AbsorbPointer(
          absorbing: isCancelled,
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

                  // 🔥 ACTION FLUIDE ET DYNAMIQUE DE NOTATION SI LE TRAJET EST PASSÉ / TERMINÉ
                  else if (isPast)
                      ElevatedButton.icon(
                        onPressed: () {
                          final int driverId = trip['driver_id'] ?? 0;
                          final String driverName = trip['driver_name'] ?? 'le chauffeur';

                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => ReviewBottomSheet(
                              tripId: trip['id'],
                              toUserId: driverId,
                              toUserName: driverName,
                            ),
                          );
                        },
                        icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        label: const Text("NOTER LE CHAUFFEUR", style: TextStyle(fontSize: 10, color: AppColors.primaryDark, fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.withOpacity(0.15),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
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
    bool isTerminated = status == 'TERMINÉ' || status == 'completed';
    Color color = isConfirmed ? AppColors.successGreen : (isTerminated ? AppColors.primaryDark : AppColors.errorRed);

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