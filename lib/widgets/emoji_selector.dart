// lib/widgets/emoji_selector.dart
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget modular del selector de emojis.
/// Permite insertar emojis en el TextEditingController
/// y guarda los recientes automáticamente.
class EmojiSelector extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function()? onEmojiSelected;

  const EmojiSelector({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onEmojiSelected,
  });

  @override
  State<EmojiSelector> createState() => _EmojiSelectorState();
}

class _EmojiSelectorState extends State<EmojiSelector> {
  late Future<SharedPreferences> _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<SharedPreferences>(
      future: _prefs,
      builder: (context, snapshot) {
        return EmojiPicker(
          onEmojiSelected: (category, emoji) {
            widget.controller
              ..text += emoji.emoji
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: widget.controller.text.length),
              );
            widget.onEmojiSelected?.call();
          },
          textEditingController: widget.controller,
          config: Config(
            height: 280,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              backgroundColor: Colors.white,
              columns: 8,
              emojiSizeMax: 28,
              recentsLimit: 36,
            ),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: Colors.white,
              indicatorColor: colorScheme.primary,
              iconColor: Colors.grey,
              iconColorSelected: colorScheme.primary,
              categoryIcons: const CategoryIcons(),
            ),
            skinToneConfig: const SkinToneConfig(),
            bottomActionBarConfig: const BottomActionBarConfig(
              showBackspaceButton: true,
            ),
            searchViewConfig: const SearchViewConfig(),
          ),
        );
      },
    );
  }
}
