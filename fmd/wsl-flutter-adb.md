# WSL 调用 Windows 版 flutter / adb

WSL 不能直接执行 Windows 的 `flutter.bat`，需通过 `cmd.exe` 打通。已在 `/usr/local/bin` 建好转发脚本，可在 WSL 里直接用 `flutter`、`adb`、`dart`、`fastboot`。

## 脚本内容

`/usr/local/bin/flutter`
```sh
#!/bin/sh
exec /mnt/c/Windows/System32/cmd.exe /c "C:\userdata\sdk\flutter\bin\flutter.bat" "$@"
```

`/usr/local/bin/adb`
```sh
#!/bin/sh
exec "/mnt/c/Users/kalip/AppData/Local/Android/sdk/platform-tools/adb.exe" "$@"
```

`/usr/local/bin/dart`
```sh
#!/bin/sh
exec "/mnt/c/userdata/sdk/flutter/bin/cache/dart-sdk/bin/dart.exe" "$@"
```

`/usr/local/bin/fastboot`
```sh
#!/bin/sh
exec "/mnt/c/Users/kalip/AppData/Local/Android/sdk/platform-tools/fastboot.exe" "$@"
```

## 注意
- 别用 `flutter/bin` 里那个无后缀的 bash `flutter`（是 Linux 版，这套 SDK 是 Windows 版，会报 `dart: No such file or directory`）。