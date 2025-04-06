import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pomodoro_timer.dart';
import 'references_guide.dart';
import 'study_tools_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'animation_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'language_provider.dart';
import 'generated/l10n/S.dart';
import 'theme_wrapper.dart';
import 'auth_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'font_size_wrapper.dart';
import 'calendar_screen.dart';


const supabaseUrl = 'https://hrddwwsiinasnopwldif.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhyZGR3d3NpaW5hc25vcHdsZGlmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MTU1Mzg2NiwiZXhwIjoyMDU3MTI5ODY2fQ.QU3CoAR_dcEqXcl-H15bI5lpUYruUzktMPl3h2bxbxc';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  final languageProvider = LanguageProvider();
  await languageProvider.loadLanguage();

  // use a multiprovider to reload the app when dark mode is toggled or language is changed
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => FontProvider()),
      ],
      child: const Studify(),
    ),
  );
}

class Studify extends StatelessWidget {

  const Studify({super.key});

  @override
  Widget build(BuildContext context) {

    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final fontProvider = Provider.of<FontProvider>(context);

    final pageTransitionsTheme = const PageTransitionsTheme(

      builders: <TargetPlatform, PageTransitionsBuilder>{

        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        
      },
    );

    return MaterialApp(
      locale: languageProvider.locale,
      supportedLocales: S.supportedLocales,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'Studify',

      // regular theme for the app
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        pageTransitionsTheme: pageTransitionsTheme,

        // setting font sizes so they can be modified
        textTheme: TextTheme(

          displayLarge:   TextStyle(fontSize: fontProvider.getSize(57)),
          displayMedium:  TextStyle(fontSize: fontProvider.getSize(45)),
          displaySmall:   TextStyle(fontSize: fontProvider.getSize(36)),
          headlineLarge:  TextStyle(fontSize: fontProvider.getSize(32)),
          headlineMedium: TextStyle(fontSize: fontProvider.getSize(28)),
          headlineSmall:  TextStyle(fontSize: fontProvider.getSize(24)),
          titleLarge:     TextStyle(fontSize: fontProvider.getSize(22)),
          titleMedium:    TextStyle(fontSize: fontProvider.getSize(16)),
          titleSmall:     TextStyle(fontSize: fontProvider.getSize(14)),
          labelLarge:     TextStyle(fontSize: fontProvider.getSize(14)),
          labelMedium:    TextStyle(fontSize: fontProvider.getSize(12)),
          labelSmall:     TextStyle(fontSize: fontProvider.getSize(11)),     
          bodyLarge:      TextStyle(fontSize: fontProvider.getSize(16)),
          bodyMedium:     TextStyle(fontSize: fontProvider.getSize(14)),
          bodySmall:      TextStyle(fontSize: fontProvider.getSize(12)),    
          
        ),

        useMaterial3: true,
      ),
      // dark theme for the app
      darkTheme: ThemeData(

        colorScheme: ColorScheme.fromSeed(

          seedColor:  Colors.deepPurple, 
          brightness: Brightness.dark,
          
        ), 
        pageTransitionsTheme: pageTransitionsTheme,

        // setting font sizes so they can be modified
        textTheme: TextTheme(

          displayLarge:   TextStyle(fontSize: fontProvider.getSize(57)),
          displayMedium:  TextStyle(fontSize: fontProvider.getSize(45)),
          displaySmall:   TextStyle(fontSize: fontProvider.getSize(36)),
          headlineLarge:  TextStyle(fontSize: fontProvider.getSize(32)),
          headlineMedium: TextStyle(fontSize: fontProvider.getSize(28)),
          headlineSmall:  TextStyle(fontSize: fontProvider.getSize(24)),
          titleLarge:     TextStyle(fontSize: fontProvider.getSize(22)),
          titleMedium:    TextStyle(fontSize: fontProvider.getSize(16)),
          titleSmall:     TextStyle(fontSize: fontProvider.getSize(14)),
          labelLarge:     TextStyle(fontSize: fontProvider.getSize(14)),
          labelMedium:    TextStyle(fontSize: fontProvider.getSize(12)),
          labelSmall:     TextStyle(fontSize: fontProvider.getSize(11)),     
          bodyLarge:      TextStyle(fontSize: fontProvider.getSize(16)),
          bodyMedium:     TextStyle(fontSize: fontProvider.getSize(14)),
          bodySmall:      TextStyle(fontSize: fontProvider.getSize(12)), 
        ),

        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: themeProvider.themeMode,
      home: const AuthScreen(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _client = Supabase.instance.client;
  int? _activeCourse;
  final _courseName = TextEditingController();
  final _addTopic = TextEditingController();
  final _addCourse = TextEditingController();
  final _topicName = TextEditingController();
  Future? _courses;
  Future? _topics;
  late User _user;

  @override
  void initState() {
    super.initState();
    _user = _client.auth.currentUser!;
    _courses = _client
      .from('courses')
      .select()
      .eq('user', _user.id);
  }

  void _deleteTopic(Map topic) async {
    await Supabase.instance.client
      .from('topics')
      .delete()
      .eq('topic', topic['topic'])
      .eq('course', _activeCourse!);
    setState(() {
      _topics = Supabase.instance.client
        .from('topics')
        .select()
        .eq('course', _activeCourse!);
    });
  }

  @override
  Widget build(BuildContext context) {

    // var for themeing
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      // Header
      appBar: AppBar(
        leading: Icon(Icons.school),
        title: Text('Studify'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [

          // Button for dark mode
          IconButton(

            icon: Icon(themeProvider.themeMode == ThemeMode.light
                ? Icons.dark_mode
                : Icons.light_mode),

            onPressed: () {

              // toggle theme betwene dark and default
              themeProvider.toggleTheme();
              setState(() {});
            },
          ),

          // button for settings
          IconButton(
            onPressed: (){
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },

            icon: Icon(Icons.settings),
          ),

        ],
      ),
      // Main content
      body: Column(
        children: [
          // Courses
          SizedBox(
            height: 50,
            child: Row(
              children: <Widget>[
                FutureBuilder(
                  future: _courses,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return CircularProgressIndicator();
                    }
                    final courses = snapshot.data!;
                    return Expanded(
                      child: courses.isEmpty
                      ? Padding(padding: EdgeInsets.all(10), child: Text('No courses'))
                      : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: courses.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.all(5),
                            child: ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  _activeCourse = courses[index]['id'];
                                  _topics = _client
                                    .from('topics')
                                    .select()
                                    .eq('course', _activeCourse!);
                                });
                              },
                              onLongPress: () {
                                setState(() => _activeCourse = courses[index]['id']);
                                _courseName.text = courses[index]['course'];
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return Dialog(
                                      child: Container(
                                        padding: EdgeInsets.all(20),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            TextField(
                                              controller: _courseName,
                                              decoration: InputDecoration(
                                                labelText: 'Course name',
                                                suffixIcon: IconButton(
                                                  onPressed: () async {
                                                    if (_courseName.text.isNotEmpty) {
                                                      await _client
                                                        .from('courses')
                                                        .update({'course': _courseName.text})
                                                        .eq('id', _activeCourse!);
                                                      setState(() {
                                                        _courses = _client
                                                          .from('courses')
                                                          .select()
                                                          .eq('user', _user.id);
                                                      });
                                                    }
                                                    if (context.mounted) Navigator.pop(context);
                                                    _courseName.clear();
                                                  },
                                                  icon: Icon(Icons.edit),
                                                ),
                                              ),
                                            ),
                                            TextField(
                                              controller: _addTopic,
                                              decoration: InputDecoration(
                                                labelText: 'Add topic',
                                                suffixIcon: IconButton(
                                                  onPressed: () async {
                                                    if (_addTopic.text.isNotEmpty) {
                                                      await _client
                                                        .from('topics')
                                                        .insert({
                                                          'topic': _addTopic.text,
                                                          'course': courses[index]['id']
                                                        });
                                                      if (_activeCourse == courses[index]['id']) {
                                                        setState(() {
                                                          _topics = _client
                                                            .from('topics')
                                                            .select()
                                                            .eq('course', courses[index]['id']);
                                                        });
                                                      }
                                                    }
                                                    if (context.mounted) Navigator.pop(context);
                                                    _addTopic.clear();
                                                  },
                                                  icon: Icon(Icons.add),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () async {
                                                await _client
                                                  .from('courses')
                                                  .delete()
                                                  .eq('id', courses[index]['id']);
                                                setState(() {
                                                  _courses = _client
                                                    .from('courses')
                                                    .select()
                                                    .eq('user', _user.id);
                                                });
                                                if (context.mounted) Navigator.pop(context);
                                              },
                                              icon: Icon(Icons.delete),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              child: Text(courses[index]['course']),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return Dialog(
                          child: Container(
                            padding: EdgeInsets.all(20),
                            child: TextFormField(
                              controller: _addCourse,
                              decoration: InputDecoration(
                                labelText: 'Add course',
                                suffixIcon: IconButton(
                                  onPressed: () async {
                                    if (_addCourse.text.isNotEmpty) {
                                      await _client
                                        .from('courses')
                                        .insert({
                                          'course': _addCourse.text,
                                          'user': _user.id
                                        });
                                      setState(() {
                                        _courses = _client
                                          .from('courses')
                                          .select()
                                          .eq('user', _user.id);
                                      });
                                    }
                                    if (context.mounted) Navigator.pop(context);
                                    _addCourse.clear();
                                  },
                                  icon: Icon(Icons.add),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  icon: Icon(Icons.add),
                ),
              ],
            ),
          ),
          // Topics for selected course
          _topics == null
            ? Padding(padding: EdgeInsets.all(10), child: Text('No topics'))
            : FutureBuilder(
              key: Key(_activeCourse.toString()),
            future: _topics,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return CircularProgressIndicator();
              }
              final topics = snapshot.data!;
              return topics.isEmpty
                ? Padding(padding: EdgeInsets.all(10), child: Text('No topics'))
                : Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: topics.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onLongPress: () {
                        _topicName.text = topics[index]['topic'];
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return Dialog(
                              child: Container(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    TextField(
                                      controller: _topicName,
                                      decoration: InputDecoration(
                                        labelText: 'Topic name',
                                        suffixIcon: IconButton(
                                          onPressed: () async {
                                            if (_topicName.text.isNotEmpty) {
                                              await Supabase.instance.client
                                                .from('topics')
                                                .update({'topic': _topicName.text})
                                                .eq('topic', topics[index]['topic']);
                                              setState(() {
                                                topics[index]['topic'] = _topicName.text;
                                              });
                                            }
                                            if (context.mounted) Navigator.pop(context);
                                            _topicName.clear();
                                          },
                                          icon: Icon(Icons.edit),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      child: TopicTile(
                        topic: topics[index],
                        onDelete: _deleteTopic,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      // Footer
      persistentFooterButtons: [
        IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PomodoroTimerScreen()),
              );
            },
            icon: Icon(Icons.timer_outlined)),
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AnimationScreen()),
            );
          },
          icon: Icon(Icons.animation)
        ),
        IconButton(
          onPressed: (){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReferencesGuide()),
            );
          },
          icon: Icon(Icons.add_link_rounded)
        ),
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StudyToolsScreen()),
            );
          },
          icon: Icon(Icons.question_mark)
        ),
        IconButton(

          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CalendarScreen()),
            );
          },

          icon: Icon(Icons.calendar_month)

        ),
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen()),
            );
          },
          icon: Icon(Icons.person)
        ),
      ],
      persistentFooterAlignment: AlignmentDirectional.center,
    );
  }
}

