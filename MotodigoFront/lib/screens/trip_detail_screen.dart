import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/app_colors.dart';
import '../providers/user_provider.dart';
import '../providers/trip_provider.dart';
import '../services/pdf_service.dart';

class TripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  String? _selectedPaymentProvider;
  int _bookedSeats = 1;

  @override
  Widget build(BuildContext context) {

    double scale = MediaQuery.of(context).size.width / 375;
    int maxAvailable = widget.trip['seats_available'] ?? 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      appBar: AppBar(
        title: Text("DÉTAILS DU TRAJET",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13 * scale, letterSpacing: 1.5, color: AppColors.primaryDark)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildItineraryTimeline(scale),
            _buildBaggageCard(scale),
            _buildSeatsSelector(scale, maxAvailable),
            _buildDriverCard(scale),
            _buildPaymentSection(scale),
            const SizedBox(height: 140),
          ],
        ),
      ),
      bottomSheet: _buildBottomAction(scale),
    );
  }

  // --- TIMELINE DYNAMIQUE (RAMASSAGE, ESCALES, DÉPOSE) ---
  Widget _buildItineraryTimeline(double scale) {
    final List waypoints = widget.trip['waypoints'] ?? [];

    // On récupère les noms des lieux. Si c'est vide, on met un texte par défaut clair.
    final String pickup = widget.trip['origin_label'] ?? "Lieu de ramassage à confirmer";
    final String dropoff = widget.trip['destination_label'] ?? "Zone de dépose standard";

    return Container(
      margin: EdgeInsets.all(20 * scale),
      padding: EdgeInsets.all(24 * scale),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28 * scale),
          boxShadow: [BoxShadow(color: AppColors.primaryDark.withOpacity(0.05), blurRadius: 20)]),
      child: Column(
          children: [
            // DÉPART + RAMASSAGE
            _timelineRow(
              icon: Icons.radio_button_checked,
              color: AppColors.accentBlue,
              // On récupère la ville de départ
              city: widget.trip['origin_city'] ?? "Ville de départ",
              // On affiche le point de ramassage précis (origin_label)
              detail: pickup,
              isLast: false,
              scale: scale,
            ),

            // ESCALES DYNAMIQUES
            if (waypoints != null && waypoints.isNotEmpty)
              ...waypoints.map((wp) {
                String escaleName = wp is Map ? (wp['city'] ?? "Escale") : wp.toString();
                return _timelineRow(
                  icon: Icons.stop_circle_outlined,
                  color: Colors.grey.shade400,
                  city: escaleName,
                  detail: "Escale prévue",
                  isLast: false,
                  scale: scale,
                );
              }),

            // DESTINATION + DÉPOSE
            _timelineRow(
              icon: Icons.location_on_rounded,
              color: AppColors.errorRed,
              // On récupère la ville d'arrivée
              city: widget.trip['destination_city'] ?? "Ville d'arrivée",
              // On affiche le point de dépôt précis (destination_label)
              detail: dropoff,
              isLast: true,
              scale: scale,
            ),
          ],
      ),
    );

  }



  Widget _timelineRow({required IconData icon, required Color color, required String city, required String detail, required bool isLast, required double scale}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, color: color, size: 22 * scale),
            if (!isLast)
              Container(width: 2, height: 45 * scale, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(2))),
          ],
        ),
        SizedBox(width: 15 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(city, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16 * scale, color: AppColors.primaryDark)),
              const SizedBox(height: 4),
              Text(detail, style: TextStyle(color: AppColors.accentBlue, fontSize: 12 * scale, fontWeight: FontWeight.w700)),
              SizedBox(height: isLast ? 0 : 20 * scale),
            ],
          ),
        ),
      ],
    );
  }

  // --- CARTE BAGAGES ---
// Dans TripDetailScreen.dart
  Widget _buildBaggageCard(double scale) {
    final String size = widget.trip['baggage_size'] ?? 'Moyen';
    final String details = widget.trip['baggage_details'] ?? "Aucune restriction particulière";

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24 * scale),
        border: Border.all(color: AppColors.lightBackground, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.luggage_rounded, color: AppColors.accentBlue, size: 24 * scale),
          ),
          SizedBox(width: 15 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    "BAGAGES : ${size.toUpperCase()}",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13 * scale, color: AppColors.primaryDark)
                ),
                const SizedBox(height: 4),
                Text(
                    details,
                    style: TextStyle(fontSize: 12 * scale, color: Colors.grey.shade600, fontWeight: FontWeight.w600)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SÉLECTEUR DE PLACES ---
  Widget _buildSeatsSelector(double scale, int max) {
    return Container(
      margin: EdgeInsets.all(20 * scale),
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 15 * scale),
      decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(20 * scale)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Nombre de places", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15)),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                _seatBtn(Icons.remove, () => setState(() => _bookedSeats--), _bookedSeats > 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Text("$_bookedSeats", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                _seatBtn(Icons.add, () => setState(() => _bookedSeats++), _bookedSeats < max),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seatBtn(IconData icon, VoidCallback onTap, bool enabled) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: CircleAvatar(radius: 18, backgroundColor: enabled ? Colors.white : Colors.white24, child: Icon(icon, size: 18, color: enabled ? AppColors.primaryDark : Colors.white38)),
    );
  }

  // --- CARTE CHAUFFEUR ---
  Widget _buildDriverCard(double scale) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20 * scale),
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24 * scale), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          CircleAvatar(radius: 28, backgroundColor: AppColors.lightBackground, child: const Icon(Icons.person_outline_rounded, color: AppColors.primaryDark, size: 30)),
          SizedBox(width: 15 * scale),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.trip['driver_name'] ?? "Chauffeur", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text(widget.trip['vehicle_model'] ?? "Véhicule Premium", style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          const Icon(Icons.verified_rounded, color: Colors.green, size: 24),
        ],
      ),
    );
  }

