import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import '../../providers/user_provider.dart';
import '../../utils/app_colors.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  const VehicleRegistrationScreen({super.key});

  @override
  State<VehicleRegistrationScreen> createState() => _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _seatsController = TextEditingController();

  File? _vehiclePhoto; // Nouvelle variable pour la photo
  File? _regCardFile;
  File? _techInspFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _modelController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  Future<File?> _pickFile({bool isImageOnly = false}) async {
    try {
      final XTypeGroup typeGroup = XTypeGroup(
        label: isImageOnly ? 'images' : 'documents',
        extensions: isImageOnly ? <String>['jpg', 'jpeg', 'png'] : <String>['jpg', 'jpeg', 'png', 'pdf'],
      );

      final XFile? xfile = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (xfile == null) return null;
      return File(xfile.path);
    } catch (e) {
      debugPrint("Erreur sélection : $e");
      return null;
    }
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate() ||
        _vehiclePhoto == null ||
        _regCardFile == null ||
        _techInspFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez ajouter la photo du véhicule et les documents.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Provider.of<UserProvider>(context, listen: false).registerVehicleAndPromote(
        vehicleData: {
          'model_name': _modelController.text.trim(),
          'plate': _plateController.text.trim(),
          'color': _colorController.text.trim(),
          'seats': _seatsController.text.trim(),
        },
        vehiclePhoto: _vehiclePhoto!, // À ajouter dans ton UserProvider
        regCardFile: _regCardFile!,
        techInspFile: _techInspFile!,
      );

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: AppColors.errorRed),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double scale = MediaQuery.of(context).size.width / 375;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("DEVENIR CHAUFFEUR",
            style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w900, fontSize: 14 * scale, letterSpacing: 1.2)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(24 * scale),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoStep(scale),
              SizedBox(height: 32 * scale),

              Text("INFOS VÉHICULE", style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
              SizedBox(height: 16 * scale),
              Row(
                children: [
                  Expanded(child: _buildField(_modelController, "Modèle (ex: Toyota)", Icons.motorcycle)),
                  SizedBox(width: 12 * scale),
                  Expanded(child: _buildField(_plateController, "Immatriculation", Icons.vignette)),
                ],
              ),
              SizedBox(height: 12 * scale),
              Row(
                children: [
                  Expanded(child: _buildField(_colorController, "Couleur", Icons.palette)),
                  SizedBox(width: 12 * scale),
                  Expanded(child: _buildField(_seatsController, "Places", Icons.event_seat, type: TextInputType.number)),
                ],
              ),

              SizedBox(height: 32 * scale),
              Text("DOCUMENTS OFFICIELS", style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
              SizedBox(height: 16 * scale),

              _documentPicker(
                  title: "Carte Grise",
                  file: _regCardFile,
                  onTap: () async {
                    final f = await _pickFile();
                    if (f != null) setState(() => _regCardFile = f);
                  }
              ),
              SizedBox(height: 12 * scale),
              _documentPicker(
                  title: "Assurance / Contrôle Technique",
                  file: _techInspFile,
                  onTap: () async {
                    final f = await _pickFile();
                    if (f != null) setState(() => _techInspFile = f);
                  }
              ),

              SizedBox(height: 40 * scale),
              _buildSubmitButton(scale),
              SizedBox(height: 20 * scale),
            ],
          ),
        ),
      ),
    );
  }

  // --- SECTION PHOTO DU VÉHICULE ---
  Widget _buildPhotoStep(double scale) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final f = await _pickFile(isImageOnly: true);
              if (f != null) setState(() => _vehiclePhoto = f);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 160 * scale,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _vehiclePhoto != null ? AppColors.accentBlue : Colors.grey.shade200,
                  width: 2,
                ),
                image: _vehiclePhoto != null
                    ? DecorationImage(image: FileImage(_vehiclePhoto!), fit: BoxFit.cover)
                    : null,
              ),
              child: _vehiclePhoto == null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, size: 40, color: AppColors.accentBlue),
                  const SizedBox(height: 8),
                  const Text("Ajouter une photo du véhicule", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                ],
              )
                  : const SizedBox.shrink(),
            ),
          ),
          if (_vehiclePhoto != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text("Cliquez pour changer la photo", style: TextStyle(color: AppColors.accentBlue, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String hint, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, size: 20, color: AppColors.primaryDark),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(18),
      ),
      validator: (v) => (v == null || v.isEmpty) ? "Obligatoire" : null,
    );
  }

  Widget _documentPicker({required String title, required File? file, required VoidCallback onTap}) {
    bool hasFile = file != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: hasFile ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: hasFile ? Colors.green : Colors.grey.shade200, width: 2),
        ),
        child: Row(
          children: [
            Icon(hasFile ? Icons.check_circle : Icons.description_outlined, color: hasFile ? Colors.green : AppColors.primaryDark),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  Text(hasFile ? "Document chargé" : "Cliquer pour joindre", style: TextStyle(color: hasFile ? Colors.green : Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            if (!hasFile) Icon(Icons.add_circle_outline, color: AppColors.accentBlue, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(double scale) {
    return SizedBox(
      width: double.infinity,
      height: 60 * scale,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegistration,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("ACTIVER MON PROFIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
      ),
    );
  }
}