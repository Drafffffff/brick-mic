# 中文字体

`font1.ttf` 是项目现有合并字体：保留 Rounded Mplus 1c 的非中文字形，汉字使用 ChillRoundM，并保留已修正的度量。新仓库只将内部名称改为 **Brick Mic Rounded CN**，避免使用上游保留字体名称；字形、字符映射、水平和垂直度量已逐表比较，完全相同。仅用于编译静态 UI 字库，不会替换 SD 卡上的系统字体。

- Rounded Mplus 1c：© 2016 The Rounded M+ Project Authors，见 `RoundedMplus-OFL.txt`。
- ChillRoundM：© 2023 ChillType，来源 https://github.com/Warren2060/ChillRound ，见 `ChillRound-OFL.txt`。
- Zen Maru Gothic：© 2021 The Zen Maru Gothic Project Authors，ChillRoundM 的上游，见 `ZenMaruGothic-OFL.txt`。
- Noto Sans SC Regular：© 2014–2021 Adobe，作为完整中文动态字库随掌机包分发，见 `NotoSansSC-OFL.txt`。

以上字体均按随附的 SIL Open Font License 1.1 分发。掌机正文优先使用 NextUI 已选择的系统字体，并以 Noto Sans SC 补字。
