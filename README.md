# Acta
行记  行記  Acta

这是一个用于托管鸿蒙（HarmonyOS）手机 APP 源码的仓库。

## 第一次托管时建议先准备的部分

如果你是首次上传鸿蒙项目，建议至少包含下面这些目录和文件：

```text
Acta/
├─ AppScope/
│  └─ app.json5
├─ entry/
│  ├─ src/main/
│  │  ├─ ets/
│  │  ├─ resources/
│  │  └─ module.json5
│  └─ oh-package.json5
├─ build-profile.json5
├─ hvigorfile.ts
├─ oh-package.json5
└─ README.md
```

## 最简单的做法（推荐）

1. 在 **DevEco Studio** 新建一个 `ArkTS` 手机项目（例如 Empty Ability）。
2. 先确认项目在本地可运行。
3. 将生成的源码与配置文件提交到本仓库（不要提交构建产物）。

## 上传前自检清单

- [ ] 有 `entry/src/main/ets` 业务代码
- [ ] 有 `module.json5` 与根目录配置（`build-profile.json5`、`hvigorfile.ts`、`oh-package.json5`）
- [ ] 未提交 `build/`、`.hvigor/`、`oh_modules/` 等产物目录
