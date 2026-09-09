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


## 架构

```mermaid
flowchart TD

subgraph group_flutter["Flutter 应用"]
  node_main(("Flutter 入口<br/>Dart 入口点<br/>[main.dart]"))
  node_app["应用组合<br/>Flutter 应用外壳<br/>[app.dart]"]
  node_routes["路由<br/>导航<br/>[app_routes.dart]"]
  node_home["首页<br/>功能页面<br/>[home_page.dart]"]
  node_tools["校园工具<br/>功能页面<br/>[tools_page.dart]"]
  node_state["应用状态<br/>Provider 状态<br/>[auth_provider.dart]"]
  node_storage[("本地存储<br/>持久化服务")]
  node_timetable["课程表 UI<br/>学业功能"]
  node_schedule_state["课程表状态<br/>Provider 状态"]
  node_course["课程模型<br/>领域模型<br/>[course.dart]"]
  node_grid["课程表网格<br/>渲染器"]
  node_calendar_rules["校历规则<br/>学期配置"]
end

subgraph group_campus["校园集成"]
  node_campus_clients["校园客户端<br/>服务客户端<br/>[cas_service.dart]"]
  node_http["HTTP 客户端工厂<br/>传输边界<br/>[dio_factory.dart]"]
end

subgraph group_android["Android 集成"]
  node_native_bridge["原生能力桥接<br/>Flutter 服务"]
  node_android_host["Android Flutter 宿主<br/>MainActivity<br/>[MainActivity.kt]"]
  node_widget_pipeline["小组件数据管道<br/>原生小组件同步"]
  node_widget_scheduler["小组件调度器<br/>WorkManager"]
  node_automation["课程自动化<br/>原生自动化"]
end

subgraph group_delivery["交付与诊断"]
  node_updates["更新服务<br/>应用更新客户端"]
  node_diagnostics["诊断<br/>日志记录与上报<br/>[talker.dart]"]
  node_build["Android 构建<br/>Gradle 构建<br/>[build.gradle.kts]"]
  node_ci["Android CI<br/>GitHub Actions<br/>[android-build.yml]"]
end

node_main -->|"初始化"| node_app
node_app -->|"配置"| node_routes
node_routes -->|"导航到"| node_home
node_routes -->|"导航到"| node_tools
node_routes -->|"导航到"| node_timetable
node_app -->|"提供"| node_state
node_state -->|"持久化到"| node_storage
node_timetable -->|"读取"| node_schedule_state
node_schedule_state -->|"管理"| node_course
node_schedule_state -->|"存储课程"| node_storage
node_timetable -->|"渲染"| node_grid
node_grid -->|"显示"| node_course
node_grid -->|"使用"| node_calendar_rules
node_state -->|"认证"| node_campus_clients
node_tools -->|"使用"| node_campus_clients
node_campus_clients -->|"使用"| node_http
node_app -->|"调用"| node_native_bridge
node_android_host -->|"承载"| node_app
node_native_bridge -->|"桥接到"| node_widget_pipeline
node_native_bridge -->|"桥接到"| node_automation
node_widget_scheduler -->|"触发更新"| node_widget_pipeline
node_app -->|"检查更新"| node_updates
node_app -.->|"上报"| node_diagnostics
node_ci -->|"运行"| node_build

classDef toneNeutral fill:#f8fafc,stroke:#334155,stroke-width:1.5px,color:#0f172a
classDef toneBlue fill:#dbeafe,stroke:#2563eb,stroke-width:1.5px,color:#172554
classDef toneAmber fill:#fef3c7,stroke:#d97706,stroke-width:1.5px,color:#78350f
classDef toneMint fill:#dcfce7,stroke:#16a34a,stroke-width:1.5px,color:#14532d
classDef toneRose fill:#ffe4e6,stroke:#e11d48,stroke-width:1.5px,color:#881337
classDef toneIndigo fill:#e0e7ff,stroke:#4f46e5,stroke-width:1.5px,color:#312e81
classDef toneTeal fill:#ccfbf1,stroke:#0f766e,stroke-width:1.5px,color:#134e4a
class node_main,node_app,node_routes,node_home,node_tools,node_state,node_storage,node_timetable,node_schedule_state,node_course,node_grid,node_calendar_rules toneBlue
class node_campus_clients,node_http toneAmber
class node_native_bridge,node_android_host,node_widget_pipeline,node_widget_scheduler,node_automation toneMint
class node_updates,node_diagnostics,node_build,node_ci toneRose
```


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
flutter build apk --release --target-platform android-arm64
```
