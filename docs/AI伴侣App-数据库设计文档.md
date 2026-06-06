# AI伴侣App — 数据库设计文档

**文档版本：** v1.0
**编写日期：** 2026年6月5日
**文档状态：** 草稿
**数据库：** PostgreSQL 16

---

## 1. 设计原则

| 原则   | 说明                                                    |
| ---- | ----------------------------------------------------- |
| 主键   | 统一使用雪花算法 BIGINT（MyBatis-Plus `IdType.ASSIGN_ID`）      |
| 公共字段 | 每张表包含 `create_time`、`update_time`、`deleted`（逻辑删除 0/1） |
| 字符集  | UTF-8MB4                                              |
| 索引策略 | 高频查询字段建索引，不使用物理外键约束（代码层面保证引用完整性）                      |
| 数据分离 | PostgreSQL 存业务数据，Redis 缓存会话/热点，Milvus 存向量，ES 做消息检索    |

---

## 2. 用户模块

### 2.1 `t_user` — 用户表

| 字段              | 类型           | 约束               | 说明               |
| --------------- | ------------ | ---------------- | ---------------- |
| id              | BIGINT       | PK               | 雪花ID             |
| email           | VARCHAR(128) | UNIQUE, NOT NULL | 邮箱（登录凭证）         |
| password_hash   | VARCHAR(255) | NULL             | 密码哈希（验证码登录可为空）   |
| nickname        | VARCHAR(64)  | NOT NULL         | 用户昵称             |
| avatar_url      | VARCHAR(512) | NULL             | 用户头像URL          |
| gender          | SMALLINT     | DEFAULT 0        | 性别：0-未设置 1-男 2-女 |
| birthday        | DATE         | NULL             | 生日               |
| guest_flag      | SMALLINT     | DEFAULT 0        | 是否游客：0-否 1-是     |
| status          | SMALLINT     | DEFAULT 1        | 状态：0-禁用 1-正常     |
| last_login_time | TIMESTAMP    | NULL             | 最后登录时间           |
| create_time     | TIMESTAMP    | NOT NULL         | 注册时间             |
| update_time     | TIMESTAMP    | NOT NULL         | 更新时间             |
| deleted         | SMALLINT     | DEFAULT 0        | 逻辑删除             |

**索引：**

- `uk_email` — UNIQUE(email)
- `idx_create_time` — (create_time)

---

### 2.2 `t_user_profile` — 用户资料表

| 字段                 | 类型          | 约束               | 说明                                  |
| ------------------ | ----------- | ---------------- | ----------------------------------- |
| id                 | BIGINT      | PK               | 雪花ID                                |
| user_id            | BIGINT      | UNIQUE, NOT NULL | 用户ID                                |
| personality_type   | VARCHAR(32) | NULL             | 性格测试结果（如 MBTI: INFP）                |
| personality_result | JSONB       | NULL             | 性格问卷原始答案                            |
| interests          | JSONB       | NULL             | 兴趣标签 `["音乐","电影","游戏"]`             |
| chat_style_pref    | VARCHAR(32) | NULL             | 偏好聊天风格：formal/casual/literary/funny |
| topics_blacklist   | JSONB       | NULL             | 禁忌话题列表                              |
| create_time        | TIMESTAMP   | NOT NULL         |                                     |
| update_time        | TIMESTAMP   | NOT NULL         |                                     |
| deleted            | SMALLINT    | DEFAULT 0        |                                     |

---

### 2.3 `t_user_settings` — 用户设置表

