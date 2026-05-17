import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/location.dart';


class LocationProvider with ChangeNotifier{
  final ApiService _apiService;


  List<Location> _suggestions = [];
  bool _isLoadingSuggestions = false;

  List<Location> get suggestions => _suggestions;
  bool  get isLoadingSuggestions => _isLoadingSuggestions;
  LocationProvider (this._apiService); // initialisation avec Api service

  //Fonction appele le champ de text lors de la saisie

  Future<void> searchLocations(String query, String countryCode) async{
    if(query.length < 3){
      _suggestions = [];
      notifyListeners();
      return;
    }
    _isLoadingSuggestions = true;
    notifyListeners();
    try {
      _suggestions = await _apiService.searchLocation(query, countryCode);
    } catch (e){
      debugPrint("Erreur de recherche de localisation: $e");
          // vider la la liste si erreur reseau
      _suggestions = [];
    } finally {
      _isLoadingSuggestions = false;
      notifyListeners();
    }
  }
  void clearSuggestions(){
    _suggestions = [];
    notifyListeners();
  }
}