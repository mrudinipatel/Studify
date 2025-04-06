import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class QuizScreen extends StatefulWidget {
  final Map<String, dynamic> quiz;

  const QuizScreen({super.key, required this.quiz});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int currentQuestionIndex = 0;
  Map<int, String> userAnswers = {};
  bool isQuizComplete = false;
  bool isLoading = true;
  List<Map<String, dynamic>> questions = [];
  List<List<Map<String, dynamic>>> options = [];
  String? _userId;
  Map<String, dynamic>? _previousResult;
  bool _isGeneratingQuiz = false;
  final TextEditingController _topicController = TextEditingController();
  late String _openAiApiKey;
  final int _numQuestionsToGenerate = 5;
  final int _numOptionsPerQuestion = 4;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _getUserId();
    _loadQuizData();
  }

  void _loadApiKey() {
    try {
      _openAiApiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      print('API key loaded successfully');
    } catch (e) {
      print('Error loading OpenAI API key: $e');
      _openAiApiKey = '';
    }
  }

  void _getUserId() {
    final user = Supabase.instance.client.auth.currentUser;
    setState(() {
      _userId = user?.id;
    });
    if (_userId != null) {
      _loadPreviousResult();
    }
  }

  Future<void> _loadPreviousResult() async {
    try {
      final response = await Supabase.instance.client
          .from('quiz_results')
          .select()
          .eq('quiz_set_id', widget.quiz['id'])
          .eq('user_id', _userId!)
          .order('id', ascending: false)
          .limit(1);
      
      if (response.isNotEmpty) {
        setState(() {
          _previousResult = response[0];
        });
      }
    } catch (e) {
      print('Error loading previous quiz result: $e');
    }
  }

  Future<void> _loadQuizData() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      // Load questions
      final questionsResponse = await Supabase.instance.client
          .from('quiz_questions')
          .select()
          .eq('quiz_set_id', widget.quiz['id'])
          .order('created_at');
      
      questions = List<Map<String, dynamic>>.from(questionsResponse);
      
      // Load options for each question
      options = await Future.wait(
        questions.map((question) async {
          final optionsResponse = await Supabase.instance.client
              .from('quiz_options')
              .select()
              .eq('question_id', question['id'])
              .order('option_index');
          return List<Map<String, dynamic>>.from(optionsResponse);
        }),
      );

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quiz: $e')),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _generateQuiz() async {
    if (_topicController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic')),
      );
      return;
    }

    if (_openAiApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OpenAI API key not configured')),
      );
      return;
    }

    setState(() {
      _isGeneratingQuiz = true;
    });

    try {
      // Get quiz questions from OpenAI
      final quizData = await _getAIGeneratedQuiz(_topicController.text);
      
      // Save questions and options to database
      for (var questionData in quizData) {
        // Insert the question
        final questionsInsert = await Supabase.instance.client
            .from('quiz_questions')
            .insert({
              'question': questionData['question'],
              'correct_answer_index': questionData['correct_answer_index'],
              'quiz_set_id': widget.quiz['id'],
              'created_at': DateTime.now().toIso8601String(),
            })
            .select();
        
        final newQuestion = questionsInsert[0];
        final questionId = newQuestion['id'];
        
        // Insert options
        for (int i = 0; i < questionData['options'].length; i++) {
          await Supabase.instance.client
              .from('quiz_options')
              .insert({
                'question_id': questionId,
                'option_text': questionData['options'][i],
                'option_index': i,
              });
        }
      }
      
      // Reload quiz data
      await _loadQuizData();
      
      // Success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated $_numQuestionsToGenerate quiz questions successfully!')),
        );
      }
    } catch (e) {
      print('Error generating quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating quiz: $e')),
        );
      }
    } finally {
      setState(() {
        _isGeneratingQuiz = false;
        _topicController.clear();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getAIGeneratedQuiz(String topic) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openAiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': '''You are a quiz generator assistant. Generate educational multiple-choice quiz questions based on the topic provided.
For each question:
1. Provide a clear question
2. Provide exactly $_numOptionsPerQuestion options (choices)
3. Specify the correct_answer_index (0-based index)

The response should be a valid JSON object with a "questions" array containing question objects with the following fields:
- "question": string
- "options": array of $_numOptionsPerQuestion strings
- "correct_answer_index": integer (0-indexed)

Generate exactly $_numQuestionsToGenerate questions.'''
            },
            {
              'role': 'user',
              'content': 'Generate quiz questions about: $topic. These questions will be for the quiz: ${widget.quiz['title']}'
            }
          ],
          'temperature': 0.7,
          'max_tokens': 1500,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final String content = jsonResponse['choices'][0]['message']['content'];
        final Map<String, dynamic> parsedJson = jsonDecode(content);
        final List<dynamic> questionsJson = parsedJson['questions'];
        return List<Map<String, dynamic>>.from(questionsJson);
      } else {
        throw Exception('Failed to generate quiz: ${response.body}');
      }
    } catch (e) {
      print('Error in AI quiz generation: $e');
      rethrow;
    }
  }

  Future<void> _saveQuizResult() async {
    try {
      if (_userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log in to save your quiz results')),
        );
        return;
      }

      final score = _calculateScore();
      final result = await Supabase.instance.client.from('quiz_results').insert({
        'quiz_set_id': widget.quiz['id'] as int,
        'user_id': _userId!,
        'score': score,
        'total_questions': questions.length,
      }).select();
      
      setState(() {
        _previousResult = result[0];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz result saved successfully!')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving quiz result: $e')),
        );
      }
    }
  }

  void _handleAnswer(String answer) {
    setState(() {
      userAnswers[currentQuestionIndex] = answer;
      if (currentQuestionIndex < questions.length - 1) {
        currentQuestionIndex++;
      } else {
        isQuizComplete = true;
        _saveQuizResult();
      }
    });
  }

  int _calculateScore() {
    int correctAnswers = 0;
    userAnswers.forEach((index, answer) {
      final correctOptionIndex = questions[index]['correct_answer_index'] as int;
      if (options[index][correctOptionIndex]['option_text'] == answer) {
        correctAnswers++;
      }
    });
    return correctAnswers;
  }

  void _showAIGenerationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate AI Quiz Questions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter a topic to generate $_numQuestionsToGenerate multiple-choice questions using AI',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                labelText: 'Topic (e.g., "World History")',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isGeneratingQuiz 
                ? null 
                : () {
                    Navigator.pop(context);
                    _generateQuiz();
                  },
            child: _isGeneratingQuiz
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Generate'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz['title']),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If no questions are available
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz['title']),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.quiz_outlined,
                size: 72,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                "No questions available",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const Text(
                "This quiz doesn't have any questions yet.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _showAIGenerationDialog,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate with AI'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAIGenerationDialog,
          child: const Icon(Icons.add),
          tooltip: 'Add AI Quiz Questions',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz['title']),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!isQuizComplete)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Generate more questions with AI',
              onPressed: _showAIGenerationDialog,
            ),
          if (_userId == null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Log in to save results',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Log in to save and track your quiz results')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Authentication status banner (if not logged in)
          if (_userId == null)
            Container(
              padding: const EdgeInsets.all(12.0),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Log in to save and track your quiz results',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Show loading indicator if generating quiz
          if (_isGeneratingQuiz)
            Container(
              padding: const EdgeInsets.all(12.0),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Generating quiz questions with AI...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Previous score display (if available and user is logged in)
          if (_userId != null && _previousResult != null && !isQuizComplete)
            Container(
              padding: const EdgeInsets.all(12.0),
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 8),
                  Text(
                    'Previous score: ${_previousResult!['score']}/${_previousResult!['total_questions']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: isQuizComplete
                  ? _buildQuizComplete()
                  : _buildQuizQuestion(),
            ),
          ),
        ],
      ),
      floatingActionButton: !isQuizComplete ? FloatingActionButton(
        onPressed: _showAIGenerationDialog,
        child: const Icon(Icons.auto_awesome),
        tooltip: 'Generate with AI',
      ) : null,
    );
  }

  Widget _buildQuizQuestion() {
    final question = questions[currentQuestionIndex];
    final questionOptions = options[currentQuestionIndex];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: (currentQuestionIndex + 1) / questions.length,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Question ${currentQuestionIndex + 1} of ${questions.length}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              question['question'],
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ...questionOptions.map((option) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ElevatedButton(
            onPressed: () => _handleAnswer(option['option_text']),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              option['option_text'],
              style: const TextStyle(fontSize: 16),
            ),
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildQuizComplete() {
    final score = _calculateScore();
    final bool isNewHighScore = _previousResult != null && score > (_previousResult!['score'] as int);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isNewHighScore ? Icons.emoji_events : Icons.celebration,
            size: 80,
            color: isNewHighScore ? Colors.amber : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            isNewHighScore ? 'New High Score!' : 'Quiz Complete!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Your Score: $score/${questions.length}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (_previousResult != null && !isNewHighScore)
            Text(
              'Previous best: ${_previousResult!['score']}/${_previousResult!['total_questions']}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          const SizedBox(height: 32),
          if (_userId == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                'Log in to save your results',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home),
            label: const Text('Return to Study Tools'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                currentQuestionIndex = 0;
                userAnswers.clear();
                isQuizComplete = false;
              });
            },
            child: const Text('Retry Quiz'),
          ),
          if (!isNewHighScore) 
            const SizedBox(height: 16),
          if (!isNewHighScore) 
            OutlinedButton.icon(
              onPressed: _showAIGenerationDialog,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate New Questions'),
            ),
        ],
      ),
    );
  }
} 