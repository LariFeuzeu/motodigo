import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/shimmer_widgets.dart'; // Contient ton ShimmerBlock
import '../../providers/trip_provider.dart';
import '../../utils/app_colors.dart';
import 'ChatScreenState.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  @override
  void initState() {
    super.initState();
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
        title: const Text(
          "MES TRAJETS PUBLIÉS",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.primaryDark,
      ),
      body: tripProvider.isLoading && trips.isEmpty
          ? _buildDriverTripsShimmer() // Cas 1 : Premier chargement réseau (mémoire vide)
          : trips.isEmpty
          ? _buildEmptyState() // Cas 2 : Aucune donnée trouvée
          : Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) => _buildTripCard(trips[index]),
          ),
          if (tripProvider.isLoading)
            const Positioned(
              top: 0, left: 0, right: 0,
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

  /// 🟢 SQUELETTE DE CHARGEMENT POUR LES TRAJETS DU CHAUFFEUR OPTIMISÉ AVEC SHIMMERBLOCK
  Widget _buildDriverTripsShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fausse Date + Faux Badge Statut
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBlock(width: 110, height: 12),
                ShimmerBlock(width: 60, height: 18, borderRadius: BorderRadius.all(Radius.circular(6))),
              ],
            ),
            const SizedBox(height: 20),

            // Fausses Villes (Origine -> Destination)
            Row(
              children: const [
                Icon(Icons.radio_button_checked, size: 16, color: Colors.grey),
                SizedBox(width: 12),
                ShimmerBlock(width: 90, height: 14),
              ],
            ),
            Container(margin: const EdgeInsets.only(left: 7, top: 4, bottom: 4), height: 12, width: 1.5, color: Colors.grey[200]),
            Row(
              children: const [
                Icon(Icons.location_on_rounded, size: 16, color: Colors.grey),
                SizedBox(width: 12),
                ShimmerBlock(width: 110, height: 14),
              ],
            ),
            const Divider(height: 30, color: Colors.transparent),

            // Faux Remplissage places
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBlock(width: 140, height: 12),
                ShimmerBlock(width: 30, height: 12),
              ],
            ),
            const SizedBox(height: 10),
            const ShimmerBlock(width: double.infinity, height: 8, borderRadius: BorderRadius.all(Radius.circular(10))),
            const SizedBox(height: 25),

            // Faux Boutons d'actions
            Row(
              children: const [
                Expanded(child: ShimmerBlock(height: 36, borderRadius: BorderRadius.all(Radius.circular(8)))),
                SizedBox(width: 8),
                Expanded(child: ShimmerBlock(height: 36, borderRadius: BorderRadius.all(Radius.circular(8)))),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final String status = (trip['status'] ?? 'published').toString().toLowerCase();

    final bool isCancelled = status == 'cancelled';
    final bool isStarted = status == 'started';
    final bool isFinished = status == 'completed';

    final int totalSeats = trip['seats_total'] ?? 1;
    final int availableSeats = trip['seats_available'] ?? totalSeats;

    final int occupiedSeats = (totalSeats - availableSeats).clamp(0, totalSeats);
    double fillPercent = totalSeats > 0 ? (occupiedSeats / totalSeats).clamp(0.0, 1.0) : 0.0;
    final bool isFull = occupiedSeats >= totalSeats || status == 'full';

    return Opacity(
      opacity: isFinished || isCancelled ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isFinished ? Colors.grey[100] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: isStarted
                    ? AppColors.accentBlue.withOpacity(0.08)
                    : Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4)
            )
          ],
          border: isStarted
              ? Border.all(color: AppColors.accentBlue, width: 2.0)
              : null,
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
                      Text(
                        DateFormat('EEE dd MMM • HH:mm').format(DateTime.parse(trip['departure_at'])),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey, fontSize: 12),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildRouteRow(Icons.radio_button_checked, AppColors.accentBlue, trip['origin_city'] ?? ''),
                  _buildRouteDivider(),
                  _buildRouteRow(Icons.location_on_rounded, AppColors.errorRed, trip['destination_city'] ?? ''),

                  const Divider(height: 30),

                  if (!isFinished && !isCancelled) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isFull ? "COMPLET 🎉" : "Remplissage : $occupiedSeats/$totalSeats places",
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: isFull ? AppColors.successGreen : Colors.black
                          ),
                        ),
                        Text(
                          "${(fillPercent * 100).toInt()}%",
                          style: TextStyle(
                              color: isFull ? AppColors.successGreen : AppColors.accentBlue,
                              fontWeight: FontWeight.bold
                          ),
                        ),
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
                  ] else ...[
                    Row(
                      children: [
                        Icon(
                            isFinished ? Icons.check_circle : Icons.cancel,
                            color: isFinished ? AppColors.successGreen : AppColors.errorRed,
                            size: 18
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isFinished ? "TRAJET TERMINÉ (ARCHIVÉ)" : "CE TRAJET A ÉTÉ ANNULÉ",
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isFinished ? AppColors.successGreen : AppColors.errorRed,
                              fontSize: 13
                          ),
                        ),
                      ],
                    )
                  ],
                ],
              ),
            ),
            if (!isFinished && !isCancelled) ...[
              const Divider(height: 1),
              _buildActionButtons(trip, status),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> trip, String status) {
    final bool isStarted = status == 'started';
    final int tripId = trip['id'];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showPassengerList(tripId),
              icon: const Icon(Icons.people_alt_outlined, size: 16, color: Colors.white),
              label: const Text("PASSAGERS", style: TextStyle(fontSize: 11, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                print("📱 CLIC DÉTECTÉ SUR LE BOUTON !");
                if (!isStarted) {
                  await context.read<TripProvider>().updateTripStatut(tripId, 'started');
                } else {
                  _showFinishConfirmDialog(tripId);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isStarted ? AppColors.successGreen : AppColors.accentBlue,
              ),
              child: Text(
                isStarted ? "FINIR LE TRAJET" : "DÉMARRER",
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (!isStarted) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
              onPressed: () => _showCancelDialog(tripId),
            ),
          ]
        ],
      ),
    );
  }

  void _showFinishConfirmDialog(int tripId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clôturer le trajet ?"),
        content: const Text("Le trajet sera marqué comme terminé et archivé. Vos passagers pourront émettre des avis."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<TripProvider>().updateTripStatut(tripId, 'completed');
            },
            child: const Text("CONFIRMER", style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold)),
          ),
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
                          child: Text(
                              p['full_name'] != null && p['full_name'].isNotEmpty ? p['full_name'][0].toUpperCase() : 'P',
                              style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold)
                          ),
                        ),
                        title: Text(p['full_name'] ?? 'Passager', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${p['seats_booked']} place(s) réservée(s)"),
                        trailing: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, color: AppColors.accentBlue),
                          onPressed: () {
                            _goToChat(tripId, p['user_id'], p['full_name'] ?? 'Passager');
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

  void _goToChat(int tripId, int receiverId, String name) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
      tripId: tripId,
      receiverId: receiverId,
      receiverName: name,
    )));
  }

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
    Color color;
    String text;

    switch (status) {
      case 'started':
        color = AppColors.accentBlue;
        text = "EN COURS";
        break;
      case 'completed':
        color = AppColors.successGreen;
        text = "TERMINÉ";
        break;
      case 'cancelled':
        color = AppColors.errorRed;
        text = "ANNULÉ";
        break;
      default:
        color = Colors.orange;
        text = "PUBLIÉ";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
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