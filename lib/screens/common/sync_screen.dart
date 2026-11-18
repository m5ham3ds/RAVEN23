import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../design/app_palette.dart';
import '../../mobile/widgets/page_kit.dart';
import 'source_repositories_screen.dart';

/// Source ordering remains user-managed on-device until a future Firebase /
/// backend integration introduces administrator-managed policy.
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(title: tr('tv_choose_source_priority')),
      body: const SourceRepositoriesScreen(embedded: true, priorityOnly: true),
    );
  }
}
