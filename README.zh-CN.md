<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-HapCLI-c96b2c?style=for-the-badge&labelColor=1f2430" alt="Cangjie HapCLI" />
  <img src="https://img.shields.io/badge/source-0.3.0-3182ce?style=for-the-badge&labelColor=1f2430" alt="Source 0.3.0" />
  <img src="https://img.shields.io/badge/mode-local--first-2f855a?style=for-the-badge&labelColor=1f2430" alt="本地优先" />
  <img src="https://img.shields.io/badge/focus-toolchain%20glue-805ad5?style=for-the-badge&labelColor=1f2430" alt="工具链兼容层" />
  <img src="https://img.shields.io/badge/license-Apache--2.0-d69e2e?style=for-the-badge&labelColor=1f2430" alt="Apache License 2.0" />
</p>
<div align="center">
<span style="font-weight:300;font-size:38px">HapCLI</span><br/>
<span style="font-weight:100;font-size:24px">本地优先的工具链兼容与修复工具</span>
<p align="center">
  <strong>先检查，再规划修复；只执行固定适配器，并保留回执。</strong><br/>
  <sub>仓颉 · Semeru JDK · Android SDK · OpenHarmony · HarmonyOS · KMP</sub>
</p>
</div>

[English](README.md) | **简体中文** | [Русский](README.ru.md)

## HapCLI 是什么

HapCLI 是一套开源命令行兼容层，主要解决项目在开发机、CI、云端和连接设备之间切换时出现的工具链配置漂移。它提供仓颉与 SDK/JDK 工具链安装，并支持仓颉/cjpm、HarmonyOS 应用开发和 Kotlin Multiplatform 工作流。

HapCLI 不替代 `cjpm`、Gradle、Xcode、DevEco Studio、`hdc` 或包管理器。它负责识别项目与环境事实，输出可审查的方案，调用有限且固定的工具适配器，并记录结构化结果。

## 快速开始

