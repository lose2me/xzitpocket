<div align="center">

# XzitPocket - 掌上徐工

[![License: GPL](https://img.shields.io/badge/License-GPLv3-yellow.svg)](https://opensource.org/licenses/gpl-3-0)

</div>

[掌上徐工](https://github.com/lose2me/xzitpocket) 是跨平台，高性能，开源，以 Material 3 风格为主的便捷校园助手（非官方）。  

> 当 ``WakeUp课程表`` 开始变更开发者，植入开屏广告，我就知道我该做些什么了。

<div align="center">

***``永无广告`` ``永久开源``***

</div>

**待办 | 较大更新**: 
- [x] 桌面小组件支持
- [x] 设计软件图标
- [ ] 苹果端适配
- [x] 更多小组件类型支持
- [x] 界面优化
- [ ] 更多个性化设置
*以优先级排序*

## 软件截图
<p align="center">
  <img src="https://github.com/lose2me/xzitpocket/blob/main/screenshots/1.jpg" width="210px" />
  <img src="https://github.com/lose2me/xzitpocket/blob/main/screenshots/2.jpg" width="210px" />
  <img src="https://github.com/lose2me/xzitpocket/blob/main/screenshots/3.jpg" width="210px" />
</p>


## 调试
Android
```
flutter run -d emulator-5554 --target-platform android-arm64
```

## 构建
Android
```
flutter build apk --target-platform android-arm64 --split-debug-info=./symbols --obfuscate
```

## Release
Android
```
flutter build apk --release --target-platform android-arm64 --dart-define-from-file=tool/upgradelink.local.json
```