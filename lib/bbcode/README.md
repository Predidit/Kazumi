# 基于 antlr4 的 BBCode 解析

## 相关文件

- [assets/bbcode/BBCode.g4](../../assets/bbcode/BBCode.g4): antlr4 语法文件
- [lib/bbcode/generated](../../lib/bbcode/generated): antlr4 生成的 dart 代码所在文件夹

## 关键文件

- [lib/bbcode/bbcode_elements.dart](bbcode_elements.dart): BBCode 元素
- [lib/bbcode/bbcode_base_listener.dart](bbcode_base_listener.dart): BBCode 解析器的入口文件
- [lib/bbcode/bbcode_widget.dart](bbcode_widget.dart): BBCode 组件

## 如何开发

### 配置环境

1. 根据[官方文档](https://github.com/antlr/antlr4/blob/dev/doc/dart-target.md)配置环境
2. 在 IDE 中安装 `antlr v4` 插件

### 开发

1. 修改 [assets/bbcode/BBCode.g4](../../assets/bbcode/BBCode.g4) 文件，通过插件的 Preview 功能确定解析是否正确
2. 通过该文件生成新的 dart 文件到 [lib/bbcode/generated](../../lib/bbcode/generated) 文件夹内，删除无用文件
3. 参考文件内的注释进行修改

### 测试 BBCode

```dart
import 'package:flutter/material.dart';
import 'bbcode/bbcode_widget.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('BBCode Parser')),
        body: Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: BBCodeWidget(
                bbcode:
                '[quote][b]用户[/b]说：[s]测试表情和删除线(bgm35)[/s][/quote]\n[mask]测试特殊符号[]()测试字符表情(TAT)[/mask][url=https://bangumi.tv/blog/348736]测试链接[/url][url]https://bangumi.tv/blog/348736[/url][img]https://bangumi.tv/img/rc3/logo_2x.png[/img]\n\n[color=grey][size=10][来自Bangumi for android] [url=https://bgm.tv/group/topic/350677][color=grey]获取[/color][/url][/size][/color]',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```
