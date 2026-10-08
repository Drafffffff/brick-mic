# Brick Mic 开发约定

语音模型固定使用百炼 `qwen-audio-3.1-asr-flash-message` 和 `/api-ws/v1/inference`，保持地域、workspace 与 Key 匹配。

修改 Mac 应用后验证并运行 `./scripts/build-mac.sh --install` 更新 `/Applications/Brick Mic.app`。仅运行一个实例；保留 Key、设置和权限。安装后从正式 GUI 检查输入权限，不用 CLI 结果代替实测。

本机固定签名身份为 `Brick Mic Local Code Signing`，SHA1 `37B2CB9F397AE9391218EF5B327C70E819512D5F`。继续复用 `~/Library/Application Support/Brick Mic/signing-identity.json`，不创建或更换证书，不回退 adhoc，不修改 TCC 或自动批准权限。

普通输入不要求 AX 确认输入框，只保留输入权限和录音开始时的前台应用检查。Codex 模式继续验证真实任务身份及消息框，仅掌机明确按 X 才发送。桌面任务身份来自官方 `list_threads` 导出的本机 Codex 元数据快照；Hook 的 cwd 和未知 session ID 不能代替它。

发布到 `Drafffffff/brick-mic`，所有 GitHub CLI 发布命令明确带 `--repo Drafffffff/brick-mic`，不用 AI 翻译项目仓库。`VERSION`、Mac 应用和 Release 标签使用同一版本号。
