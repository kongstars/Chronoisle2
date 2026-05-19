# 脚本目录

根目录 `scripts/` 只放与仓库整体有关、但不属于 `server/scripts/` 的辅助脚本。

当前分层：

- `windows/`: Windows 本机环境辅助脚本

约定：

- 服务端部署、巡检、修库脚本继续放在 `server/scripts/`
- `server/scripts/` 现在进一步分为 `deploy/`、`ops/`、`repair/`、`shared/`
- 临时排查脚本和一次性输出文件不要长期留在根目录
