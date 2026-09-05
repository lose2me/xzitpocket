<div align="center">

# XzitPocket - 掌上徐工

[![License: GPL](https://img.shields.io/badge/License-GPLv3-yellow.svg)](https://opensource.org/licenses/gpl-3-0)

</div>

[掌上徐工](https://github.com/lose2me/xzitpocket) 是一款开源，高性能，跨平台，以 MD3 风格为主的校园助手APP（非官方）。  

> 当 ``WakeUp课程表`` 开始变更开发者，植入开屏广告时，我就知道我该做些什么了。

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
  <img src="https://github.com/lose2me/xzitpocket/blob/main/screenshots/1.jpg" width="180px" />
  <img src="https://github.com/lose2me/xzitpocket/blob/main/screenshots/2.jpg" width="180px" />
  <img src="https://github.com/lose2me/xzitpocket/blob/main/screenshots/3.jpg" width="180px" />
  <img src="https://github.com/lose2me/xzitpocket/blob/main/screenshots/4.jpg" width="180px" />
</p>


## 调试
Android
```
flutter run -d emulator-5554 --target-platform android-arm64
```

APP 固定连接 `https://con.xuda.live`。Control 服务不可用时，OA 登录、APP 启动和其他免费功能保持可用；学习中心入口会自动禁用。

调试日志默认关闭。启用 Talker 调试日志后，仅错误级别记录会脱敏并按当前学号自动上报 Control，完整请求和响应日志只保留在本地。

## 构建
Android
```
flutter build apk --target-platform android-arm64 --split-debug-info=./symbols --obfuscate
```

## Release
Android
```
flutter build apk --release --target-platform android-arm64
```
