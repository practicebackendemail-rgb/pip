import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../models/task_model.dart';

class TaskProvider extends ChangeNotifier {
  List<TaskItem> _tasks = [];
  String _selectedProject = 'All';
  int _completedTodayCount = 0;
  int _streakDays = 1;
  final _uuid = const Uuid();

  List<TaskItem> get tasks {
    if (_selectedProject == 'All') return List.unmodifiable(_tasks);
    return List.unmodifiable(_tasks.where((t) => t.project == _selectedProject));
  }

  List<TaskItem> get allTasks => List.unmodifiable(_tasks);
  String get selectedProject => _selectedProject;
  int get completedTodayCount => _completedTodayCount;
  int get streakDays => _streakDays;

  List<String> get projects {
    final set = {'All', 'Work', 'Personal', 'Fitness', 'Learning'};
    for (final task in _tasks) {
      if (task.project.isNotEmpty) set.add(task.project);
    }
    return set.toList();
  }

  TaskProvider() {
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    _completedTodayCount = prefs.getInt('completed_today_count') ?? 0;
    _streakDays = prefs.getInt('streak_days') ?? 1;

    final jsonStr = prefs.getString('saved_tasks');
    if (jsonStr != null) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        _tasks = list.map((item) => TaskItem.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Error parsing saved tasks: $e');
      }
    } else {
      // Starter sample tasks
      _tasks = [
        TaskItem(
          id: _uuid.v4(),
          title: 'Review quarterly goals & projects',
          project: 'Work',
          priority: TaskPriority.high,
          dueDate: DateTime.now().add(const Duration(hours: 4)),
        ),
        TaskItem(
          id: _uuid.v4(),
          title: '30-minute cardio & stretch workout',
          project: 'Fitness',
          priority: TaskPriority.medium,
          dueDate: DateTime.now().add(const Duration(hours: 8)),
        ),
        TaskItem(
          id: _uuid.v4(),
          title: 'Organize unread emails and archive clutter',
          project: 'Personal',
          priority: TaskPriority.high,
          dueDate: DateTime.now().add(const Duration(days: 1)),
        ),
      ];
      _saveTasks();
    }
    notifyListeners();
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await prefs.setString('saved_tasks', jsonStr);
    await prefs.setInt('completed_today_count', _completedTodayCount);
    await prefs.setInt('streak_days', _streakDays);
  }

  void selectProject(String project) {
    _selectedProject = project;
    notifyListeners();
  }

  void addTask({
    required String title,
    String? description,
    String project = 'Work',
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
  }) {
    final newTask = TaskItem(
      id: _uuid.v4(),
      title: title,
      description: description,
      project: project,
      priority: priority,
      dueDate: dueDate,
    );
    _tasks.insert(0, newTask);
    _saveTasks();
    notifyListeners();
  }

  void toggleTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final task = _tasks[index];
      final newCompleted = !task.isCompleted;
      _tasks[index] = task.copyWith(isCompleted: newCompleted);
      if (newCompleted) {
        _completedTodayCount++;
      } else if (_completedTodayCount > 0) {
        _completedTodayCount--;
      }
      _saveTasks();
      notifyListeners();
    }
  }

  void updateTask({
    required String id,
    String? title,
    String? project,
    TaskPriority? priority,
    DateTime? dueDate,
  }) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final t = _tasks[index];
      _tasks[index] = t.copyWith(
        title: title ?? t.title,
        project: project ?? t.project,
        priority: priority ?? t.priority,
        dueDate: dueDate ?? t.dueDate,
      );
      _saveTasks();
      notifyListeners();
    }
  }

  void completeAllTasks() {
    bool changed = false;
    for (int i = 0; i < _tasks.length; i++) {
      if (!_tasks[i].isCompleted) {
        _tasks[i] = _tasks[i].copyWith(isCompleted: true);
        _completedTodayCount++;
        changed = true;
      }
    }
    if (changed) {
      _saveTasks();
      notifyListeners();
    }
  }

  void deleteAllCompletedTasks() {
    final before = _tasks.length;
    _tasks.removeWhere((t) => t.isCompleted);
    if (_tasks.length != before) {
      _saveTasks();
      notifyListeners();
    }
  }

  /// Searches for task matching title closely with tokenized matching
  TaskItem? findTaskByFuzzyTitle(String titleQuery) {
    final query = titleQuery.trim().toLowerCase();
    if (query.isEmpty) return null;

    // 1. Exact or substring match
    for (final t in _tasks) {
      final tTitle = t.title.toLowerCase();
      if (tTitle == query || tTitle.contains(query) || query.contains(tTitle)) {
        return t;
      }
    }

    // 2. Word intersection match (e.g. user says "workout" or "stretch")
    final queryWords = query.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    if (queryWords.isNotEmpty) {
      for (final t in _tasks) {
        final taskWords = t.title.toLowerCase().split(RegExp(r'\s+')).toSet();
        if (queryWords.intersection(taskWords).isNotEmpty) {
          return t;
        }
      }
    }

    return null;
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _saveTasks();
    notifyListeners();
  }
}
