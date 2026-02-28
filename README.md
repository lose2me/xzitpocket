<div align="center">

# XzitPocket - 掌上徐工

[![License: GPL](https://img.shields.io/badge/License-GPLv3-yellow.svg)](https://opensource.org/licenses/gpl-3-0)

</div>

[掌上徐工](https://github.com/lose2me/xzitpocket) 是跨平台，高性能，以 Material 3 风格为主的便捷校园助手（非官方）。  
<img src="https://github.com/lose2me/xzitpocket/blob/main/screenshots/1.jpg" width="210px">


## 项目规划
当前 ``1.x.x`` 版本

**待办**: 
- [ ] 绘制APP图标，以替代Flutter默认图标。
- [ ] 苹果端适配
- [ ] 鸿蒙端适配
- [ ] 更多个性化设置

*以优先级排序*

``1.x.x`` 版本，仅支持课表功能，请求完全由客户端发出，无服务器中转数据。  
``2.x.x`` 版本，若得到校方授权，开始对接学校通知，使用中继服务器对接，电费查询，水卡查询，图书馆等功能。  

## 版本说明
> 本项目版本号由三个部分组成：主版本号（Major）、次版本号（Minor）和修订版本号（Patch）。这三个部分通过点（.）分隔，形成一个标准的版本号格式，如 1.2.3。

Major：表示软件的主要版本变更。当进行大规模的、不兼容的变更时，应该增加主版本号。  
Minor：表示向后兼容的新功能添加。当软件以向下兼容的方式添加新功能时，应该增加次版本号。  
Patch：表示向后兼容的错误修复或小的改进。  

## 调试

Android
```
flutter run -d emulator-5554
```

## 构建

Android
```
flutter build apk --split-per-abi --split-debug-info=./symbols --obfuscate
```