| 字段             | 类型           | 约束               | 说明                        |
| -------------- | ------------ | ---------------- | ------------------------- |
| id             | BIGINT       | PK               | 雪花ID                      |
| user_id        | BIGINT       | UNIQUE, NOT NULL | 用户ID                      |
| dark_mode      | SMALLINT     | DEFAULT 0        | 暗黑模式：0-跟随系统 1-开 2-关       |
| font_size      | VARCHAR(16)  | DEFAULT 'normal' | 字体大小：small/normal/large   |
| language       | VARCHAR(16)  | DEFAULT 'zh-CN'  | 语言                        |
| message_notify | SMALLINT     | DEFAULT 1        | 消息通知：0-关 1-开              |
| proactive_care | SMALLINT     | DEFAULT 1        | 主动关心：0-关 1-开              |
| model_base_url | VARCHAR(256) | NULL             | 自定义模型地址（LM Studio/Ollama） |
| model_name     | VARCHAR(64)  | NULL             | 当前使用的模型名称                 |
| create_time    | TIMESTAMP    | NOT NULL         |                           |
| update_time    | TIMESTAMP    | NOT NULL         |                           |
| deleted        | SMALLINT     | DEFAULT 0        |                           |

---

## 3. AI伴侣模块

### 3.1 `t_companion` — AI伴侣表

| 字段                | 类型           | 约束               | 说明                                 |
| ----------------- | ------------ | ---------------- | ---------------------------------- |
| id                | BIGINT       | PK               | 雪花ID                               |
| user_id           | BIGINT       | NOT NULL         | 所属用户ID                             |
| name              | VARCHAR(64)  | NOT NULL         | 伴侣名字                               |
| gender            | SMALLINT     | NOT NULL         | 性别：1-男 2-女 3-非二元                   |
| relationship_type | VARCHAR(32)  | NOT NULL         | 关系类型：lover/friend/mentor/confidant |
| description       | TEXT         | NULL             | 背景故事/描述                            |
| speaking_style    | VARCHAR(32)  | DEFAULT 'casual' | 说话风格：formal/casual/literary/funny  |
| avatar_url        | VARCHAR(512) | NULL             | 当前头像URL                            |
| theme_color       | VARCHAR(16)  | NULL             | 主题色（由性格决定）                         |
| status            | SMALLINT     | DEFAULT 1        | 状态：0-归档 1-活跃                       |
| companion_order   | INT          | DEFAULT 0        | 排序权重（置顶等）                          |
| create_time       | TIMESTAMP    | NOT NULL         |                                    |
| update_time       | TIMESTAMP    | NOT NULL         |                                    |
| deleted           | SMALLINT     | DEFAULT 0        |                                    |

**索引：**

- `idx_user_id` — (user_id)
- `idx_user_status` — (user_id, status)

---

### 3.2 `t_companion_personality` — 伴侣性格标签表

| 字段              | 类型          | 约束        | 说明                                                  |
| --------------- | ----------- | --------- | --------------------------------------------------- |
| id              | BIGINT      | PK        | 雪花ID                                                |
| companion_id    | BIGINT      | NOT NULL  | 伴侣ID                                                |
| personality_key | VARCHAR(32) | NOT NULL  | 性格关键词：gentle/lively/calm/humorous/intellectual/cool |
| create_time     | TIMESTAMP   | NOT NULL  |                                                     |
| deleted         | SMALLINT    | DEFAULT 0 |                                                     |

**索引：** `idx_companion_id` — (companion_id)

> 一个伴侣最多选3个性格标签，不同性格影响气泡配色和回复策略。

---

### 3.3 `t_companion_voice` — 伴侣声音配置表

| 字段           | 类型           | 约束               | 说明                         |
| ------------ | ------------ | ---------------- | -------------------------- |
| id           | BIGINT       | PK               | 雪花ID                       |
| companion_id | BIGINT       | UNIQUE, NOT NULL | 伴侣ID                       |
| voice_id     | VARCHAR(64)  | NOT NULL         | 音色标识（Azure TTS voice name） |
| voice_name   | VARCHAR(64)  | NULL             | 音色显示名（磁性/甜美/少年/知性）         |
| pitch        | DECIMAL(3,1) | DEFAULT 0.0      | 音调偏移                       |
| speed        | DECIMAL(3,1) | DEFAULT 1.0      | 语速倍率                       |
| create_time  | TIMESTAMP    | NOT NULL         |                            |
| update_time  | TIMESTAMP    | NOT NULL         |                            |
| deleted      | SMALLINT     | DEFAULT 0        |                            |

