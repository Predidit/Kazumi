# 贡献指引

欢迎您提交 Pull Request 来一起建设这个项目！

在开始之前, 请先阅读这份指引, 以保障审阅者和您之间的协作效率。

## 开发环境设置

### 前置需求

- [Flutter SDK](https://flutter.dev/) - 本项目的开发框架。
- 良好的网络环境
    - 建议至少保证 Google, Github, SourceForge, MavenCentral, pub.dev 的可访问性。
    - 某些资源访问质量不佳时, 可能需要通过设置镜像地址或其他方式解决。
- 开发侧所需的 SDK, 如 [Android SDK](https://developer.android.com/) 等。在配置 Flutter 时, 也会要求下载安装开发侧 SDK.

### 基本配置

```bash
# 克隆仓库
git clone https://github.com/Predidit/Kazumi.git
cd Kazumi

# 检查 Flutter SDK 状态并下载相关包
flutter doctor -v
flutter pub get

# 进行检查
flutter test
flutter analyze --no-fatal-infos --fatal-warnings

# 进行调试
flutter run
# flutter run --profile
# flutter run --release

# 为生产环境编译
flutter build apk --release
# flutter build windows --release
# flutter build macos --release
# ...
```

## 代码质量

您的更改应该通过检查和验证。

```bash
flutter test
flutter analyze --no-fatal-infos --fatal-warnings
```

## 编写规范

项目大多数功能都遵循 `抽象 -> 调用` 的实现。不同组件按职责分类存放, UI 组件、功能、页面、服务分属不同目录, 互不混写。

有关项目中不同组件的分类, 可以参考 [项目结构树](STRUCTURE.md) 或自行查看。

开发过程中, 您应该**慎重考虑**新增外部库、会导致包体积大量膨胀的实现和其它不安全的行为。

- 如果要引入新的外部库 - 考虑一下是否有更轻便的实现方法？
- 如果功能会导致包体积巨增 - 也许这个功能目前不应该实现？
- 如果需要使用 `Print()` 等输出 - 使用 `KazumiLogger` 或其它代替？
- 如果性能表现大打折扣 - 当前功能的思路是不是需要重新考虑？

当出现行为或风险改动时, 您应该完善测试文件。有的修改也无需测试文件, 可在推送 PR 后关注审查者意见。

## 更改与 Commits

建议使用 [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(theme): 增加新的主题设计
fix(external_player): 修复外部播放器启动失败的问题
refactor: re-design parser implements
chore: replace print() with KazumiLogger
docs: 更新文档 Q&A 
```

**不建议您使用模糊不清的 commits**, 反之, 上述建议能够使 commits 准确简洁地说明您做出的工作, 为审查提供便利。

## 推送与 Pull Requests

### 限制

您的 PR 至少应该符合以下基本要求: 
- **一个 PR 只解决一件事情**。比起把多个功能、调整和修复都堆在一个 PR 中, 把它们拆开并分别创建 PR, 分别提交是正确的选择。
- **一个 PR 更改的代码量不应太多**。1000 行甚至更多的更改是不建议的, 可以分成几个 PR 分别提交, 利于审查和修改。
- **提交 PR 时的描述部分必须由您亲自填写**。您可以利用 AI 润色措辞, 但不得让 AI 直接生成整个描述, 也不得完全依赖 AI 撰写。

### 类型

在推送 PR 时, 根据类型不同可以分为: 
- Bug 修复 - 您应当打开 Issue 并确认所描述的 Bug 已修复, 然后在 PR 中引用该 Issue。
- 新功能 - 编写代码和推送前, 请确认这个新功能已经被维护者批准, 以防您的贡献因为不在计划中而拒绝合并。
- 功能重构 - 重构和新功能应当清楚分开。在重构功能时, 不要加入新功能。

### PR 标题

您的 PR 标题应该遵循 [Conventional Commits](https://www.conventionalcommits.org/) 的格式:

```
refactor: 重构 WebDAV 同步功能
feat(danmaku): 为弹幕添加了新的屏蔽方法
fix(network): fix proxy issues
```

同样, 遵循该规范能够使标题准确、简洁地说明您做出的工作。

### 推送 PR 之后

KiloCode Bot 会对您的 PR 和改动先进行检查。如果出现了问题, 您需要进行修复。
当检查通过、没有合并冲突且审查者没有其他意见时, PR 会被合并。

如果最终 PR 未被接受合并, 通常可能是因为该实现有以下问题之一: 
- 这个实现的性能开销无法接受。
- 这个实现会导致安全或隐私问题。
- 这个实现过于臃肿, 可能有更好的方法。
- 这个实现只有部分设计比较好, 其它的部分有更好的方法。
- 这个实现不在计划中。
- 其它...

一般情况下都会解释为什么您的 PR 没有被接受。**这并非对您工作的否定, 只是因为您的贡献可能并不适合项目当前的情况。我们感谢您所做的付出！**

### AI 参与辅助开发

我们欢迎您使用 AI 辅助开发工作, 这可以为您带来便利。然而, 我们无法接受的是直接让 AI 生成代码, 却不加检查就直接提交, 根本没有处理 AI 产物中的冗余和问题 (Vibe Coding -> AI Slop)。这不仅严重降低审查者和您之间的协作效率, 还不利于 PR 处理。

因此, 当您使用了 AI 参与开发工作时, 您必须遵守以下规则。

#### 规则:

1. **如果您使用了 AI 辅助开发, 您不应该隐瞒。**
2. 您应当理解 AI 写出的每行代码, 了解 AI 做了什么。
3. 当审查者询问某处改动的原因, 您需要作出解释, 不论这是您写的还是 AI 写的。
4. 您的 PR 中不应该出现 `AI 生成 -> 修复 -> 修复 -> 修复` 多次这样的循环, 这可能显示您并没有审查 AI 生成的代码, 而是在出现问题后再让 AI 自己修复, 循环往复。

#### 提交:

Pull Request 模板中有关于 AI 辅助的部分。如果您使用了 AI 辅助开发, 您需要说明所使用的**确切模型**, 例如 `OpenAI GPT-5.6 Sol` 或 `Claude Fable 5` 。

```
AI 辅助模型: Kimi-K3
```

某些模型在辅助开发方面的性能不足, 而这种信息能够帮助我们更好地判断代码质量。

审查 AI 生成的代码有时会比审查人类所写的代码更耗时耗力。我们制定这样的规则, 是为了维护 Pull Request 秩序, 避免被繁杂无效的纯 AI 生成产物干扰。**因此, 如果您的 Pull Request 违反了上述规则, 您的 Pull Request 可能被延后处理或直接关闭。**


## 许可证

本项目基于 [GNU 通用公共许可证第 3 版（GPL-3.0）](../../LICENSE)授权。参与贡献即说明您同意您的代码以此许可证进行许可。