class TopicTile extends StatefulWidget {
  const TopicTile({
    required this.topic,
    required this.onDelete,
    super.key
  });

  final Map topic;
  final Function onDelete;

  @override
  State<TopicTile> createState() => _TopicTile();
}

class _TopicTile extends State<TopicTile> {
  final _client = Supabase.instance.client;
  var _notes = [];
  var _count = 0;

  void _addNote() async {
    await _client
      .from('notes')
      .insert({
        'content': null,
        'topic': widget.topic['id'],});
    setState(() {
      _loadNotes();
      _count++;
    });
  }

  void _deleteNote(int index) async {
    await _client
      .from('notes')
      .delete()
      .eq('id', _notes[index]['id']);
    setState(() {
      _notes.removeAt(index);
      _count--;
    });
  }

  Future<bool?> _confirmDismiss(BuildContext context, int index) async {
    late bool confirmed;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure you want to delete this note?'),
          titlePadding: const EdgeInsets.all(20),
          contentPadding: const EdgeInsets.all(20),
          actions: [
            TextButton(
              onPressed: () {
                confirmed = true;
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Yes'),
            ),
            TextButton(
              onPressed: () {
                confirmed = false;
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('No'),
            ),
          ],
        );
      },
    );
    return confirmed;
  }

  void _loadCount() async {
    final future = await _client
      .from('notes')
      .select()
      .eq('topic', widget.topic['id'])
      .count();
    setState(() => _count = future.count);
  }

  void _loadNotes() async {
    final future = await _client
      .from('notes')
      .select()
      .eq('topic', widget.topic['id'])
      .order('created_at', ascending: true);
    setState(() => _notes = future);
  }

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(10),
      child: ExpansionTile(
        title: Text(widget.topic['topic']),
        maintainState: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20))
        ),
        onExpansionChanged: (value) {
          if (value == true) _loadNotes();
        },
        children: [
          Column(
            children: [
              Container(
                padding: EdgeInsets.all(5),
                height: 400,
                child: _notes.isEmpty ? Center(child: Text('No notes')) : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    return Dismissible(
                      key: UniqueKey(),
                      background: Container(
                        // margin: EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                      confirmDismiss: (_) => _confirmDismiss(context, index),
                      onDismissed: (_) => _deleteNote(index),
                      child: Note(note: _notes[index]),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return SizedBox(height: 5);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => widget.onDelete(widget.topic),
                    icon: Icon(Icons.delete),
                  ),
                  Text("$_count notes"),
                  IconButton(
                    onPressed: () => _addNote(),
                    icon: Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Note extends StatefulWidget {
  const Note({
    required this.note,
    super.key
  });

  final Map note;

  @override
  State<Note> createState() => _Note();
}

class _Note extends State<Note> {
  final _client = Supabase.instance.client;
  final _title = TextEditingController();
  final _content = TextEditingController();
  bool _saved = true;

  @override
  void initState() {
    super.initState();
    if (widget.note['title'] != null) _title.text = widget.note['title'];
    if (widget.note['content'] != null) _content.text = widget.note['content'];
  }

  void _shareNote(BuildContext context) {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (content.isNotEmpty) {
      Share.share(content, subject: "Share Note: $title");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Note is empty! Please write something to share."),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _updateNote() async {
    await _client
      .from('notes')
      .update({
        'title': _title.text,
        'content': _content.text,})
      .eq('id', widget.note['id']);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // margin: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceBright,
        borderRadius: BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: _saved
          ? Theme.of(context).colorScheme.inversePrimary
          : Theme.of(context).colorScheme.primary,
          width: 2.0,
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              hintText: 'Title',
              contentPadding: EdgeInsets.all(10),
            ),
            onChanged: (event) {
              setState(() => _saved = false);
            },
            onTapOutside: (event) {
              _updateNote();
              setState(() => _saved = true);
            },
          ),
          TextField(
            controller: _content,
            decoration: InputDecoration(
              hintText: 'Note',
              contentPadding: EdgeInsets.all(10),
              border: InputBorder.none,
            ),
            maxLines: null,
            onChanged: (event) {
              setState(() => _saved = false);
            },
            onTapOutside: (event) {
              _updateNote();
              setState(() => _saved = true);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _shareNote(context),
                icon: Icon(Icons.share_rounded),
              ),
              Text(widget.note['created_at'].substring(0, 10)),
              IconButton(
                onPressed: () {
                  _updateNote();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Note saved."),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(
                  Icons.edit,
                  color: _saved
                    ? IconTheme.of(context).color
                    : Theme.of(context).colorScheme.primary
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }
}