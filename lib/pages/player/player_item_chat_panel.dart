import 'package:kazumi/bbcode/bbcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:intl/intl.dart';

class SyncPlayChatPanel extends StatefulWidget {
  const SyncPlayChatPanel({super.key});

  static _SyncPlayChatPanelState? currentState;

  @override
  State<SyncPlayChatPanel> createState() => _SyncPlayChatPanelState();
}

class _SyncPlayChatPanelState extends State<SyncPlayChatPanel> {
  final PlayerController playerController = Modular.get<PlayerController>();
  final VideoPageController videoPageController = Modular.get<VideoPageController>();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SyncPlayChatPanel.currentState = this;
  }

  @override
  void dispose() {
    if (SyncPlayChatPanel.currentState == this) {
      SyncPlayChatPanel.currentState = null;
    }
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void notifyNewMessage() {
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    try {
      await playerController.sendSyncPlayChatMessage(text);
    } catch (e) {
      KazumiDialog.showToast(message:'SyncPlay: 消息发送失败');
    }

    final name = playerController.syncplayController?.username ?? '我';

    final newItem = {
      'name': name,
      'message': text,
      'time': DateTime.now(),
    };

    setState(() {
      playerController.syncplayChatHistory.add(newItem);
      _textController.clear();
    });

    _scrollToBottom();
  }

  Widget _buildMessageItem(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名字 - 时间
          Text(
            '${item['name'] ?? '用户'} - ${item['time'] is DateTime ? DateFormat('yyyy/MM/dd HH:mm:ss').format(item['time']) : ''}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          BBCodeWidget(bbcode: item['message'] ?? ''),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: FractionallySizedBox(
        heightFactor: (Utils.isDesktop() || Utils.isTablet()) ? 0.9 : 0.85,
        widthFactor: 1.0,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '聊天室',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // 消息列表
                Expanded(
                  child: playerController.syncplayChatHistory.isEmpty
                      ? Center(
                          child: Text(
                            '聊天室为空，赶快说点什么吧～',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          itemCount: playerController.syncplayChatHistory.length,
                          itemBuilder: (context, index) {
                            return _buildMessageItem(playerController.syncplayChatHistory[index]);
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: '在一起看里发言',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _handleSend,
                        child: const Text('发送'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
