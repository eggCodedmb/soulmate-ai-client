# LLM 模型切换 — 后端对接文档

> 基于实际项目：soulmate-ai-server（Spring Boot 4.0 + Spring AI 2.0.0-M6 + Java 21）
> 客户端：Flutter（已实现前端配置）

---

## 一、改动概览

仅需修改 **4 个文件** + **1 个新增文件** + **1 条 DDL**：

| 文件 | 改动 |
|------|------|
| `soulmate-domain/.../dto/ChatRequest.java` | 新增 4 个 LLM 字段 |
| `soulmate-domain/.../entity/UserSettings.java` | 新增 `llmProviderType`、`llmApiKey` 字段 |
| `soulmate-service/.../ChatService.java` | 接口方法增加 `ChatRequest` 参数 |
| `soulmate-service/.../impl/ChatServiceImpl.java` | 动态解析 ChatModel |
| `soulmate-service/.../impl/ConversationServiceImpl.java` | 透传 ChatRequest |
| **新增** `soulmate-service/.../DynamicLlmService.java` | 动态 ChatModel 构建与缓存 |

---

## 二、客户端请求协议（已实现）

`POST /api/chat/stream` 请求体新增 4 个**可选**字段：

```json
{
  "conversationId": 42,
  "companionId": 7,
  "content": "讲个笑话",
  "contentType": "text",

  "llmProviderType": "openai",
  "llmBaseUrl": "http://localhost:11434/v1",
  "llmApiKey": "",
  "llmModel": "qwen2.5:7b"
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `llmProviderType` | `String?` | `null`/`"system"` = 系统默认，`"openai"` = OpenAI 协议（含 Ollama） |
| `llmBaseUrl` | `String?` | Base URL，如 `https://api.deepseek.com/v1` 或 `http://localhost:11434/v1` |
| `llmApiKey` | `String?` | API Key，Ollama 等本地模型可不传 |
| `llmModel` | `String?` | 模型名称，如 `deepseek-chat`、`qwen2.5:7b` |

---

## 三、逐文件改动

### 3.1 ChatRequest.java — 新增字段

**文件：** `soulmate-domain/src/main/java/com/soulmate/domain/dto/ChatRequest.java`

```java
@Data
public class ChatRequest {

    @NotNull(message = "会话ID不能为空")
    private Long conversationId;

    @NotNull(message = "伴侣ID不能为空")
    private Long companionId;

    @NotBlank(message = "消息内容不能为空")
    private String content;

    private String contentType = "text";
    private String sceneMode;

    // ===== LLM 模型切换（可选，不传则使用系统默认） =====
    private String llmProviderType;  // "system" | "openai" | null
    private String llmBaseUrl;
    private String llmApiKey;
    private String llmModel;
}
```

### 3.2 UserSettings.java — 新增字段

**文件：** `soulmate-domain/src/main/java/com/soulmate/domain/entity/UserSettings.java`

在已有字段后追加：

```java
    /** LLM 提供商类型：system / openai */
    private String llmProviderType;

    /** LLM API Key（加密存储） */
    private String llmApiKey;

    // 已有的 modelBaseUrl、modelName 保留，与新字段共用
```

对应 DDL：

```sql
ALTER TABLE t_user_settings ADD COLUMN llm_provider_type VARCHAR(20) DEFAULT 'system' COMMENT 'LLM提供商类型';
ALTER TABLE t_user_settings ADD COLUMN llm_api_key VARCHAR(500) DEFAULT NULL COMMENT 'LLM API Key';
```

### 3.3 DynamicLlmService.java — 新增（核心）

**新建文件：** `soulmate-service/src/main/java/com/soulmate/service/impl/DynamicLlmService.java`

