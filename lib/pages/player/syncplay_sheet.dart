import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/services/player/syncplay_endpoint.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/device.dart';

/// The lobby pops itself with the step to open next, so the framework animates
/// the swap. Steps never route back — dismissing one ends the flow.
enum _SyncPlayDestination { create, join, server }

/// Single entry point for everything SyncPlay: status, create, join, server.
Future<void> showSyncPlaySheet(
  BuildContext context, {
  required PlayerController playerController,
  required Future<void> Function(int episode, {int currentRoad, int offset})
      changeEpisode,
}) async {
  final _SyncPlayDestination? destination =
      await _showStep<_SyncPlayDestination>(
    context,
    (context) => _SyncPlayHomeSheet(playerController: playerController),
  );
  if (destination == null || !context.mounted) {
    return;
  }
  await _showStep<void>(
    context,
    (context) => switch (destination) {
      _SyncPlayDestination.create ||
      _SyncPlayDestination.join =>
        _SyncPlayRoomSheet(
          isCreate: destination == _SyncPlayDestination.create,
          playerController: playerController,
          changeEpisode: changeEpisode,
        ),
      _SyncPlayDestination.server => const _SyncPlayServerSheet(),
    },
  );
}

Future<T?> _showStep<T>(BuildContext context, WidgetBuilder builder) {
  return showAdaptiveBottomSheet<T>(
    context: context,
    maxHeightFactor: 0.8,
    compactLandscapeMaxHeightFactor: 0.95,
    builder: builder,
  );
}

String _readEndPoint() =>
    GStorage.getSetting<String>(SettingsKeys.syncPlayEndPoint);

/// M3 outlined field on the sheet's tonal cards, carrying the cards' radius
/// instead of the 4dp baseline.
///
/// Outlined rather than filled: these fields float a label, and only the
/// outline can notch around it. A fill would slice the label along the
/// container's top edge.
InputDecoration _sheetInputDecoration({
  required String labelText,
  required IconData icon,
  String? hintText,
  String? helperText,
  String? errorText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    errorText: errorText,
    prefixIcon: Icon(icon),
    // Radius only: InputDecorator recolors this border per state from the M3
    // defaults, covering hover and disabled as well.
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
  );
}

class _SyncPlaySheetScaffold extends StatelessWidget {
  const _SyncPlaySheetScaffold({
    required this.title,
    required this.description,
    required this.bodyBuilder,
    this.showCancel = false,
    this.primaryAction,
  });

  final String title;
  final String description;
  final Widget Function(BuildContext context, bool compact) bodyBuilder;
  final bool showCancel;
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Size size = MediaQuery.sizeOf(context);
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    // Phone landscape leaves almost no height once the keyboard is up, so the
    // layout collapses to rows and sheds the descriptive copy.
    final bool compact =
        size.width > size.height && !isDesktop() && size.shortestSide < 600;
    final bool showDescription = !(compact && keyboardInset > 0);