---

### 3.4 `t_companion_avatar` — 伴侣形象配置表

| 字段           | 类型           | 约束               | 说明                                 |
| ------------ | ------------ | ---------------- | ---------------------------------- |
| id           | BIGINT       | PK               | 雪花ID                               |
| companion_id | BIGINT       | UNIQUE, NOT NULL | 伴侣ID                               |
| avatar_type  | VARCHAR(32)  | NOT NULL         | 类型：preset/ai_generated/uploaded    |
| image_url    | VARCHAR(512) | NOT NULL         | 形象图片URL                            |
| expression   | VARCHAR(32)  | DEFAULT 'normal' | 当前表情：normal/happy/shy/thinking/sad |
| lottie_url   | VARCHAR(512) | NULL             | Lottie动画文件URL                      |
| sd_prompt    | TEXT         | NULL             | Stable Diffusion 生成提示词（AI生成时记录）    |
| create_time  | TIMESTAMP    | NOT NULL         |                                    |
| update_time  | TIMESTAMP    | NOT NULL         |                                    |
| deleted      | SMALLINT     | DEFAULT 0        |                                    |

---

## 4. 对话消息模块

### 4.1 `t_conversation` — 对话会话表

| 字段                   | 类型           | 约束              | 说明                                                  |
| -------------------- | ------------ | --------------- | --------------------------------------------------- |
| id                   | BIGINT       | PK              | 雪花ID                                                |
| user_id              | BIGINT       | NOT NULL        | 用户ID                                                |
| companion_id         | BIGINT       | NOT NULL        | 伴侣ID                                                |
| scene_mode           | VARCHAR(32)  | DEFAULT 'daily' | 场景模式：daily/deep_night/story/roleplay/study/greeting |
| last_message_preview | VARCHAR(256) | NULL            | 最后一条消息预览                                            |
| last_message_time    | TIMESTAMP    | NULL            | 最后消息时间                                              |
| unread_count         | INT          | DEFAULT 0       | 未读消息数                                               |
| pinned               | SMALLINT     | DEFAULT 0       | 是否置顶：0-否 1-是                                        |
| context_window       | INT          | DEFAULT 50      | 上下文窗口大小（轮数）                                         |
| create_time          | TIMESTAMP    | NOT NULL        |                                                     |
| update_time          | TIMESTAMP    | NOT NULL        |                                                     |
| deleted              | SMALLINT     | DEFAULT 0       |                                                     |

**索引：**

- `idx_user_id` — (user_id)
- `idx_companion_id` — (companion_id)
- `idx_user_last_msg` — (user_id, last_message_time DESC)

---

### 4.2 `t_message` — 消息表

| 字段              | 类型           | 约束             | 说明                           |
| --------------- | ------------ | -------------- | ---------------------------- |
| id              | BIGINT       | PK             | 雪花ID                         |
| conversation_id | BIGINT       | NOT NULL       | 会话ID                         |
| sender_type     | VARCHAR(16)  | NOT NULL       | 发送方：user/companion           |
| content         | TEXT         | NOT NULL       | 消息内容                         |
| content_type    | VARCHAR(16)  | DEFAULT 'text' | 内容类型：text/voice/image/system |
| voice_url       | VARCHAR(512) | NULL           | 语音文件URL（语音消息）                |
| voice_duration  | INT          | NULL           | 语音时长（秒）                      |
| image_url       | VARCHAR(512) | NULL           | 图片URL（图片消息）                  |
| emotion_tag     | VARCHAR(32)  | NULL           | AI识别的情绪标签                    |
| emotion_score   | DECIMAL(3,2) | NULL           | 情绪得分：-1.00 ~ 1.00            |
| tokens_used     | INT          | DEFAULT 0      | 本次消耗的token数                  |
| llm_model       | VARCHAR(64)  | NULL           | 生成该消息的模型标识                   |
| read_status     | SMALLINT     | DEFAULT 0      | 已读状态：0-未读 1-已读               |
| create_time     | TIMESTAMP    | NOT NULL       | 发送时间                         |
| deleted         | SMALLINT     | DEFAULT 0      |                              |

