// lib/screens/phone_input_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/location_services.dart';
import '../utils/app_constants.dart'; // Importation de tes constantes globales
import '../utils/app_colors.dart';
import 'otp_verify_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();

  String _completePhoneNumber = "";
  String _detectedCountryCode = 'CM'; // Valeur par défaut
  bool _isLoading = false;
  bool _isCountryLoaded = false; // Bloque l'UI le temps que le GPS réponde

  @override
  void initState() {
    super.initState();
    _initDeviceCountry();
  }

  // Détection automatique du pays de l'appareil via le GPS local
  Future<void> _initDeviceCountry() async {
    final locationService = LocationService();
    String code = await locationService.getCountryCode();

    // Si le pays de l'appareil n'est pas dans ta liste autorisée, fallback sur le Cameroun
    if (!AppConstants.allowedCountries.contains(code)) {
      code = 'CM';
    }

    if (mounted) {
      setState(() {
        _detectedCountryCode = code;
        _isCountryLoaded = true;
      });
      // Synchronisation immédiate du code pays initial avec ton AuthProvider
      context.read<AuthProvider>().setCountryCode(code);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Évite le sursaut visuel (le drapeau qui change brusquement après le build)
    if (!_isCountryLoaded) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Form(
            key: _formKey, // Clé de validation globale du formulaire
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.motorcycle, size: 80, color: Colors.orange),
                const SizedBox(height: 20),
                const Text("MotoDigo", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),

                IntlPhoneField(
                  controller: _phoneController,
                  initialCountryCode: _detectedCountryCode, // Devient dynamique grâce au GPS
                  languageCode: "fr",

                  //  Utilisation de la liste centralisée et propre
                  countries: countries.where((country) => AppConstants.allowedCountries.contains(country.code)).toList(),

                  decoration: InputDecoration(
                    labelText: 'Numéro de téléphone',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  invalidNumberMessage: "Numéro de téléphone invalide",
                  onChanged: (phone) {
                    _completePhoneNumber = phone.completeNumber;
                    context.read<AuthProvider>().setCountryCode(phone.countryISOCode);
                  },
                ),

                const SizedBox(height: 30),
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.orange)
                    : SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: _submit,
                    child: const Text("CONTINUER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() async {
    // Validation stricte : longueur, indicatif et structure selon le pays
    if (!_formKey.currentState!.validate() || _completePhoneNumber.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.sendOtp(_completePhoneNumber, (String vId) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerifyScreen(
              phoneNumber: _completePhoneNumber,
              verificationId: vId,
            ),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : ${e.toString()}"))
      );
    }
  }
}