import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/common.dart';
import 'beneficiary_detail_screen.dart';
import 'registration_screen.dart';

class BeneficiariesScreen extends ConsumerStatefulWidget {
  const BeneficiariesScreen({super.key});

  @override
  ConsumerState<BeneficiariesScreen> createState() => _State();
}

class _State extends ConsumerState<BeneficiariesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final list = ref.watch(beneficiariesProvider).valueOrNull ?? const [];
    final identities = ref.watch(identitiesProvider).valueOrNull ?? const {};
    final pending = ref.watch(pendingKeysProvider).valueOrNull ?? const {};
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? list
        : list.where((b) {
            final name = identities[b.id]?.displayName.toLowerCase() ?? '';
            return name.contains(q) || (b.code?.toLowerCase().contains(q) ?? false);
          }).toList();

    return FaniloScaffold(
      title: l.beneficiariesTitle,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RegistrationScreen())),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l.menuRegister),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search), hintText: l.searchHint),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(l.noBeneficiaries)
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final b = filtered[i];
                      final name = identities[b.id]?.displayName;
                      final isPending = pending.contains('beneficiary/${b.id}');
                      return ListTile(
                        minVerticalPadding: 16,
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(name ?? (b.code ?? l.codePending),
                            style: const TextStyle(fontSize: 18)),
                        subtitle: Text(b.code ?? l.codePending),
                        trailing: isPending
                            ? const Icon(Icons.cloud_upload_outlined)
                            : const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                BeneficiaryDetailScreen(beneficiaryId: b.id))),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