本说明对应**源码版本 0.3.0**。可下载的版本和主机资产以
[GitHub Releases](https://github.com/HapPub/Hap/releases) 为准；源码版本徽章不代表对应二进制已经发布。

已有 0.2.0 或更新版本的 Hapup 时，可安装最新已发布的 HapCLI：

```bash
hapup install
hap version
```

首次安装见[安装说明](docs/INSTALLATION.md)。如果已发布二进制还不支持下面的命令，
可[从当前源码构建](docs/INSTALLATION.md#build-from-source)。
完整仓颉安装需要 HapCLI 0.2.0 或更新版本；SDK/JDK 安装需要 **0.3.0 或更新版本**。

可独立选择构建 HapCLI 所用的编译器，见[仓颉 1.0.5 / 1.1.3 发行说明](docs/RELEASING.md#selecting-a-toolchain-qualified-release)。手动解压安装时须保留随包运行库。

### 安装工具链

```bash
hap get cangjie --version sts
# 精确指定版本：hap get cangjie --version 1.1.3
hap get jdk --provider semeru --version 17
hap get android --version 36 --accept-licenses
hap get ohos --version 6.0 --profile native
```

仓颉 `sts` 会自动配对 SDK **1.1.3** 与 stdx **1.1.3.1**，无需手动查找不同的发布标签。
安装器完成下载、校验和工具验证后，再激活私有环境。新终端自动加载，当前终端执行返回的
`activationHint` 即可。`--plan` 不联网、不写文件；`--no-activate` 只安装，不切换当前选择。

SDK/JDK 安装目前在**本机 macOS/Linux** 执行；Windows 和跨主机目标只提供计划。
各提供方的目录范围不同，例如 HarmonyOS 内置目录目前对应 **Linux x64**：

```bash
hap get harmonyos --version 5.1.0.840 --accept-licenses
```

其他 HarmonyOS 主机或版本需要官方归档，或 HTTPS 地址及 SHA-256。
使用 `--accept-licenses` 前请阅读提供方的许可条款。
Android NDK/CMake、平台范围、私有 Java 启动器和多环境共存见
[SDK/JDK 安装指南](docs/SDK_TOOLCHAINS.md)。

### 检查项目

```bash
hap project detect --project .
hap toolchain providers
hap help
```

## 核心能力

- 区分普通仓颉/cjpm、仓颉原生 HarmonyOS 打包工作区、hvigor HarmonyOS、iOS 和 Compose Multiplatform 项目。
- 在选择打包 Provider 之前，只读检查仓颉原生 HarmonyOS 的 `[app]` / `[workspace]` 与 HAP/HSP/HAR 模块图。
- 检查 `cjpm.toml`，诊断本地 `path` 依赖与远端 `git` 依赖的差异。
- 从可构建项目记录 stdx 目标配置，在其他项目中规划或写入带备份的修复。
- 执行固定的 `cjpm build` 和 `cjpm bundle`，提供受限的环境诊断、一次修复重试和中心仓依赖发布顺序提示。
- `hap get cangjie` 安装完整 SDK/stdx，验证编译运行后备份并配置 shell 环境；单组件 `hap install cangjie*` 保留只安装、不改 shell 的契约。
- 安装 Semeru JDK、Android SDK 与可选 NDK/CMake、OpenHarmony SDK 和 HarmonyOS Command Line Tools，校验包与工具并分别管理环境；可用范围取决于提供方和主机。
- 通过固定的 `hvigor` 与 `hdc` 命令构建、安装、启动和验证 HarmonyOS 应用。
- 按 Phone/Tablet/Fold/PC 布局先请求 HarmonyOS 窗口尺寸，再用 bundle PID
  绑定 WMS 实际矩形，截取 display 并生成结构化窗口截图回执。
- 保存经过确认的 HarmonyOS 设备别名和最近一次 USB 证明的无线端点，不扫描局域网。
- 运行 Compose Multiplatform 桌面应用；在主机已有有效 Apple 签名资产时构建、安装和启动 iOS 应用。
- 诊断 GitHub Actions 并生成可审查的 CI 脚本，CLI 不直接修改工作流文件。
- 默认输出面向人类的简洁结果；`-v` / `--verbose` 输出结构化细节，`--write-receipt` 生成明确的 自动化/CI 回执。

## 常用流程

### 仓颉与 stdx

```bash
hap inspect-cjpm ./cjpm.toml
hap record cangjie.stdx --project . --target x86_64-unknown-linux-gnu
hap doctorfix cangjie.stdx --project . --target x86_64-unknown-linux-gnu --plan
hap build --project . --target x86_64-unknown-linux-gnu
hap bundle --project . --skip-lint
hap install cangjie@latest --target macos-arm64 --region auto
hap install cangjie-sdk@1.1.3 --target linux-amd64 --region global
hap install cangjie-stdx@1.1.3 --target macos-arm64 --region zh-cn
hap install cangjie@nightly --target macos-arm64 --route auto
hap install cangjie@latest --target macos-arm64 --plan
hap get cangjie-sdk --target linux-amd64 --version <nightly-tag> --region auto --install-root "$HOME/.hap/runtimes"
hap get cangjie-stdx --target linux-amd64 --version <nightly-tag> --region auto --install-root "$HOME/.hap/stdx"
```

在单组件 `hap install` 接口中，`cangjie` 是 `cangjie-sdk` 的别名；`cangjie-stdx` 始终是独立包。省略版本、
`@latest` 或 `@lts` 都固定解析到当前 LTS `1.0.5`；`@1.1.3` 保持精确 STS；
`@nightly` 动态解析最新且通过校验的预发布版本，也可用
`@1.3.0-alpha.20260828010050` 这样的有界精确 nightly 标签复现安装。
默认安装到 `~/.hap/toolchains`；显式根目录只能位于 `HOME/.hap` 或操作系统临时目录内。
`--plan` 不下载也不写文件。

在交互终端中直接运行 `hap install cangjie` 会打开安装 TUI：先选择 LTS、STS 或
当前动态解析出的 nightly，
再对受审阅的 HapPub 镜像、中国大陆加速线路和官方源执行有界 HTTPS 延迟观测，
随后可选择“自动采用当前最快成功线路”或强制指定一条线路，并在最终确认后安装。
探测失败会明确显示“不可达”，不会伪造延迟。脚本、重定向输入、显式版本和
`--plan` 仍保持非交互；自动化脚本和 CI 可使用
`--route auto|mirror|ghfast|ghproxy|official`，强制线路不会静默回退。测速只证明
本次传输状态，不替代固定 SHA-256 校验权威。

两个旧 `get` 命令仍保留为只生成方案的获取入口；真实 nightly 安装现已由 `install`
支持。`--plan` 会报告等待动态解析且完全不访问网络。HapCLI 将
`https://cli.hap.pub/manifests/cangjie-install-v1.json` 作为经过 schema 校验的补充字典；
字典缺失、过期，或返回官网 HTML 而非 JSON 时，会回退到 HapPub Mirror 的实时索引。
最终版本对应的精确 `manifest.v1.json` 仍是资产与 SHA-256 权威。
真实稳定/LTS 安装中，`global` 优先使用
[CangjieSDK-Mirror](https://github.com/HapPub/CangjieSDK-Mirror)，`zh-cn` 在同一
镜像 URL 前添加受控加速前缀，然后回退到直连镜像与官方源；加速器不是校验权威。
字节级校验始终由精确镜像 `manifest.v1.json` 与固定 SHA-256 决定。

### HarmonyOS 应用开发

```bash
hap project detect --project .
hap device --project .
hap dev --project .
hap dev --project . --device demo-phone
hap dev --project . --device 192.0.2.40:5555 -v
hap prnt --project . --device demo-pc --layoutType Phone --ratio 18:9 --plan
hap prnt --project . --device demo-pc --layoutType Tablet/Fold4:3
```

纯仓颉 HarmonyOS 工作区会被识别为独立的 `cangjie-harmonyos`，不会再折叠成
普通 `cangjie`，也不会与 hvigor 工程混为一谈：

```bash
hap project detect --project ./native-harmony-app
hap build --project ./native-harmony-app --platform cangjie-harmonyos --plan
```

检测器读取根清单的 `[app]` / `[workspace]`，以及成员清单的 `[hap]`、
`[hsp]`、`[har]`。打包能力默认 fail-close：在独立审计、固定 argv 且能输出
结构化回执的 Provider 接入前，构建计划返回 `package-provider-required`；这一
入口不会静默采用外部打包器，也不会生成、签名、安装或启动 HAP。

`hap prnt` 严格按“窗口参数 → PID/WMS 实际矩形 → display 截图 → 实际矩形裁剪”
执行。Phone 支持 `16:9`、`18:9`、`21:9`；Tablet/Fold 支持
`Fold4:3`、`Fold√2:1`、`Fold1.15:1`、`16:9`、`3:2`、`7:5`；PC 支持
`2in1`。字面值 `trible` 仅在同时提供 `--width` 和 `--height` 时接受，
避免工具擅自猜比例。外部截图仍可能包含遮挡物，不能代替视觉验收。

当目录中只有一种受支持项目时，`hap dev` 会自动选择流程。只有混合目录或无法明确识别时，才需要 `--platform`。

### Kotlin Multiplatform

```bash
hap dev --project . --target desktop
hap dev --project . --target ios
hap dev --project . --target ios --useOld --artifact ./iosApp/build/Debug-iphoneos/DemoApp.app
```

### CI 与依赖图

```bash
hap ci action-doctor --workflow .github/workflows/build.yml --project . --target linux-amd64
hap cjpm graph doctor --manifest ./cjpm.toml
hap cjpm graph ci-workflow-export --manifest ./cjpm.toml --workflow-output /tmp/hap-preflight.yml --review-token reviewed
```

## 平台状态

| 能力面 | 状态 | 真实边界 |
| --- | --- | --- |
| SDK/JDK 安装 | 本机 macOS/Linux 执行；Windows/跨主机只提供计划 | 下列提供方范围与 HapCLI 二进制可用平台分别说明。 |
| IBM Semeru JDK | 从 GitHub Release 安装；macOS ARM64 已验证 Java 编译运行 | 需要匹配的 Open Edition JDK 资产；不代表兼容所有 Gradle 项目。 |
| Android SDK/NDK/CMake | 目录覆盖 macOS Intel/ARM、Linux x64；受控集成通过 | 真实上游下载验收尚未完成；需要接受提供方条款并使用兼容 Java。 |
| OpenHarmony SDK | 6.0 目录覆盖 macOS Intel/ARM、Linux x64；macOS ARM64 native/full 已验证 | SDK 6.0.0.47 / API 20；目标对象编译不代表设备运行验收。 |
| HarmonyOS Command Line Tools | 内置 Linux x64 5.1.0.840 目录；支持官方归档/URL | 当前 macOS 真包验收尚未完成；其他主机或版本需要官方资产和 SHA-256。 |
| macOS arm64 仓颉/cjpm | 源码、测试和标签发布链已验证 | 当前仓颉 1.1.3 静态运行时对象要求 macOS 13.3，即使链接目标设置得更低也不能证明更老系统可运行。 |
| Linux AMD64/ARM64 仓颉/cjpm | 已有标签发布链 | 每个发布必须由对应原生 Runner 完成构建、测试和二进制自检。 |
| Windows AMD64 | 两条工具链发行均包含此构建目标 | 必须通过原生测试和 ZIP 解包启动验证；SDK 安装仍只提供计划。 |
| macOS Intel | 保留 nightly 原生构建 | 1.0.5/1.1.3 稳定目录没有对应主机 SDK，需要匹配的 nightly SDK。 |
| OHOS ARM64/AMD64 | nightly 交叉构建和链接验证可用 | 产物尚未在 OHOS 设备上执行运行时自检，并依赖兼容的目标端仓颉运行时。 |
| Windows ARM64/x86 | 已记录上游缺口 | 当前镜像的仓颉发布没有匹配的原生宿主 SDK，因此 HapCLI 不会把其他架构改名后声称支持。 |
| HarmonyOS 应用 | 已有真实构建、安装和启动流程 | 需要可用的 DevEco 工具链、已授权设备和有效签名配置。 |
| 仓颉原生 HarmonyOS 包 | 已有检测、HAP/HSP/HAR 模块图与 Provider 计划 | 在受审固定 Provider 接入前，包生成保持 fail-close。 |
| macOS KMP Desktop | 已验证真实 Gradle 构建与运行 | 其他桌面平台仍需单独现场验证。 |
| KMP iOS/iPadOS | 已实现构建、安装和启动 | Apple 账号、证书、描述文件、开发团队、已配对设备和 CoreDevice 状态仍由主机提供。 |
| Android 设备列表 | 支持只读 ADB 识别 | 尚未实现 APK 构建和安装编排。 |

独立 nightly 工作流会在匹配的 GitHub 托管 Runner 构建 Linux AMD64/ARM64、macOS
ARM64/Intel 与 Windows AMD64；同时使用 Linux-to-OHOS 仓颉 SDK 和经过校验的
OpenHarmony sysroot 交叉构建、链接验证 OHOS ARM64/AMD64。原生产物从归档解压后，
必须在不继承仓颉 SDK 环境的条件下通过 `hap version`，才标记为
`sdk-independent-runtime-smoke-verified`；交叉产物标记为
`cross-built-link-verified`。每次 nightly 还会发布机器可读的运行时可移植性回执和
全镜像覆盖回执，逐项覆盖 SDK、stdx、frontend、文档与源码资产，并明确证明
Windows ARM64/x86 宿主 SDK 当前确实不存在。

## 配置与安全

HapCLI 按以下顺序读取私有配置：

1. `~/.hap/config.toml`
2. 项目内 `./.hapData/config.toml`
3. 仅在识别出受支持项目后读取项目内 `./happub.toml`

仓颉下载渠道依次读取 `--region`、`HAP_REGION`、TOML 的
`downloadRegion`、locale/timezone 信号，最后回退到 `global`。可选值为
`auto`、`global`、`zh-cn`：

```toml
downloadRegion = "auto"
```

对于仓颉项目，旗舰版 `hap build --target ohos` 默认启用工具链自举。如果当前
环境缺少 `cjpm` 或目标 stdx，Hap 会从镜像 manifest 精确解析一组 SDK/stdx，
按 SHA-256 校验下载归档，安装到私有缓存，并且只向固定构建子进程暴露：

```toml
toolchainAutoBootstrap = true
cangjieSdkVersion = "auto"
toolchainCacheRoot = "/absolute/path/to/hap-toolchains"
toolchainBootstrapTimeoutSeconds = 900
toolchainDownloadRetryCount = 2
downloadAcceleration = "auto"
downloadAccelerators = ["https://ghfast.top/", "https://ghproxy.link/"]
```

可以用 `--no-toolchain-bootstrap` 关闭。SDK/stdx 自举不会安装或证明
OpenHarmony native sysroot、签名资产、运行时或设备验收。

设备别名使用同样的本地优先回退方式。公开示例只使用合成标识；请勿提交真实设备序列号、UDID、局域网地址、令牌、回执或设备记忆文件。

子工具进程默认使用 `no-proxy`。只有明确传入 `--proxy` 时，才继承当前 Shell 的代理变量。Review token 只是人工确认的存在性闸门，不是身份认证凭据。受审执行入口不接受任意 Shell 指令。

## 开发与验证

```bash
export SDKROOT="$(xcrun --show-sdk-path)"  # 仅 macOS
cjpm build
cjpm test --timeout-each=30s --no-progress --no-color
sh -n release/hapup.sh
sh tests/hapup-security.sh
sh tests/public-surface.sh
sh tests/release-workflow.sh
sh tests/nightly-workflow.sh
```

GitHub 的公开面工作流会检查文档、发布元数据、Shell 语法、checksum 和安装器安全样例。与包版本一致的 `v*` 标签会下载 checksum 固定的仓颉官方 SDK；只有通过原生构建、测试和版本自检的二进制才会发布。

## 文档

- [HapCLI 与仓颉安装](docs/INSTALLATION.md)
- [SDK 与 JDK 安装](docs/SDK_TOOLCHAINS.md)
- [命令参考](docs/COMMAND_REFERENCE.md)
- [架构](docs/ARCHITECTURE.md)
- [stdx 自学习与 doctorfix](docs/STDX_SELF_LEARNING_AND_DOCTORFIX.md)
- [stdx/runtime 执行边界](docs/STDX_RUNTIME_EXECUTION_BOUNDARY.md)
- [下游采用策略](docs/DOWNSTREAM_ADOPTION_POLICY.md)
- [发布流程](docs/RELEASING.md)
- [Shell 与旗舰版边界](docs/SHELL_AND_FLAGSHIP_BOUNDARY_2026-06-07.md)

## 项目边界

HapCLI 不是仓颉或 HarmonyOS 官方工具，不替代包管理器，不提供包注册中心，不提供覆盖所有 SDK 的通用管理器，也不会静默重写项目清单；第三方镜像和设备工具链是否可用仍取决于外部环境。

完整 CLI 与源码以 Apache License 2.0 开源。商业支持可以覆盖集成、迁移、培训、部署协助和服务等级承诺，但不会通过隐藏的专有版本解锁 CLI 功能。

## 贡献与安全

提交修改前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。安全问题请按 [SECURITY.md](SECURITY.md) 中的私密流程报告，不要直接创建公开漏洞 issue。

## 许可证

HapCLI 使用 [Apache License 2.0](LICENSE) 发布。项目归属说明见 [NOTICE](NOTICE)。
