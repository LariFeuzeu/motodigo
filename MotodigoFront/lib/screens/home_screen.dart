import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../providers/user_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../models/location.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../services/api_service.dart';
import '../widgets/profile_drawer.dart';

import '../screens/PhoneInputScreen.dart';
import '../screens/messages_list_screen.dart';
import 'vehicule_registration.dart';
import 'PublishTripScreen.dart';
import 'search_trip_screen.dart';
import 'trip_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Location? _startLocation;
  Location? _endLocation;
  DateTime _selectedDate = DateTime.now();
  int _passengerCount = 1;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _configureSystemUI();
    _loadInitialData();
  }

  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userProv = context.read<UserProvider>();
      final tripProv = context.read<TripProvider>();

      // Chargement du profil utilisateur pour récupérer son pays d'origine (GPS/Profil)
      await userProv.fetchUserProfile();

      // Utilisation du code pays pour charger les trajets locaux ciblés
      String countryCode = userProv.userCountryCode.isNotEmpty ? userProv.userCountryCode : 'CM';
      await tripProv.fetchSearchTrips("", "", "", countryCode);
    });
  }

  void _configureSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / 375;
    final userProvider = context.watch<UserProvider>();
    final tripProvider = context.watch<TripProvider>();
    final currentUser = userProvider.currentUser;

    if (userProvider.isLoading && currentUser == null) {
      return const Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      endDrawer: currentUser != null
          ? ProfileDrawer(user: currentUser, scale: scale)
          : const Drawer(child: Center(child: CircularProgressIndicator())),
      bottomNavigationBar: _buildPremiumBottomNav(scale),
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildHomeBody(userProvider, tripProvider, currentUser, scale),
          const MessagesListScreen(),
          const Center(child: Text("Alertes (Bientôt disponible)")),
        ],
      ),
    );
  }

  Widget _buildHomeBody(UserProvider userProvider, TripProvider tripProvider, User? currentUser, double scale) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accentBlue,
        onRefresh: () async {
          await userProvider.fetchUserProfile();
          String countryCode = userProvider.userCountryCode.isNotEmpty ? userProvider.userCountryCode : 'CM';
          await tripProvider.fetchSearchTrips("", "", "", countryCode);
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 15 * scale),
              _buildHeader(currentUser, userProvider.isLoading, scale),
              SizedBox(height: 25 * scale),
              _buildSearchCard(scale),
              SizedBox(height: 25 * scale),
              _buildActionBanner(currentUser, userProvider.isLoading, scale),
              SizedBox(height: 30 * scale),
              _sectionHeader("TRAJETS À PROXIMITÉ", "VOIR TOUT", scale, () => _handleSeeAll()),
              SizedBox(height: 15 * scale),
              // 🔥 Appel de notre liste fluide optimisée
              _buildHorizontalTripList(tripProvider, scale),
              SizedBox(height: 30 * scale),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(User? user, bool isLoading, double scale) {
    bool isDriver = user?.role == 'driver';
    final double rating = user?.rating ?? 0.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Content de vous revoir,",
                style: TextStyle(fontSize: 13 * scale, color: AppColors.textGrey, fontWeight: FontWeight.w500)),
            Row(
              children: [
                Text(user?.fullName ?? 'Chargement...',
                    style: TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                if (isDriver && rating > 0) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  Text(" ${rating.toStringAsFixed(1)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ]
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isDriver ? AppColors.successGreen : AppColors.accentBlue).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isDriver ? "CHAUFFEUR" : "PASSAGER",
                style: TextStyle(
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w800,
                    color: isDriver ? AppColors.successGreen : AppColors.accentBlue,
                    letterSpacing: 0.5),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
          child: CircleAvatar(
            radius: 25 * scale,
            backgroundColor: AppColors.accentBlue.withOpacity(0.1),
            backgroundImage: (user?.profilePhotoUrl != null && user!.profilePhotoUrl!.isNotEmpty)
                ? NetworkImage("${ApiService.baseUrl}${user.profilePhotoUrl}")
                : null,
            child: (user?.profilePhotoUrl == null || user!.profilePhotoUrl!.isEmpty)
                ? Text(
              user?.fullName != null && user!.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : "?",
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            )
                : null,
          ),
        )
      ],
    );
  }

  Widget _buildSearchCard(double scale) {
    return Container(
      padding: EdgeInsets.all(18 * scale),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(24 * scale),
        boxShadow: [BoxShadow(color: AppColors.primaryDark.withOpacity(0.04), blurRadius: 25, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          _buildLocationInput(Icons.radio_button_checked, AppColors.accentBlue, "D'où partez-vous ?", (loc) => setState(() => _startLocation = loc), scale),
          Padding(padding: EdgeInsets.only(left: 35 * scale), child: Divider(color: Colors.grey.shade100, height: 25 * scale)),
          _buildLocationInput(Icons.location_on_rounded, AppColors.errorRed, "Où allez-vous ?", (loc) => setState(() => _endLocation = loc), scale),
          SizedBox(height: 20 * scale),
          Row(
            children: [
              Expanded(child: _buildSmallAction(Icons.calendar_today_rounded, DateFormat('dd MMM').format(_selectedDate), _pickDate, scale)),
              SizedBox(width: 12 * scale),
              Expanded(child: _buildPassengerCounter(scale)),
            ],
          ),
          SizedBox(height: 20 * scale),
          SizedBox(
            width: double.infinity,
            height: 54 * scale,
            child: ElevatedButton(
              onPressed: _handleSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * scale)),
                elevation: 0,
              ),
              child: const Text("RECHERCHER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBanner(User? user, bool isLoading, double scale) {
    if (user == null && isLoading) return const SizedBox();
    final isDriver = user?.role == 'driver';

    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
          gradient: isDriver ? AppColors.premiumGradient : const LinearGradient(colors: [Color(0xFF09091A), Color(0xFF1E1E2F)]),
          borderRadius: BorderRadius.circular(22 * scale)),
      child: Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isDriver ? "PUBLIER UN TRAJET" : "DEVENIR CHAUFFEUR", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              Text(isDriver ? "Maximisez vos revenus" : "Gagnez jusqu'à 50.000 CFA / jour", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
            ])),
        ElevatedButton(
          onPressed: () => _handleMainAction(user),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(isDriver ? "PUBLIER" : "S'INSCRIRE", style: const TextStyle(fontWeight: FontWeight.w900)),
        )
      ]),
    );
  }

  Widget _buildPremiumBottomNav(double scale) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(top: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navIcon(0, Icons.explore_rounded, "Explorer", scale),
              _navIcon(1, Icons.message_outlined, "Messages", scale),
              _navIcon(2, Icons.notifications_none_rounded, "Alertes", scale),
              _navIcon(3, Icons.account_circle_outlined, "Moi", scale, isDrawerTrigger: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIcon(int idx, IconData icon, String label, double scale, {bool isDrawerTrigger = false}) {
    bool active = _currentNavIndex == idx && !isDrawerTrigger;
    return InkWell(
      onTap: () {
        if (isDrawerTrigger) {
          _scaffoldKey.currentState?.openEndDrawer();
        } else {
          setState(() => _currentNavIndex = idx);
          if (idx == 1) {
            context.read<TripProvider>().fetchUserDiscussions();
          }
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? AppColors.accentBlue : AppColors.textGrey, size: 26 * scale),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10 * scale, fontWeight: active ? FontWeight.w900 : FontWeight.w600, color: active ? AppColors.accentBlue : AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _buildHorizontalTripList(TripProvider provider, double scale) {
    // 🔥 FLUIDITÉ : Si ça charge, on affiche une vraie liste horizontale fantôme animée
    if (provider.isLoading) return _buildHorizontalShimmerList(scale);

    final trips = provider.filteredTrips;

    if (trips.isEmpty) {
      return Container(
        height: 140 * scale,
        alignment: Alignment.center,
        child: Text(
          "Aucun trajet disponible à proximité",
          style: TextStyle(color: AppColors.textGrey, fontSize: 13 * scale, fontWeight: FontWeight.w500),
        ),
      );
    }

    return SizedBox(
      height: 165 * scale,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: trips.length,
        itemBuilder: (context, index) => _TripShortcutCard(
            trip: trips[index],
            scale: scale
        ),
      ),
    );
  }

  // 🔥 FLUIDITÉ : Le squelette Shimmer horizontal parfait
  Widget _buildHorizontalShimmerList(double scale) {
    return SizedBox(
      height: 165 * scale,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: Colors.grey[200]!,
          highlightColor: Colors.grey[50]!,
          child: Container(
            width: 250 * scale,
            margin: EdgeInsets.only(right: 16 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24 * scale),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInput(IconData icon, Color color, String hint, Function(Location) onSelected, double scale) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18 * scale),
        SizedBox(width: 12 * scale),
        Expanded(child: LocationAutocompleteField(label: hint, onLocationSelected: onSelected)),
      ],
    );
  }

  Widget _buildSmallAction(IconData icon, String text, VoidCallback onTap, double scale) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14 * scale),
        decoration: BoxDecoration(color: AppColors.lightBackground, borderRadius: BorderRadius.circular(14 * scale)),
        child: Row(children: [
          Icon(icon, size: 14, color: AppColors.accentBlue),
          SizedBox(width: 10 * scale),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))
        ]),
      ),
    );
  }

  Widget _buildPassengerCounter(double scale) {
    return Container(
      decoration: BoxDecoration(color: AppColors.lightBackground, borderRadius: BorderRadius.circular(14 * scale)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: () => setState(() => _passengerCount > 1 ? _passengerCount-- : null), icon: const Icon(Icons.remove, size: 14)),
          Text("$_passengerCount", style: const TextStyle(fontWeight: FontWeight.w900)),
          IconButton(onPressed: () => setState(() => _passengerCount < 8 ? _passengerCount++ : null), icon: const Icon(Icons.add, size: 14, color: AppColors.accentBlue)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String action, double scale, VoidCallback onAction) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w900, color: AppColors.textGrey)),
        TextButton(onPressed: onAction, child: Text(action, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
      ],
    );
  }

  void _handleSearch() {
    if (_startLocation == null || _endLocation == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => SearchTripScreen(originName: _startLocation!.displayName, destinationName: _endLocation!.displayName, date: _selectedDate, seats: _passengerCount, countryCode: context.read<UserProvider>().userCountryCode)));
  }

  void _handleSeeAll() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SearchTripScreen(originName: "", destinationName: "", date: DateTime.now(), seats: 1, countryCode: context.read<UserProvider>().userCountryCode)));
  }

  void _handleMainAction(User? user) {
    if (user?.role == 'driver') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishTripScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleRegistrationScreen()));
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
    if (picked != null) setState(() => _selectedDate = picked);
  }
}

