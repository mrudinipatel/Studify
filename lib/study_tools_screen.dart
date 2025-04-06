import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'quiz_screen.dart';
import 'flashcard_screen.dart';
import 'create_study_set_screen.dart';

class StudyToolsScreen extends StatefulWidget {
  const StudyToolsScreen({super.key});

  @override
  State<StudyToolsScreen> createState() => _StudyToolsScreenState();
}

class _StudyToolsScreenState extends State<StudyToolsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingQuizzes = true;
  bool _isLoadingFlashcards = true;
  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _flashcardDecks = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadQuizzes();
    _loadFlashcards();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQuizzes() async {
    try {
      final response = await Supabase.instance.client
          .from('quiz_sets')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

      setState(() {
        _quizzes = List<Map<String, dynamic>>.from(response);
        _isLoadingQuizzes = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quizzes: $e')),
        );
      }
      setState(() {
        _isLoadingQuizzes = false;
      });
    }
  }

  Future<void> _loadFlashcards() async {
    try {
      final response = await Supabase.instance.client
          .from('flashcard_decks')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

      setState(() {
        _flashcardDecks = List<Map<String, dynamic>>.from(response);
        _isLoadingFlashcards = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading flashcard decks: $e')),
        );
      }
      setState(() {
        _isLoadingFlashcards = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Tools'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Quizzes', icon: Icon(Icons.quiz)),
            Tab(text: 'Flashcards', icon: Icon(Icons.flip)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuizzesTab(),
          _buildFlashcardsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Create New',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCreateButton(
                        context, 
                        'Quiz', 
                        Icons.quiz, 
                        () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateStudySetScreen(
                                type: StudySetType.quiz,
                              ),
                            ),
                          ).then((created) {
                            if (created == true) {
                              _loadQuizzes();
                            }
                          });
                        },
                      ),
                      _buildCreateButton(
                        context, 
                        'Flashcards', 
                        Icons.flip, 
                        () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateStudySetScreen(
                                type: StudySetType.flashcard,
                              ),
                            ),
                          ).then((created) {
                            if (created == true) {
                              _loadFlashcards();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildQuizzesTab() {
    if (_isLoadingQuizzes) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_quizzes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No quizzes yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first quiz set',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _quizzes.length,
      itemBuilder: (context, index) {
        final quiz = _quizzes[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              quiz['title'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                if (quiz['description'] != null)
                  Text(quiz['description']),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizScreen(quiz: quiz),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFlashcardsTab() {
    if (_isLoadingFlashcards) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_flashcardDecks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flip_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No flashcard decks yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first flashcard deck',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _flashcardDecks.length,
      itemBuilder: (context, index) {
        final deck = _flashcardDecks[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              deck['title'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                if (deck['description'] != null)
                  Text(deck['description']),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FlashcardScreen(deck: deck),
                      ),
                    );
                  },
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FlashcardScreen(deck: deck),
                ),
              );
            },
          ),
        );
      },
    );
  }
} 