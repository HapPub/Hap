<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-HapCLI-c96b2c?style=for-the-badge&labelColor=1f2430" alt="Cangjie HapCLI" />
  <img src="https://img.shields.io/badge/version-0.1.0-3182ce?style=for-the-badge&labelColor=1f2430" alt="Version 0.1.0" />
  <img src="https://img.shields.io/badge/mode-local--first-2f855a?style=for-the-badge&labelColor=1f2430" alt="本地优先" />
  <img src="https://img.shields.io/badge/focus-toolchain%20glue-805ad5?style=for-the-badge&labelColor=1f2430" alt="工具链兼容层" />
  <img src="https://img.shields.io/badge/license-Apache--2.0-d69e2e?style=for-the-badge&labelColor=1f2430" alt="Apache License 2.0" />
</p>
<div align="center">
<span style="font-weight:300;font-size:38px">HapCLI</span><br/>
<span style="font-weight:100;font-size:24px">本地优先的工具链兼容与修复工具</span>
<p align="center">
  <strong>先检查，再规划修复；只执行固定适配器，并保留回执。</strong><br/>
  <sub>仓颉 · cjpm · stdx · HarmonyOS · Kotlin Multiplatform · CI</sub>
</p>
</div>

[English](README.md) | **简体中文** | [Русский](README.ru.md)

## HapCLI 是什么

HapCLI 是一套开源命令行兼容层，主要解决项目在开发机、CI、云端和连接设备之间切换时出现的工具链配置漂移。目前重点支持仓颉/cjpm、HarmonyOS 应用开发和 Kotlin Multiplatform 工作流。

HapCLI 不替代 `cjpm`、Gradle、Xcode、DevEco Studio、`hdc` 或包管理器。它负责识别项目与环境事实，输出可审查的方案，调用有限且固定的工具适配器，并记录结构化结果。

## 快速开始

发布页提供 Linux AMD64、Linux ARM64 与 macOS ARM64 的验证二进制。先下载 Hapup
和由真实产物生成的 manifest，校验两者后，再安装当前主机对应的二进制：

```bash
VERSION=0.1.0
BASE="https://github.com/HapPub/Hap/releases/download/v$VERSION"
WORK="$(mktemp -d)"
cd "$WORK"
curl -fsSLO "$BASE/hapup.sh" -O "$BASE/hapup.sh.sha256"
curl -fsSLO "$BASE/manifest.v0.json" -O "$BASE/manifest.v0.json.sha256"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c hapup.sh.sha256
  sha256sum -c manifest.v0.json.sha256
else
  shasum -a 256 -c hapup.sh.sha256
  shasum -a 256 -c manifest.v0.json.sha256
fi
sh ./hapup.sh install-from-manifest \
  --manifest ./manifest.v0.json \
  --install-dir "$HOME/.local/bin" \
  --review-token reviewed
"$HOME/.local/bin/hap" version
```

源码包始终作为可移植回退。源码构建需要仓颉 SDK 与 `cjpm` 1.1.x；macOS
构建前先提供当前 SDK 路径：

```bash
export SDKROOT="$(xcrun --show-sdk-path)"
```

构建并安装到用户目录：

```bash
cjpm build
mkdir -p "$HOME/.local/bin"
cp ./target/release/bin/main "$HOME/.local/bin/hap"
chmod +x "$HOME/.local/bin/hap"
hap version
```

在项目目录执行第一组只读检查：

```bash
hap project detect --project .
hap toolchain providers
hap help
```

仓库内的 [`release/manifest.v0.json`](release/manifest.v0.json) 记录源码预览面；
每个 GitHub Release 会根据真正完成构建、测试、checksum 和 `hap version` 闸门的
原生任务重新生成发布 manifest。

## 核心能力

- 识别仓颉/cjpm、HarmonyOS、iOS 和 Compose Multiplatform 项目。
- 检查 `cjpm.toml`，诊断本地 `path` 依赖与远端 `git` 依赖的差异。
- 从可构建项目记录 stdx 目标配置，在其他项目中规划或写入带备份的修复。
- 执行固定的 `cjpm build` 和 `cjpm bundle`，提供受限的环境诊断、一次修复重试和中心仓依赖发布顺序提示。
- 通过固定的 `hvigor` 与 `hdc` 命令构建、安装、启动和验证 HarmonyOS 应用。
- 保存经过确认的 HarmonyOS 设备别名和最近一次 USB 证明的无线端点，不扫描局域网。
- 运行 Compose Multiplatform 桌面应用；在主机已有有效 Apple 签名资产时构建、安装和启动 iOS 应用。
- 诊断 GitHub Actions 并生成可审查的 CI 脚本，CLI 不直接修改工作流文件。
- 默认输出面向人类的简洁结果；`-v` / `--verbose` 输出结构化细节，`--write-receipt` 生成明确的 agent/CI 回执。

