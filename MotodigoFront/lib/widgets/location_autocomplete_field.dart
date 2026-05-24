import 'dart:async'; // Nécessaire pour le Timer
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/location.dart';
import '../providers/location_provider.dart';
import '../providers/user_provider.dart';
import '../services/location_services.dart';
import '../utils/app_colors.dart';

class LocationAutocompleteField extends StatefulWidget {
  final Function(Location) onLocationSelected;
  final String label;
  final TextEditingController? controller;

  const LocationAutocompleteField({
    Key? key,
    required this.onLocationSelected,
    required this.label,
    this.controller,
  }) : super(key: key);

  @override
  State<LocationAutocompleteField> createState() => _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _showSuggestions = false;
  Timer? _debounce;

  // 🔥 Ajoute cette variable pour stocker le code pays local
  String _currentLocalCountryCode = 'CM';
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();

    // 🔥 On détecte le pays réel via le GPS dès l'ouverture du composant
    _initCurrentCountry();

    _focusNode.addListener(() {
      setState(() {
        _showSuggestions = _focusNode.hasFocus;
      });
    });
  }

  //  Fonction de détection GPS
  Future<void> _initCurrentCountry() async {
    String code = await _locationService.getCountryCode();
    if (mounted) {
      setState(() {
        _currentLocalCountryCode = code;
      });
    }
  }

  //  C'est le cœur du système d'autocomplétion
  void _onSearchChanged(String query, String countryCode) {
    // Si l'utilisateur tape une nouvelle lettre, on annule le compte à rebours précédent
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // On lance un nouveau compte à rebours de 600ms
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (query.trim().length >= 2) { // Sécurité : au moins 2 caractères requis
        context.read<LocationProvider>().searchLocations(query.trim(), countryCode);
      } else {
        context.read<LocationProvider>().clearSuggestions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
   // final countryCode = context.watch<UserProvider>().userCountryCode ?? 'CM';
    final countryCode = _currentLocalCountryCode;
    final locationProv = context.watch<LocationProvider>();

    return Column(
      children: [
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (value) => _onSearchChanged(value, countryCode),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: widget.label,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.accentBlue.withOpacity(0.5), size: 20),
            suffixIcon: locationProv.isLoadingSuggestions
                ? const SizedBox(
              width: 20, height: 20,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBlue),
              ),
            )
                : (_controller.text.isNotEmpty
                ? IconButton(
                icon: const Icon(Icons.cancel_rounded, size: 18, color: Colors.grey),
                onPressed: () {
                  _controller.clear();
                  locationProv.clearSuggestions();
                })
                : null),
          ),
        ),

        // LISTE DE PROPOSITIONS (Design Premium)
        if (_showSuggestions && locationProv.suggestions.isNotEmpty)
          _buildSuggestionsList(locationProv),
      ],
    );
  }

  Widget _buildSuggestionsList(LocationProvider provider) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: provider.suggestions.length,
          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
          itemBuilder: (context, index) {
            final location = provider.suggestions[index];
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.accentBlue.withOpacity(0.05), shape: BoxShape.circle),
                child: const Icon(Icons.location_on_rounded, color: AppColors.accentBlue, size: 18),
              ),
              title: Text(location.displayName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primaryDark),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () {
                widget.onLocationSelected(location);
                _controller.text = location.displayName.split(',').first; // Juste le nom de la ville pour le style
                provider.clearSuggestions();
                _focusNode.unfocus();
              },
            );
          },
        ),
      ),
    );
  }
}