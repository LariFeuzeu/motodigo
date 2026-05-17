import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  Future<String> getCountryCode() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Vérifier si le service GPS est activé
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return 'CM'; // Fallback par défaut

    // 2. Gérer les permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return 'CM';
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);

      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        String? code = placemarks.first.isoCountryCode;
        if (code != null && code.length == 2) {
          return code.toUpperCase(); // CM, TD, etc.
        }
      }

      // Sécurité : Si le reverse geocoding échoue, on déduit par la position brute
      // (Optionnel: tu peux ajouter une logique de périmètre ici)
      return 'CM';
    } catch (e) {
      return 'CM';
    }
  }
}