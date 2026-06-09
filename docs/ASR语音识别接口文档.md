# ASR 语音识别接口文档

## 概述

语音识别（ASR）接口基于小米 `mimo-v2.5-asr` 模型，支持将用户语音转换为文字。

## 接口列表

### 1. 语音转文字

**接口地址**：`POST /api/asr/transcribe`

**请求方式**：`multipart/form-data`

**是否需要登录**：是（需要 JWT Token）

#### 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| audio | File | 是 | 音频文件 |

#### 支持的音频格式

| 格式 | MIME Type |
|------|-----------|
| WAV | audio/wav, audio/wave, audio/x-wav |
| MP3 | audio/mpeg, audio/mp3 |
| M4A | audio/mp4, audio/m4a |
| WEBM | audio/webm |
| OGG | audio/ogg |
| FLAC | audio/flac |

#### 限制说明

- 最大文件大小：25MB
- 最大音频时长：无硬性限制（建议不超过 5 分钟）

#### 响应结果

**成功响应**：
```json
{
    "code": 0,
    "message": "success",
    "data": "今天天气怎么样"
}
```

**失败响应**：
```json
{
    "code": 500,
    "message": "音频文件不能为空",
    "data": null
}
```

#### 错误码说明

| 错误码 | 说明 |
|--------|------|
| 0 | 成功 |
| 500 | 通用错误（参数错误、服务异常等） |

#### 错误信息

| 错误信息 | 说明 |
|----------|------|
| 音频文件不能为空 | 未上传音频文件 |
| 不支持的音频格式 | 文件格式不在支持列表中 |
| 音频文件不能超过25MB | 文件大小超限 |
| 语音识别失败，未识别出文字 | ASR 未返回有效文字 |
| 语音识别服务异常 | 服务内部错误 |

---

## 调用示例

### cURL

```bash
curl -X POST "http://localhost:8080/api/asr/transcribe" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "audio=@/path/to/recording.wav"
```

### JavaScript (Fetch API)

```javascript
async function transcribeAudio(audioBlob) {
    const formData = new FormData();
    formData.append('audio', audioBlob, 'recording.wav');
    
    const response = await fetch('/api/asr/transcribe', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${token}`
        },
        body: formData
    });
    
    const result = await response.json();
    
    if (result.code === 0) {
        console.log('识别结果:', result.data);
        return result.data;
    } else {
        console.error('识别失败:', result.message);
        throw new Error(result.message);
    }
}
```

### JavaScript (录制并上传)

```javascript
// 录音功能示例
async function startRecording() {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const mediaRecorder = new MediaRecorder(stream);
    const audioChunks = [];
    
    mediaRecorder.ondataavailable = (event) => {
        audioChunks.push(event.data);
    };
    
    mediaRecorder.onstop = async () => {
        const audioBlob = new Blob(audioChunks, { type: 'audio/wav' });
        const text = await transcribeAudio(audioBlob);
        // 将识别的文字发送给 AI
        console.log('用户语音:', text);
    };
    
    mediaRecorder.start();
    
    // 5秒后停止录音
    setTimeout(() => {
        mediaRecorder.stop();
        stream.getTracks().forEach(track => track.stop());
    }, 5000);
}
```

### Java (RestTemplate)

```java
public String transcribe(MultipartFile audioFile) {
    RestTemplate restTemplate = new RestTemplate();
    
    HttpHeaders headers = new HttpHeaders();
    headers.setContentType(MediaType.MULTIPART_FORM_DATA);
    headers.setBearerAuth(token);
    
    MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
    body.add("audio", new ByteArrayResource(audioFile.getBytes()) {
        @Override
        public String getFilename() {
            return audioFile.getOriginalFilename();
        }
    });
    
    HttpEntity<MultiValueMap<String, Object>> requestEntity = new HttpEntity<>(body, headers);
    
    ResponseEntity<R> response = restTemplate.exchange(
        "http://localhost:8080/api/asr/transcribe",
        HttpMethod.POST,
        requestEntity,
        R.class
    );
    
    return (String) response.getBody().getData();
}
```

---

## 配置说明

在 `application.yml` 中配置 ASR 相关参数：

```yaml
soulmate:
  ai:
    base-url: https://token-plan-sgp.xiaomimimo.com/v1
    api-key: your-api-key
    asr:
      enabled: true                    # 是否启用语音识别
      model: mimo-v2.5-asr            # ASR 模型名称
      max-size-mb: 25                  # 最大音频文件大小（MB）
```

---

## 语音转文字 + AI 对话流程

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   用户录音   │ ──▶ │  上传音频    │ ──▶ │  ASR 识别   │ ──▶ │  AI 对话    │
│             │     │  /api/asr   │     │  mimo-asr   │     │  /api/chat  │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                              │
                                              ▼
                                       ┌─────────────┐
                                       │   返回文字   │
                                       │  "今天天气   │
                                       │   怎么样"    │
                                       └─────────────┘
```

---

## 注意事项

1. **音频质量**：清晰的语音识别准确率更高，建议在安静环境下录制
2. **语言支持**：主要支持中文和英文
3. **网络要求**：需要能够访问小米 API 服务
4. **并发限制**：请勿频繁调用，建议限制每用户每分钟调用次数
5. **隐私安全**：音频数据不会被存储，仅用于实时识别

---

## 相关接口

| 接口 | 说明 |
|------|------|
| POST /api/chat/stream | 流式对话（SSE） |
| POST /api/chat/send | 同步对话 |
| POST /api/asr/transcribe | 语音转文字 |
