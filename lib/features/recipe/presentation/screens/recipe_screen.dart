import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/motion_config.dart';
import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/theme/cookbook_theme.dart';
import '../../../../core/widgets/letterpress_card.dart';
import '../../../camera/domain/models/dietary_modifier.dart';
import '../providers/recipe_providers.dart';
import '../widgets/cookbook_illustration.dart';

/// Displays the stylized cookbook page: illustrated photo (top) + rendered
/// Markdown recipe (bottom).
class RecipeScreen extends ConsumerStatefulWidget {
  const RecipeScreen({
    super.key,
    required this.imageBytes,
    required this.modifier,
  });

  final Uint8List imageBytes;
  final DietaryModifier modifier;

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off the API call.
    Future.microtask(() {
      ref.read(recipeNotifierProvider.notifier).generate(
            imageBytes: widget.imageBytes,
            modifier: widget.modifier,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipeNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Recipe',
          style: CookbookTheme.headlineStyle(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: MotionConfig.routeTransition,
        switchInCurve: MotionConfig.routeCurve,
        child: state.when(
          loading: () => _LoadingView(key: const ValueKey('loading')),
          error: (message) => _ErrorView(
            key: const ValueKey('error'),
            message: message,
            onRetry: () {
              ref.read(recipeNotifierProvider.notifier).generate(
                    imageBytes: widget.imageBytes,
                    modifier: widget.modifier,
                  );
            },
          ),
          success: (markdown) => _SuccessView(
            key: const ValueKey('success'),
            imageBytes: widget.imageBytes,
            markdown: markdown,
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: CookbookPalette.lightAccent,
          ),
          const SizedBox(height: 20),
          Text(
            'Reverse-engineering your dish...',
            style: CookbookTheme.bodyStyle(
              color: CookbookPalette.lightInk.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: CookbookPalette.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CookbookTheme.bodyStyle(),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    super.key,
    required this.imageBytes,
    required this.markdown,
  });

  final Uint8List imageBytes;
  final String markdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Illustrated food image card.
          LetterpressCard(
            padding: const EdgeInsets.all(8),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CookbookIllustration(imageBytes: imageBytes),
            ),
          ),
          const SizedBox(height: 16),
          // Recipe markdown card.
          LetterpressCard(
            child: MarkdownBody(
              data: markdown,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                h1: CookbookTheme.headlineStyle(
                  color: theme.colorScheme.onSurface,
                ),
                h2: CookbookTheme.titleStyle(
                  fontSize: 19,
                  color: theme.colorScheme.onSurface,
                ),
                h3: CookbookTheme.titleStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
                p: CookbookTheme.bodyStyle(
                  color: theme.colorScheme.onSurface,
                ),
                listBullet: CookbookTheme.bodyStyle(
                  color: theme.colorScheme.onSurface,
                ),
                strong: CookbookTheme.bodyStyle(fontWeight: 680).copyWith(
                  fontWeight: FontWeight.w700,
                ),
                em: CookbookTheme.bodyStyle().copyWith(
                  fontStyle: FontStyle.italic,
                ),
                blockSpacing: 12,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