```java
package com.soulmate.service.impl;

import com.soulmate.domain.dto.ChatRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.openai.api.OpenAiApi;
import org.springframework.stereotype.Service;

import java.util.concurrent.ConcurrentHashMap;

/**
 * 动态 LLM 模型解析服务
 * 根据客户端传入的 LLM 配置，动态构建 ChatModel / ChatClient
 */
@Slf4j
@Service
public class DynamicLlmService {

    private final ChatClient.Builder defaultBuilder;
    private final ConcurrentHashMap<String, ChatModel> modelCache = new ConcurrentHashMap<>();

    public DynamicLlmService(ChatClient.Builder chatClientBuilder) {
        this.defaultBuilder = chatClientBuilder;
    }

    /**
     * 根据请求解析 ChatClient
     * - providerType 为 null 或 "system" → 返回 null（调用方使用默认 ChatClient）
     * - providerType 为 "openai" → 动态构建并缓存
     */
    public ChatClient resolveChatClient(ChatRequest request, ChatClient fallback) {
        if (request.getLlmProviderType() == null
                || "system".equals(request.getLlmProviderType())) {
            return fallback;
        }

        if ("openai".equals(request.getLlmProviderType())) {
            String baseUrl = request.getLlmBaseUrl();
            if (baseUrl == null || baseUrl.isBlank()) {
                log.warn("llmProviderType=openai 但 llmBaseUrl 为空，回退到系统默认");
                return fallback;
            }
            ChatModel model = getOrCreateModel(
                    baseUrl, request.getLlmApiKey(), request.getLlmModel());
            return ChatClient.builder(model).build();
        }

        log.warn("未知的 llmProviderType: {}，回退到系统默认", request.getLlmProviderType());
        return fallback;
    }

    private ChatModel getOrCreateModel(String baseUrl, String apiKey, String model) {
        String cacheKey = baseUrl + "::" + (model != null ? model : "default");

        return modelCache.computeIfAbsent(cacheKey, k -> {
            String effectiveKey = (apiKey != null && !apiKey.isEmpty()) ? apiKey : "ollama";
            log.info("创建动态 ChatModel: baseUrl={}, model={}", baseUrl, model);

            OpenAiApi openAiApi = OpenAiApi.builder()
                    .baseUrl(baseUrl)
                    .apiKey(effectiveKey)
                    .build();

            OpenAiChatOptions options = OpenAiChatOptions.builder()
                    .model(model != null && !model.isBlank() ? model : "gpt-4o")
                    .temperature(0.7)
                    .build();

            return new OpenAiChatModel(openAiApi, options);
        });
    }
}
```

### 3.4 ChatService.java — 接口签名调整

**文件：** `soulmate-service/src/main/java/com/soulmate/service/ChatService.java`

```java
public interface ChatService {

    /**
     * 流式聊天（SSE）
     * @param request 透传 ChatRequest，用于获取 LLM 配置
     */
    Flux<ChatResponse> streamChat(Long userId, Conversation conversation,
                                  Companion companion, String userMessage,
                                  ChatRequest request);

    /**
     * 同步聊天（非流式）
     */
    String chatSync(Long userId, Conversation conversation,
                    Companion companion, String userMessage,
                    ChatRequest request);
}
```

### 3.5 ChatServiceImpl.java — 动态模型解析

**文件：** `soulmate-service/src/main/java/com/soulmate/service/impl/ChatServiceImpl.java`

