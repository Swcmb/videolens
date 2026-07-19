# 本地 Whisper 模型配置

## 背景

VideoLens 使用 `faster-whisper` 做音频转录。商汤 `sensenova-6.7-flash-lite` 不支持音频转录 API，因此 SDK 自动回退到本地 whisper（见 `src/videolens/processors/transcribe_audio.py` 的 `_transcribe_local` 函数）。

## 模型下载

### 国内网络限制

- HuggingFace 被墙 → 使用镜像站 `hf-mirror.com`
- Systran 仓库：`https://huggingface.co/Systran/faster-whisper-tiny` → 镜像：`https://hf-mirror.com/Systran/faster-whisper-tiny`

### 手动下载

```bash
# 设置 HF 镜像
export HF_ENDPOINT="https://hf-mirror.com"

# 使用 huggingface-cli 下载到指定目录
huggingface-cli download Systran/faster-whisper-tiny \
  --local-dir /home/admin/.cache/whisper/tiny

# 或直接用 git clone
git clone https://hf-mirror.com/Systran/faster-whisper-tiny \
  /home/admin/.cache/whisper/tiny
```

## 环境变量

```bash
# 指向模型文件直接父目录（不是 whisper 根目录）
export VIDEOLENS_WHISPER_DIR="/home/admin/.cache/whisper/tiny"
```

## 常见陷阱

### 1. 必须使用绝对路径

`faster-whisper` 加载模型时，若传入 `"tiny"` 等模型名会尝试联网下载（在国内会失败）。必须传入**绝对路径**：

```python
# 错误：会触发联网下载
model = WhisperModel("tiny", ...)

# 正确：使用绝对路径
model = WhisperModel("/home/admin/.cache/whisper/tiny", ...)
```

### 2. 目录结构

`VIDEOLENS_WHISPER_DIR` 指向的目录应包含以下文件（faster-whisper-tiny）：

```
/home/admin/.cache/whisper/tiny/
├── config.json
├── model.bin
├── preprocessor_config.json
├── tokenizer.json
└── vocabulary.json
```

### 3. 模型尺寸选择

| 模型 | 大小 | 速度 | 准确度 | 适用场景 |
|------|------|------|--------|---------|
| tiny | ~75MB | 最快 | 一般 | 短视频、快速转录 |
| base | ~145MB | 快 | 较好 | 通用场景 |
| small | ~480MB | 中 | 好 | 长视频、高准确度需求 |
| medium | ~1.5GB | 慢 | 很好 | 专业转录 |
| large | ~3GB | 最慢 | 最好 | 最高准确度需求 |

VideoLens 默认使用 `tiny`（沙箱环境预下载）。

## 验证

```bash
# 验证目录存在且非空
[ -d "$VIDEOLENS_WHISPER_DIR" ] && [ -n "$(ls -A "$VIDEOLENS_WHISPER_DIR")" ] && echo "OK" || echo "FAIL"

# 验证模型文件完整
ls "$VIDEOLENS_WHISPER_DIR/model.bin" && echo "OK" || echo "missing model.bin"
```
