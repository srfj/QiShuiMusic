# QiShuiMusic

汽水音乐（`com.soda.music`）TrollStore 注入插件：屏蔽启动时的强制升级弹窗。

## 原理

汽水音乐使用字节通用 `TTAppUpdate` 模块做版本检测：

| 环节 | 类 / 方法 |
| --- | --- |
| 发起检测 | `-[TTAppUpdateHelper startCheckVersion]` |
| 发起检测 | `-[TTAppUpdateHelperDefault startCheckVersion]` |
| 解析响应 | `-[TTAppUpdateHelper handleResponseWithJsonObjc:]` |
| 展示弹窗 | `-[TTAppUpdateHelperDefault showUpdateViewWithModel:error:]` |
| 展示弹窗 | `-[TTAppUpdateHelperDefault showWithModel:]` |
| 汽水封装 | `STOuterTest.STAppUpdateHelper` |

检测请求发往 `/check_version/v7/`，响应中的 `force_update` 决定弹窗是否强制。

插件用 `method_setImplementation` 做两层拦截：

1. `startCheckVersion` 置空 —— 不发起版本检测请求；
2. 弹窗展示方法置空 —— 即使有其它入口触发，也不会弹出更新界面。

之所以不改 `force_update`：它是服务端下发字段，直接丢弃检查请求比篡改 UI 状态更稳定，也不会影响 App 其它联网功能。

## 构建

需要 macOS 或已配置 iOS 交叉编译工具链的 Linux 环境（clang + iPhoneOS SDK + ldid）。

```bash
./build.sh <原始解密版.ipa> [输出.ipa]
```

脚本会依次完成：编译 `SodaUpdateFix.dylib` → 解包 → 注入 `LC_LOAD_DYLIB` → 复制到 `Frameworks/` → `ldid` 重签 → 打包。

工具链路径可用环境变量覆盖：`TOOLCHAIN`、`SDK`、`LDID`、`LDID_LIB`、`TINFO_LIB`。

## 安装

- 方式一：TrollStore 直接安装构建出的 IPA；
- 方式二：用 TrollFools 把 `SodaUpdateFix.dylib` 注入原版 App。

## 兼容性

在汽水音乐 10.3.0（arm64）上逆向定位；同版本族（类名未变更）可直接复用。若新版本仍弹窗，说明存在其它更新通道，可继续 hook `handleResponseWithJsonObjc:` 丢弃服务端返回。

## 声明

仅供个人学习与逆向工程研究，请勿用于商业用途。
