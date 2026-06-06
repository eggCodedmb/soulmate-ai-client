# SoulMate AI - API 接口文档

> 框架: Spring Boot | 认证: JWT Bearer Token | 统一响应: `{ code, message, data }`

---

## 1. 认证模块 `/api/auth` — 无需登录

| 方法 | 路径 | 入参 | 返回值 | 文件 |
|------|------|------|--------|------|
| POST | `/api/auth/send-code` | `{ email }` | `null` | `soulmate-web/.../controller/AuthController.java` |
| POST | `/api/auth/login` | `{ email, verifyCode }` | `LoginResponse { token, userId, nickname, avatarUrl, isNewUser }` | 同上 |
| POST | `/api/auth/guest` | 无 | `LoginResponse` | 同上 |

---

## 2. 用户模块 `/api/user` — 需 JWT

| 方法 | 路径 | 入参 | 返回值 | 文件 |
|------|------|------|--------|------|
| GET | `/api/user/info` | — | `User { id, email, nickname, avatarUrl, gender, birthday, ... }` | `soulmate-web/.../controller/UserController.java` |
| GET | `/api/user/profile` | — | `UserProfile { personalityType, interests, chatStylePref, ... }` | 同上 |
| PUT | `/api/user/profile` | `UserProfile` body | `null` | 同上 |
| GET | `/api/user/settings` | — | `UserSettings { darkMode, fontSize, language, modelBaseUrl, modelName, ... }` | 同上 |
| PUT | `/api/user/settings` | `UserSettings` body | `null` | 同上 |

---

## 3. AI伴侣模块 `/api/companion` — 需 JWT

| 方法 | 路径 | 入参 | 返回值 | 文件 |
|------|------|------|--------|------|
| POST | `/api/companion` | `{ name, gender, relationshipType, personalityKeys?, speakingStyle?, description? }` | `Companion` | `soulmate-web/.../controller/CompanionController.java` |
| GET | `/api/companion/list` | — | `List<Companion>` | 同上 |
| GET | `/api/companion/{id}` | path: `id` | `Companion` | 同上 |
| PUT | `/api/companion/{id}` | path: `id`, body: `Companion` | `null` | 同上 |
| DELETE | `/api/companion/{id}` | path: `id` | `null` | 同上 |

---

## 4. 对话与聊天模块 `/api` — 需 JWT

| 方法 | 路径 | 入参 | 返回值 | 文件 |
|------|------|------|--------|------|
| POST | `/api/conversation` | query: `companionId` | `Conversation` | `soulmate-web/.../controller/ConversationController.java` |
| GET | `/api/conversation/list` | — | `List<Conversation>` | 同上 |
| GET | `/api/conversation/{id}/messages` | path: `id`, query: `page=1, size=20` | `List<Message>` | 同上 |
| POST | `/api/chat/stream` | `{ conversationId, companionId, content, contentType?, sceneMode? }` | **SSE 流** `ChatResponse { messageId, content, done, emotionTag, ... }` | 同上 |
| POST | `/api/chat/send` | 同上 | `Message { id, content, emotionTag, tokensUsed, ... }` | 同上 |

---

## 5. 记忆模块 `/api/memory` — 需 JWT

| 方法 | 路径 | 入参 | 返回值 | 文件 |
|------|------|------|--------|------|
| GET | `/api/memory/list` | query: `companionId?, category?` | `List<Memory>` | `soulmate-web/.../controller/MemoryController.java` |
| PUT | `/api/memory/{id}` | path: `id`, body: `Memory` | `null` | 同上 |
| DELETE | `/api/memory/{id}` | path: `id` | `null` | 同上 |

---

## 6. 订阅模块 `/api/subscription` — 需 JWT

| 方法 | 路径 | 入参 | 返回值 | 文件 |
|------|------|------|--------|------|
| GET | `/api/subscription/plans` | — | `List<SubscriptionPlan>` | `soulmate-web/.../controller/SubscriptionController.java` |
| GET | `/api/subscription/current` | — | `UserSubscription` | 同上 |

---

## 7. WebSocket

| 协议 | 路径 | 用途 | 文件 |
|------|------|------|------|
| STOMP/SockJS | `/ws` | 实时消息推送、AI输入状态 | `soulmate-web/.../config/WebSocketConfig.java` |

---

## 总计: 21 REST + 1 WebSocket = 22 个接口
