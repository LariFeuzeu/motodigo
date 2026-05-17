import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'otp_verify_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _completePhoneNumber = "";
  bool _isLoading = false;

  // ✅ On définit les codes autorisés
  final List<String> _allowedCodes = [
    'CM', 'TD', 'GA', 'CI', 'SN', 'BJ', 'TG', 'NE', 'ML', 'CG', 'CD', 'CF'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.motorcycle, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text("MotoDigo", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),

              IntlPhoneField(
                controller: _phoneController,
                initialCountryCode: 'CM',
                languageCode: "fr",
                // LA CORRECTION EST ICI :
                // On transforme nos Strings en objets 'Country' que le package comprend
                countries: countries.where((country) => _allowedCodes.contains(country.code)).toList(),

                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onChanged: (phone) {
                  _completePhoneNumber = phone.completeNumber;
                  context.read<AuthProvider>().setCountryCode(phone.countryISOCode);
                },
              ),

              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _submit,
                  child: const Text("CONTINUER", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() async {
    if (_completePhoneNumber.isEmpty || _completePhoneNumber.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez entrer un numéro valide")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.sendOtp(_completePhoneNumber, (String vId) {
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
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : ${e.toString()}")));
    }
  }
}