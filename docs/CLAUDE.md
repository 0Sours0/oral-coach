# CLAUDE.md — 项目约束说明

## 核心架构约束（禁止违反）

1. 所有聊天 API 视为无状态接口，每次调用前必须从本地数据库构造完整 messages 数组
2. 禁止将任何用户数据、会话历史、学习记录存储到云端
3. 禁止实现登录系统、用户账号体系
4. 所有 API 调用必须封装在 services/ 目录，禁止在页面组件中直接调用 fetch

## 技术约束

5. SQLite 使用 expo-sqlite v14 的异步 API，禁止使用旧版同步 API
6. DeepSeek 模型固定为 deepseek-chat（V3），禁止使用 deepseek-reasoner（R1）
7. DeepSeek 调用必须启用 response_format: { type: "json_object" }
8. 所有 DeepSeek 响应必须经过 utils/jsonParser.ts 的安全解析，不得直接 JSON.parse
9. 音频文件必须通过 storage/audioFileManager.ts 统一管理，禁止在其他地方直接操作文件系统
10. .env 文件不得提交 Git

## 开发约束

11. 禁止使用 Expo Go 测试录音功能，必须使用 Development Build
12. 禁止在阶段 1～4 实现任何云端 API 调用
13. 每个阶段完成后必须输出阶段产出报告
