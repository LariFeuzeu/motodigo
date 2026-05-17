class Vehicle {
  final int id;
  final int driverId;
  final String make;
  final String modelName; // Assure-toi que c'est model_name ici
  final String plate;
  final int seats;
  final String? color;

  Vehicle({
    required this.id,
    required this.driverId,
    required this.make,
    required this.modelName,
    required this.plate,
    required this.seats,
    this.color,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] ?? 0,
      driverId: json['driver_id'] ?? 0,
      // On utilise ?? '' pour éviter les erreurs de nullité
      make: json['make']?.toString() ?? '',
      modelName: json['model_name']?.toString() ?? '', // Important: model_name
      plate: json['plate']?.toString() ?? '',
      seats: json['seats'] ?? 0,
      color: json['color']?.toString(),
    );
  }

  String get displayName => "$make $modelName".trim();
}