import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// wrapper class to handle switching of themes via a toggle
class ThemeProvider with ChangeNotifier {

  // default theme
  ThemeMode _themeMode = ThemeMode.light;
  String currentTheme = 'light';

  // get theme from apps
  ThemeMode get themeMode => _themeMode;

  ThemeProvider(){

    _load();
  }

  // switch theme
  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;    

    if(_themeMode == ThemeMode.dark){

      currentTheme = "dark";
    }else{

      currentTheme = "light";
    }

    _save();
    notifyListeners();
  }

  // load current saved theme
  Future<void> _load() async {

    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString("currentTheme");

    if (theme != null) {
      
      // if statement to check return string and then set themeMode

      if(theme == "dark"){

        _themeMode = ThemeMode.dark;
        currentTheme = "dark";
      }else{

        _themeMode = ThemeMode.light;
        currentTheme = "light";
      }
    }

    notifyListeners();
  }

  // save curernt theme to shared preferences
  Future<void> _save() async {

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("currentTheme", currentTheme);
  }
}