import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';

class SyncProgressAppBarBottom extends StatelessWidget
    implements PreferredSizeWidget {
  static const double height = 3;

  const SyncProgressAppBarBottom({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Consumer<MeshCoreConnector>(
      builder: (context, connector, _) {
        final state = _SyncProgressState.fromConnector(
          connector,
          Theme.of(context).colorScheme,
        );
        if (state == null) return const SizedBox(height: height);

        return SizedBox(
          height: height,
          child: LinearProgressIndicator(
            value: state.value,
            minHeight: height,
            color: state.color,
            backgroundColor: state.color.withValues(alpha: 0.18),
          ),
        );
      },
    );
  }
}

class _SyncProgressState {
  final double? value;
  final Color color;

  const _SyncProgressState({required this.value, required this.color});

  static _SyncProgressState? fromConnector(
    MeshCoreConnector connector,
    ColorScheme scheme,
  ) {
    if (connector.isLoadingContacts) {
      return _SyncProgressState(
        value: connector.contactSyncProgress,
        color: scheme.tertiary,
      );
    }
    if (connector.isSyncingChannels) {
      return _SyncProgressState(
        value: connector.channelSyncProgress / 100,
        color: scheme.primary,
      );
    }
    if (connector.isShowingQueuedMessageSyncProgress) {
      return _SyncProgressState(value: null, color: scheme.secondary);
    }
    return null;
  }
}
