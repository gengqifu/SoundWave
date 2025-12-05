# Story 02：C/C++ 音频核心基础

## 目标
搭建跨平台 C/C++ 音频核心骨架与 CMake 工程，抽象 `AudioEngine` 接口（`init/load/play/pause/stop/seek`），空跑回调，确保可编译和单测跑通（TDD）。

## 测试优先（TDD）
- ✅ [1] 先编写 gtest：接口实例化、生命周期调用序列（init→play→pause→stop）空实现不崩溃，返回成功码。
- ✅ [2] 验证 CMake 构建目标存在、可被测试用例链接。

## 开发任务
- ✅ [3] 创建 `AudioEngine` 接口与空实现（stub），定义初始化参数结构。
- ✅ [4] 预留解码、缓冲、时钟、事件回调接口（纯虚/空实现）。
- ✅ [5] 配置 CMake 构建，输出静态/共享库供插件桥接。
- ✅ [6] 引入 gtest 测试框架，基础编译与运行脚本。

## 完成标准（DoD）
- ✅ [7] gtest 通过：接口实例化与生命周期调用无崩溃。
- ✅ [8] CMake 配置在 iOS/Android toolchain 下可生成库（本地可模拟类 Unix 交叉编译检查）。
- ✅ [9] 基础 API/类型声明文档化。
