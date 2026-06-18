# BNBU 学生端 iOS App 模拟器运行命令

以下命令均在终端执行。

## 方式一：从源码打开 Xcode

```bash
cd /Users/labyr1nth/Desktop/DaKa/ios-app
open BNBUStudent.xcodeproj
```

在 Xcode 中选择任意 iPhone Simulator，然后点击 Run。

## 方式二：安装交付包中的 Simulator App

先进入交付目录：

```bash
cd /Users/labyr1nth/Desktop/DaKa/deliverables/BNBUStudent-iOS-MVP-20260613-v1
```

解压模拟器 App：

```bash
ditto -x -k BNBUStudent-Simulator-Debug.app.zip .
```

启动模拟器：

```bash
xcrun simctl boot "iPhone 17 Pro"
```

如果模拟器已经启动，上面的命令可能提示已启动，可忽略。

安装 App：

```bash
xcrun simctl install booted BNBUStudent.app
```

启动 App：

```bash
xcrun simctl launch booted edu.bnbu.student.mvp
```

打开 Simulator 界面：

```bash
open -a Simulator
```

## 重置本地演示数据后启动

```bash
xcrun simctl terminate booted edu.bnbu.student.mvp
xcrun simctl launch booted edu.bnbu.student.mvp --args -ui-testing-reset
```

## 预览空状态版本

```bash
xcrun simctl terminate booted edu.bnbu.student.mvp
xcrun simctl launch booted edu.bnbu.student.mvp --args -ui-testing-reset -ui-testing-empty-state
```

## 从源码重新构建

```bash
xcodebuild -project /Users/labyr1nth/Desktop/DaKa/ios-app/BNBUStudent.xcodeproj \
  -target BNBUStudent \
  -configuration Debug \
  -sdk iphonesimulator \
  SYMROOT=/Users/labyr1nth/Desktop/DaKa/ios-app/build \
  CLANG_MODULE_CACHE_PATH=/Users/labyr1nth/Desktop/DaKa/ios-app/build/ModuleCache.noindex \
  build
```

构建产物：

```text
/Users/labyr1nth/Desktop/DaKa/ios-app/build/Debug-iphonesimulator/BNBUStudent.app
```