    return Padding(
      // Lifting the sheet by the keyboard inset and letting the body shrink
      // keeps the fields reachable instead of covered.
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, compact ? 12 : 20, 12, compact ? 10 : 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: (compact
                                ? theme.textTheme.titleLarge
                                : theme.textTheme.headlineSmall)
                            ?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (showDescription) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Compact spends its remaining pixels on the fields, so the
                // primary action lives here instead of a second button bar.
                if (compact && primaryAction != null) ...[
                  const SizedBox(width: 12),
                  primaryAction!,
                ],
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '关闭',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: bodyBuilder(context, compact),
            ),
          ),
          if (compact)
            const SizedBox(height: 12)
          else if (showCancel || primaryAction != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  if (showCancel)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  const Spacer(),
                  if (primaryAction != null) primaryAction!,
                ],
              ),
            )
          else
            const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SyncPlayHomeSheet extends StatelessWidget {
  const _SyncPlayHomeSheet({required this.playerController});

  final PlayerController playerController;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Observer(builder: (context) {
      // Read every observable here and unconditionally: the body builder runs
      // from the scaffold's build, where reads are no longer tracked, and a
      // short-circuited read would register no dependency.
      final bool hasSession = playerController.syncplay.hasSession;
      final String room = playerController.syncplay.syncplayRoom;
      final int rtt = playerController.syncplay.syncplayClientRtt;
      final bool connected = room.isNotEmpty;
      // Connected socket, room not joined yet. The server picker must stay out
      // of reach, otherwise the saved address stops matching what we dialed.
      final bool connecting = hasSession && !connected;

      return _SyncPlaySheetScaffold(
        title: '一起看',
        description: '与好友同步播放、暂停与选集',
        primaryAction: hasSession
            ? FilledButton.tonalIcon(
                onPressed: () async {
                  await playerController.exitSyncPlayRoom();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                ),
                icon: const Icon(Icons.logout_rounded),
                label: Text(connecting ? '取消连接' : '断开连接'),
              )
            : null,
        bodyBuilder: (context, compact) {
          if (connected) {
            return _buildConnected(context, room: room, rtt: rtt);
          }
          if (connecting) {
            return _buildConnecting(context);
          }
          return _buildLobby(context, compact: compact);
        },
      );
    });
  }

  Widget _buildConnecting(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(materialBottomSheetRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '正在连接',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _readEndPoint(),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLobby(BuildContext context, {required bool compact}) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    final Widget create = _ChoiceCard(
      icon: Icons.add_home_outlined,
      title: '创建房间',
      description: '生成房间号并邀请好友',
      emphasized: true,
      onTap: () => Navigator.of(context).pop(_SyncPlayDestination.create),
    );
    final Widget join = _ChoiceCard(
      icon: Icons.login_rounded,
      title: '加入房间',
      description: '已有好友的房间号',
      emphasized: false,
      onTap: () => Navigator.of(context).pop(_SyncPlayDestination.join),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: create),
                const SizedBox(width: 12),
                Expanded(child: join),
              ],
            ),
          )
        else ...[
          create,
          const SizedBox(height: 12),
          join,
        ],
        const SizedBox(height: 16),
        Material(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(materialBottomSheetRadius),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            leading:
                Icon(Icons.dns_outlined, color: colorScheme.onSurfaceVariant),
            title: Text(
              '同步服务器',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: Text(
              _readEndPoint(),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pop(_SyncPlayDestination.server),
          ),
        ),
      ],
    );
  }

  Widget _buildConnected(
    BuildContext context, {
    required String room,
    required int rtt,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RoomNumberCard(
          room: room,
          label: '当前房间',
          trailing: [_CopyButton(value: room)],
        ),
        const SizedBox(height: 12),
        Material(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(materialBottomSheetRadius),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildInfoRow(
                context,
                icon: Icons.network_ping_rounded,
                label: '网络延迟',
                value: '$rtt ms',
              ),
              Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
              _buildInfoRow(
                context,
                icon: Icons.dns_outlined,
                label: '同步服务器',
                value: _readEndPoint(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '分享房间号，好友即可加入',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.emphasized,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color background = emphasized
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final Color foreground = emphasized
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(materialBottomSheetRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          child: Row(
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: emphasized
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncPlayRoomSheet extends StatefulWidget {
  const _SyncPlayRoomSheet({
    required this.isCreate,
    required this.playerController,
    required this.changeEpisode,
  });

  final bool isCreate;
  final PlayerController playerController;
  final Future<void> Function(int episode, {int currentRoad, int offset})
      changeEpisode;

  @override
  State<_SyncPlayRoomSheet> createState() => _SyncPlayRoomSheetState();
}

class _SyncPlayRoomSheetState extends State<_SyncPlayRoomSheet> {
  static final Random _random = Random();

  /// Eight digits keeps accidental collisions with strangers on the public
  /// server unlikely while staying inside the 6-10 digit room name rule.
  static String _generateRoomNumber() =>
      List.generate(8, (_) => _random.nextInt(10)).join();

  /// Alternating consonants and vowels: the field only accepts 4-12 latin
  /// letters, and plain random letters out of that alphabet read as noise.
  static String _generateUserName() {
    const String consonants = 'bcdfghjklmnpqrstvwxyz';
    const String vowels = 'aeiou';
    final int syllables = 3 + _random.nextInt(2);
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < syllables; i++) {
      buffer.write(consonants[_random.nextInt(consonants.length)]);
      buffer.write(vowels[_random.nextInt(vowels.length)]);
    }
    final String name = buffer.toString();
    return name[0].toUpperCase() + name.substring(1);
  }

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  late String _createdRoom = _generateRoomNumber();

  @override
  void initState() {
    super.initState();
    _usernameController.text =
        GStorage.getSetting<String>(SettingsKeys.syncPlayUserName);
    if (_usernameController.text.isEmpty) {
      _usernameController.text = _generateUserName();
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String username = _usernameController.text.trim();
    final String room =
        widget.isCreate ? _createdRoom : _roomController.text.trim();
    GStorage.putSetting<String>(SettingsKeys.syncPlayUserName, username);
    // Close first so the connection toasts land on the page underneath rather
    // than behind this sheet.
    Navigator.of(context).pop();
    widget.playerController
        .createSyncPlayRoom(room, username, widget.changeEpisode);
  }

  @override
  Widget build(BuildContext context) {
    final bool isCreate = widget.isCreate;

    return _SyncPlaySheetScaffold(
      title: isCreate ? '创建房间' : '加入房间',
      description: isCreate ? '将房间号分享给好友' : '输入好友的房间号',
      showCancel: true,
      primaryAction: FilledButton.icon(
        onPressed: _submit,
        icon: Icon(
            isCreate ? Icons.play_circle_outline_rounded : Icons.login_rounded),
        label: Text(isCreate ? '创建并加入' : '加入房间'),
      ),
      bodyBuilder: (context, compact) {
        final Widget lead = isCreate
            ? _RoomNumberCard(
                room: _createdRoom,
                label: '房间号',
                trailing: [
                  IconButton(
                    onPressed: () =>
                        setState(() => _createdRoom = _generateRoomNumber()),
                    tooltip: '重新生成',
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  _CopyButton(value: _createdRoom),
                ],
              )
            : _buildRoomField();

        return Form(
          key: _formKey,
          child: compact
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: lead),
                    const SizedBox(width: 12),
                    Expanded(child: _buildUsernameField(compact: true)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    lead,
                    const SizedBox(height: 16),
                    _buildUsernameField(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildRoomField() {
    return TextFormField(
      controller: _roomController,
      autofocus: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: _sheetInputDecoration(
        labelText: '房间号',
        hintText: '6-10 位数字',
        icon: Icons.meeting_room_outlined,
      ),
      validator: (value) {
        final String text = (value ?? '').trim();
        if (text.isEmpty) {
          return '请输入房间号';
        }
        if (!RegExp(r'^[0-9]{6,10}$').hasMatch(text)) {
          return '房间号为 6-10 位数字';
        }
        return null;
      },
    );
  }

  Widget _buildUsernameField({bool compact = false}) {
    return TextFormField(
      controller: _usernameController,
      textInputAction: TextInputAction.done,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: _sheetInputDecoration(
        labelText: '昵称',
        icon: Icons.person_outline_rounded,
        helperText: compact ? null : '4-12 位英文字母，房间内可见',
      ),
      validator: (value) {
        final String text = (value ?? '').trim();
        if (text.isEmpty) {
          return '请输入昵称';
        }
        if (!RegExp(r'^[a-zA-Z]{4,12}$').hasMatch(text)) {
          return '昵称为 4-12 位英文字母';
        }
        return null;
      },
      onFieldSubmitted: (_) => _submit(),
    );
  }
}

class _SyncPlayServerSheet extends StatefulWidget {
  const _SyncPlayServerSheet();

  @override
  State<_SyncPlayServerSheet> createState() => _SyncPlayServerSheetState();
}

class _SyncPlayServerSheetState extends State<_SyncPlayServerSheet> {
  /// Stands in for a user supplied address in the otherwise fixed list.
  static const String _customOption = '自定义服务器';

  final TextEditingController _customEndPointController =
      TextEditingController();

  late String _selectedEndPoint;
  String? _customEndPointError;

  /// Only focus the address field when the user picks the custom option, not
  /// when the sheet opens with a custom server already saved.
  bool _focusCustomEndPoint = false;

  @override
  void initState() {
    super.initState();
    final String savedEndPoint = _readEndPoint();
    if (officialSyncPlayEndPoints.contains(savedEndPoint)) {
      _selectedEndPoint = savedEndPoint;
    } else {
      _selectedEndPoint = _customOption;
      _customEndPointController.text = savedEndPoint;
    }
  }

  @override
  void dispose() {
    _customEndPointController.dispose();
    super.dispose();
  }

  void _save() {
    String endPoint = _selectedEndPoint;
    if (endPoint == _customOption) {
      endPoint = _customEndPointController.text.trim();
      if (parseSyncPlayEndPoint(endPoint) == null) {
        setState(() => _customEndPointError = '地址格式为 host:port');
        return;
      }
    }
    GStorage.putSetting<String>(SettingsKeys.syncPlayEndPoint, endPoint);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _SyncPlaySheetScaffold(
      title: '同步服务器',
      description: '房间成员需使用同一服务器',
      showCancel: true,
      primaryAction: FilledButton(
        onPressed: _save,
        child: const Text('保存'),
      ),
      bodyBuilder: (context, compact) {
        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        final List<String> endPoints = [
          ...officialSyncPlayEndPoints,
          _customOption,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(materialBottomSheetRadius),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int index = 0; index < endPoints.length; index++) ...[
                    _buildEndPointTile(context, endPoints[index]),
                    if (index != endPoints.length - 1)
                      Divider(
                        height: 1,
                        indent: 56,
                        color: colorScheme.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),
            if (_selectedEndPoint == _customOption) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customEndPointController,
                autofocus: _focusCustomEndPoint,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: _sheetInputDecoration(
                  labelText: '服务器地址',
                  hintText: 'example.com:8996',
                  errorText: _customEndPointError,
                  icon: Icons.link_rounded,
                ),
                onChanged: (_) {
                  if (_customEndPointError != null) {
                    setState(() => _customEndPointError = null);
                  }
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEndPointTile(BuildContext context, String endPoint) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool selected = _selectedEndPoint == endPoint;
    final bool isCustom = endPoint == _customOption;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      leading: Icon(
        isCustom ? Icons.edit_outlined : Icons.public_rounded,
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        endPoint,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: selected ? colorScheme.primary : colorScheme.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded, color: colorScheme.primary)
          : null,
      onTap: () => setState(() {
        _selectedEndPoint = endPoint;
        _customEndPointError = null;
        _focusCustomEndPoint = isCustom;
      }),
    );
  }
}

class _RoomNumberCard extends StatelessWidget {
  const _RoomNumberCard({
    required this.room,
    required this.label,
    required this.trailing,
  });

  final String room;
  final String label;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(materialBottomSheetRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color:
                        colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 2),
                // Compact gives this card half the sheet width, so the
                // wide-tracked number scales down instead of overflowing.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    room,
                    maxLines: 1,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// Confirms inline by swapping to a checkmark: a SnackBar raised from inside a
/// modal sheet lands on the page's Scaffold underneath and stays hidden.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.value});

  final String value;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  void didUpdateWidget(_CopyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _copied = false;
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.value));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _copy,
      tooltip: _copied ? '已复制' : '复制',
      color: Theme.of(context).colorScheme.onPrimaryContainer,
      icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
    );
  }
}
