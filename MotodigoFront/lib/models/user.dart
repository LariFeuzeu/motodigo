import 'package:untitled/models/vehicle.dart';

class User {
  final int id;
  final String firebaseUid;
  final String fullName;
  final String email;
  final String phone; // Ajout du téléphone pour la cohérence
  final String role;
  final String? countryCode;
  final int? vehicleId;
  final String? profilePhotoUrl;
  final String? requestedRole; // Optionnel (peut être null)
  final List<Vehicle> vehicles;
  final double rating;
  User({
    required this.id,
    required this.firebaseUid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.profilePhotoUrl,
    this.countryCode,
    this.requestedRole,
    this.vehicleId,
    this.vehicles = const [],
    required this.rating,
  });

  // Factory Constructor pour créer un objet User à partir du JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      firebaseUid: json['firebase_uid']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      rating: (json['rating'] ?? 0.0).toDouble(),
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      // La solution pour ton erreur : utiliser .toString() si ce n'est pas null
      requestedRole: json['requested_role']?.toString(),
      vehicles: json['vehicules'] != null
          ? (json['vehicules'] as List).map((v) => Vehicle.fromJson(v)).toList()
          : [],
    );
  }

  // Méthode pour vérifier si l'utilisateur est un chauffeur validé
  bool get isDriverValidated => role == 'driver';

  // Méthode pour vérifier si le compte est en cours de validation
  bool get isValidationPending => role == 'passenger' && requestedRole == 'driver';
}