import 'package:equatable/equatable.dart';

enum ToolConfirmationLevel {
  level0ReadOnly, // Level 0: Auto-executed without user prompting
  level1ConfirmAction, // Level 1: Mutating writes require user confirmation card
  level2ReportAfter, // Level 2: Low-risk mutations executed then reported
  level3DangerousDoubleConfirm, // Level 3: Destructive writes (wipe, send email, delete)
}

class ToolParameterSpec extends Equatable {
  final String name;
  final String type;
  final String description;
  final bool isRequired;

  const ToolParameterSpec({
    required this.name,
    required this.type,
    required this.description,
    this.isRequired = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'description': description,
        'required': isRequired,
      };

  @override
  List<Object?> get props => [name, type, description, isRequired];
}

abstract class PipTool extends Equatable {
  final String name;
  final String description;
  final ToolConfirmationLevel confirmationLevel;
  final List<ToolParameterSpec> parameters;

  const PipTool({
    required this.name,
    required this.description,
    required this.confirmationLevel,
    required this.parameters,
  });

  bool get isReadOnly => confirmationLevel == ToolConfirmationLevel.level0ReadOnly;

  Future<Map<String, dynamic>> execute(Map<String, dynamic> args);

  Map<String, dynamic> toSchema() => {
        'name': name,
        'description': description,
        'parameters': parameters.map((p) => p.toJson()).toList(),
        'is_read_only': isReadOnly,
        'confirmation_level': confirmationLevel.name,
      };

  @override
  List<Object?> get props => [name, description, confirmationLevel, parameters];
}
