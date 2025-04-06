import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class PomodoroTimerScreen extends StatefulWidget {
  const PomodoroTimerScreen({super.key});
  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> with SingleTickerProviderStateMixin {
  int remainingTime = 25 * 60;
  bool isRunning = false;
  bool isTimeUp = false;
  late TabController _tabController;
  Timer? timer;

  static const int pomodoroTime = 25 * 60;
  static const int shortBreakTime = 5 * 60;
  static const int longBreakTime = 20 * 60;

  List<String> tasks = [];
  TextEditingController taskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    timer?.cancel();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) return;

    setState(() {
      if (_tabController.index == 0) {
        remainingTime = pomodoroTime;
      } else if (_tabController.index == 1) {
        remainingTime = shortBreakTime;
      } else if (_tabController.index == 2) {
        remainingTime = longBreakTime;
      }
      isRunning = false;
      isTimeUp = false;
      timer?.cancel();
    });
  }

  void startPauseTimer() {
    if (isRunning) {
      timer?.cancel();
    } else {
      timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (remainingTime > 0) {
          setState(() {
            remainingTime--;
          });
        } else {
          t.cancel();
          setState(() {
            isRunning = false;
            isTimeUp = true;
          });
        }
      });
    }

    setState(() {
      isRunning = !isRunning;
      isTimeUp = false;
    });
  }

  void resetTimer() {
    setState(() {
      if (_tabController.index == 0) {
        remainingTime = pomodoroTime;
      } else if (_tabController.index == 1) {
        remainingTime = shortBreakTime;
      } else if (_tabController.index == 2) {
        remainingTime = longBreakTime;
      }
      isRunning = false;
      isTimeUp = false;
    });
    timer?.cancel();
  }

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      tasks = prefs.getStringList('tasks') ?? [];
    });
  }

  Future<void> _saveTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('tasks', tasks);
  }

  void _addTask() {
    if (taskController.text.isNotEmpty) {
      setState(() {
        tasks.add(taskController.text);
        taskController.clear();
      });
      _saveTasks();
    }
  }

  void _removeTask(int index) {
    setState(() {
      tasks.removeAt(index);
    });
    _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isTimeUp ? const Color.fromARGB(255, 242, 101, 91) : null,
      appBar: AppBar(
        title: const Text("Study Timer"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        // pomodoro timer stuff
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              'Pomodoro Timer',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              width: MediaQuery.of(context).size.width * 0.92,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(),
                    tabs: List.generate(3, (index) {
                      final titles = ['Pomodoro', 'Short Break', 'Long Break'];
                      bool isSelected = _tabController.index == index;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).colorScheme.inversePrimary.withOpacity(0.5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(titles[index], style: const TextStyle(fontSize: 14)),
                      );
                    }),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    formatTime(remainingTime),
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: startPauseTimer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 125, 127, 204),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        ),
                        child: Text(isRunning ? 'Pause' : 'Start', style: const TextStyle(fontSize: 14, color: Colors.white)),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: resetTimer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 214, 134, 184),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        ),
                        child: const Text("Reset", style: TextStyle(fontSize: 14, color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Task scheduling stuff 
            Text(
              'Task Scheduler',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: TextField(
                        controller: taskController,
                        decoration: InputDecoration(
                          hintText: "Add a task",
                          filled: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 18),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _addTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 149, 189, 130),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: const Text("Add"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(
                        tasks[index],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removeTask(index),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
