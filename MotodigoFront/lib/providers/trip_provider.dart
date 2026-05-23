import 'package:flutter/material.dart';
import '../models/location.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class TripProvider with ChangeNotifier {
  final ApiService _apiService;

  // --- ÉTATS DE PUBLICATION (Objets Location complets) ---
  Location? _originCity; // La ville de départ
  Location? _pickupPoint; // Le lieu précis de ramassage (ex: Carrefour)
  Location? _destinationCity; // La ville d'arrivée
  Location? _dropoffPoint; // Le lieu précis de dépose
  List<Location> _waypoints = [];
  List<dynamic> _myBookings = []; // Pour le passager
  List<dynamic> _driverTrips = []; // Pour le chauffeur

  String _baggageSize = "Moyen";
  String _baggageDetails = "";

  // String _myBookings;
  // --- ÉTATS DE RECHERCHE & UI ---
  bool _isLoading = false;
  List<dynamic> _searchResults = [];
  int _requestedSeats = 1;

  TripProvider(this._apiService);

  // --- GETTERS ---
  Location? get origin => _originCity;

  Location? get pickup => _pickupPoint;

  Location? get destination => _destinationCity;

  Location? get dropoff => _dropoffPoint;

  List<Location> get waypoints => _waypoints;

  List<dynamic> get myBookings => _myBookings;

  List<dynamic> get driverTrips => _driverTrips;

  // fichier trip_provider.dart
  List<dynamic> get filteredTrips {
    final now = DateTime.now();
    return _searchResults.where((trip) {
      try {
        // On convertit la date du JSON en objet DateTime
        final departureDate = DateTime.parse(trip['departure_at']);
        // On ne garde que si le départ est dans le futur
        return departureDate.isAfter(now);
      } catch (e) {
        return false; // Sécurité si la date est corrompue
      }
    }).toList();
  }

  String get baggageSize => _baggageSize;

  String get baggageDetails => _baggageDetails;

  bool get isLoading => _isLoading;

  List<dynamic> get searchResults => _searchResults;

  List<dynamic> _userDiscussions = []; // Notre fameuse liste
  List<dynamic> get userDiscussions => _userDiscussions;

  // --- SETTERS (Stockage des objets Location) ---
  void setOrigin(Location loc) {
    _originCity = loc;
    notifyListeners();
  }

  void setPickup(Location loc) {
    _pickupPoint = loc;
    notifyListeners();
  }

  void setDestination(Location loc) {
    _destinationCity = loc;
    notifyListeners();
  }

  void setDropoff(Location loc) {
    _dropoffPoint = loc;
    notifyListeners();
  }

  void setBaggageSize(String size) {
    _baggageSize = size;
    notifyListeners();
  }

  void setBaggageDetails(String details) {
    _baggageDetails = details;
    notifyListeners();
  }

  void addWaypoint(Location loc) {
    _waypoints.add(loc);
    notifyListeners();
  }

  void removeWaypoint(int index) {
    _waypoints.removeAt(index);
    notifyListeners();
  }

  // --- LOGIQUE DE RECHERCHE ---
  Future<void> fetchSearchTrips(
    String origin,
    String destination,
    String date,
    String countryCode,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await _apiService.searchTrips(
        origin,
        destination,
        date,
        countryCode,
      );
      _searchResults = results;
    } catch (e) {
      _searchResults = [];
      debugPrint("🛑 Erreur recherche : $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- PUBLICATION DU TRAJET ---
  Future<bool> publishTrip({
    required int vehicleId,
    required DateTime departureAt,
    required double pricePerSeat,
    required int seatsTotal,
    required String countryCode,
    String? pickupPoint, // <--- AJOUT : Paramètre optionnel
    String? dropoffPoint, // <--- AJOUT : Paramètre optionnel
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Construction du payload JSON pour FastAPI
      final Map<String, dynamic> data = {
        'vehicle_id': vehicleId,
        'country_code': countryCode,
        'departure_at': departureAt.toIso8601String(),
        'price_per_seat': pricePerSeat,
        'seats_total': seatsTotal,

        // --- GESTION DU DÉPART (PICKUP) ---
        'origin_city': _originCity!.displayName.split(',').first.trim(),
        // On utilise pickupPoint s'il est fourni par le controller, sinon le label par défaut
        'origin_label': (pickupPoint != null && pickupPoint.isNotEmpty)
            ? pickupPoint
            : (_pickupPoint?.displayName ?? _originCity!.displayName),
        'origin_lat': _pickupPoint?.latitude ?? _originCity!.latitude,
        'origin_lng': _pickupPoint?.longitude ?? _originCity!.longitude,

        // --- GESTION DE L'ARRIVÉE (DROPOFF) ---
        'destination_city': _destinationCity!.displayName
            .split(',')
            .first
            .trim(),
        // On utilise dropoffPoint s'il est fourni, sinon le label par défaut
        'destination_label': (dropoffPoint != null && dropoffPoint.isNotEmpty)
            ? dropoffPoint
            : (_dropoffPoint?.displayName ?? _destinationCity!.displayName),
        'destination_lat':
            _dropoffPoint?.latitude ?? _destinationCity!.latitude,
        'destination_lng':
            _dropoffPoint?.longitude ?? _destinationCity!.longitude,

        // Liste des escales
        'waypoints': _waypoints
            .map(
              (w) => {
                'city': w.displayName.split(',').first.trim(),
                'label': w.displayName,
                'lat': w.latitude,
                'lng': w.longitude,
              },
            )
            .toList(),

        'baggage_size': _baggageSize,
        'baggage_details': _baggageDetails,
      };

      debugPrint("🚀 Payload envoyé avec Pickup/Dropoff : $data");

      await _apiService.postTrip(data);
      _resetFields();
      return true;
    } catch (e) {
      debugPrint("🛑 Erreur lors de la publication : $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- RÉSERVATION ---
  Future<bool> bookTrip({
    required int tripId,
    required String paymentMethod,
    required int seatsCount,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.postBooking({
        'trip_id': tripId,
        'seats_booked': seatsCount,
        'payment_method': paymentMethod,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        // On cherche le trajet dans notre liste locale
        final index = _searchResults.indexWhere((t) => t['id'] == tripId);
        if (index != -1) {
          _searchResults[index]['seats_available'] -= seatsCount;

          notifyListeners(); // On prévient l'UI de se redessiner
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("🛑 Erreur réservation : $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> cancelBooking(
    int bookingId,
    int tripId,
    int seatsToRestore,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      //  Appel API via ton ApiService
      await _apiService.cancelBooking(bookingId);

      //  Mise à jour locale du compteur de places
      final index = _searchResults.indexWhere((t) => t['id'] == tripId);
      if (index != -1) {
        // On rajoute les places libérées (comme dans ton code Python)
        int currentSeats =
            int.tryParse(_searchResults[index]['seats_available'].toString()) ??
            0;
        _searchResults[index]['seats_available'] =
            currentSeats + seatsToRestore;
      }

      notifyListeners();
      return null; // Pas d'erreur
    } catch (e) {
      // On retourne le message d'erreur du backend (ex: "Moins de 12h")
      return e.toString().replaceAll("Exception: ", "");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- POUR LE PASSAGER ---
  Future<String?> handlePassengerCancel(
    int bookingId,
    DateTime departureAt,
  ) async {
    // Vérification locale immédiate (Gain de temps/réseau)
    // if (DateTime.now().add(const Duration(hours: 12)).isAfter(departureAt)) {
    //   return "Impossible d'annuler moins de 12h avant le départ.";
    // }

    try {
      _isLoading = true;
      notifyListeners();

      // Appel à ton ApiService
      await _apiService.cancelBooking(bookingId);

      // On retire la réservation de la liste locale 'Mes Réservations'
      _myBookings.removeWhere((booking) {
        // Si booking est un objet de ton modèle Booking, utilise booking.id
        // Si booking est un Map JSON, utilise booking['id']
        final id = (booking is Map) ? booking['id'] : booking.id;
        return id == bookingId;
      });
      return null; // Succès
    } catch (e) {
      debugPrint("Erreur annulation passager: $e");
      return e.toString().replaceAll("Exception: ", "");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- POUR LE CHAUFFEUR ---
  Future<bool> handleDriverCancel(int tripId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _apiService.cancelTrip(tripId);

      // Mise à jour propre de l'état local
      final index = _driverTrips.indexWhere((t) => t['id'] == tripId);
      if (index != -1) {
        _driverTrips[index]['status'] =
            "Cancelled"; // On met à jour le statut dans la Map
      }

      return true;
    } catch (e) {
      debugPrint("Erreur annulation chauffeur: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserBookings() async {
    _isLoading = true;
    notifyListeners();

    try {
      // On va chercher les données sur le serveur
      final results = await _apiService.getMyBookings();

      //  On les stocke dans notre variable locale
      _myBookings = results;

      notifyListeners(); // L'écran "Mes Réservations" va se dessiner tout seul !
    } catch (e) {
      debugPrint("Erreur: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Charger mes trajets en tant que CHAUFFEUR
  Future<void> fetchDriverTrips() async {
    _isLoading = true;
    notifyListeners();
    try {
      _driverTrips = await _apiService
          .getMyPublishedTrips(); // GET /trips/meTrips
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- RÉINITIALISATION ---
  void _resetFields() {
    _originCity = null;
    _pickupPoint = null;
    _destinationCity = null;
    _dropoffPoint = null;
    _waypoints = [];
    _baggageSize = "Moyen";
    _baggageDetails = "";
    notifyListeners();
  }

  //  RÉCUPÉRER LES PASSAGERS Pour le chauffeur
  Future<List<dynamic>> getTripPassengers(int tripId) async {
    // Optionnel.... ajouter un indicateur de chargement ici si besoin
    try {
      // On passe bien le tripId à la méthode du service
      final List<dynamic> results = await _apiService.getTripPassengers(tripId);

      //  On retourne directement les résultats reçus
      return results;
    } catch (e) {
      debugPrint(" Erreur Provider getTripPassengers: $e");
      // En cas d'erreur, on retourne une liste vide pour ne pas faire planter l'UI
      return [];
    }
  }

  // CHATPROVIDER
  List<dynamic> _chatMessages = []; // Le coffre-fort local des messages
  bool _isChatLoading =
      false; // Pour savoir si on affiche un petit cercle de chargement

  List<dynamic> get chatMessages => _chatMessages;

  bool get isChatLoading => _isChatLoading;

  // FONCTION POUR CHARGER LES DISCUSSIONS
  Future<void> fetchUserDiscussions() async {
    _isLoading = true;
    notifyListeners();

    try {
      // On appelle l'API qu'on a créée plus haut
      final List<dynamic> results = await _apiService.getUserDiscussions();
      _userDiscussions = results;
    } catch (e) {
      debugPrint("Erreur chargement discussions: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Filtrer les messages pour un trajet spécifique en local
  List<dynamic> getMessagesByTrip(int tripId) {
    return _chatMessages.where((m) => m['trip_id'] == tripId).toList();
  }

  // --- RÉCUPÉRER L'HISTORIQUE API ---
  Future<void> fetchMessages(int tripId) async {
    _isChatLoading = true; // On prévient l'app qu'on charge
    notifyListeners(); // L'UI affiche le chargement

    try {
      // On appelle le transporteur (ApiService)
      final List<dynamic> results = await _apiService.getChatMessages(tripId);
      // On remplace l'ancienne liste par la nouvelle reçue du serveur
      _chatMessages = results;
    } catch (e) {
      debugPrint("❌ Erreur fetchMessages: $e");
    } finally {
      _isChatLoading = false; // fini
      notifyListeners(); // L'UI affiche les messages
    }
  }

  // --- ENVOYER UN MESSAGE (API) ---
  Future<bool> sendMessage({
    required int tripId,
    required int receiverId,
    required String content,
  }) async {
    try {
      // On prépare le petit colis pour le serveur

      final Map<String, dynamic> msgData = {
        'trip_id': tripId,
        'receiver_id': receiverId,
        'content': content,
      };
      //  On demande à l'ApiService d'envoyer
      final response = await _apiService.postChatMessage(msgData);

      // Si le serveur confirme l'enregistrement
      if (response != null) {
        // On l'ajoute IMMÉDIATEMENT à notre liste locale pour que l'utilisateur le voi
        _chatMessages.add(response);
        notifyListeners(); // Mise à jour de l'écran
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Erreur sendMessage: $e");
      return false;
    }
  }

  //  NETTOYAGE DU CHAT
  void clearChat() {
    _chatMessages = [];
    notifyListeners();
  }
  Future<void> updateTripStatut(int tripId, String newStatus) async {
    try {
      _isLoading = true;
      notifyListeners();

      late final Response response;
      if (newStatus == 'started') {
        response = await _apiService.startTrip(tripId);
      } else {
        response = await _apiService.completeTrip(tripId);
      }

      debugPrint("🌐 [TripProvider] Code retour API : ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        //  CORRECTION ULTRA-SAFE : On met à jour directement le statut dans notre liste locale
        final index = _driverTrips.indexWhere((t) => t['id'] == tripId);
        if (index != -1) {
          _driverTrips[index]['status'] = newStatus;
          debugPrint("Statut mis à jour en local pour le trajet $tripId");
        }
      }

    } catch (e) {
      debugPrint("❌ Erreur updateTripStatus ($newStatus): $e");
    } finally {
      _isLoading = false;
      notifyListeners(); //  On éteint obligatoirement le spinner ici
    }
  }
}

