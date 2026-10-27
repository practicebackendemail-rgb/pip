import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/task_model.dart';
import '../../domain/entities/task_entity.dart';
import 'tasks_event.dart';
import 'tasks_state.dart';

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  static const _uuid = Uuid();

  TasksBloc() : super(const TasksState()) {
    on<LoadTasksEvent>(_onLoadTasks);
    on<AddTaskEvent>(_onAddTask);
    on<ToggleTaskEvent>(_onToggleTask);
    on<DeleteTaskEvent>(_onDeleteTask);
    on<SelectProjectFilterEvent>(_onSelectProject);
  }

  Future<void> _onLoadTasks(LoadTasksEvent event, Emitter<TasksState> emit) async {
    emit(state.copyWith(status: TasksStatus.loading));
    try {
      final prefs = await SharedPreferences.getInstance();
      final streak = prefs.getInt('streak_days') ?? 1;
      final todayCount = prefs.getInt('completed_today_count') ?? 0;
      final jsonStr = prefs.getString('saved_tasks');

      List<TaskEntity> list = [];
      if (jsonStr != null) {
        final List<dynamic> raw = jsonDecode(jsonStr);
        list = raw.map((item) => TaskModel.fromJson(item as Map<String, dynamic>).toEntity()).toList();
      } else {
        list = [
          TaskEntity(
            id: _uuid.v4(),
            title: 'Review quarterly goals & projects',
            project: 'Work',
            priority: TaskPriority.high,
          ),
          TaskEntity(
            id: _uuid.v4(),
            title: '30-minute cardio & stretch workout',
            project: 'Fitness',
            priority: TaskPriority.medium,
          ),
        ];
      }
      emit(state.copyWith(
        status: TasksStatus.success,
        tasks: list,
        streakDays: streak,
        completedTodayCount: todayCount,
      ));
    } catch (e) {
      emit(state.copyWith(status: TasksStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onAddTask(AddTaskEvent event, Emitter<TasksState> emit) async {
    final newTask = TaskEntity(
      id: _uuid.v4(),
      title: event.title,
      description: event.description,
      project: event.project,
      priority: event.priority,
      dueDate: event.dueDate,
    );
    final updated = [newTask, ...state.tasks];
    emit(state.copyWith(tasks: updated));
    await _persist(updated);
  }

  Future<void> _onToggleTask(ToggleTaskEvent event, Emitter<TasksState> emit) async {
    int todayCount = state.completedTodayCount;
    final updated = state.tasks.map((task) {
      if (task.id == event.id) {
        final nextState = !task.isCompleted;
        if (nextState) {
          todayCount++;
        } else if (todayCount > 0) {
          todayCount--;
        }
        return task.copyWith(isCompleted: nextState);
      }
      return task;
    }).toList();

    emit(state.copyWith(tasks: updated, completedTodayCount: todayCount));
    await _persist(updated, todayCount: todayCount);
  }

  Future<void> _onDeleteTask(DeleteTaskEvent event, Emitter<TasksState> emit) async {
    final updated = state.tasks.where((t) => t.id != event.id).toList();
    emit(state.copyWith(tasks: updated));
    await _persist(updated);
  }

  void _onSelectProject(SelectProjectFilterEvent event, Emitter<TasksState> emit) {
    emit(state.copyWith(selectedProject: event.project));
  }

  Future<void> _persist(List<TaskEntity> tasks, {int? todayCount}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = tasks.map((t) => TaskModel.fromEntity(t).toJson()).toList();
    await prefs.setString('saved_tasks', jsonEncode(jsonList));
    if (todayCount != null) {
      await prefs.setInt('completed_today_count', todayCount);
    }
  }
}
