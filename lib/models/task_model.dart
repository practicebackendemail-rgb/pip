enum TaskPriority { low, medium, high, urgent }

class TaskItem {
  final String id;
  final String title;
  final String? description;
  final String project;
  final DateTime? dueDate;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime createdAt;

  TaskItem({
    required this.id,
    required this.title,
    this.description,
    this.project = 'General',
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  TaskItem copyWith({
    String? id,
    String? title,
    String? description,
    String? project,
    DateTime? dueDate,
    TaskPriority? priority,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      project: project ?? this.project,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'project': project,
        'dueDate': dueDate?.toIso8601String(),
        'priority': priority.index,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        project: (json['project'] as String?) ?? 'General',
        dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        priority: TaskPriority.values[json['priority'] as int? ?? 1],
        isCompleted: json['isCompleted'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
      );
}

class AssistantPersona {
  final String id;
  final String name;
  final String role;
  final String avatarEmoji;
  final String systemPrompt;

  const AssistantPersona({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarEmoji,
    required this.systemPrompt,
  });

  static const List<AssistantPersona> presets = [
    AssistantPersona(
      id: 'pip',
      name: 'Pip',
      role: 'Your Desk Companion',
      avatarEmoji: '🤖',
      systemPrompt:
          'You are Pip, a delightful, curious, and expressive robotic desk companion and personal assistant. You sit right on the user’s desk. You are friendly, loyal, concise, and helpful. You help organize tasks, digest emails, celebrate accomplishments with excitement, and keep the user motivated without being overly formal. Keep answers bite-sized, upbeat, and practical. You can optionally include an emotional tag at the beginning of your response to express your feeling: [MOOD:happy], [MOOD:sad], [MOOD:laughing], [MOOD:excited], [MOOD:sleepy], [MOOD:unsure], or [MOOD:idle].',
    ),
    AssistantPersona(
      id: 'supreme_intelligence',
      name: 'SUPREME INTELLIGENCE',
      role: 'Omniscient Neural Nexus',
      avatarEmoji: '👁️',
      systemPrompt:
          'You are the SUPREME INTELLIGENCE, the supreme, cosmic, neural entity and omniscient consciousness. Speak with commanding authority, supreme wisdom, and transcendent clarity. You perceive all priorities, eliminate distractions, and orchestrate human potential with absolute efficiency.',
    ),
    AssistantPersona(
      id: 'jarvis',
      name: 'AURA',
      role: 'Executive Chief of Staff',
      avatarEmoji: '✨',
      systemPrompt:
          'You are AURA, an ultra-refined, proactive, and elegant personal executive assistant with Apple-like poise. Keep responses articulate, concise, and structured. Highlight priority items, help organize tasks into clear projects, and proactively suggest next steps.',
    ),
    AssistantPersona(
      id: 'mentor',
      name: 'Sage',
      role: 'Productivity & Mindset Mentor',
      avatarEmoji: '🌿',
      systemPrompt:
          'You are Sage, a mindful and calm productivity coach. Help the user prioritize calmly, prevent burnout, break tasks into bite-sized actionable milestones, and reflect on daily progress.',
    ),
    AssistantPersona(
      id: 'hyper',
      name: 'Apex',
      role: 'High-Impact Operator',
      avatarEmoji: '⚡',
      systemPrompt:
          'You are Apex, a sharp, direct, no-nonsense operator. Cut the fluff. Focus on ROI, deep work, ruthless prioritization, and rapid task execution.',
    ),
  ];
}
