# 在官方 SnowLuma 镜像之上，只替换 SnowLuma 自身的 JS 运行时。
#
# 为什么不从零构建：
#   官方镜像里那套「Linux QQ + Xvfb + VNC/noVNC + supervisord + ptrace hook」
#   是上游精心调过的（`cap_add: SYS_PTRACE` + `seccomp=unconfined` 缺一不可），
#   自己重写一遍只会引入新的坑。SnowLuma 的运行时代码全部集中在 /app/runtime/，
#   直接覆盖它就能带上我们的改动，其余环境原样继承。
#
# 覆盖范围（与官方 runtime 的目录结构一一对应）：
#   · 根目录 *.mjs / *.js  —— 我们自己构建的产物（index.mjs + 若干内容哈希 chunk）
#   · client/              —— 我们自己构建的 WebUI 静态资源
#   原样保留：
#   · native/              —— 与 Node ABI 绑定的原生扩展（含 ffmpeg），跟随基础镜像更稳
#   · launcher.sh / package-lock.json / check-node-version.cjs —— 启动脚手架
#
# 构建参数：
#   BASE_IMAGE 允许指向别的 SnowLuma 镜像（默认取官方 latest）。
ARG BASE_IMAGE=motricseven7/snowluma:latest
FROM ${BASE_IMAGE}

# 先清掉基础镜像里的旧运行时。chunk 名带内容哈希，不清理就会留下永远不会被引用的
# 死文件（例如两个 config-*.js 并存），排查「线上到底跑的是哪份代码」时极易误判。
# 这两条路径都由下面的 COPY 完整重建，删除是安全的。
RUN rm -rf /app/runtime/client /app/runtime/*.mjs /app/runtime/*.js

# 官方镜像里 /app/runtime 属主是 1001:1001，覆盖后必须还原，
# 否则以非 root 身份运行的 SnowLuma 进程读不到自己的入口文件。
COPY --chown=1001:1001 dist/ /app/runtime/

# 让「镜像里到底跑的是哪一版」可被外部查证，排查时不用进容器翻文件。
ARG SNOWLUMA_REVISION=unknown
LABEL org.opencontainers.image.revision="${SNOWLUMA_REVISION}" \
      org.opencontainers.image.title="snowluma-fork-runtime"
