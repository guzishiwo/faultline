# Faultline 中文说明

[English README](../README.md)

Faultline 是一个轻量级自托管错误追踪系统，基于 Phoenix、LiveView 和
SQLite 构建。它适合想复用 Sentry SDK 上报能力，但不想维护 PostgreSQL、
Redis、Kafka、ClickHouse 或对象存储的小团队。

> 当前状态：早期 V1.0。目标是做一个实用的单节点开源版本，不是完整替代
> Sentry。

## 它能做什么

- 接收 Sentry SDK 的事件上报，支持兼容的 store/envelope 接口。
- 使用 SQLite 存储原始事件、标准化事件和聚合后的 issue。
- 提供 LiveView 控制台，用于 issue 分诊、事件查看、搜索、保留策略和告警配置。
- 部署保持简单：一个容器，加一个持久化 `/data` 卷。
- 支持结构化搜索，例如 `release:1.2.3`、`environment:prod`、
  `status:unresolved`。

## 它不是什么

- 不是完整的 Sentry API 实现。
- 不是完整可观测性平台。
- 暂不支持 session replay、profiling、metrics、APM、source maps、minidumps。
- 开源 V1.0 不以多节点 SaaS 架构为目标。

## 架构

```text
Sentry SDK
  -> Faultline Phoenix 应用
  -> SQLite 数据库 /data/faultline.db
  -> LiveView issue 分诊界面
```

事件上报路径使用普通 Phoenix HTTP controller。LiveView 只用于人工操作的控制台。

## 本地启动

安装依赖并准备本地数据库：

```sh
mix setup
```

启动 Phoenix：

```sh
mix phx.server
```

打开：

```text
http://localhost:4010
```

也可以用 IEx 启动：

```sh
iex -S mix phx.server
```

## Docker 部署

构建并运行单节点容器：

```sh
docker build -t faultline .

docker run -p 4010:4010 \
  -v faultline-data:/data \
  -e PHX_HOST=errors.example.com \
  -e SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  faultline
```

`PHX_HOST` 应该填写浏览器和 SDK 能访问到的公网 HTTPS 域名。这里只填 host，不要带
`https://`。

正确：

```text
PHX_HOST=errors.example.com
```

错误：

```text
PHX_HOST=https://errors.example.com
```

生产数据默认存放在：

```text
/data/faultline.db
```

部署时一定要把 `/data` 挂到持久化存储。

## Railway 部署

这个仓库自带 Dockerfile，可以直接用 Railway 从 GitHub 仓库部署。

推荐 Railway 变量：

```env
PORT=4010
PHX_HOST=${{RAILWAY_PUBLIC_DOMAIN}}
SECRET_KEY_BASE=<mix phx.gen.secret 的输出>
LANG=en_US.UTF-8
LC_CTYPE=en_US.UTF-8
FAULTLINE_ADMIN_EMAIL=admin@example.com
FAULTLINE_ADMIN_PASSWORD=<临时强密码>
```

同时在 Railway 创建 Volume，并挂载到：

```text
/data
```

注意：

- 不要在 Dockerfile 里写 `VOLUME`。Railway 要在 UI 里配置 Volume。
- `PHX_HOST` 用于 Phoenix LiveView 的 origin check。没设置 `PHX_HOST` 时，
  Faultline 会尝试使用 Railway 提供的 `RAILWAY_PUBLIC_DOMAIN`。
- 应用启动时会自动执行数据库迁移，并初始化第一个管理员。
- 如果 Railway 部署在新加坡，而你在中国大陆访问，LiveView 后台操作可能会有明显延迟。
  这是网络 RTT 导致的，不是页面本身崩了。

## 第一个管理员

容器启动时会执行：

```text
Faultline.Release.bootstrap_admin_from_env()
```

如果数据库里还没有用户，会创建第一个管理员。

推荐生产变量：

```env
FAULTLINE_ADMIN_EMAIL=admin@example.com
FAULTLINE_ADMIN_PASSWORD=<临时强密码>
```

如果没有提供密码，Faultline 会生成一个密码并写入：

```text
/data/bootstrap_admin_password
```

## Sentry SDK 接口

Faultline 优先支持 SDK 事件上报：

```text
POST /api/:project_id/envelope/
POST /api/:project_id/store/
```

当前重点支持：

- Events 和 messages。
- Exceptions 和 stacktraces。
- Breadcrumbs。
- Tags、user、request、release、environment、server name。
- 自定义 fingerprint。
- 未识别的 envelope item 可以接收并忽略。

暂缓支持：

- Source maps。
- Minidumps。
- Performance transactions。
- Session replay。
- Profiling。
- Metrics。

## 搜索

示例：

```text
TypeError
release:1.2.3
environment:prod
project:cai-label
project:"Cai Label"
status:unresolved
level:error checkout
release:1.2.3 environment:prod TypeError
```

规则：

- 普通文本会搜索 issue search document。
- `key:value` 会走结构化过滤。
- `project:` 可以匹配项目 id、slug 或名称。
- `status:` 用来过滤 issue 状态。
- 其他 key 会匹配 issue 结构化字段或标准化后的 SDK tags。

## 开发

常用命令：

```sh
mix setup
mix phx.server
mix test
mix precommit
```

提交改动前建议跑：

```sh
mix precommit
```

## 更多文档

- [单节点部署](SINGLE_NODE_DEPLOYMENT.md)
- [SQLite 存储方案](SQLITE3.md)
- [Fly.io 部署](FLY_IO_DEPLOYMENT.md)
- [Roadmap](ROADMAP.md)
- [用户和管理员任务](USER_ADMIN_TASKS.md)
