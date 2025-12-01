# Demo/文档验收清单（Story14）

当前聚焦本地播放链路，流式播放待 Story10 恢复。

## 环境准备
- 安装 Flutter stable，确保 `flutter doctor` 通过。
- 拉取仓库，建议设置可写 HOME：`export HOME=/tmp/soundwave_home`。
- 准备本地音频文件：`/tmp/sample.mp3`（或自行指定文件路径）。

## 快速开始（需满足即为通过）
1) 在 `soundwave_player` 目录执行：
   - `dart format --output=none lib test`
   - `flutter analyze`
   - `flutter test`（流式相关用例已标记跳过，不应失败）。
2) 运行示例（profile 或 release 均可），指定本地音频：
   - `cd soundwave_player/example`
   - `flutter run --dart-define=SOUNDWAVE_SAMPLE_URL=file:///tmp/sample.mp3`
3) 在 Demo 页面：
   - 输入/确认音频路径，点击播放，音频可正常播放。
   - 波形/频谱有刷新（本地可视化），无明显掉帧。
   - 前后台切换：返回前台后播放持续、波形可继续刷新。

## 已知限制（验收不要求）
- 流式播放/弱网行为暂未实现（Story10）。
- Android 通知栏样式为占位，如需定制另行处理。
