import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui' as ui;

class FlashcardScreen extends StatefulWidget {
  final Map<String, dynamic> deck;

  const FlashcardScreen({super.key, required this.deck});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  int currentCardIndex = 0;
  bool isShowingAnswer = false;
  bool isLoading = true;
  List<Map<String, dynamic>> flashcards = [];
  Map<String, bool> knownCards = {};
  String? _userId;
  bool _isUserProgressLoaded = false;
  bool _isGeneratingCards = false;
  final TextEditingController _topicController = TextEditingController();
  late String _openAiApiKey;
  final int _numCardsToGenerate = 5;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _getUserId();
    _loadFlashcards();
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
  }

  Future<void> _loadFlashcards() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      // Load flashcards regardless of user authentication
      final flashcardsResponse = await Supabase.instance.client
          .from('flashcards')
          .select()
          .eq('deck_id', widget.deck['id'])
          .order('created_at');
      
      flashcards = List<Map<String, dynamic>>.from(flashcardsResponse);

      // Only load progress if user is authenticated
      if (_userId != null) {
        try {
          final progressResponse = await Supabase.instance.client
              .from('flashcard_progress')
              .select()
              .eq('user_id', _userId!)
              .inFilter('flashcard_id', flashcards.map((f) => f['id']).toList());

          final progress = List<Map<String, dynamic>>.from(progressResponse);
          knownCards = Map.fromEntries(
            progress.map((p) => MapEntry(p['flashcard_id'].toString(), p['is_known'] as bool))
          );
          _isUserProgressLoaded = true;
        } catch (progressError) {
          print('Error loading progress: $progressError');
          // Continue even if progress loading fails
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading flashcards: $e')),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _generateFlashcards() async {
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
      _isGeneratingCards = true;
    });

    try {
      // Get flashcards from OpenAI
      final flashcardsJson = await _getAIGeneratedFlashcards(_topicController.text);
      
      // Save flashcards to database
      for (var card in flashcardsJson) {
        await Supabase.instance.client
            .from('flashcards')
            .insert({
              'question': card['question'],
              'answer': card['answer'],
              'deck_id': widget.deck['id'],
              'created_at': DateTime.now().toIso8601String(),
            });
      }
      
      // Reload flashcards
      await _loadFlashcards();
      
      // Success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated $_numCardsToGenerate flashcards successfully!')),
        );
      }
    } catch (e) {
      print('Error generating flashcards: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating flashcards: $e')),
        );
      }
    } finally {
      setState(() {
        _isGeneratingCards = false;
        _topicController.clear();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getAIGeneratedFlashcards(String topic) async {
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
              'content': 'You are a flashcard generator assistant. Generate educational flashcards based on the topic provided. For each card, provide a question and an answer. The response should be a valid JSON array of objects with "question" and "answer" fields. Generate exactly $_numCardsToGenerate flashcards.'
            },
            {
              'role': 'user',
              'content': 'Generate flashcards about: $topic. These flashcards will be for deck: ${widget.deck['title']}'
            }
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final String content = jsonResponse['choices'][0]['message']['content'];
        final Map<String, dynamic> parsedJson = jsonDecode(content);
        final List<dynamic> flashcardsJson = parsedJson['flashcards'];
        return List<Map<String, dynamic>>.from(flashcardsJson);
      } else {
        throw Exception('Failed to generate flashcards: ${response.body}');
      }
    } catch (e) {
      print('Error in AI flashcard generation: $e');
      rethrow;
    }
  }

  Future<void> _updateCardProgress(int flashcardId, bool isKnown) async {
    try {
      if (_userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to track your progress')),
        );
        return;
      }

      // Upsert progress
      await Supabase.instance.client
          .from('flashcard_progress')
          .upsert({
            'flashcard_id': flashcardId,
            'user_id': _userId!,
            'is_known': isKnown,
          }, onConflict: 'flashcard_id, user_id');

      setState(() {
        knownCards[flashcardId.toString()] = isKnown;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isKnown ? 'Card marked as known' : 'Card marked as not known'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating progress: $e')),
        );
      }
    }
  }

  void _nextCard() {
    setState(() {
      if (currentCardIndex < flashcards.length - 1) {
        currentCardIndex++;
        isShowingAnswer = false;
      }
    });
  }

  void _previousCard() {
    setState(() {
      if (currentCardIndex > 0) {
        currentCardIndex--;
        isShowingAnswer = false;
      }
    });
  }

  void _toggleAnswer() {
    setState(() {
      isShowingAnswer = !isShowingAnswer;
    });
  }

  void _toggleKnown() {
    final flashcard = flashcards[currentCardIndex];
    final newKnownState = !(knownCards[flashcard['id'].toString()] ?? false);
    _updateCardProgress(flashcard['id'] as int, newKnownState);
  }

  void _showAIGenerationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate AI Flashcards'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter a topic to generate $_numCardsToGenerate flashcards using AI',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                labelText: 'Topic (e.g., "Quantum Physics")',
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
            onPressed: _isGeneratingCards 
                ? null 
                : () {
                    Navigator.pop(context);
                    _generateFlashcards();
                  },
            child: _isGeneratingCards
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
          title: Text(widget.deck['title']),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If no flashcards are available
    if (flashcards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.deck['title']),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.layers_outlined,
                size: 72,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                "No flashcards available",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const Text(
                "This deck doesn't have any flashcards yet.",
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
          tooltip: 'Add AI Flashcards',
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    
    return Scaffold(
      backgroundColor: colorScheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onBackground,
        title: Text(
          widget.deck['title'],
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Generate with AI',
            onPressed: _showAIGenerationDialog,
          ),
          if (_userId == null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Log in to track progress',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Log in to track your progress across devices')),
                );
              },
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.3),
              colorScheme.background,
            ],
            stops: const [0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Authentication and loading banners at top              
              if (_userId == null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        color: colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Log in to track progress',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
              if (_isGeneratingCards)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Generating flashcards...',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
              // Progress indicator
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (currentCardIndex + 1) / flashcards.length,
                          backgroundColor: colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${currentCardIndex + 1}/${flashcards.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    if (_userId != null && _isUserProgressLoaded)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${knownCards.values.where((known) => known).length} known',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
                
              // Flashcard - takes most of screen space
              Expanded(
                child: GestureDetector(
                  onTap: _toggleAnswer,
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity! > 0 && currentCardIndex > 0) {
                      _previousCard();
                    } else if (details.primaryVelocity! < 0 && currentCardIndex < flashcards.length - 1) {
                      _nextCard();
                    }
                  },
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: AspectRatio(
                        aspectRatio: 0.72, // Card aspect ratio
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // perspective
                            ..rotateY(isShowingAnswer ? 3.14159 : 0),
                          transformAlignment: Alignment.center,
                          child: TweenAnimationBuilder(
                            tween: Tween<double>(
                              begin: 0,
                              end: isShowingAnswer ? 1.0 : 0.0,
                            ),
                            duration: const Duration(milliseconds: 300),
                            builder: (context, value, child) {
                              // Show back side
                              if (value >= 0.5) {
                                return Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(3.14159),
                                  child: _buildCardSide(
                                    true,
                                    colorScheme,
                                    context,
                                  ),
                                );
                              } 
                              // Show front side
                              return Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity(),
                                child: _buildCardSide(
                                  false,
                                  colorScheme,
                                  context,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Navigation buttons directly below card
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Previous button
                    NavigationButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: currentCardIndex > 0 ? _previousCard : null,
                      colorScheme: colorScheme,
                      tooltip: 'Previous Card',
                    ),
                    
                    // Toggle known button
                    Material(
                      elevation: 4,
                      shadowColor: colorScheme.shadow.withOpacity(0.3),
                      shape: const CircleBorder(),
                      child: FloatingActionButton(
                        heroTag: 'toggleKnown',
                        onPressed: _toggleKnown,
                        backgroundColor: (knownCards[flashcards[currentCardIndex]['id'].toString()] ?? false)
                          ? Colors.green
                          : colorScheme.surface,
                        child: Icon(
                          (knownCards[flashcards[currentCardIndex]['id'].toString()] ?? false)
                            ? Icons.check
                            : Icons.help_outline,
                          color: (knownCards[flashcards[currentCardIndex]['id'].toString()] ?? false)
                            ? Colors.white
                            : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    
                    // Next button
                    NavigationButton(
                      icon: Icons.arrow_forward_rounded,
                      onPressed: currentCardIndex < flashcards.length - 1 ? _nextCard : null,
                      colorScheme: colorScheme,
                      tooltip: 'Next Card',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'generateCards',
        onPressed: _showAIGenerationDialog,
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        elevation: 8,
        child: const Icon(Icons.auto_awesome),
        tooltip: 'Generate with AI',
      ),
    );
  }

  Widget _buildCardSide(bool isAnswerSide, ColorScheme colorScheme, BuildContext context) {
    final flashcard = flashcards[currentCardIndex];
    final isKnown = knownCards[flashcard['id'].toString()] ?? false;
    final textStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: isAnswerSide ? colorScheme.onTertiary : colorScheme.onPrimary,
      fontWeight: FontWeight.w500,
      height: 1.4,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: isAnswerSide ? ui.ImageFilter.blur() : ui.ImageFilter.blur(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isAnswerSide 
                ? [
                    colorScheme.tertiary.withOpacity(0.8),
                    colorScheme.tertiaryContainer.withOpacity(0.9),
                  ]
                : [
                    colorScheme.primary.withOpacity(0.8),
                    colorScheme.primaryContainer.withOpacity(0.9),
                  ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Card type indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAnswerSide ? colorScheme.onTertiary.withOpacity(0.15) : colorScheme.onPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAnswerSide ? 'Answer' : 'Question',
                    style: TextStyle(
                      color: isAnswerSide ? colorScheme.onTertiary : colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                
                // Known indicator for logged in users
                if (_userId != null && _isUserProgressLoaded)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Icon(
                      isKnown ? Icons.check_circle : Icons.circle_outlined,
                      size: 18,
                      color: isAnswerSide ? colorScheme.onTertiary.withOpacity(0.5) : colorScheme.onPrimary.withOpacity(0.5),
                    ),
                  ),
                
                // Content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        isAnswerSide ? flashcard['answer'] : flashcard['question'],
                        style: textStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                
                // Tap instruction
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 18,
                      color: isAnswerSide ? colorScheme.onTertiary.withOpacity(0.7) : colorScheme.onPrimary.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tap to flip • Swipe for next/previous',
                        style: TextStyle(
                          fontSize: 12,
                          color: isAnswerSide ? colorScheme.onTertiary.withOpacity(0.7) : colorScheme.onPrimary.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Add this class for the navigation buttons
class NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;
  final String tooltip;

  const NavigationButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shadowColor: colorScheme.shadow.withOpacity(0.2),
      shape: const CircleBorder(),
      color: onPressed != null ? colorScheme.surface : colorScheme.surfaceVariant.withOpacity(0.5),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: onPressed != null 
                ? colorScheme.primary 
                : colorScheme.onSurfaceVariant.withOpacity(0.4),
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
} 