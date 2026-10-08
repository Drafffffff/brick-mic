# Brick Mic

<img src="mac/assets/BrickMic.png" width="112" alt="Brick Mic 图标">

把 **TrimUI Brick** 变成电脑的语音输入按钮：按住 **A** 说话，松开后把完整识别文字填入当前应用。

**掌机仅支持 NextUI。Mac 预编译版支持 Apple Silicon（M 系列）与 macOS 13+；也提供 Bazzite / Linux 后台接收端。** 语音走蓝牙，电脑调用百炼识别；掌机无需 Wi-Fi。

## 下载与安装

最新版 **0.4.16**，应用版本与 Release 标签统一。

| 安装包 | 安装位置 |
| --- | --- |
| [BrickMic-macOS-arm64.zip](https://github.com/Drafffffff/brick-mic/releases/latest/download/BrickMic-macOS-arm64.zip) | 先退出旧版，解压并覆盖 Mac「应用程序」中的 `Brick Mic.app` |
| [BrickMic-TrimUI-Brick-NextUI.zip](https://github.com/Drafffffff/brick-mic/releases/latest/download/BrickMic-TrimUI-Brick-NextUI.zip) | 将 `Brick Mic.pak` 放到 SD 卡 `Tools/tg5040/` |
| [BrickMic-Linux.tar.gz](https://github.com/Drafffffff/brick-mic/releases/latest/download/BrickMic-Linux.tar.gz) | 按 [Linux 教程](docs/LINUX.md)安装 |

1. Mac 打开 `/Applications/Brick Mic.app`，允许蓝牙，在 **设置** 填入 [百炼 API Key](https://bailian.console.aliyun.com/?apiKey=1) 并保存。已有 `~/.zshrc` 的 `DASHSCOPE_API_KEY` 会自动读取。
2. 掌机打开 **工具 → Brick Mic**，按 **L1+R1 → 查找电脑 → 选择自己的电脑**。以后记住上次选择，不会自动换到另一台。旧 Mac 应用 0.2.0 不支持当前电脑身份登记，请同时升级电脑端。
3. Mac 开启 **自动输入**，在 **系统设置 → 隐私与安全性 → 辅助功能** 添加并开启 `/Applications/Brick Mic.app`。
4. 点击目标应用的文本框，按住掌机 **A** 说话，松开结束；录音时 **B** 取消，平时 **B** 删除文字，**MENU** 退出。

Mac 采用固定本地证书签名，尚未经过 Apple 公证。系统阻止打开时，按 [Apple 说明](https://support.apple.com/zh-cn/102445)在「隐私与安全性」手动允许。更新后权限尚未生效时，先正常退出并重开正式应用。

## 日常使用

- 菜单栏保留掌机＋麦克风标识：叉号未连接，勾号已连接，声波录音，三点识别；电池和百分比显示掌机电量，闪电表示充电。
- 十字键移动电脑文本光标，长按连移，肩键＋方向键选字；L3 空格，R3 回车。普通输入不自动发送消息。
- 息屏保留蓝牙，按住 **A** 直接唤醒并录音；持续断连 5 分钟后进入深度休眠。A 唤醒仅在本应用内有效。停在应用内关机，开机可恢复；MENU 退出则返回 NextUI。
- 不足 0.5 秒的误触不发给百炼。语音模型固定为 **`qwen-audio-3.1-asr-flash-message`**，接口 `/api-ws/v1/inference`，Key 与服务地域需匹配。
- 正常录音和识别历史不落盘；Key 保存到 `.zshrc`，不读取钥匙串。这是语音转文字工具，不注册系统麦克风设备。
- 可选 [Codex 任务、回复、提醒与操作审批](codex-hooks/README.md)，需手动信任 hooks，并提供官方本机任务元数据快照；只有掌机 **X** 才发送。Linux 当前支持普通语音输入和文本编辑。

[完整编译教程](docs/BUILD.md) · [工作原理](docs/ARCHITECTURE.md) · [第三方说明](THIRD_PARTY_NOTICES.md)

代码采用 [GPL-3.0](LICENSE)。PocketJS、QuickJS、Solid、Go 依赖与字体按各自许可证分发。感谢 [NextUI](https://github.com/LoveRetro/NextUI) 与 [PocketJS](https://github.com/pocket-nexus/pocketjs)。
