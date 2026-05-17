import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_widgets.dart';

import '../../providers/user_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../models/location.dart';
import '../../utils/app_colors.dart';
import '../../widgets/location_autocomplete_field.dart';

import '../screens/PhoneInputScreen.dart';
import '../screens/messages_list_screen.dart';

// --- NAVIGATION ---
import '../widgets/shimmer_widgets.dart';
import 'vehicule_registration.dart';
import 'PublishTripScreen.dart';
import 'search_trip_screen.dart';
import 'trip_detail_screen.dart';
import 'MyBookingsScreen.dart';
import 'MyTripsScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // États pour la recherche
  Location? _startLocation;
  Location? _endLocation;
  DateTime _selectedDate = DateTime.now();
  int _passengerCount = 1;

  // État de la navigation
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _configureSystemUI();
    _loadInitialData();
  }

  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProv = context.read<UserProvider>();
      userProv.fetchUserProfile().then((_) {
        context.read<TripProvider>().fetchSearchTrips("", "", "", userProv.userCountryCode);
      });
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

    // Si le profil est nul et que ça charge, on montre le squelette pro.
    if (userProvider.isLoading && currentUser == null) {
      return const HomeShimmer();
    }
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      endDrawer: Drawer(
        width: width * 0.85,
        child: currentUser != null
            ? _ProfileDrawerContent(user: currentUser, scale: scale)
            : const Center(child: CircularProgressIndicator()),
      ),
      bottomNavigationBar: _buildPremiumBottomNav(scale),
      // IndexedStack permet de changer de page sans perdre le scroll de l'accueil
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildHomeBody(userProvider, tripProvider, currentUser, scale), // Index 0
          const MessagesListScreen(),                                     // Index 1
          const Center(child: Text("Alertes (Bientôt disponible)")),     // Index 2
          const Center(child: Text("Profil")),                            // Index 3
        ],
      ),
    );
  }

  // --- CONTENU DE LA PAGE ACCUEIL (EXPLORER) ---
  Widget _buildHomeBody(UserProvider userProvider, TripProvider tripProvider, User? currentUser, double scale) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accentBlue,
        onRefresh: () async {
          await userProvider.fetchUserProfile();
          await tripProvider.fetchSearchTrips("", "", "", userProvider.userCountryCode);
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
              _buildHorizontalTripList(tripProvider, scale),
              SizedBox(height: 30 * scale),
            ],
          ),
        ),
      ),
    );
  }

  // --- HEADER : Nom & Badge ---
  Widget _buildHeader(User? user, bool isLoading, double scale) {
    bool isDriver = user?.role == 'driver';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Content de vous revoir,",
                style: TextStyle(fontSize: 13 * scale, color: AppColors.textGrey, fontWeight: FontWeight.w500)),
            Text(user?.fullName ?? 'Chargement...',
                style: TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
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
        backgroundColor: Colors.grey.shade200,
        backgroundImage: (user?.profilePhotoUrl != null && user!.profilePhotoUrl!.isNotEmpty)
        ? NetworkImage("${ApiService.baseUrl}${user.profilePhotoUrl}")
            : const AssetImage("assets/default_avatar.png") as ImageProvider,
        child: (user?.profilePhotoUrl == null)
        ? Text(user?.fullName[0] ?? "?", style: const TextStyle(fontWeight: FontWeight.bold))
            : null,
        ),

        )
      ],
    );
  }

  // --- CARTE DE RECHERCHE ---
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

  // --- BANNIÈRE D'ACTION ---
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

  // --- BARRE DE NAVIGATION BASSE ---
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
              _navIcon(3, Icons.account_circle_outlined, "Moi", scale, isProfile: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIcon(int idx, IconData icon, String label, double scale, {bool isProfile = false}) {
    bool active = _currentNavIndex == idx;
    return InkWell(
      onTap: () {
        if (isProfile) {
          _scaffoldKey.currentState?.openEndDrawer();
        } else {
          setState(() => _currentNavIndex = idx);
        }
        if (idx == 1){
          context.read<TripProvider>().fetchUserDiscussions();
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

  // --- HELPERS WIDGETS ---
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

  Widget _buildHorizontalTripList(TripProvider provider, double scale) {
    if (provider.isLoading) return _buildShimmerCard(scale);

    // ON APPELLE LE GETTER ICI
    final trips = provider.filteredTrips;

    if (trips.isEmpty) {
      return Container(
        height: 100 * scale,
        alignment: Alignment.center,
        child: Text(
          "Aucun trajet disponible pour le moment",
          style: TextStyle(color: AppColors.textGrey, fontSize: 13 * scale),
        ),
      );
    }

    return SizedBox(
      height: 165 * scale,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: trips.length,
        // On utilise la liste filtrée
        itemBuilder: (context, index) => _TripShortcutCard(
            trip: trips[index],
            scale: scale
        ),
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

  Widget _buildShimmerCard(double scale) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(height: 165, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
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

// --- CARD RACCOURCI ---
class _TripShortcutCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final double scale;
  const _TripShortcutCard({required this.trip, required this.scale});

  @override
  Widget build(BuildContext context) {
    // Parsing de la date pour l'affichage
    DateTime departureDate = DateTime.parse(trip['departure_at']);
    String formattedDate = DateFormat('dd MMM, HH:mm').format(departureDate);

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip))
      ),
      child: Container(
        width: 250 * scale,
        margin: EdgeInsets.only(right: 16 * scale),
        padding: EdgeInsets.all(18 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24 * scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge de temps restant ou Date
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                formattedDate,
                style: const TextStyle(
                  color: AppColors.accentBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Itinéraire
            Text(
              "${trip['origin_city']}",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16 * scale),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Icon(Icons.arrow_downward, size: 14, color: Colors.grey.shade400),
            Text(
              "${trip['destination_city']}",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16 * scale),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Prix
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${trip['price_per_seat']} CFA",
                  style: const TextStyle(
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "${trip['seats_available']} pl.",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- DRAWER ---
class _ProfileDrawerContent extends StatelessWidget {
  final User user;
  final double scale;
  const _ProfileDrawerContent({required this.user, required this.scale});

  @override
  Widget build(BuildContext context) {
    final bool isDriver = user.role == 'driver';
    return Column(
      children: [
        UserAccountsDrawerHeader(
          decoration: const BoxDecoration(gradient: AppColors.premiumGradient),
          accountName: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
          accountEmail: Text(isDriver ? "Chauffeur" : "Passager"),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            backgroundImage: (user.profilePhotoUrl != null && user.profilePhotoUrl!.isNotEmpty)
                ? NetworkImage("${ApiService.baseUrl}${user.profilePhotoUrl}")
                : const AssetImage("assets/default_avatar.png") as ImageProvider,
            child: (user.profilePhotoUrl == null || user.profilePhotoUrl!.isEmpty)
                ? Text(user.fullName[0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryDark))
                : null,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text("Mes Réservations"),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen())),
        ),
        if (isDriver)
          ListTile(
            leading: const Icon(Icons.directions_car),
            title: const Text("Mes Trajets"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTripsScreen())),
          ),
        const Spacer(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text("Déconnexion", style: TextStyle(color: Colors.red)),
          onTap: () async {
            await context.read<AuthProvider>().logout();
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PhoneInputScreen()), (r) => false);
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}