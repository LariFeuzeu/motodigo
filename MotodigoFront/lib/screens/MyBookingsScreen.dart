import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/trip_provider.dart';
import '../../utils/app_colors.dart';

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
      body: tripProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookings.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) => _buildBookingTicket(bookings[index]),
      ),
    );
  }

  Widget _buildBookingTicket(dynamic booking) {
    final trip = booking['trip'];

    final departureDate = DateTime.parse(trip['departure_at'] ?? DateTime.now().toIso8601String());

    // Est-ce que le trajet est déjà passé ?
    final bool isPast = departureDate.isBefore(DateTime.now());
    // NOUVELLES CONDITIONS
    final bool isCancelled = booking['status'] == 'Cancelled'; // Si le chauffeur ou le passager a annulé

    return Opacity(
      opacity: (isPast || isCancelled) ? 0.6 : 1.0, // On grise si c'est passé
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPast ? Colors.grey[100] : Colors.white, // Fond légèrement gris
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: AbsorbPointer(
          absorbing: isPast, // Empêche de cliquer sur les boutons si c'est passé
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("MTD-${booking['id']}",
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                  _statusBadge(isCancelled ? 'ANNULÉ' : (isPast ? 'TERMINÉ': booking['status'])),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _stationInfo(trip['origin_city'], DateFormat('HH:mm').format(departureDate)),
                  const Expanded(child: Icon(Icons.arrow_forward, color: AppColors.accentBlue, size: 16)),
                  _stationInfo(trip['destination_city'], "Arrivée"),
                ],
              ),
              const Divider(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _detailItem("Places", "${booking['seats_booked']}"),
                  _detailItem("Total", "${booking['amount_total']} CFA"),

                  // On affiche le bouton ANNULER uniquement si ce n'est pas passé
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