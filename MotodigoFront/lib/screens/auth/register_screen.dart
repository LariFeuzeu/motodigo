import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import '../../utils/app_colors.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  final String idToken;
  const RegisterScreen({super.key, required this.idToken});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _selectedRole = 'passenger';
  bool _isLoading = false;
  bool _obscurePassword = true;


  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50, // On réduit la qualité pour l'envoi réseau (Cameroun friendly)
      );

      if (pickedFile != null && mounted) {
        // On envoie le fichier au Provider (qu'on a modifié ensemble)
        context.read<AuthProvider>().setProfileImage(File(pickedFile.path));
      }
    } catch (e) {
      debugPrint("Erreur picking image: $e");
    }
  }



  Future<void> _handleProfileCompletion() async {
    if (!_formKey.currentState!.validate()) return;
    if (context.read<AuthProvider>().profileImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez ajouter une photo de profil")),
      );
      return;
    }
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact(); // Vibration pro au clic

    try {
      final profileData = {
        'id_token': widget.idToken,
        'full_name': "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}",
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'role': _selectedRole,
        'country_code': context.read<AuthProvider>().currentCountryCode, // Récupération auto
      };

      await Provider.of<AuthProvider>(context, listen: false).register(profileData);

      if (!mounted) return;
      if (_selectedRole == 'driver') {
        Navigator.pushReplacementNamed(context, '/vehicle-registration');
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: ${e.toString()}"), backgroundColor: AppColors.errorRed, behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text("1/2", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text("Créer votre compte",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primaryDark, letterSpacing: -1)),
                const SizedBox(height: 8),
                Text("Rejoignez la communauté MotoDigo dès maintenant.",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16, height: 1.5)),

                const SizedBox(height: 40),


                //  AJOUT DE L'AVATAR PICKER
                Center(
                  child: Stack(
                    children: [
                      Consumer<AuthProvider>(
                        builder: (context, auth, child) {
                          return CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: auth.profileImageFile != null
                                ? FileImage(auth.profileImageFile!)
                                : null,
                            child: auth.profileImageFile == null
                                ? const Icon(Icons.person_rounded, size: 50, color: Colors.grey)
                                : null,
                          );
                        },
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage, // On va créer cette fonction
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.accentBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Center(child: Text("Ajouter une photo", style: TextStyle(color: Colors.grey, fontSize: 13))),



                // RÔLE SELECTOR EN PREMIER (Design Uber)
                const Text("Vous êtes ?", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primaryDark)),
                const SizedBox(height: 16),
                _buildRoleSelector(),

                const SizedBox(height: 35),

                // CHAMPS DE SAISIE
                _buildPremiumField(
                  controller: _firstNameController,
                  label: "Prénom",
                  hint: "Ex: Jean",
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 20),
                _buildPremiumField(
                  controller: _lastNameController,
                  label: "Nom",
                  hint: "Ex: Dupont",
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 20),
                _buildPremiumField(
                  controller: _emailController,
                  label: "Email",
                  hint: "prenom@exemple.com",
                  icon: Icons.email_outlined,
                  type: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                _buildPremiumField(
                  controller: _passwordController,
                  label: "Mot de passe",
                  hint: "••••••••",
                  icon: Icons.lock_open_rounded,
                  obscureText: _obscurePassword,
                  suffix: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),

                const SizedBox(height: 50),

                // BOUTON DE VALIDATION
                _buildSubmitButton(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: type,
          obscureText: obscureText,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            prefixIcon: Icon(icon, color: AppColors.accentBlue, size: 22),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200, width: 2)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentBlue, width: 2)),
            errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.errorRed, width: 1)),
          ),
          validator: (v) => v!.isEmpty ? "Obligatoire" : null,
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Row(
      children: [
        _roleOption("Passager", Icons.directions_walk_rounded, "passenger"),
        const SizedBox(width: 16),
        _roleOption("Chauffeur", Icons.two_wheeler_rounded, "driver"),
      ],
    );
  }

  Widget _roleOption(String title, IconData icon, String value) {
    bool isSelected = _selectedRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedRole = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? AppColors.primaryDark : Colors.grey.shade200, width: 1.5),
            boxShadow: isSelected ? [BoxShadow(color: AppColors.primaryDark.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))] : [],
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade400, size: 28),
              const SizedBox(height: 10),
              Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.accentBlue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleProfileCompletion,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : const Text("CRÉER MON COMPTE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      ),
    );
  }
}