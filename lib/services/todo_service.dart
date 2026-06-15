import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soulsync_dairyapp/models/todo_item.dart';

class TodoService {
  static const String _todoListKey = 'todo_list';

  /// Get all todo items
  static Future<List<TodoItem>> getTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todoJson = prefs.getString(_todoListKey);
      
      if (todoJson == null || todoJson.isEmpty) {
        return [];
      }

      final List<dynamic> todoList = json.decode(todoJson);
      return todoList.map((json) => TodoItem.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error loading todos: $e');
      return [];
    }
  }

  /// Save all todo items
  static Future<bool> saveTodos(List<TodoItem> todos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todoJson = json.encode(todos.map((todo) => todo.toJson()).toList());
      return await prefs.setString(_todoListKey, todoJson);
    } catch (e) {
      print('Error saving todos: $e');
      return false;
    }
  }

  /// Add a new todo item
  static Future<bool> addTodo(TodoItem todo) async {
    final todos = await getTodos();
    todos.add(todo);
    return await saveTodos(todos);
  }

  /// Update a todo item
  static Future<bool> updateTodo(TodoItem updatedTodo) async {
    final todos = await getTodos();
    final index = todos.indexWhere((todo) => todo.id == updatedTodo.id);
    
    if (index != -1) {
      todos[index] = updatedTodo;
      return await saveTodos(todos);
    }
    return false;
  }

  /// Delete a todo item
  static Future<bool> deleteTodo(String id) async {
    final todos = await getTodos();
    todos.removeWhere((todo) => todo.id == id);
    return await saveTodos(todos);
  }

  /// Toggle todo completion status
  static Future<bool> toggleTodo(String id) async {
    final todos = await getTodos();
    final index = todos.indexWhere((todo) => todo.id == id);
    
    if (index != -1) {
      final todo = todos[index];
      todos[index] = todo.copyWith(
        isCompleted: !todo.isCompleted,
        completedAt: !todo.isCompleted ? DateTime.now() : null,
      );
      return await saveTodos(todos);
    }
    return false;
  }

  /// Clear all completed todos
  static Future<bool> clearCompleted() async {
    final todos = await getTodos();
    final activeTodos = todos.where((todo) => !todo.isCompleted).toList();
    return await saveTodos(activeTodos);
  }
}

