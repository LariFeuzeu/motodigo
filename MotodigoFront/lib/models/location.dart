// lib/models/location.dart

class Location {
  final String placeId;
  final String displayName;
  final double latitude;
  final double longitude;
  final String? country; // Correspond au champ optionnel

  Location({
    required this.placeId,
    required this.displayName,
    required this.latitude,
    required this.longitude,                               
    this.country,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      placeId: json['place_id'] as String,
      displayName: json['display_name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      country: json['country'] as String?,
    );
  }
}