## 常用流程

### 仓颉与 stdx

```bash
hap inspect-cjpm ./cjpm.toml
hap record cangjie.stdx --project . --target x86_64-unknown-linux-gnu
hap doctorfix cangjie.stdx --project . --target x86_64-unknown-linux-gnu --plan
hap build --project . --target x86_64-unknown-linux-gnu
hap bundle --project . --skip-lint
hap get cangjie-sdk --target linux-amd64 --version <nightly-tag> --region auto --install-root "$HOME/.hap/runtimes"
hap get cangjie-stdx --target linux-amd64 --version <nightly-tag> --region auto --install-root "$HOME/.hap/stdx"
```

两个 `get` 命令只输出方案，不在这个入口直接下载或安装。`global` 优先使用按原字节搬运的
[CangjieSDK-Mirror](https://github.com/HapPub/CangjieSDK-Mirror)，`zh-cn`
优先使用 GitCode 原始 release；两个内置渠道都以镜像的 `manifest.v1.json` 作为
SHA-256 依据。显式传入 `--provider-url` 时保持自定义渠道，不静默回退。

### HarmonyOS 应用开发

```bash
hap project detect --project .
hap device --project .
hap dev --project .
hap dev --project . --device demo-phone
hap dev --project . --device 192.0.2.40:5555 -v
```

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
| macOS arm64 仓颉/cjpm | 源码、测试和标签发布链已验证 | 当前仓颉 1.1.3 静态运行时对象要求 macOS 13.3，即使链接目标设置得更低也不能证明更老系统可运行。 |
| Linux AMD64/ARM64 仓颉/cjpm | 已有标签发布链 | 每个发布必须由对应原生 Runner 完成构建、测试和二进制自检。 |
| Windows 与 macOS Intel | 源码可审查 | POSIX FFI 与匹配的官方 SDK 发布链验证前，不声明提供二进制。 |
| HarmonyOS 应用 | 已有真实构建、安装和启动流程 | 需要可用的 DevEco 工具链、已授权设备和有效签名配置。 |
| macOS KMP Desktop | 已验证真实 Gradle 构建与运行 | 其他桌面平台仍需单独现场验证。 |
| KMP iOS/iPadOS | 已实现构建、安装和启动 | Apple 账号、证书、描述文件、开发团队、已配对设备和 CoreDevice 状态仍由主机提供。 |
| Android 设备列表 | 支持只读 ADB 识别 | 尚未实现 APK 构建和安装编排。 |

独立 nightly 工作流会使用 GitHub 原生 Runner 和镜像 manifest，尝试构建 Linux
AMD64/ARM64、macOS ARM64/Intel 与 Windows AMD64。只有真正通过构建、测试、打包和
`hap version` 自检的产物才标记为 `built-and-smoke-verified`；在没有真实 Runner
前，HarmonyOS 只标记为 `sdk-mirrored-only`。

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

- [命令参考](docs/COMMAND_REFERENCE.md)
- [架构](docs/ARCHITECTURE.md)
- [stdx 自学习与 doctorfix](docs/STDX_SELF_LEARNING_AND_DOCTORFIX.md)
- [stdx/runtime 执行边界](docs/STDX_RUNTIME_EXECUTION_BOUNDARY.md)
- [下游采用策略](docs/DOWNSTREAM_ADOPTION_POLICY.md)
- [发布流程](docs/RELEASING.md)
- [Shell 与旗舰版边界](docs/SHELL_AND_FLAGSHIP_BOUNDARY_2026-06-07.md)

## 项目边界

HapCLI 不是仓颉或 HarmonyOS 官方工具，不替代包管理器，不提供包注册中心，不承担 SDK 版本管理，也不会静默重写项目清单；第三方镜像和设备工具链是否可用仍取决于外部环境。

完整 CLI 与源码以 Apache License 2.0 开源。商业支持可以覆盖集成、迁移、培训、部署协助和服务等级承诺，但不会通过隐藏的专有版本解锁 CLI 功能。

## 贡献与安全

提交修改前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。安全问题请按 [SECURITY.md](SECURITY.md) 中的私密流程报告，不要直接创建公开漏洞 issue。

## 许可证

HapCLI 使用 [Apache License 2.0](LICENSE) 发布。项目归属说明见 [NOTICE](NOTICE)。
