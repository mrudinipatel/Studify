import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// wrapper class to change font size
class FontProvider with ChangeNotifier {

  // load current size from shared preferences
  

  // default font size
  String _selectedSize = 'medium';

  FontProvider() {
    
    _load();
  }

  String get selectedSize => _selectedSize;

  // sets the size of the font based on input, used in settings
  void setSize(String string){

    if (string.toLowerCase() == 'small') {

      _selectedSize = 'small';

    } else if (string.toLowerCase() == 'medium') {

      _selectedSize = 'medium';

    } else if (string.toLowerCase() == 'large') {

      _selectedSize = 'large';

    } else {
      
      // default to medium in case something goes wrong
      _selectedSize = 'medium';
    }

    _save();
    notifyListeners();
  }

  // returns the current size of the font with the correct modifications, used in themeData
  double getSize(double currentSize){

    if (_selectedSize == 'small') {

      return currentSize - 2.0;

    } else if (_selectedSize == 'large') {

      return currentSize + 4.0;

    } else {

      return currentSize;
    }
  }

  // aync load saved font size so we can set app to it on startup
  Future<void> _load() async {

    final prefs = await SharedPreferences.getInstance();
    final size = prefs.getString("fontSize");

    if (size != null) {

      _selectedSize = size;      
    }

    notifyListeners();
  }

  // save curernt font size to shared preferences
  Future<void> _save() async {

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("fontSize", _selectedSize);
  }

}