**索引：**

- `idx_conversation_id` — (conversation_id)
- `idx_conversation_time` — (conversation_id, create_time DESC)
- `idx_sender_type` — (sender_type)

> **分表策略：** 单表超过5000万行时按月分表 `t_message_YYYYMM`，分片键 `conversation_id`。
> **ES同步：** 消息写入后异步同步到 Elasticsearch，支持全文检索。

---

## 5. 记忆模块

### 5.1 `t_memory` — 长期记忆表

| 字段                | 类型           | 约束        | 说明                                                  |
| ----------------- | ------------ | --------- | --------------------------------------------------- |
| id                | BIGINT       | PK        | 雪花ID                                                |
| user_id           | BIGINT       | NOT NULL  | 用户ID                                                |
| companion_id      | BIGINT       | NOT NULL  | 关联伴侣ID                                              |
| category          | VARCHAR(32)  | NOT NULL  | 分类：personal_info/shared_experience/preference/habit |
| title             | VARCHAR(128) | NOT NULL  | 记忆标题                                                |
| content           | TEXT         | NOT NULL  | 记忆内容                                                |
| source_message_id | BIGINT       | NULL      | 来源消息ID                                              |
| importance        | SMALLINT     | DEFAULT 5 | 重要度：1-10                                            |
| vector_id         | VARCHAR(64)  | NULL      | Milvus中的向量ID                                        |
| access_count      | INT          | DEFAULT 0 | 被检索引用次数                                             |
| last_access_time  | TIMESTAMP    | NULL      | 最后被引用时间                                             |
| user_visible      | SMALLINT     | DEFAULT 1 | 是否对用户可见：0-隐藏 1-可见                                   |
| user_edited       | SMALLINT     | DEFAULT 0 | 是否被用户编辑过                                            |
| create_time       | TIMESTAMP    | NOT NULL  |                                                     |
| update_time       | TIMESTAMP    | NOT NULL  |                                                     |
| deleted           | SMALLINT     | DEFAULT 0 |                                                     |

**索引：**

- `idx_user_id` — (user_id)
- `idx_companion_id` — (companion_id)
- `idx_user_category` — (user_id, category)
- `idx_vector_id` — (vector_id)

---

### 5.2 `t_memory_tag` — 记忆标签表

| 字段          | 类型          | 约束        | 说明                   |
| ----------- | ----------- | --------- | -------------------- |
| id          | BIGINT      | PK        | 雪花ID                 |
| memory_id   | BIGINT      | NOT NULL  | 记忆ID                 |
| tag_name    | VARCHAR(64) | NOT NULL  | 标签名（如"生日"、"旅行"、"宠物"） |
| create_time | TIMESTAMP   | NOT NULL  |                      |
| deleted     | SMALLINT    | DEFAULT 0 |                      |

**索引：**

- `idx_memory_id` — (memory_id)
- `idx_tag_name` — (tag_name)

---

## 6. 情感模块

### 6.1 `t_emotion_record` — 消息级情绪记录

| 字段               | 类型           | 约束            | 说明                                               |
| ---------------- | ------------ | ------------- | ------------------------------------------------ |
| id               | BIGINT       | PK            | 雪花ID                                             |
| user_id          | BIGINT       | NOT NULL      | 用户ID                                             |
| message_id       | BIGINT       | NOT NULL      | 关联消息ID                                           |
| emotion_label    | VARCHAR(32)  | NOT NULL      | 情绪标签：happy/sad/anxious/angry/lonely/calm/excited |
| emotion_score    | DECIMAL(3,2) | NOT NULL      | 情绪得分：-1.00 ~ 1.00                                |
| intensity        | SMALLINT     | NULL          | 情绪强度：1-5                                         |
| detection_method | VARCHAR(32)  | DEFAULT 'llm' | 检测方式：llm/bert                                    |
| create_time      | TIMESTAMP    | NOT NULL      |                                                  |

