import '../../../features/games/domain/game_kind.dart';
import '../../domain/pip_tool.dart';
import '../../routes/app_navigation.dart';
import '../../routes/app_routes.dart';

/// "Let's play" / "play rock paper scissors with me": opens game mode.
class StartGameTool extends PipTool {
  const StartGameTool()
      : super(
          name: 'start_game',
          description: 'Open game mode to play a two-player game with the user. Use when they want to play, '
              'are bored, or name a game. Games: four_in_row, rock_paper_scissors, twenty_questions. '
              'Leave game empty to show the game picker.',
          confirmationLevel: ToolConfirmationLevel.level0ReadOnly,
          parameters: const [
            ToolParameterSpec(
              name: 'game',
              type: 'string',
              description: 'four_in_row, rock_paper_scissors or twenty_questions; empty for the picker.',
              isRequired: false,
            ),
          ],
        );

  static GameKind? kindFor(String? name) {
    final n = (name ?? '').toLowerCase().replaceAll(RegExp(r'[\s-]'), '_');
    if (n.contains('four') || n.contains('connect')) return GameKind.fourInRow;
    if (n.contains('rock') || n.contains('rps') || n.contains('scissor')) return GameKind.rockPaperScissors;
    if (n.contains('twenty') || n.contains('20') || n.contains('question')) return GameKind.twentyQuestions;
    return null;
  }

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final kind = kindFor(args['game'] as String?);
    final opened = AppNavigation.push(kind == null ? AppRoutes.games : AppRoutes.game(kind.slug));
    if (!opened) return {'error': 'Game mode could not be opened right now.'};
    return {'opened': kind?.name ?? 'game_picker'};
  }
}