// --- CARD RACCOURCI PREMIUM ---
class _TripShortcutCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final double scale;
  const _TripShortcutCard({required this.trip, required this.scale});

  @override
  Widget build(BuildContext context) {
    // Extraction sécurisée des dates avec fallback pour éviter les crashs d'UI
    String formattedDate = "...";
    if (trip['departure_at'] != null) {
      DateTime departureDate = DateTime.parse(trip['departure_at']);
      formattedDate = DateFormat('dd MMM, HH:mm').format(departureDate);
    }

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip))
      ),
      child: Container(
        width: 250 * scale,
        margin: EdgeInsets.only(right: 16 * scale, bottom: 4 * scale), // Légère marge basse pour l'ombre
        padding: EdgeInsets.all(14 * scale), // Réduction légère du padding interne pour donner de l'air
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22 * scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge Date & Heure
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                formattedDate,
                style: const TextStyle(
                  color: AppColors.accentBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(height: 10 * scale),

            // Ville de Départ
            Row(
              children: [
                const Icon(Icons.radio_button_checked, size: 12, color: AppColors.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${trip['origin_city'] ?? 'Ville inconnue'}",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13 * scale, color: AppColors.primaryDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // 🔥 Ligne de liaison corrigée (plus d'overflow ici)
            Padding(
              padding: EdgeInsets.only(left: 5, top: 2 * scale, bottom: 2 * scale),
              child: Container(width: 2, height: 10 * scale, color: Colors.grey.shade200),
            ),

            // Ville d'Arrivée
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 12, color: AppColors.errorRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${trip['destination_city'] ?? 'Ville inconnue'}",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13 * scale, color: AppColors.primaryDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const Spacer(), // Pousse proprement le bloc financier vers le bas
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            SizedBox(height: 6 * scale),

            // Prix et Places restantes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${trip['price_per_seat'] ?? '0'} CFA",
                  style: const TextStyle(
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${trip['seats_available'] ?? '0'} pl.",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}