**索引：**

- `idx_user_id` — (user_id)
- `idx_message_id` — (message_id)
- `idx_user_time` — (user_id, create_time)

---

### 6.2 `t_emotion_diary` — 情绪日记表

| 字段                 | 类型           | 约束        | 说明          |
| ------------------ | ------------ | --------- | ----------- |
| id                 | BIGINT       | PK        | 雪花ID        |
| user_id            | BIGINT       | NOT NULL  | 用户ID        |
| diary_date         | DATE         | NOT NULL  | 日记日期        |
| overall_emotion    | VARCHAR(32)  | NULL      | 当日整体情绪      |
| avg_score          | DECIMAL(3,2) | NULL      | 当日情绪均分      |
| summary            | TEXT         | NULL      | AI生成的当日情绪摘要 |
| keyword            | VARCHAR(128) | NULL      | 当日关键词       |
| conversation_count | INT          | DEFAULT 0 | 当日对话数       |
| create_time        | TIMESTAMP    | NOT NULL  |             |
| update_time        | TIMESTAMP    | NOT NULL  |             |
| deleted            | SMALLINT     | DEFAULT 0 |             |

**索引：**

- `uk_user_date` — UNIQUE(user_id, diary_date)

---

## 7. 订阅支付模块

### 7.1 `t_subscription_plan` — 套餐定义表

| 字段                 | 类型            | 约束               | 说明                               |
| ------------------ | ------------- | ---------------- | -------------------------------- |
| id                 | BIGINT        | PK               | 雪花ID                             |
| plan_code          | VARCHAR(32)   | UNIQUE, NOT NULL | 套餐编码：FREE/BASIC/PREMIUM/ULTIMATE |
| plan_name          | VARCHAR(64)   | NOT NULL         | 套餐名称                             |
| price_monthly      | DECIMAL(10,2) | NOT NULL         | 月费（元）                            |
| max_companions     | INT           | NOT NULL         | 最大伴侣数（-1=无限）                     |
| max_daily_messages | INT           | NOT NULL         | 每日消息上限（-1=无限）                    |
| voice_message      | SMALLINT      | DEFAULT 0        | 语音消息：0-否 1-是                     |
| voice_call         | SMALLINT      | DEFAULT 0        | 语音通话：0-否 1-是                     |
| advanced_memory    | SMALLINT      | DEFAULT 0        | 高级记忆：0-否 1-是                     |
| custom_voice       | SMALLINT      | DEFAULT 0        | 自定义声音：0-否 1-是                    |
| priority_response  | SMALLINT      | DEFAULT 0        | 优先响应：0-否 1-是                     |
| display_order      | INT           | DEFAULT 0        | 展示排序                             |
| status             | SMALLINT      | DEFAULT 1        | 0-下架 1-上架                        |
| create_time        | TIMESTAMP     | NOT NULL         |                                  |
| update_time        | TIMESTAMP     | NOT NULL         |                                  |
| deleted            | SMALLINT      | DEFAULT 0        |                                  |

**初始化数据：**

| plan_code | plan_name | price_monthly | max_companions | max_daily_messages | voice_message | voice_call | advanced_memory | custom_voice | priority_response |
| --------- | --------- | ------------- | -------------- | ------------------ | ------------- | ---------- | --------------- | ------------ | ----------------- |
| FREE      | 免费版       | 0             | 1              | 30                 | ✗             | ✗          | ✗               | ✗            | ✗                 |
| BASIC     | 基础版       | 18            | 3              | -1                 | ✓             | ✗          | ✗               | ✗            | ✗                 |
| PREMIUM   | 高级版       | 38            | 5              | -1                 | ✓             | ✓          | ✓               | ✓            | ✗                 |
| ULTIMATE  | 尊享版       | 68            | -1             | -1                 | ✓             | ✓          | ✓               | ✓            | ✓                 |