```java
@Slf4j
@Service
@RequiredArgsConstructor
public class ChatServiceImpl implements ChatService {

    private final ChatClient.Builder chatClientBuilder;
    private final PromptBuilder promptBuilder;
    private final WeatherToolService weatherToolService;
    private final TimeToolService timeToolService;
    private final DynamicLlmService dynamicLlmService;  // 新增

    private ChatClient chatClient;
    private ChatClient weatherChatClient;
    private ChatClient timeChatClient;

    // ... WEATHER_KEYWORDS, TIME_KEYWORDS 不变 ...

    @PostConstruct
    public void init() {
        chatClient = chatClientBuilder.build();
        weatherChatClient = chatClientBuilder.build().mutate()
                .defaultTools(weatherToolService).build();
        timeChatClient = chatClientBuilder.build().mutate()
                .defaultTools(timeToolService).build();
    }

    @Override
    public Flux<ChatResponse> streamChat(Long userId, Conversation conversation,
                                          Companion companion, String userMessage,
                                          ChatRequest request) {            // 新增参数
        try {
            List<Message> messages = promptBuilder.buildMessages(
                    userId, conversation, companion, userMessage);

            // 1. 先按关键词选择工具增强的 client（系统默认）
            ChatClient toolClient = resolveClient(userMessage);

            // 2. 再根据 LLM 配置决定最终 client
            ChatClient client = dynamicLlmService.resolveChatClient(request, toolClient);

            log.info("聊天请求: userId={}, llmType={}, model={}",
                    userId,
                    request.getLlmProviderType() != null ? request.getLlmProviderType() : "system",
                    request.getLlmModel() != null ? request.getLlmModel() : "default");

            return client.prompt()
                    .messages(messages)
                    .stream()
                    .chatResponse()
                    .map(response -> {
                        String content = "";
                        if (response.getResult() != null
                                && response.getResult().getOutput() != null) {
                            content = response.getResult().getOutput().getText();
                        }
                        return ChatResponse.builder()
                                .conversationId(conversation.getId())
                                .content(content)
                                .done(false)
                                .build();
                    })
                    .onErrorResume(e -> {
                        log.error("AI流式响应异常: userId={}, conversationId={}",
                                userId, conversation.getId(), e);
                        return Flux.just(ChatResponse.builder()
                                .conversationId(conversation.getId())
                                .error("AI服务暂时不可用，请稍后再试")
                                .done(true)
                                .build());
                    })
                    .concatWithValues(ChatResponse.builder()
                            .conversationId(conversation.getId())
                            .content("")
                            .done(true)
                            .build());

        } catch (Exception e) {
            log.error("AI流式聊天异常: userId={}, conversationId={}",
                    userId, conversation.getId(), e);
            return Flux.just(ChatResponse.builder()
                    .conversationId(conversation.getId())
                    .error("AI服务暂时不可用，请稍后再试")
                    .done(true)
                    .build());
        }
    }

    // chatSync 同理，增加 ChatRequest 参数
    // resolveClient 方法不变
}
```

### 3.6 ConversationServiceImpl.java — 透传 ChatRequest

**文件：** `soulmate-service/src/main/java/com/soulmate/service/impl/ConversationServiceImpl.java`

仅需修改 `sendMessage` 和 `sendMessageSync` 中调用 `chatService` 的那一行：

```java
// 第 149 行，原：
return chatService.streamChat(userId, conversation, companion, request.getContent())

// 改为：
return chatService.streamChat(userId, conversation, companion, request.getContent(), request)
```

```java
// sendMessageSync 中同理，原：
String aiReply = chatService.chatSync(userId, conversation, companion, request.getContent());

// 改为：
String aiReply = chatService.chatSync(userId, conversation, companion, request.getContent(), request);
```

---

## 四、调用链路图

```
客户端 POST /api/chat/stream
  │  { llmProviderType: "openai", llmBaseUrl: "...", llmApiKey: "...", llmModel: "..." }
  │
  ▼
ConversationController.streamChat()
  │
  ▼
ConversationServiceImpl.sendMessage(userId, ChatRequest)
  │  ① 校验会话、保存用户消息
  │  ② chatService.streamChat(userId, conv, companion, content, request)
  │
  ▼
ChatServiceImpl.streamChat(..., ChatRequest)
  │  ① promptBuilder.buildMessages() → 构建上下文
  │  ② resolveClient(userMessage) → 按关键词选工具 client（系统默认）
  │  ③ dynamicLlmService.resolveChatClient(request, toolClient)
  │     ├─ llmProviderType=null/system → 返回 toolClient（系统默认）
  │     └─ llmProviderType=openai → 动态构建 OpenAiChatModel → 返回新 ChatClient
  │  ④ client.prompt().messages().stream() → SSE 流式输出
  │
  ▼
ConversationServiceImpl.doOnComplete()
  │  ① 保存 AI 回复到 DB
  │  ② 保存到 Redis 上下文
  │  ③ 异步提取记忆
```

---

## 五、注意事项

| 项目 | 说明 |
|---|---|
| **工具调用** | 自定义模型的工具调用能力取决于该模型本身。Ollama 本地小模型可能不支持 function calling，weather/time 工具会静默失效 |
| **缓存** | `DynamicLlmService` 按 `baseUrl::model` 缓存 `ChatModel`，相同配置复用同一连接池 |
| **apiKey 安全** | 建议 `t_user_settings.llm_api_key` 字段使用 AES 加密存储，接口返回时脱敏 |
| **MemoryService** | `MemoryServiceImpl` 使用系统默认 `ChatClient.Builder`，不受用户自定义模型影响（记忆提取始终用系统模型） |
| **向后兼容** | 客户端不传 LLM 字段时，后端行为与改动前完全一致 |
