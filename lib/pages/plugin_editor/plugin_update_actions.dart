import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

Future<void> updateAllPluginsWithFeedback(
  PluginsController controller, {
  required bool ensureCatalog,
}) async {
  KazumiDialog.showLoading(msg: '更新中');
  try {
    final result = await controller.tryUpdateAllPlugin(
      ensureCatalog: ensureCatalog,
    );
    KazumiDialog.dismiss();
    KazumiDialog.showToast(message: _batchUpdateMessage(result));
  } catch (_) {
    KazumiDialog.dismiss();
    KazumiDialog.showToast(message: '更新规则失败');
  }
}

Future<PluginUpdateResult> updatePluginWithFeedback(
  PluginsController controller,
  String name, {
  required bool installing,
}) async {
  KazumiDialog.showToast(message: installing ? '导入中' : '更新中');
  late final PluginUpdateResult result;
  try {
    result = await controller.tryUpdatePluginByName(name);
  } catch (_) {
    KazumiDialog.showToast(message: '保存规则失败');
    return PluginUpdateResult.failed;
  }
  final message = switch (result) {
    PluginUpdateResult.updated => installing ? '导入成功' : '更新成功',
    PluginUpdateResult.requiresNewerClient => '规则需要更高版本客户端',
    PluginUpdateResult.failed => installing ? '导入规则失败' : '更新规则失败',
    PluginUpdateResult.notNewer => '远程规则版本不高于本地，已跳过更新',
  };
  KazumiDialog.showToast(message: message);
  return result;
}

String _batchUpdateMessage(PluginBatchUpdateResult result) {
  if (result.hasNoCandidates) {
    return '没有可更新的规则';
  }
  if (result.failed == 0 &&
      result.requiresNewerClient == 0 &&
      result.notNewer == 0) {
    return '更新成功 ${result.updated} 条';
  }

  final parts = <String>['成功 ${result.updated} 条'];
  if (result.requiresNewerClient > 0) {
    parts.add('不兼容 ${result.requiresNewerClient} 条');
  }
  if (result.notNewer > 0) {
    parts.add('已跳过 ${result.notNewer} 条');
  }
  if (result.failed > 0) {
    parts.add('失败 ${result.failed} 条');
  }
  return '更新完成：${parts.join('，')}';
}