---

### 7.2 `t_user_subscription` — 用户订阅表

| 字段          | 类型        | 约束        | 说明                   |
| ----------- | --------- | --------- | -------------------- |
| id          | BIGINT    | PK        | 雪花ID                 |
| user_id     | BIGINT    | NOT NULL  | 用户ID                 |
| plan_id     | BIGINT    | NOT NULL  | 套餐ID                 |
| start_time  | TIMESTAMP | NOT NULL  | 订阅开始时间               |
| end_time    | TIMESTAMP | NOT NULL  | 订阅到期时间               |
| auto_renew  | SMALLINT  | DEFAULT 1 | 自动续费：0-否 1-是         |
| status      | SMALLINT  | DEFAULT 1 | 状态：0-已取消 1-生效中 2-已过期 |
| create_time | TIMESTAMP | NOT NULL  |                      |
| update_time | TIMESTAMP | NOT NULL  |                      |
| deleted     | SMALLINT  | DEFAULT 0 |                      |

**索引：**

- `idx_user_id` — (user_id)
- `idx_user_status` — (user_id, status)
- `idx_end_time` — (end_time) — 定时任务查到期订阅

---

### 7.3 `t_payment_order` — 支付订单表

| 字段              | 类型            | 约束                | 说明                         |
| --------------- | ------------- | ----------------- | -------------------------- |
| id              | BIGINT        | PK                | 雪花ID                       |
| order_no        | VARCHAR(64)   | UNIQUE, NOT NULL  | 业务订单号                      |
| user_id         | BIGINT        | NOT NULL          | 用户ID                       |
| plan_id         | BIGINT        | NOT NULL          | 套餐ID                       |
| amount          | DECIMAL(10,2) | NOT NULL          | 支付金额（元）                    |
| payment_channel | VARCHAR(32)   | DEFAULT 'alipay'  | 支付渠道                       |
| payment_status  | SMALLINT      | DEFAULT 0         | 状态：0-待支付 1-已支付 2-已退款 3-已关闭 |
| trade_no        | VARCHAR(128)  | NULL              | 第三方交易号（支付宝）                |
| paid_time       | TIMESTAMP     | NULL              | 支付完成时间                     |
| period_type     | VARCHAR(16)   | DEFAULT 'monthly' | 周期类型：monthly               |
| create_time     | TIMESTAMP     | NOT NULL          |                            |
| update_time     | TIMESTAMP     | NOT NULL          |                            |
| deleted         | SMALLINT      | DEFAULT 0         |                            |

**索引：**

- `uk_order_no` — UNIQUE(order_no)
- `idx_user_id` — (user_id)
- `idx_payment_status` — (payment_status)

---

## 8. 通知日程模块

### 8.1 `t_notification` — 通知消息表

| 字段           | 类型           | 约束        | 说明                                                      |
| ------------ | ------------ | --------- | ------------------------------------------------------- |
| id           | BIGINT       | PK        | 雪花ID                                                    |
| user_id      | BIGINT       | NOT NULL  | 用户ID                                                    |
| companion_id | BIGINT       | NULL      | 关联伴侣ID                                                  |
| type         | VARCHAR(32)  | NOT NULL  | 类型：proactive_care/birthday/greeting/system/subscription |
| title        | VARCHAR(128) | NOT NULL  | 通知标题                                                    |
| content      | TEXT         | NULL      | 通知内容                                                    |
| read_status  | SMALLINT     | DEFAULT 0 | 已读：0-未读 1-已读                                            |
| create_time  | TIMESTAMP    | NOT NULL  |                                                         |
| deleted      | SMALLINT     | DEFAULT 0 |                                                         |

**索引：**

