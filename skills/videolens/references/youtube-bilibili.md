# YouTube / B站 / TikTok 视频下载

## YouTube

### 工具

使用 `yt-dlp`（已作为 VideoLens 的 Python 依赖安装）。

### 命令

```bash
# 基础下载
yt-dlp -o /tmp/video.mp4 "https://youtube.com/watch?v=xxx"

# 指定格式（最高质量 mp4）
yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" \
  -o /tmp/video.mp4 "https://youtube.com/watch?v=xxx"

# 短链接
yt-dlp -o /tmp/video.mp4 "https://youtu.be/xxx"
```

### 常见问题

- **地区限制**：部分视频有地区限制，需配合代理（`--proxy "http://..."`）
- **年龄限制**：需提供 cookies（`--cookies cookies.txt`）
- **字幕下载**：`--write-subs --write-auto-subs --sub-langs "zh,en"`

## B站（bilibili）

### 工具

使用 `yt-dlp`（B站有原生支持）。

### 命令

```bash
# 基础下载
yt-dlp -o /tmp/video.mp4 "https://www.bilibili.com/video/BVxxx"

# 高质量（需登录态）
yt-dlp -f "bestvideo+bestaudio/best" \
  --cookies cookies.txt \
  -o /tmp/video.mp4 "https://www.bilibili.com/video/BVxxx"
```

### 常见问题

- **1080P+ 限制**：B站 1080P+ 需登录，需提供 cookies
- **番剧限制**：部分番剧有地区与版权限制
- **下载地址**：`bilibili.com/video/` 后的 ID 即 BV 号

## TikTok

### 工具

使用 `yt-dlp`（TikTok 有原生支持）。

### 命令

```bash
# 基础下载
yt-dlp -o /tmp/video.mp4 "https://www.tiktok.com/@user/video/xxx"

# 移动端短链
yt-dlp -o /tmp/video.mp4 "https://vm.tiktok.com/xxx"
```

### 常见问题

- **水印**：默认下载带水印版本，可通过 `--extractor-args "tiktok:api_hostname=api22-normal-c-useast2a.tiktokv.com"` 获取无水印版本
- **地区限制**：部分国家访问受限，需配合代理

## 通用提示

- 下载前先 `yt-dlp --version` 确认版本（建议 ≥ 2024.12.0）
- 网络问题导致下载失败时，重试 2-3 次
- 大视频（> 500MB）下载时间长，建议先 `yt-dlp -F <url>` 查看可用格式，再选择合适清晰度
