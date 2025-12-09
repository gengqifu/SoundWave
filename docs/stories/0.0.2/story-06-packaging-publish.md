# Story 06：AAR/XCFramework 构建与发布准备

## 目标
- 产出可发布的 Android AAR（Maven）与 iOS XCFramework，支持源码/二进制双模式集成，准备发布脚本与文档。

## 测试优先（TDD）
- ✖️ [1] 构建测试：AAR/XCFramework 本地构建脚本执行成功，产物包含核心符号与所需资源。
- ✖️ [2] 集成测试：新建最小宿主项目分别引用 AAR/XCFramework，验证 PCM push/波形/频谱事件通路。
- ✖️ [3] 发布脚本检查：Maven/本地私有仓库推送、XCFramework 打包脚本可执行。

## 开发任务
- ✖️ [4] Android 构建：Gradle/CMake 配置输出 AAR，处理 ABI/符号、版本号、POM 元数据。
- ✖️ [5] iOS 构建：Xcode/CMake 生成 XCFramework（静态/动态选择），准备 SPM/Pod 集成说明。
- ✖️ [6] 发布与文档：编写发布脚本与 README/接入说明，包含版本/依赖/示例。

## 完成标准（DoD）
- ✖️ [7] 构建与宿主集成验证通过，核心 API/事件可用。
- ✖️ [8] 发布脚本与文档齐全，版本号/依赖声明清晰。 
