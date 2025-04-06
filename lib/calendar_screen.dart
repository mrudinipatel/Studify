import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

// a class that manages a calendar from the table_calendar package
// Logic has been based off of the provided examples from the pub.dev page for table_calendar
// The user can scroll the calendar, select days and then add deadlines to the selected day
class CalendarScreen extends StatefulWidget{

  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>{

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Pre-populating some events so that there are some to show right away
  final Map<DateTime, List<Event>> _events = {

    DateTime.utc(2025, 4, 20): [

      const Event('Meeting'),
      const Event('Project Due')
    ],

    DateTime.utc(2025, 4, 22): [
      
      const Event('Birthday Party')
    ],

    DateTime.utc(2025, 4, 5): [
      
      const Event('Vacation Start')
    ],
  };

  // returns the list of events for a certain day
  List<Event> _getEventsForDay(DateTime day) {

    return _events[day] ?? [];
  }

  // adds an event to the event list
  void _addEvent(DateTime date, Event event) {

    setState(() {

      if (_events.containsKey(date)) {
        _events[date]!.add(event);
      } else {
        _events[date] = [event];
      }
    });
  }

  // handles day selection, logic from the pub.dev page for table_calendar
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {

    if (!isSameDay(_selectedDay, selectedDay)) {

      setState(() {

        _selectedDay = selectedDay;
        // /_focusedDay = focusedDay;
      });
    }
  }

  // removes an event from the list of events
  void _removeEvent(DateTime date, Event event) {

    setState(() {

      _events[date]?.remove(event);

      if (_events[date]?.isEmpty ?? false) {

        _events.remove(date);
      }
    });
  }

  @override
  void initState(){

    super.initState();
  }

  @override
  void dispose(){

    super.dispose();
  }

  @override
  Widget build(BuildContext context){

    return Scaffold(

      appBar: AppBar(

        title: Text("Calendar"),

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

            // Table Calendar widget from table_calendar
            // It's values are set based on the examples given on the pub.dev page 
            TableCalendar(

              firstDay: DateTime.utc(2000, 10, 10),
              lastDay: DateTime.utc(2050, 10, 10),
              focusedDay: _focusedDay,

              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },

              onDaySelected: _onDaySelected,

              calendarFormat: _calendarFormat,

              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },

              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },

              // built into the widget, eventLoader shows the amount of events per day on the calendar, up to 4
              eventLoader: (day) {
                return _getEventsForDay(day);
              },

              
            ),

            // checking if we have selected a day, if we have show a button that allows us to add a deadline, as well as a list of 
            //    deadlines for that day
            if (_selectedDay != null)

              Column(

                crossAxisAlignment: CrossAxisAlignment.center,

                children: [

                  Padding(

                    padding: const EdgeInsets.all(8.0),

                    child: ElevatedButton(

                      onPressed: () {

                        showDialog(

                          context: context,

                          builder: (context) {

                            String eventText = '';

                            // popup to add a deadline
                            return AlertDialog(

                              title: const Text('Add Deadline'),

                              content: TextField(

                                onChanged: (text) {

                                  eventText = text;
                                },
                              ),
                              actions: [

                                TextButton(

                                  onPressed: () {

                                    Navigator.pop(context);
                                  },
                                  child: const Text('Cancel'),
                                ),

                                TextButton(

                                  onPressed: () {

                                    if (eventText.isNotEmpty) {

                                      // add a deadline to the calendar
                                      _addEvent(_selectedDay!, Event(eventText));
                                    }

                                    Navigator.pop(context);
                                  },
                                  child: const Text('Add'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Text('Add Deadline'),
                    ),
                  ),

                  const Padding(

                    padding: EdgeInsets.only(left: 8.0, top: 8.0, bottom: 8.0),

                    child: Text(

                      "Deadlines on selected day:",

                      style: TextStyle(

                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // builds a list of cards that show the current deadlines for the selected day
                  ListView.builder(

                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),

                    itemCount: _getEventsForDay(_selectedDay!).length,

                    itemBuilder: (context, index) {

                      // gets all events for the current day
                      final event = _getEventsForDay(_selectedDay!)[index];

                      return Card(

                        margin: const EdgeInsets.all(8.0),

                        child: Padding(

                          padding: const EdgeInsets.all(16.0),
                          child: Row(

                            children: [

                              Expanded(

                                child: Text(event.title),
                              ),

                              // allows the user to delete a deadline
                              IconButton(

                                icon: const Icon(Icons.delete),

                                onPressed: () {

                                  _removeEvent(_selectedDay!, event);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                ]
              )
            else
              const Padding(

                padding: EdgeInsets.all(10.0),
                
              ),

          ],
        )

        
      )
    );
  }
}

// basic class for an event/deadline, from the pub.dev examples for table_calendar
class Event {
  final String title;

  const Event(this.title);

  @override
  String toString() => title;
}