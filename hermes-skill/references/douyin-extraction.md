# Douyin Video Extraction (Cookie-Free)

## The Problem

Douyin (抖音) videos require authentication cookies to download via yt-dlp. Headless servers cannot easily obtain these cookies. However, the video URL can be extracted from the Douyin API response accessible via browser.

## The Workaround

### Step 1: Get the video page URL

Convert the short URL to the full video page URL:
- Short link: `https://v.douyin.com/fKo8eYsiQAQ/`
- Full page: `https://www.douyin.com/video/{video_id}`
- The video ID can be obtained from the aweme API response

### Step 2: Use Playwright to capture the API response

1. Navigate to the video page using Playwright
2. Wait for the network request to `aweme/v1/web/aweme/detail/`
3. This GET request returns the full video metadata in its response body

```python
# Navigate to page
await page.goto("https://www.douyin.com/video/{video_id}")

# Wait for the API response
response = await page.wait_for_response(
    lambda r: "aweme/v1/web/aweme/detail/" in r.url and r.status == 200,
    timeout=15000
)
data = await response.json()
```

### Step 3: Extract video URLs from the response

The response JSON structure:
```json
{
  "aweme_detail": {
    "video": {
      "play_addr": {
        "url_list": ["https://v26-web.douyinvod.com/...", "https://v11-weba.douyinvod.com/...", "https://www.douyin.com/aweme/v1/play/..."]
      },
      "download_addr": {
        "url_list": ["https://v26-web.douyinvod.com/..."]
      },
      "bit_rate": [
        {"quality_type": 1, "width": 720, "height": 1280, "bit_rate": 984648},
        ...
      ]
    },
    "statistics": {
      "digg_count": 628,
      "comment_count": 12,
      "share_count": 22,
      "collect_count": 221
    },
    "author": {
      "nickname": "老段聊就业",
      "follower_count": 19457
    },
    "duration": 136000,  // ms
    "desc": "视频标题"
  }
}
```

- `download_addr.url_list[0]` — Highest quality download URL (preferred)
- `play_addr.url_list[0]` — Primary play URL (slightly lower quality)
- Cookies are NOT needed for curl download of these URLs

### Step 4: Download with curl

```bash
curl -L -o video.mp4 "<download_addr_url>" \
  -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
  -H "Referer: https://www.douyin.com/"
```

### Step 5: Run VideoLens analysis

```bash
cd /home/admin/videolens
export PATH="$HOME/.local/bin:$PATH"
export OPENAI_API_KEY="..."
export OPENAI_BASE_URL="https://token.sensenova.cn/v1"
export VIDEOLENS_MODEL_VISION="sensenova-6.7-flash-lite"
export VIDEOLENS_MODEL_SYNTHESIZE="sensenova-6.7-flash-lite"
export VIDEOLENS_WHISPER_DIR="/home/admin/.cache/whisper"

uv run videolens analyze video.mp4 \
  --prompt "分析这个视频的核心内容" \
  --mode general \
  --max-frames 8 \
  --frame-interval 15.0 \
  --output-dir /tmp/videolens_result
```

## Alternative: Hermes Browser Tool

The Hermes built-in browser (`browser_navigate` + `browser_console`) can also be used
to extract the video URL:

1. Navigate to the Douyin page
2. Use `browser_console(expression="...")` to extract the `aweme_detail` from the page's
   embedded JSON data (look for `window.__INITIAL_STATE__` or similar)
3. Or use `browser_network_requests` + `browser_network_request` to get the API response

## Output Structure

- `download_addr` — 1285 bitrate (best quality, ~22MB for 2min 19s video)
- `play_addr` — 961 bitrate (primary stream)
- Multiple `bit_rate` entries for different quality levels (quality_type codes vary)

## Limits

- Video URLs expire after some time (typically hours). Download immediately after extraction.
- Douyin may rate-limit or require captchas on rapid repeated requests.
- Some videos are region-locked; if curl fails with 403, try adding more headers.