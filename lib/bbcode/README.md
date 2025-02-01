# 基于 antlr4 的 BBCode 解析

## 相关文件

- [assets/bbcode/BBCode.g4](../../assets/bbcode/BBCode.g4): antlr4 语法文件
- [lib/bbcode/generated](../../lib/bbcode/generated): antlr4 生成的 dart 代码所在文件夹

## 关键文件

- [lib/bbcode/BBCodeBaseListener.dart](generated/BBCodeBaseListener.dart): antlr4 生成的 Listener 抽象类空实现
- [lib/bbcode/bbcode.dart](bbcode.dart): BBCode 解析器的入口文件

## 如何开发

### 配置环境

1. 根据[官方文档](https://github.com/antlr/antlr4/blob/dev/doc/dart-target.md)配置环境
2. 在 IDE 中安装 `antlr v4` 插件

### 开发

1. 修改 [assets/bbcode/BBCode.g4](../../assets/bbcode/BBCode.g4) 文件，通过插件的 Preview 功能确定解析是否正确
2. 通过该文件生成新的 dart 文件到 [lib/bbcode/generated](../../lib/bbcode/generated) 文件夹内
3. 将 [lib/bbcode/BBCodeBaseListener.dart](generated/BBCodeBaseListener.dart) 中的空实现复制到 [lib/bbcode/bbcode.dart](bbcode.dart) 中，参考文件内的注释进行修改

### 测试 BBCode

```
[url=https://bangumi.tv/blog/348736]测试链接[/url][url]https://bangumi.tv/blog/348736[/url][quote][b]用户[/b]测试表情(bgm35)[/quote]测试换行\t\n测试特殊符号[]()测试字符表情(TAT)哈哈哈哈[img]https://p.inari.site/guest/25-01/22/67907598b3a74.jpg[/img]
```