- `idx_user_id` — (user_id)
- `idx_user_read` — (user_id, read_status)

---

### 8.2 `t_schedule_reminder` — 日程提醒表

| 字段           | 类型           | 约束             | 说明                             |
| ------------ | ------------ | -------------- | ------------------------------ |
| id           | BIGINT       | PK             | 雪花ID                           |
| user_id      | BIGINT       | NOT NULL       | 用户ID                           |
| companion_id | BIGINT       | NOT NULL       | 关联伴侣ID                         |
| title        | VARCHAR(128) | NOT NULL       | 提醒标题                           |
| content      | TEXT         | NULL           | 提醒内容                           |
| remind_time  | TIMESTAMP    | NOT NULL       | 提醒时间                           |
| repeat_type  | VARCHAR(16)  | DEFAULT 'once' | 重复类型：once/daily/weekly/monthly |
| status       | SMALLINT     | DEFAULT 0      | 状态：0-待触发 1-已触发 2-已取消           |
| create_time  | TIMESTAMP    | NOT NULL       |                                |
| update_time  | TIMESTAMP    | NOT NULL       |                                |
| deleted      | SMALLINT     | DEFAULT 0      |                                |

**索引：**

- `idx_user_id` — (user_id)
- `idx_remind_time` — (remind_time, status) — 定时任务扫待触发提醒

---

## 9. 系统配置模块

### 9.1 `t_system_config` — 系统配置表

| 字段           | 类型           | 约束               | 说明           |
| ------------ | ------------ | ---------------- | ------------ |
| id           | BIGINT       | PK               | 雪花ID         |
| config_key   | VARCHAR(128) | UNIQUE, NOT NULL | 配置键          |
| config_value | TEXT         | NOT NULL         | 配置值（JSON字符串） |
| description  | VARCHAR(256) | NULL             | 配置说明         |
| create_time  | TIMESTAMP    | NOT NULL         |              |
| update_time  | TIMESTAMP    | NOT NULL         |              |

---

### 9.2 `t_model_config` — 模型配置表

| 字段             | 类型           | 约束               | 说明                                 |
| -------------- | ------------ | ---------------- | ---------------------------------- |
| id             | BIGINT       | PK               | 雪花ID                               |
| model_code     | VARCHAR(64)  | UNIQUE, NOT NULL | 模型编码                               |
| model_name     | VARCHAR(128) | NOT NULL         | 模型显示名                              |
| provider       | VARCHAR(32)  | NOT NULL         | 提供商：openai/anthropic/local/alibaba |
| base_url       | VARCHAR(256) | NOT NULL         | API基础地址                            |
| api_key        | VARCHAR(256) | NULL             | API密钥（加密存储）                        |
| max_tokens     | INT          | DEFAULT 4096     | 最大token数                           |
| temperature    | DECIMAL(2,1) | DEFAULT 0.7      | 温度参数                               |
| support_stream | SMALLINT     | DEFAULT 1        | 支持流式输出：0-否 1-是                     |
| support_vision | SMALLINT     | DEFAULT 0        | 支持图片理解：0-否 1-是                     |
| status         | SMALLINT     | DEFAULT 1        | 0-禁用 1-启用                          |
| create_time    | TIMESTAMP    | NOT NULL         |                                    |
| update_time    | TIMESTAMP    | NOT NULL         |                                    |
| deleted        | SMALLINT     | DEFAULT 0        |                                    |

**初始化数据：**

| model_code    | model_name        | provider  | base_url                                 |
| ------------- | ----------------- | --------- | ---------------------------------------- |
| gpt-4o        | GPT-4o            | openai    | https://api.openai.com/v1                |
| claude-3.5    | Claude 3.5 Sonnet | anthropic | https://api.anthropic.com/v1             |
| qwen-max      | 通义千问 Max          | alibaba   | https://dashscope.aliyuncs.com/api/v1    |
| local-default | 本地模型              | local     | http://localhost:1234/v1                 |
| mimo-v2.5-pro | mimo-v2.5-pro     | 小米        | https://token-plan-sgp.xiaomimimo.com/v1 |

