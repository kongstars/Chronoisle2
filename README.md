# Chronoisle2

四时清单的主仓库，包含 HarmonyOS 客户端、Node.js 服务端、设计/产品/恢复文档，以及少量辅助脚本。

## 技术栈

- HarmonyOS 5.0.0 / API 10
- ArkTS + ArkUI
- Node.js / Express / MongoDB

## 目录导航

- `entry/`: HarmonyOS 主模块，主要客户端代码都在这里
- `server/`: 服务端接口、模型、部署脚本和测试资产
- `docs/`: 产品、开发、设计、恢复、运维与参考文档
- `scripts/`: 根目录辅助脚本，当前主要放本机环境类脚本
- `AppScope/`、`app/`、`hvigor/`: HarmonyOS 工程配置与构建入口

## 文档入口

- `docs/README.md`: 文档总导航
- `docs/core/development.md`: 开发文档
- `docs/core/product.md`: 产品文档
- `docs/core/todo.md`: 代办清单
- `server/README.md`: 服务端开发与部署说明

## 本地开发

### HarmonyOS 客户端

1. 安装 DevEco Studio。
2. 配置并下载 HarmonyOS 5.0.0 / API 10 对应 SDK。
3. 打开项目后优先通过 DevEco Studio 执行依赖安装和构建。

常见工具路径通常来自 DevEco Studio 安装目录：

- `node`
- `ohpm`
- `hvigor`

如果终端里找不到这些命令，优先使用 DevEco Studio 自带 Terminal，或者按本机安装位置配置环境变量。

### 服务端

在 `server/` 目录内安装依赖并启动：

```bash
cd server
npm install
npm run dev
```

## 维护约定

- 根目录尽量只保留工程入口、顶层配置和导航文档。
- 过程文档统一放在 `docs/` 下分层管理，不再散落在根目录。
- 运行时依赖、构建缓存和临时检查文件不作为长期维护内容。