// --- SECTION PAIEMENT AVEC LOGOS ---
  Widget _buildPaymentSection(double scale) {
    return Padding(
      padding: EdgeInsets.all(20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              "MODE DE PAIEMENT",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5, color: Colors.grey)
          ),
          const SizedBox(height: 15),

          // Option MTN : On passe le chemin de l'image
          _buildPaymentTile(
            label: "MTN Mobile Money",
            value: "MTN",
            imagePath: "assets/images/mtnmomo.png",
            color: const Color(0xFFFFCC00),
          ),

          const SizedBox(height: 12),

          // Option Orange : On passe le chemin de l'image
          _buildPaymentTile(
            label: "Orange Money",
            value: "ORANGE",
            imagePath: "assets/images/orangemoney.png",
            color: const Color(0xFFFF6600),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTile({
    required String label,
    required String value,
    required String imagePath, // Nouveau paramètre pour l'image
    required Color color
  }) {
    bool isSelected = _selectedPaymentProvider == value;

    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact(); // Vibration plus marquée pour le côté Premium
        setState(() => _selectedPaymentProvider = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250), // Un peu plus rapide pour la réactivité
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20), // Coins plus arrondis
          border: Border.all(
              color: isSelected ? color : Colors.grey.shade200,
              width: isSelected ? 2.5 : 1.5 // Bordure plus épaisse si sélectionné
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
          ] : [],
        ),
        child: Row(
          children: [
            // AFFICHAGE DU LOGO
            Container(
              height: 40,
              width: 55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.contain, // Respecte les proportions du logo original
                ),
              ),
            ),
            const SizedBox(width: 15),

            // LIBELLÉ
            Expanded(
              child: Text(
                  label,
                  style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.primaryDark
                  )
              ),
            ),

            // INDICATEUR DE SÉLECTION
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected ? color : Colors.grey.shade300,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
  // --- ACTION DE RÉSERVATION (BOTTOM) ---
  Widget _buildBottomAction(double scale) {
    final double unitPrice = double.tryParse(widget.trip['price_per_seat'].toString()) ?? 0;
    final double totalPrice = unitPrice * _bookedSeats;

    return Container(
      padding: EdgeInsets.fromLTRB(25 * scale, 20 * scale, 25 * scale, 35 * scale),
      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(35)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text("TOTAL", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
            Text("${totalPrice.toInt()} CFA", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.primaryDark, letterSpacing: -1)),
          ]),
          const SizedBox(width: 20),
          Expanded(
            child: ElevatedButton(
              onPressed: _selectedPaymentProvider == null ? null : _confirmBooking,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, disabledBackgroundColor: Colors.grey.shade200, minimumSize: const Size(0, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
              child: const Text("RÉSERVER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  void _confirmBooking() async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.accentBlue)));
    final success = await context.read<TripProvider>().bookTrip(tripId: widget.trip['id'], paymentMethod: _selectedPaymentProvider!, seatsCount: _bookedSeats);
    if (!mounted) return;
    Navigator.pop(context);
    if (success) {
      HapticFeedback.vibrate();
      showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => _PremiumTicketModal(trip: widget.trip, seats: _bookedSeats));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Échec de la réservation."), backgroundColor: AppColors.errorRed, behavior: SnackBarBehavior.floating));
    }
  }
}

// --- MODAL DE CONFIRMATION (TICKET) ---
class _PremiumTicketModal extends StatelessWidget {
  final Map<String, dynamic> trip;
  final int seats;
  const _PremiumTicketModal({required this.trip, required this.seats});

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserProvider>().currentUser;
    final double totalPrice = (double.tryParse(trip['price_per_seat'].toString()) ?? 0) * seats;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
      child: Column(
        children: [
          const SizedBox(height: 15),
          Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10))),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
                  const SizedBox(height: 15),
                  const Text("RÉSERVATION RÉUSSIE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1, color: AppColors.primaryDark)),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(color: AppColors.lightBackground.withOpacity(0.5), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade100)),
                    child: Column(
                      children: [
                        _ticketItem("Passager", user?.fullName ?? "Client"),
                        _ticketItem("De", trip['origin_city']),
                        _ticketItem("Ramassage", trip['origin_label'] ?? "À confirmer"),

                        _ticketItem("À", trip['destination_city']),
                        // Correction
                        _ticketItem("Dépôt", trip['destination_label'] ?? "À confirmer"),
                        _ticketItem("Places", "$seats place(s)"),
                        const Divider(height: 30),
                        _ticketItem("TOTAL", "${totalPrice.toInt()} CFA", isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // _actionCircle(Icons.phone_rounded, "Appeler", Colors.green, (){}),
                      _actionCircle(Icons.message_rounded, "Message", AppColors.accentBlue, (){}),
                      _actionCircle(Icons.download_rounded, "PDF", AppColors.primaryDark, () async {
                        await PdfService.generateTripTicket(trip: trip, bookedSeats: seats, passengerName: user?.fullName ?? "Passager");
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(30),
            child: ElevatedButton(onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text("RETOUR À L'ACCUEIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          ),
        ],
      ),
    );
  }

  Widget _ticketItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13)),
        Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w800, fontSize: 14, color: isBold ? AppColors.accentBlue : AppColors.primaryDark))),
      ]),
    );
  }

  Widget _actionCircle(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Column(children: [CircleAvatar(radius: 28, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 24)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11))]));
  }

}