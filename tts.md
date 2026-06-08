服务地址：http://127.0.0.1:17493

生成接口

POST  /generate

入参

```json
{
  "profile_id": "string",
  "text": "string",
  "language": "en",
  "seed": 0,
  "model_size": "1.7B",
  "instruct": "string",
  "engine": "qwen",
  "personality": false,
  "max_chunk_chars": 800,
  "crossfade_ms": 50,
  "normalize": true,
  "effects_chain": [
    {
      "type": "string",
      "enabled": true,
      "params": {
        "additionalProp1": {}
      }
    }
  ]
```



POST /generate/stream

入参

```json
{
  "profile_id": "string",
  "text": "string",
  "language": "en",
  "seed": 0,
  "model_size": "1.7B",
  "instruct": "string",
  "engine": "qwen",
  "personality": false,
  "max_chunk_chars": 800,
  "crossfade_ms": 50,
  "normalize": true,
  "effects_chain": [
    {
      "type": "string",
      "enabled": true,
      "params": {
        "additionalProp1": {}
      }
    }
  ]
}
```



获取声音列表

GET /profiles

入参 无

返回结果

```json
[
  {
    "id": "a7fc3292-d4e8-4a6c-9362-6d0dffdc4607",
    "name": "步非烟",
    "description": "",
    "language": "zh",
    "avatar_path": null,
    "effects_chain": null,
    "voice_type": "cloned",
    "preset_engine": null,
    "preset_voice_id": null,
    "design_prompt": null,
    "default_engine": "qwen",
    "personality": "「声音甜美的御姐」",
    "generation_count": 5,
    "sample_count": 1,
    "created_at": "2026-05-17T09:17:25.276598",
    "updated_at": "2026-05-17T09:20:15.534063"
  }
]
```
