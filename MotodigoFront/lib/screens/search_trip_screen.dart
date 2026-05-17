import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/trip_provider.dart';
import '../../utils/app_colors.dart';
import 'trip_detail_screen.dart';

class SearchTripScreen extends StatefulWidget {
  final String originName;
  final String destinationName;
  final DateTime date;
  final int seats;
  final String countryCode;

  const SearchTripScreen({
    super.key,
    required this.originName,
    required this.destinationName,
    required this.date,
    required this.seats,
    required this.countryCode,
  });

  @override
  State<SearchTripScreen> createState() => _SearchTripScreenState();
}

class _SearchTripScreenState extends State<SearchTripScreen> {
  double get scale => MediaQuery.of(context).size.width / 375;

  @override
  void initState() {
    super.initState();
    _setSystemUI();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTrips());
  }

  void _setSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  void _loadTrips() {
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);
    context.read<TripProvider>().fetchSearchTrips(
      widget.originName.split(',').first.trim(),
      widget.destinationName.split(',').first.trim(),
      dateStr,
      widget.countryCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70 * scale,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.primaryDark, size: 20 * scale),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text("TRAJETS DISPONIBLES",
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 13 * scale,
                  letterSpacing: 1.2,
                )),
            const SizedBox(height: 4),
            Text(DateFormat('EEEE dd MMMM', 'fr_FR').format(widget.date).toUpperCase(),
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10 * scale, fontWeight: FontWeight.w700)),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60 * scale),
          child: _buildSummaryHeader(),
        ),
      ),
      body: tripProvider.isLoading
          ? _buildShimmerList()
          : tripProvider.searchResults.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
        itemCount: tripProvider.searchResults.length,
        itemBuilder: (context, index) {
          final trip = tripProvider.searchResults[index];
          return _PremiumTripCard(trip: trip, scale: scale);
        },
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20 * scale, 0, 20 * scale, 15 * scale),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _cityBadge(widget.originName),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12 * scale),
            child: Icon(Icons.swap_horiz_rounded, color: AppColors.accentBlue, size: 20 * scale),
          ),
          _cityBadge(widget.destinationName),
        ],
      ),
    );
  }

  Widget _cityBadge(String name) {
    return Flexible(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 8 * scale),
        decoration: BoxDecoration(color: AppColors.lightBackground, borderRadius: BorderRadius.circular(12)),
        child: Text(
          name.split(',').first.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark, fontSize: 12 * scale),
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: EdgeInsets.all(20 * scale),
      itemCount: 3,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Container(
          margin: EdgeInsets.only(bottom: 20 * scale),
          height: 200 * scale,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28 * scale)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80 * scale, color: Colors.grey.shade200),
          const SizedBox(height: 20),
          Text("Aucun trajet trouvé", style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 18 * scale)),
        ],
      ),
    );
  }
}

class _PremiumTripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final double scale;

  const _PremiumTripCard({required this.trip, required this.scale});

  @override
  Widget build(BuildContext context) {
    final int seatsLeft = trip['seats_available'] ?? 0;
    final bool isFull = seatsLeft <= 0;
    final DateTime departureDate = DateTime.tryParse(trip['departure_at'] ?? "") ?? DateTime.now();
    final List waypoints = trip['waypoints'] ?? [];

    return GestureDetector(
      onTap: isFull ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip))),
      child: Opacity(
        opacity: isFull ? 0.6 : 1.0,
        child: Container(
          margin: EdgeInsets.only(bottom: 20 * scale),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28 * scale),
            boxShadow: [BoxShadow(color: AppColors.primaryDark.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 12))],
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(24 * scale),
                child: Column(
                  children: [
                    // --- HEADER : HEURE ET PRIX ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat.Hm().format(departureDate),
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26 * scale, color: AppColors.primaryDark, letterSpacing: -1)),
                            Text("DÉPART", style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.w900, fontSize: 10 * scale)),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 10 * scale),
                          decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(16 * scale)),
                          child: Text("${trip['price_per_seat']} CFA", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
                        ),
                      ],
                    ),
                    SizedBox(height: 25 * scale),

                    // --- TRAJET VERTICAL (LE STYLE UBER) ---
                    _buildRoutePreview(waypoints),

                    SizedBox(height: 25 * scale),
                    const Divider(height: 1, color: AppColors.lightBackground),
                    SizedBox(height: 20 * scale),

                    // --- CHAUFFEUR ---
                    Row(
                      children: [
                        _buildAvatar(trip['driver_name'] ?? "C"),
                        SizedBox(width: 12 * scale),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(trip['driver_name'] ?? "Chauffeur", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15 * scale, color: AppColors.primaryDark)),
                              Text(trip['vehicle_model'] ?? "Véhicule", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 12 * scale)),
                            ],
                          ),
                        ),
                        _buildSeatsLeft(seatsLeft),
                      ],
                    ),
                  ],
                ),
              ),

              // --- FOOTER TAGS ---
              _buildCardFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutePreview(List waypoints) {
    return Column(
      children: [
        _routeRow(trip['origin_city'], Icons.radio_button_checked, AppColors.accentBlue),
        if (waypoints.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: 8 * scale),
            child: Row(
              children: [
                Container(width: 2, height: 20 * scale, color: Colors.grey.shade100),
                SizedBox(width: 20 * scale),
                Text("+ ${waypoints.length} escale${waypoints.length > 1 ? 's' : ''}",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11 * scale, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        _routeRow(trip['destination_city'], Icons.location_on_rounded, Colors.redAccent),
      ],
    );
  }

  Widget _routeRow(String city, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18 * scale, color: color),
        SizedBox(width: 15 * scale),
        Expanded(child: Text(city, style: TextStyle(fontSize: 15 * scale, fontWeight: FontWeight.w700, color: AppColors.primaryDark), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildAvatar(String name) {
    return CircleAvatar(
      radius: 20 * scale,
      backgroundColor: AppColors.lightBackground,
      child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildSeatsLeft(int seats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: seats <= 1 ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
      child: Text("$seats pl.", style: TextStyle(fontWeight: FontWeight.w900, color: seats <= 1 ? Colors.red : Colors.green, fontSize: 12 * scale)),
    );
  }

  Widget _buildCardFooter() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14 * scale, horizontal: 24 * scale),
      decoration: BoxDecoration(
        color: AppColors.lightBackground.withOpacity(0.4),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28 * scale)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, size: 14 * scale, color: Colors.green),
          const SizedBox(width: 6),
          Text("Chauffeur Vérifié", style: TextStyle(fontSize: 11 * scale, color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primaryDark),
        ],
      ),
    );
  }
}