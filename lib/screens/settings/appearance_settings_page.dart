import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/hemma_theme.dart';
import '../../theme/tokens.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    const accentOptions = [
      HemmaTokens.defaultAccent,
      Color(0xFFE8934F),
      Color(0xFF63C58B),
      Color(0xFFE85D4F),
      Color(0xFFB07FE0),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance & Theme')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Theme Variant', style: TextStyle(fontWeight: FontWeight.bold)),
          SegmentedButton<ThemeVariant>(
            segments: const [
              ButtonSegment(value: ThemeVariant.base, label: Text('Base')),
              ButtonSegment(value: ThemeVariant.glass, label: Text('Glass')),
            ],
            selected: {theme.variant},
            onSelectionChanged: (s) => theme.setVariant(s.first),
          ),
          const SizedBox(height: 16),
          const Text('Color Mode', style: TextStyle(fontWeight: FontWeight.bold)),
          SegmentedButton<ColorModePref>(
            segments: const [
              ButtonSegment(value: ColorModePref.system, label: Text('System')),
              ButtonSegment(value: ColorModePref.light, label: Text('Light')),
              ButtonSegment(value: ColorModePref.dark, label: Text('Dark')),
            ],
            selected: {theme.colorMode},
            onSelectionChanged: (s) => theme.setColorMode(s.first),
          ),
          const SizedBox(height: 16),
          const Text('Accent Color', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: accentOptions
                .map((c) => GestureDetector(
                      onTap: () => theme.setAccentColor(c),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: theme.accentColor == c
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Text('Card Transparency: ${(theme.cardTransparency * 100).round()}%'),
          Slider(
            value: theme.cardTransparency,
            onChanged: theme.setCardTransparency,
          ),
          const SizedBox(height: 8),
          Text('Animation Speed: ${theme.animationSpeed.toStringAsFixed(1)}x'),
          Slider(
            value: theme.animationSpeed,
            min: 0.5,
            max: 2.0,
            divisions: 6,
            onChanged: theme.setAnimationSpeed,
          ),
          SwitchListTile(
            title: const Text('Entrance Animations'),
            value: theme.entranceAnimationsEnabled,
            onChanged: theme.setEntranceAnimationsEnabled,
          ),
          SwitchListTile(
            title: const Text('Smart Row Sorting'),
            value: theme.smartRowSortingEnabled,
            onChanged: theme.setSmartRowSortingEnabled,
          ),
          SwitchListTile(
            title: const Text('Parallax Background Effect'),
            value: theme.parallaxEnabled,
            onChanged: theme.setParallaxEnabled,
          ),
        ],
      ),
    );
  }
}
