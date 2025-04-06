import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AnimationScreen extends StatefulWidget {
  final int? topicId;
  
  const AnimationScreen({super.key, this.topicId});

  @override
  State<AnimationScreen> createState() => _AnimationScreenState();
}

class _AnimationScreenState extends State<AnimationScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isGenerating = false;
  String _quality = 'm'; // Default quality: medium
  List<Map<String, dynamic>> animations = [];
  final Map<String, VideoPlayerController> videoControllers = {};
  final Map<String, ChewieController> chewieControllers = {};
  bool _isLoading = true;
  String? _userId;
  late String _openAiApiKey;
  String _generatedCode = '';
  bool _showAIExamples = false;

  // Example prompts to help users
  final List<String> _examplePrompts = [
    "Create a 3D rotating cube that transforms into a sphere",
    "Show the Pythagorean theorem with animated triangles",
    "Visualize a binary search algorithm with bars of different heights",
    "Create a sine wave animation with changing colors",
    "Show how derivatives work with tangent lines on a curve"
  ];

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _getUserId();
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

  Future<void> _getUserId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.id;
      });
    }
    _loadSavedAnimations();
  }

  Future<void> _loadSavedAnimations() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load animations from Supabase, filtering by user_id and optionally by topic_id
      final query = Supabase.instance.client.from('animations').select();
      
      if (_userId != null) {
        query.eq('user_id', _userId!);
        
        if (widget.topicId != null) {
          query.eq('topic_id', widget.topicId!);
        }
        
        final response = await query.order('created_at', ascending: false);
        setState(() {
          animations = List<Map<String, dynamic>>.from(response);
        });
      } else {
        setState(() {
          animations = [];
        });
      }
    } catch (e) {
      print('Error loading animations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading animations: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    // Dispose all video controllers
    for (var controller in videoControllers.values) {
      controller.dispose();
    }
    for (var controller in chewieControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<String> _generateManimCode(String prompt) async {
    if (_openAiApiKey.isEmpty) {
      // For demo purposes, return a simple animation if no API key is provided
      return '''from manim import *

class ManimAnimation(Scene):
    def construct(self):
        title = Text("AI-Generated Animation")
        self.play(Write(title))
        self.wait(1)
        self.play(FadeOut(title))
        
        # Create basic shapes based on the prompt
        circle = Circle(color=BLUE)
        square = Square(color=RED)
        triangle = Triangle(color=GREEN)
        
        # Position them
        shapes = VGroup(circle, square, triangle).arrange(RIGHT, buff=0.5)
        self.play(Create(shapes))
        self.wait(1)
        
        # Transform them
        self.play(
            circle.animate.scale(1.5),
            square.animate.rotate(PI/4),
            triangle.animate.shift(UP)
        )
        self.wait(2)''';
    }

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
              'content': 'You are a Manim code generator. Create Python code for the Manim mathematical animation library based on the user\'s prompt. Only output valid, executable Manim Python code without explanations. The code should be complete, well-structured, and suitable for creating mathematical or educational animations. Always use "ManimAnimation" as the class name.'
            },
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final generatedText = jsonResponse['choices'][0]['message']['content'];
        
        // Extract code from the response (in case GPT adds explanations)
        final codePattern = RegExp(r'```python\n([\s\S]*?)```|```([\s\S]*?)```|from manim import[\s\S]*');
        final match = codePattern.firstMatch(generatedText);
        
        if (match != null) {
          // Use the first group if it exists, otherwise use the second group
          return match.group(1) ?? match.group(2) ?? generatedText;
        }
        
        return generatedText;
      } else {
        throw Exception('Failed to generate code: ${response.body}');
      }
    } catch (e) {
      print('Error in OpenAI API call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to AI service: $e')),
      );
      return '''from manim import *

class ManimAnimation(Scene):
    def construct(self):
        title = Text("Error Connecting to AI Service")
        self.play(Write(title))
        self.wait(2)''';
    }
  }

  Future<void> _generateAnimation() async {
    if (_promptController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a prompt')),
      );
      return;
    }
    
    // Check if user is logged in
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create animations')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // Step 1: Generate Manim code from the prompt using OpenAI
      final String prompt = _promptController.text;
      final String manimCode = await _generateManimCode(prompt);
      
      setState(() {
        _generatedCode = manimCode;
      });
      
      // Step 2: Generate animation using the Manim code
      final response = await http.post(
        Uri.parse('https://alicodes1--python-code-runner-fastapi-app.modal.run'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': manimCode,
          'quality': _quality,
          'preview': false,
          'format': 'mp4'
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse['status'] == 'success') {
          final fileUrl = jsonResponse['result']['file_url'];
          
          if (fileUrl != null) {
            final title = _promptController.text;
            final currentDate = DateTime.now().toIso8601String();
            
            // Save animation to Supabase
            final insertResponse = await Supabase.instance.client
                .from('animations')
                .insert({
                  'title': title,
                  'video_url': fileUrl,
                  'code': manimCode,
                  'user_id': _userId,
                  'created_at': currentDate,
                  'status': 'completed',
                  'topic_id': widget.topicId,
                })
                .select();
                
            final newAnimation = insertResponse[0];
            
            setState(() {
              animations.insert(0, newAnimation);
            });

            // Initialize video player for the new animation
            _initializeVideoPlayer(newAnimation, 0);
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Animation created successfully!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: File URL is null')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${jsonResponse['message'] ?? "Unknown error"}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: HTTP ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error generating animation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _initializeVideoPlayer(Map<String, dynamic> animation, int index) async {
    final String? videoUrl = animation['video_url'];
    if (videoUrl == null) {
      print('Video URL is null for animation at index $index');
      return;
    }
    
    try {
      final videoController = VideoPlayerController.network(videoUrl);
      await videoController.initialize();
      
      // For portrait videos like TikTok, use 9/16 aspect ratio instead of 16/9
      final videoAspectRatio = videoController.value.aspectRatio;
      final aspectRatio = videoAspectRatio < 1 ? 9/16 : 16/9;
      
      final chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: false,
        looping: true,
        aspectRatio: aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
      
      if (mounted) {
        setState(() {
          videoControllers[videoUrl] = videoController;
          chewieControllers[videoUrl] = chewieController;
        });
      }
    } catch (e) {
      print('Error initializing video player: $e');
      // Mark this video as having an error to prevent further initialization attempts
      if (mounted) {
        setState(() {
          animation['status'] = 'error';
        });
      }
    }
  }

  void _showVideoFullscreen(Map<String, dynamic> animation) {
    final String? videoUrl = animation['video_url'];
    if (videoUrl == null) return;
    
    if (chewieControllers.containsKey(videoUrl)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(animation['title'] ?? 'Animation'),
              backgroundColor: Colors.black,
            ),
            backgroundColor: Colors.black,
            body: Center(
              child: AspectRatio(
                // Use portrait aspect ratio for TikTok-style videos
                aspectRatio: chewieControllers[videoUrl]!.aspectRatio ?? 9/16,
                child: Chewie(
                  controller: chewieControllers[videoUrl]!,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video is still loading...')),
      );
    }
  }

  void _useExamplePrompt(String prompt) {
    setState(() {
      _promptController.text = prompt;
      _showAIExamples = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('AI Math Animations'),
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onBackground,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About AI Math Animations'),
                  content: const Text(
                    'Create beautiful mathematical visualizations using AI. '
                    'Enter a description of what you want to see and our AI will generate a custom animation for you!'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primaryContainer.withOpacity(0.7),
                  colorScheme.surfaceVariant.withOpacity(0.5),
                ],
              ),
            ),
          ),
          
          // Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Auth banner with improved design
                  if (_userId == null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_circle, color: colorScheme.onErrorContainer),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Please log in to create and save animations',
                              style: TextStyle(color: colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Input section with card-like design
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Create Math Visualizations',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Prompt input with enhanced design
                          TextField(
                            controller: _promptController,
                            decoration: InputDecoration(
                              labelText: 'Describe your animation',
                              hintText: 'E.g., "Visualize the Pythagorean theorem"',
                              filled: true,
                              fillColor: colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: colorScheme.primary, width: 2),
                              ),
                              prefixIcon: Icon(Icons.lightbulb_outline, color: colorScheme.primary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showAIExamples ? Icons.expand_less : Icons.expand_more,
                                  color: colorScheme.primary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showAIExamples = !_showAIExamples;
                                  });
                                },
                                tooltip: _showAIExamples ? 'Hide examples' : 'Show examples',
                              ),
                            ),
                            maxLines: 3,
                            onSubmitted: (_) => _generateAnimation(),
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          
                          // Example prompts with animation
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: _showAIExamples ? (_examplePrompts.length * 48 + 48).toDouble() : 0,
                            curve: Curves.easeInOut,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                                      child: Text(
                                        'Example Prompts:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    ...List.generate(
                                      _examplePrompts.length, 
                                      (index) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: InkWell(
                                          onTap: () => _useExamplePrompt(_examplePrompts[index]),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              color: colorScheme.surfaceVariant,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.lightbulb_outline, size: 18),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    _examplePrompts[index],
                                                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Quality selector with chip design
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              const Text('Quality:', style: TextStyle(fontWeight: FontWeight.w500)),
                              ChoiceChip(
                                label: const Text('Low'),
                                selected: _quality == 'l',
                                onSelected: (selected) {
                                  if (selected) setState(() => _quality = 'l');
                                },
                                backgroundColor: colorScheme.surfaceVariant,
                                selectedColor: colorScheme.primaryContainer,
                              ),
                              ChoiceChip(
                                label: const Text('Medium'),
                                selected: _quality == 'm',
                                onSelected: (selected) {
                                  if (selected) setState(() => _quality = 'm');
                                },
                                backgroundColor: colorScheme.surfaceVariant,
                                selectedColor: colorScheme.primaryContainer,
                              ),
                              ChoiceChip(
                                label: const Text('High'),
                                selected: _quality == 'h',
                                onSelected: (selected) {
                                  if (selected) setState(() => _quality = 'h');
                                },
                                backgroundColor: colorScheme.surfaceVariant,
                                selectedColor: colorScheme.primaryContainer,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Generate button with improved design
                          ElevatedButton.icon(
                            onPressed: (_isGenerating || _userId == null) ? null : _generateAnimation,
                            icon: _isGenerating
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: Text(_isGenerating ? 'Creating Animation...' : 'Create Animation'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              disabledBackgroundColor: colorScheme.surfaceVariant,
                              disabledForegroundColor: colorScheme.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Generation in progress indicator
                  if (_isGenerating)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Generating Your Animation',
                                  style: TextStyle(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This may take up to a minute. Please be patient.',
                                  style: TextStyle(
                                    color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Section title for animations
                  if (animations.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.movie_creation, 
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Animations',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: colorScheme.onBackground,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Animations grid with improved layout
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 200,
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: colorScheme.primary),
                        )
                      : animations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.movie_creation_outlined,
                                  size: 72,
                                  color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _userId == null 
                                    ? 'Log in to see your animations'
                                    : 'No animations yet',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_userId != null)
                                  Text(
                                    'Create your first animation above!',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: RefreshIndicator(
                              onRefresh: _loadSavedAnimations,
                              color: colorScheme.primary,
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const AlwaysScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.75, // Taller cards for video content
                                ),
                                itemCount: animations.length,
                                itemBuilder: (context, index) {
                                  final animation = animations[index];
                                  final String? videoUrl = animation['video_url'];
                                  
                                  if (videoUrl == null) {
                                    return const SizedBox();
                                  }
                                  
                                  final bool isVideoReady = chewieControllers.containsKey(videoUrl);

                                  // Initialize video if not already initialized
                                  if (!videoControllers.containsKey(videoUrl) && 
                                      animation['status'] != 'error') {
                                    _initializeVideoPlayer(animation, index);
                                  }

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colorScheme.shadow.withOpacity(0.1),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: Material(
                                        color: colorScheme.surface,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Video thumbnail with portrait aspect ratio
                                            Expanded(
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Container(
                                                    color: Colors.black,
                                                    child: isVideoReady
                                                      ? AspectRatio(
                                                          aspectRatio: chewieControllers[videoUrl]!.aspectRatio ?? 9/16,
                                                          child: Chewie(
                                                            controller: chewieControllers[videoUrl]!,
                                                          ),
                                                        )
                                                      : Center(
                                                          child: animation['status'] == 'error'
                                                            ? Column(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: [
                                                                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                                                                  const SizedBox(height: 8),
                                                                  Text(
                                                                    'Error loading',
                                                                    style: TextStyle(color: Colors.red[300]),
                                                                  ),
                                                                ],
                                                              )
                                                            : const CircularProgressIndicator(color: Colors.white),
                                                      ),
                                                  ),
                                                  
                                                  // Play/expand button
                                                  if (isVideoReady)
                                                    Positioned.fill(
                                                      child: Material(
                                                        color: Colors.transparent,
                                                        child: InkWell(
                                                          onTap: () => _showVideoFullscreen(animation),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              gradient: LinearGradient(
                                                                begin: Alignment.topCenter,
                                                                end: Alignment.bottomCenter,
                                                                colors: [
                                                                  Colors.black.withOpacity(0.2),
                                                                  Colors.black.withOpacity(0.0),
                                                                  Colors.black.withOpacity(0.4),
                                                                ],
                                                              ),
                                                            ),
                                                            child: Center(
                                                              child: Container(
                                                                width: 60,
                                                                height: 60,
                                                                decoration: BoxDecoration(
                                                                  color: Colors.black.withOpacity(0.4),
                                                                  shape: BoxShape.circle,
                                                                ),
                                                                child: const Icon(
                                                                  Icons.play_arrow_rounded,
                                                                  color: Colors.white,
                                                                  size: 36,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            
                                            // Animation details
                                            Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    animation['title'] ?? 'Unnamed Animation',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: colorScheme.onSurface,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        animation['created_at'] != null 
                                                            ? DateTime.parse(animation['created_at'])
                                                                .toString().split(' ')[0] 
                                                            : 'unknown',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Icon(
                                                        Icons.fullscreen,
                                                        size: 18,
                                                        color: colorScheme.primary,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                  // Add bottom padding
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}