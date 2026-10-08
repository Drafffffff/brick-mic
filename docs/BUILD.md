# 完整编译教程

两个端可独立构建，无需 AI 翻译项目或 NextUI 源码。掌机包只支持安装在运行 NextUI 的 TrimUI Brick。

## 获取代码

```sh
git clone https://github.com/Drafffffff/brick-mic.git
cd brick-mic
```

## 编译 Mac 接收端

需要 macOS 13+ 和 Xcode Command Line Tools：

```sh
xcode-select --install
./scripts/build-mac.sh
```

产物：`build/brick-mic/Brick Mic.app`。编译为当前 Mac 的架构：Apple Silicon 上为 arm64，Intel 上为 x86_64；当前 Release 仅提供已经验证的 arm64 包。

构建要求本机已配置固定代码签名身份。先在钥匙串中选择自己的既有代码签名证书，确认信任后手动执行 `python3 scripts/mac-signing.py init --identity "证书名称"`；后续始终复用它，脚本不会自动创建证书或退回 adhoc。当前维护者固定身份见 AGENTS.md。

脚本用 Swift 编译 AppKit 程序，并生成图标、Info.plist 和固定签名。不需要 Go、Docker、PocketJS、百炼 Key 或 Rust。开发预览可跳过蓝牙与云端：

```sh
"build/brick-mic/Brick Mic.app/Contents/MacOS/BrickMic" --ui-preview=result --dark
```

预览状态：`ready`、`waiting`、`recording`、`processing`、`result`、`permission`、`settings`；`--long-text` 检查长文字，`--missing-permission` 模拟权限提示。省略 `--dark` 使用浅色。

正式更新运行 `./scripts/build-mac.sh --install`，自动备份、校验固定签名、替换并打开 `/Applications/Brick Mic.app`。保留 Key 和设置。授权后仍提示未生效时，先退出并重开正式版；系统授权由用户手动完成，不改 TCC。预览也遵守单实例，先退出正式版，结束后重开安装版。

## 编译掌机包

需要 Git、Go 1.23+、Python 3、Docker、curl、unzip；Docker 必须处于运行状态。macOS 可安装 [Docker Desktop](https://www.docker.com/products/docker-desktop/) 和 Go，Linux x86_64 需要支持 `linux/arm64` 容器。

```sh
# macOS，已安装 Homebrew 时
brew install go python
./scripts/build-brick.sh
```

产物：`build/brick-mic/Brick Mic.pak`，按 README 拷到 SD 卡。

首次构建会自动下载固定版本的 PocketJS、QuickJS 和 Bun；Docker 使用固定摘要的 tg5040 工具链，并在项目 `build/` 下准备 Rust。不会安装 Rust 或 Bun 到系统目录。第一次下载和 Rust 编译可能需要较长时间；后续复用本地缓存。

固定版本记录在 [`scripts/pins.env`](../scripts/pins.env)，Rust crates 由上游 Cargo.lock 固定，Go 依赖由 go.sum 校验。`build/brick-mic/brick-build-receipt.txt` 记录输入版本、掌机二进制校验值及动态库需求。

可选 `BRICK_MIC_CACHE=/绝对路径` 复用其他目录的依赖缓存；可选 `POCKETJS_BUN=/绝对路径/bun` 使用同版本 Bun。缓存工作目录有修改时构建会停止，不会覆盖修改。

## 在 Mac 预览掌机界面

需要上面的固定依赖，以及 SDL2、SDL2_ttf 和 pkg-config；此模式不需要运行 Docker：

```sh
brew install sdl2 sdl2_ttf pkgconf
./scripts/build-ui.sh mac
python3 ui/preview.py
```

预览使用真实 PocketJS + Solid + QuickJS 布局与本地麦克风模拟，不连接掌机、不调用百炼。Enter / 空格对应 A，Backspace 对应 B，Esc 退出，P 模拟息屏与唤醒，上下键滚动正文。

## 验证

```sh
(cd brick && go test ./...)
python3 ui/verify-startup.py
python3 ui/verify-resume.py

# macOS：Key 解析 / 保存测试只操作临时目录
mkdir -p build/brick-mic
swiftc -swift-version 5 mac/Credentials.swift mac/verify-credentials.swift -o build/brick-mic/verify-credentials
build/brick-mic/verify-credentials

# 已构建 Mac 掌机预览后
python3 ui/verify.py
python3 ui/verify-recovery.py
```

UI 模型也可使用准备好的 Bun 运行：

```sh
build/pocketjs-port/bun/bun-darwin-aarch64/bun ui/verify-model.ts
```

Linux 或 Intel Mac 请使用 `scripts/prepare.sh` 下载的对应 Bun 路径。

## 打包 Release

先构建两个端，再在 macOS 执行：

```sh
./scripts/package-release.sh
```

`releases/v<VERSION>/` 包含 Mac ZIP、Brick ZIP、Linux 源码安装包、SHA256SUMS.txt 和构建说明。ZIP 保留应用文件夹名称与执行权限；Mac 包包含 arm64 接收端，Brick 包包含完整 PocketJS 字库与依赖许可证。

发布二进制前，请保留同版本源代码、固定依赖记录和第三方许可证；Release 不应包含 API Key、录音、个人配置、诊断输出或设备数据目录。

可选 Codex 功能见 [hooks 配置](../codex-hooks/README.md)。Linux 依赖和安装见 [Linux 教程](LINUX.md)。Mac 固定签名、短录音、任务输入及通知的离线边界测试位于 `mac/tests/`。
