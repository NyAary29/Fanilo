import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/models.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'content_screen.dart';

/// « Fampahalalana » : menus vocaux par module (`GET /public/menus`), en
/// gros boutons numérotés.
class InfoTab extends ConsumerWidget {
  const InfoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final module = ref.watch(infoModuleProvider);
    final lang = ref.watch(languageProvider);
    final menu = ref.watch(menuProvider((module, lang)));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(menuProvider((module, lang)).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Row(children: [
            for (final m in Module.values) ...[
              if (m != Module.values.first) const SizedBox(width: 10),
              Expanded(
                child: _ModuleTab(
                  module: m,
                  selected: m == module,
                  onTap: () => ref.read(infoModuleProvider.notifier).state = m,
                ),
              ),
            ],
          ]),
          const SizedBox(height: 14),
          ...menu.when(
            loading: () => [
              const Padding(
                  padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            ],
            error: (e, _) => [
              IconLine(icon: Icons.cloud_off, text: apiErrorMessage(context, e)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(menuProvider((module, lang))),
                icon: const Icon(Icons.refresh),
                label: Text(context.l.retry),
              ),
            ],
            data: (m) => [
              if (m.isDemo) ...[const DemoBanner(), const SizedBox(height: 10)],
              if (m.items.isEmpty) IconLine(icon: Icons.info_outline, text: context.l.menuUnavailable),
              for (final item in m.items)
                _MenuButton(
                  item: item,
                  module: module,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) =>
                          ContentScreen(content: item.content, module: module, number: item.key))),
                ),
            ],
          ),
          const ScreenFooter(),
        ],
      ),
    );
  }
}

class _ModuleTab extends StatelessWidget {
  const _ModuleTab({required this.module, required this.selected, required this.onTap});
  final Module module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? moduleColor(module) : FaniloColors.surface,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          key: Key('info-module-${module.name}'),
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(
                  color: selected ? moduleStrong(module) : FaniloColors.line, width: 2),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(module == Module.reny ? Icons.pregnant_woman : Icons.face_3,
                  color: moduleStrong(module), size: 30),
              const SizedBox(width: 6),
              Text(moduleTitle(module),
                  style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w900, color: moduleInk(module))),
            ]),
          ),
        ),
      );
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.item, required this.module, required this.onTap});
  final MenuItem item;
  final Module module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: FaniloColors.surface,
          borderRadius: BorderRadius.circular(kRadius),
          child: InkWell(
            key: Key('menu-${item.key}'),
            borderRadius: BorderRadius.circular(kRadius),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 76),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: FaniloColors.line)),
              child: Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: moduleStrong(module), shape: BoxShape.circle),
                  child: Text('${item.key}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(item.content.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                Icon(
                    item.content.audioUrl != null ? Icons.volume_up : Icons.chevron_right,
                    color: FaniloColors.forest,
                    size: 30),
              ]),
            ),
          ),
        ),
      );
}
