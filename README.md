# VideoLens — Universal Video Intelligence

VideoLens 是一个 AI 驱动的视频智能分析工具，支持对本地视频文件、YouTube、抖音、B站等平台的视频进行深度分析。

## 功能特性

- **多平台支持:** 本地视频、YouTube、抖音、B站、TikTok
- **多维度分析:** 画面识别、OCR 文字提取、语音转录、时间线拆解
- **多种分析模式:** 通用分析、内容审核、Bug 检测、UX 分析、产品演示、教程分析、会议总结、隐私检查
- **结构化输出:** Markdown 报告 + JSON 结构化数据
- **置信度评估:** 对每个发现给出置信度评分

## 项目结构

```
videolens/
├── src/videolens/
│   ├── cli.py              # 命令行入口
│   ├── pipeline.py         # 分析流水线
│   ├── mcp_server.py       # MCP 服务器
│   ├── config.py           # 配置管理
│   ├── types.py            # 类型定义
│   ├── cache.py            # 缓存管理
│   ├── analysis/           # 分析引擎
│   │   ├── modes/          # 分析模式
│   │   │   ├── general.py         # 通用分析
│   │   │   ├── content.py         # 内容审核
│   │   │   ├── bug.py             # Bug 检测
│   │   │   ├── ux.py              # UX 分析
│   │   │   ├── product_demo.py    # 产品演示
│   │   │   ├── tutorial.py        # 教程分析
│   │   │   ├── meeting.py         # 会议总结
│   │   │   └── privacy.py         # 隐私检查
│   │   ├── analyze_timeline.py    # 时间线分析
│   │   ├── ask_question.py        # 问答
│   │   └── enhance_prompt.py      # 提示增强
│   ├── processors/          # 视频处理
│   │   ├── download.py            # 视频下载
│   │   ├── extract_frames.py      # 帧提取
│   │   ├── describe_frames.py     # 帧描述
│   │   ├── extract_audio.py       # 音频提取
│   │   ├── transcribe_audio.py    # 语音转录
│   │   ├── build_timeline.py      # 时间线构建
│   │   ├── extract_metadata.py    # 元数据提取
│   │   └── browser_capture.py     # 浏览器截图
│   ├── outputs/             # 输出格式
│   │   ├── write_markdown.py
│   │   ├── write_json.py
│   │   └── write_pdf.py
│   ├── resolvers/           # 视频源解析
│   └── web/                 # Web 界面
├── hermes-skill/            # Hermes Agent 技能
│   ├── SKILL.md
│   └── references/
└── hermes-video-tools/      # Hermes 视频工具
    ├── video_generation_tool.py
    └── xai_video_tools.py
```

## 快速开始

```bash
# 安装
pip install -e .

# 分析视频
videolens analyze /path/to/video.mp4 --mode general --output report.md

# 分析 YouTube 视频
videolens analyze https://youtube.com/watch?v=xxx --mode general

# 分析抖音视频
videolens analyze https://v.douyin.com/xxx --mode general
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `OPENAI_API_KEY` | OpenAI API 密钥（用于分析） |
| `OPENAI_BASE_URL` | 自定义 API 端点 |

## 许可证

GPL-3.0