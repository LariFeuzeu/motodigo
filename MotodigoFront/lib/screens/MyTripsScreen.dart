import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/trip_provider.dart';
import '../../utils/app_colors.dart';
import '../screens/ChatScreenState.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  @override
  void initState() {
    super.initState();
    // Charger les trajets du chauffeur au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().fetchDriverTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context);
    final trips = tripProvider.driverTrips;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text("MES TRAJETS PUBLIÉS",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.primaryDark,
      ),
      body: tripProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
          : trips.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        itemBuilder: (context, index) => _buildTripCard(trips[index]),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    // Traduction des statuts pour l'UI
    final String status = (trip['status'] ?? 'published').toString().toLowerCase();
    final bool isCancelled = status == 'cancelled';
    final bool isFull = status == 'full' || (trip['seats_available'] ?? 0) == 0;

    // Logique de remplissage
    final int totalSeats = trip['total_seats'] ?? 1;
    final int availableSeats = trip['seats_available'] ?? totalSeats;
    final int occupiedSeats = totalSeats - availableSeats;
    double fillPercent = occupiedSeats / totalSeats;

    return Opacity(
      opacity: isCancelled ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isCancelled ? Colors.grey[50] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('EEE dd MMM • HH:mm').format(DateTime.parse(trip['departure_at'])),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey, fontSize: 12)),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildRouteRow(Icons.radio_button_checked, AppColors.accentBlue, trip['origin_city']),
                  _buildRouteDivider(),
                  _buildRouteRow(Icons.location_on_rounded, AppColors.errorRed, trip['destination_city']),

                  const Divider(height: 30),

                  // --- INDICATEUR DE REMPLISSAGE DYNAMIQUE ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isCancelled ? "ANNULÉ" : "Remplissage : $occupiedSeats/$totalSeats places",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13,
                            color: isFull ? AppColors.successGreen : Colors.black),
                      ),
                      Text("${(fillPercent * 100).toInt()}%",
                          style: TextStyle(color: isFull ? AppColors.successGreen : AppColors.accentBlue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: fillPercent,
                    backgroundColor: AppColors.lightBackground,
                    color: isFull ? AppColors.successGreen : AppColors.accentBlue,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _buildActionButtons(trip, isCancelled),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> trip, bool isCancelled) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showPassengerList(trip['id']),
              icon: const Icon(Icons.people_alt_outlined, size: 16, color: Colors.white),
              label: const Text("PASSAGERS", style: TextStyle(fontSize: 11, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
            ),
          ),
          if (!isCancelled) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => _showCancelDialog(trip['id']),
              child: const Text("ANNULER", style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w900, fontSize: 11)),
            ),
          ]
        ],
      ),
    );
  }
  void _showPassengerList(int tripId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("PASSAGERS DU TRAJET", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                // On appelle le provider pour récupérer les passagers de ce trajet
                future: context.read<TripProvider>().getTripPassengers(tripId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("Aucun passager pour le moment"));
                  }

                  final passengers = snapshot.data!;
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: passengers.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final p = passengers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accentBlue.withOpacity(0.1),
                          child: Text(p['full_name'][0], style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(p['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${p['seats_booked']} place(s) réservée(s)"),
                        trailing: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, color: AppColors.accentBlue),
                          onPressed: () {
                            // On peut ouvrir le chat directement ici !
                            _goToChat(tripId, p['user_id'], p['full_name']);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Petit helper pour naviguer vers le chat depuis la liste
  void _goToChat(int tripId, int receiverId, String name) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
      tripId: tripId,
      receiverId: receiverId,
      receiverName: name,
    )));
  }
  // Widgets Helper (Route, Divider, Status)
  Widget _buildRouteRow(IconData icon, Color color, String city) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 12),
      Text(city, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
    ]);
  }

  Widget _buildRouteDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 7, top: 2, bottom: 2),
      height: 15, width: 1.5, color: Colors.grey.shade200,
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status == 'published' ? AppColors.successGreen : AppColors.errorRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus_filled_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("Aucun trajet publié", style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  void _showCancelDialog(int tripId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Annuler le trajet ?"),
        content: const Text("Cette action annulera aussi toutes les réservations liées."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("NON")),
          TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await context.read<TripProvider>().handleDriverCancel(tripId);
              },
              child: const Text("OUI, ANNULER", style: TextStyle(color: AppColors.errorRed))
          ),
        ],
      ),
    );
  }
}