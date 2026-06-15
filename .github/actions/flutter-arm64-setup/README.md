# Flutter ARM64 Linux Setup Action

在 ARM64 Linux 上安装 Flutter 的 GitHub Action。

Flutter 官方不提供 ARM64 Linux 的预编译 SDK 包，本 action 通过 `git clone` + 自动触发 Dart SDK 下载的方式，在 `ubuntu-24.04-arm` runner 上完成安装。

## 用法

```yaml
name: Flutter ARM64 CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-24.04-arm
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: ./flutter-arm64-setup

      - run: flutter build linux
```

## Inputs

| 参数 | 必需 | 默认值 | 说明 |
|---|---|---|---|
| `channel` | 否 | `stable` | Flutter 频道 (stable, beta, main) |
| `flutter-version` | 否 | `""` | 指定版本（git ref），覆盖 channel |
| `cache` | 否 | `true` | 是否缓存 Flutter SDK |
| `cache-key` | 否 | `""` | 额外缓存 key 后缀 |
| `install-linux-deps` | 否 | `true` | 是否安装 Linux 桌面构建依赖 |

## Outputs

| 输出 | 说明 |
|---|---|
| `flutter-path` | Flutter SDK 路径 |
| `flutter-version` | 安装的 Flutter 版本 |
| `dart-version` | 捆绑的 Dart 版本 |

## 高级用法

固定版本：

```yaml
- uses: ./flutter-arm64-setup
  with:
    flutter-version: '3.44.2'
```

跳过 Linux 依赖（Web 开发等）：

```yaml
- uses: ./flutter-arm64-setup
  with:
    install-linux-deps: 'false'
```