---

## 10. Redis 缓存设计

| Key 模式                               | 数据结构        | 用途                              | TTL          |
| ------------------------------------ | ----------- | ------------------------------- | ------------ |
| `user:session:{token}`               | Hash        | 用户会话信息（userId, email, planCode） | 7天           |
| `user:daily_msg:{userId}:{date}`     | String(计数器) | 当日消息计数（免费用户限30条）                | 到当日 23:59:59 |
| `companion:context:{conversationId}` | List        | 最近N轮对话上下文（JSON序列化）              | 24小时         |
| `companion:typing:{conversationId}`  | String      | AI正在输入状态                        | 30秒          |
| `user:subscription:{userId}`         | Hash        | 用户订阅信息缓存（planCode, endTime）     | 1小时          |
| `config:model:current`               | Hash        | 当前全局默认模型配置                      | 10分钟         |

---

## 11. Milvus 向量库设计

| Collection        | 用途           | 向量维度                     | 字段                                                     |
| ----------------- | ------------ | ------------------------ | ------------------------------------------------------ |
| `memory_vectors`  | 长期记忆语义检索     | 1536（OpenAI）/ 1024（国产模型） | id, user_id, companion_id, memory_id, vector, category |
| `message_vectors` | 历史消息语义检索（可选） | 同上                       | id, conversation_id, message_id, vector                |

**使用场景：**

- 用户问"我之前说过什么关于旅行的？" → 向量检索 memory_vectors，命中相关记忆
- AI生成回复时 → RAG检索相关记忆注入 prompt，实现长期记忆

---

## 12. Elasticsearch 索引设计

| 索引名            | 用途       | 主要字段                                                             |
| -------------- | -------- | ---------------------------------------------------------------- |
| `idx_messages` | 聊天记录全文检索 | conversation_id, content, sender_type, content_type, create_time |

**同步方式：** 消息写入 PostgreSQL 后，通过 RocketMQ 异步同步到 ES。

---

## 13. 分表策略（预埋）

当 `t_message` 单表超过 **5000万行** 时，按月分表：

- 表名格式：`t_message_202606`
- 分片键：`conversation_id`（取模分片）
- 实现方案：ShardingSphere 或 MyBatis-Plus ShardingPlugin

---

## 14. 表总览

| #   | 表名                      | 说明     | 预估数据量        |
| --- | ----------------------- | ------ | ------------ |
| 1   | t_user                  | 用户表    | 百万级          |
| 2   | t_user_profile          | 用户资料   | 百万级          |
| 3   | t_user_settings         | 用户设置   | 百万级          |
| 4   | t_companion             | AI伴侣   | 百万级          |
| 5   | t_companion_personality | 伴侣性格标签 | 百万级          |
| 6   | t_companion_voice       | 伴侣声音配置 | 百万级          |
| 7   | t_companion_avatar      | 伴侣形象配置 | 百万级          |
| 8   | t_conversation          | 对话会话   | 千万级          |
| 9   | t_message               | 消息     | **亿级**（主力大表） |
| 10  | t_memory                | 长期记忆   | 千万级          |
| 11  | t_memory_tag            | 记忆标签   | 千万级          |
| 12  | t_emotion_record        | 情绪记录   | 亿级           |
| 13  | t_emotion_diary         | 情绪日记   | 百万级          |
| 14  | t_subscription_plan     | 套餐定义   | 4条（固定）       |
| 15  | t_user_subscription     | 用户订阅   | 百万级          |
| 16  | t_payment_order         | 支付订单   | 百万级          |
| 17  | t_notification          | 通知消息   | 千万级          |
| 18  | t_schedule_reminder     | 日程提醒   | 百万级          |
| 19  | t_system_config         | 系统配置   | 百条级          |
| 20  | t_model_config          | 模型配置   | 十条级          |
