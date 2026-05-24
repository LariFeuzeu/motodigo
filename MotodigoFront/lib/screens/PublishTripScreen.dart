import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/trip_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/location_autocomplete_field.dart';

class PublishTripScreen extends StatefulWidget {
  const PublishTripScreen({super.key});

  @override
  State<PublishTripScreen> createState() => _PublishTripScreenState();
}

class _PublishTripScreenState extends State<PublishTripScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 16;

  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _baggageController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  int _seats = 4;
  String _selectedBaggage = "Moyen";
  int? _selectedVehicleId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDriverData());
  }

  void _initDriverData() {
    final user = context.read<UserProvider>().currentUser;
    if (user?.vehicles.isNotEmpty ?? false) {
      setState(() => _selectedVehicleId = user!.vehicles.first.id);
    }
  }

  void _nextStep() {
    HapticFeedback.mediumImpact();
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripProv = context.watch<TripProvider>();
    final userProv = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSlimProgressBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentStep = i),
              children: [
                _buildDateStep(),
                _buildLocationStep("Ville de départ", "D'où partez-vous ?", true),
                _buildPickUpStep(),
                _buildLocationStep("Destination", "Où allez-vous ?", false),
                _buildDropOffStep(),
                _buildWaypointsStep(tripProv),
                _buildBaggageStep(),
                _buildPriceAndSeatsStep(),
                _buildSummaryStep(tripProv, userProv),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ÉTAPES DE SAISIE ---

  Widget _buildPickUpStep() {
    return _buildStepTemplate(
      title: "Lieu de ramassage",
      subtitle: "Précisez un quartier ou un point de repère pour vos passagers.",
      child: Column(
        children: [
          _buildTextField("Ex: Devant la boulangerie Saker, Mvan...", _pickupController, icon: Icons.hail_rounded),
          const Spacer(),
          _buildPrimaryButton("VALIDER LE DÉPART", onTap: _nextStep),
        ],
      ),
    );
  }

  Widget _buildDropOffStep() {
    return _buildStepTemplate(
      title: "Point de dépôt",
      subtitle: "Où déposerez-vous les passagers à l'arrivée ?",
      child: Column(
        children: [
          _buildTextField("Ex: Entrée campus, Gare routière...", _dropoffController, icon: Icons.flag_rounded),
          const Spacer(),
          _buildPrimaryButton("VALIDER L'ARRIVÉE", onTap: _nextStep),
        ],
      ),
    );
  }

  // --- RÉSUMÉ PRO (STYLE TIMELINE) ---

  Widget _buildSummaryStep(TripProvider tripProv, UserProvider userProv) {
    final vehicle = userProv.currentUser?.vehicles.firstWhere((v) => v.id == _selectedVehicleId, orElse: () => userProv.currentUser!.vehicles.first);

    return _buildStepTemplate(
      title: "Récapitulatif",
      subtitle: "Vérifiez les détails de votre trajet avant publication.",
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // CARTE ITINÉRAIRE
                  _buildSummaryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTimelineRow(Icons.radio_button_checked, AppColors.accentBlue, tripProv.origin?.displayName ?? "Ville départ", _pickupController.text, isFirst: true),
                        ...tripProv.waypoints.map((w) => _buildTimelineRow(Icons.location_on_outlined, Colors.grey, w.displayName, "Escale", isWaypoint: true)),
                        _buildTimelineRow(Icons.location_on, AppColors.errorRed, tripProv.destination?.displayName ?? "Destination", _dropoffController.text, isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // CARTE INFOS LOGISTIQUES
                  _buildSummaryCard(
                    child: Column(
                      children: [
                        _buildInfoDetailRow(Icons.calendar_today_rounded, "Date & Heure", DateFormat('EEEE dd MMMM • HH:mm').format(_selectedDate)),
                        _buildInfoDetailRow(Icons.directions_car_rounded, "Véhicule", "${vehicle?.displayName}"),
                        _buildInfoDetailRow(Icons.luggage_rounded, "Bagages", "$_selectedBaggage (${_baggageController.text.isEmpty ? 'Standard' : _baggageController.text})"),
                        _buildInfoDetailRow(Icons.person_pin_circle_rounded, "Places", "$_seats disponibles", isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // PRIX
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.successGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Gain par passager", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.successGreen)),
                        Text("${_priceController.text} CFA", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.successGreen)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          tripProv.isLoading
              ? const CircularProgressIndicator()
              : _buildPrimaryButton("PUBLIER MAINTENANT", onTap: () async {
            bool success = await tripProv.publishTrip(
              vehicleId: _selectedVehicleId!,
              departureAt: _selectedDate,
              pricePerSeat: double.parse(_priceController.text),
              seatsTotal: _seats,
              countryCode: context.read<AuthProvider>().currentCountryCode,
              pickupPoint: _pickupController.text,
              dropoffPoint: _dropoffController.text,
            );
            if (success && mounted) Navigator.pop(context);
          }),
        ],
      ),
    );
  }

  // --- WIDGETS DE STYLE ---

  Widget _buildTimelineRow(IconData icon, Color color, String title, String sub, {bool isFirst = false, bool isLast = false, bool isWaypoint = false}) {
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 11,
            top: 25,
            bottom: 0,
            child: Container(width: 2, color: Colors.grey.shade200),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isWaypoint ? Colors.grey.shade700 : AppColors.primaryDark)),
                    if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 12, color: AppColors.accentBlue, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoDetailRow(IconData icon, String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: AppColors.textGrey),
          ),
          const SizedBox(width: 12),

          // Le libellé à gauche
          Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 13, fontWeight: FontWeight.w500)),

          const SizedBox(width: 16), // Une petite marge de sécurité minimale entre le libellé et la valeur

          //  On remplace le Spacer par un Expanded
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end, //  Aligne le texte à droite (comme le Spacer faisait)
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
              maxLines: 1, //  Empêche de casser le design sur deux lignes
              overflow: TextOverflow.ellipsis, //  Ajoute  proprement si la date est trop longue
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  // --- BASIQUES ---

  Widget _buildStepTemplate({required String title, required String subtitle, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primaryDark, letterSpacing: -0.8)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textGrey, fontWeight: FontWeight.w500, height: 1.4)),
          const SizedBox(height: 30),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, {IconData? icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: AppColors.accentBlue) : null,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          contentPadding: const EdgeInsets.all(20),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, {required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.2)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.lightBackground,
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.close_rounded, color: AppColors.primaryDark, size: 28), onPressed: () => Navigator.pop(context)),
      title: const Text("PUBLICATION", style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
      centerTitle: true,
    );
  }

  Widget _buildSlimProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: (_currentStep + 1) / _totalSteps,
          minHeight: 6,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
        ),
      ),
    );
  }



  Widget _buildDateStep() {
    return _buildStepTemplate(
      title: "Quand partez-\nvous ?",
      subtitle: "Choisissez la date et l'heure précises de votre départ.",
      child: Column(
        children: [
          _buildInteractiveCard(
            onTap: () async {
              //  Sélection de la date
              final DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );

              if (pickedDate != null && mounted) {
                //  Sélection de l'heure juste après validation de la date
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_selectedDate),
                );

                if (pickedTime != null) {
                  setState(() {
                    // On fusionne la date choisie et l'heure choisie dans un seul DateTime
                    _selectedDate = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    );
                  });
                }
              }
            },
            icon: Icons.access_time_filled_rounded, // Icône changée pour symboliser Date + Heure
            title: DateFormat('EEEE dd MMMM yyyy • HH:mm').format(_selectedDate),
          ),
          const Spacer(),
          _buildPrimaryButton("CONTINUER", onTap: _nextStep),
        ],
      ),
    );
  }
  Widget _buildLocationStep(String title, String hint, bool isOrigin) {
    return _buildStepTemplate(
      title: title,
      subtitle: hint,
      child: LocationAutocompleteField(
        label: "Rechercher une ville...",
        onLocationSelected: (loc) {
          if (isOrigin) context.read<TripProvider>().setOrigin(loc);
          else context.read<TripProvider>().setDestination(loc);
          _nextStep();
        },
      ),
    );
  }

  Widget _buildWaypointsStep(TripProvider prov) {
    return _buildStepTemplate(
      title: "Escales",
      subtitle: "Ajoutez des villes étapes pour trouver plus de passagers.",
      child: Column(
        children: [
          LocationAutocompleteField(
            label: "Ajouter une escale...",
            onLocationSelected: (loc) => prov.addWaypoint(loc),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: prov.waypoints.length,
              itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on, color: AppColors.warningOrange),
                  title: Text(prov.waypoints[index].displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.errorRed),
                    onPressed: () => prov.removeWaypoint(index),
                  ),
                ),
              ),
            ),
          ),
          _buildPrimaryButton(prov.waypoints.isEmpty ? "PAS D'ESCALE" : "CONTINUER", onTap: _nextStep),
        ],
      ),
    );
  }

  Widget _buildBaggageStep() {
    return _buildStepTemplate(
      title: "Bagages",
      subtitle: "Précisez la taille des bagages acceptés.",
      child: Column(
        children: [
          Row(
            children: [
              _baggageOption("Petit", Icons.shopping_bag_outlined),
              const SizedBox(width: 12),
              _baggageOption("Moyen", Icons.work_outline),
              const SizedBox(width: 12),
              _baggageOption("Grand", Icons.luggage_outlined),
            ],
          ),
          const SizedBox(height: 30),
          _buildTextField("Précisions (ex: Uniquement sacs souples...)", _baggageController),
          const Spacer(),
          _buildPrimaryButton("CONTINUER", onTap: _nextStep),
        ],
      ),
    );
  }

  Widget _baggageOption(String label, IconData icon) {
    bool isSelected = _selectedBaggage == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedBaggage = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentBlue : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isSelected ? AppColors.accentBlue : Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : AppColors.textGrey),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceAndSeatsStep() {
    return _buildStepTemplate(
      title: "Tarif & Places",
      subtitle: "Dernière étape ! Fixez votre prix par place.",
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: "0"),
                  ),
                ),
                const Text("CFA", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.accentBlue, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildCounterRow("Nombre de places", _seats, (val) => setState(() => _seats = val)),
          const Spacer(),
          _buildPrimaryButton("VOIR LE RÉSUMÉ", onTap: _nextStep),
        ],
      ),
    );
  }

  Widget _buildCounterRow(String label, int value, Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
        Row(
          children: [
            _counterBtn(Icons.remove, () => value > 1 ? onChanged(value - 1) : null),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text("$value", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
            _counterBtn(Icons.add, () => value < 8 ? onChanged(value + 1) : null),
          ],
        )
      ],
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) {
    return IconButton.filled(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDark, side: BorderSide(color: Colors.grey.shade200)),
    );
  }

  Widget _buildInteractiveCard({required VoidCallback onTap, required IconData icon, required String title}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade100)),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentBlue, size: 24),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}