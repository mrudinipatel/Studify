import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'generated/l10n/S.dart';
import 'theme_wrapper.dart';
import 'font_size_wrapper.dart';

class SettingsScreen extends StatefulWidget {

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  /* final List<Map<String, dynamic>> _settingsGen = [
    {'icon': Icons.settings, 'text': 'Setting 1', 'value': false},
    {'icon': Icons.settings, 'text': 'Setting 2', 'value': true},
    {'icon': Icons.settings, 'text': 'Setting 3', 'value': false},
  ]; */

  final List<Map<String, dynamic>> _settingsAcc = [
    {'icon': Icons.dark_mode, 'text': 'Dark Mode', 'value': false},
    {'icon': Icons.text_fields, 'text': 'Font Size', 'size': 'medium'},
    //{'icon': Icons.settings, 'text': 'Setting 3', 'value': true},
  ];

  @override
  Widget build(BuildContext context) {

    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final fontProvider = Provider.of<FontProvider>(context);
    
    return Scaffold(

      appBar: AppBar(

        title: Text(S.of(context)!.settings),

        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        leading: IconButton(

          icon: const Icon(Icons.arrow_back),

          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(

        child: Column(

          children: [
            
            // General Settings ------------------------------------------------------------------------------------------------
            /* 
            Padding(

              padding: const EdgeInsets.all(8.0),

              child: Text(S.of(context)!.generalSettings, style: TextStyle(fontWeight: FontWeight.bold)),
              // child: Text("General Settings", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListView.builder(

              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: _settingsGen.length,

              itemBuilder: (context, index) {

                final settingsGen = _settingsGen[index];

                return Card(

                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),

                  child: Padding(

                    padding: const EdgeInsets.all(16.0),

                    child: Row(

                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: <Widget>[

                        Row(

                          children: [
                            Icon(settingsGen['icon']),
                            const SizedBox(width: 16.0),
                            Text(settingsGen['text']),
                          ],
                        ),
                        Switch(

                          value: settingsGen['value'],

                          onChanged: (bool newValue) {
                            setState(() {
                              _settingsGen[index]['value'] = newValue;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ), 
            */

            // Accessibility Settings -----------------------------------------------------------------------------------------------
            Padding(

              padding: const EdgeInsets.all(8.0),
              child: Text(S.of(context)!.accessibilitySettings, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListView.builder(

              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: _settingsAcc.length,

              itemBuilder: (context, index) {

                final settingsAcc = _settingsAcc[index];

                // Dark Mode option |||||||||||||||||||||||||||||||
                if(index == 0){

                  return Card(

                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),

                    child: Padding(

                      padding: const EdgeInsets.all(16.0),

                      child: Row(

                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[

                          Row(
                            children: [
                              Icon(settingsAcc['icon']),
                              const SizedBox(width: 16.0),
                              Text(settingsAcc['text']),
                            ],
                          ),
                          Switch(

                            value: themeProvider.themeMode == ThemeMode.dark,

                            onChanged: (bool newValue) {

                              themeProvider.toggleTheme();
                              setState(() {
                                _settingsAcc[index]['value'] = newValue;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );

                // Font size option |||||||||||||||||||||||||||
                }else if (index == 1){
                  
                  return Card(

                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),

                    child: Padding(

                      padding: const EdgeInsets.all(16.0),

                      child: Row(

                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[

                          Row(
                            children: [
                              Icon(settingsAcc['icon']),
                              const SizedBox(width: 16.0),
                              Text(settingsAcc['text']),
                            ],
                          ),
                          
                          // Controls font size
                          DropdownButton<String>(

                            value: fontProvider.selectedSize,

                            items: const [
                              DropdownMenuItem(value: 'small', child: Text("Small")),
                              DropdownMenuItem(value: 'medium', child: Text("Medium")),
                              DropdownMenuItem(value: 'large', child: Text("Large")),
                            ],

                            onChanged: (String? newSize) {
                        
                              if (newSize != null) {

                                fontProvider.setSize(newSize);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                  
                }else{

                  return Card(

                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),

                    child: Padding(

                      padding: const EdgeInsets.all(16.0),

                      child: Row(

                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[

                          Row(
                            children: [
                              Icon(settingsAcc['icon']),
                              const SizedBox(width: 16.0),
                              Text(settingsAcc['text']),
                            ],
                          ),

                          Switch(

                            value: themeProvider.themeMode == ThemeMode.dark,

                            onChanged: (bool newValue) {

                              themeProvider.toggleTheme();
                              setState(() {
                                _settingsAcc[index]['value'] = newValue;
                              });
                            },
                          ),
                          
                        ],
                      ),
                    ),
                  );
                }                
              },
            ),

            // Language Settings -------------------------------------------------------------------------------------------------
            Padding(

              padding: const EdgeInsets.all(8.0),
              child: Text(S.of(context)!.languageSettings, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Card(

              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),

              child: Padding(

                padding: const EdgeInsets.all(16.0),

                child: Row(

                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [

                    Text(S.of(context)!.selectLanguage),

                    DropdownButton<String>(

                      value: languageProvider.locale.languageCode,

                      onChanged: (String? newLanguage) {
                        
                        if (newLanguage != null) {
                          languageProvider.setLanguage(newLanguage);
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text("English")),
                        DropdownMenuItem(value: 'fr', child: Text("French")),
                        DropdownMenuItem(value: 'es', child: Text("Spanish")),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
