# 钉钉群消息工具

## send_group_message
描述：向钉钉群发送文本消息  
用法：dingtalk send_group_message --webhook <webhook_url> --msg "消息内容"  
参数：
- webhook: 钉钉群自定义机器人 webhook 地址（必填）
- msg: 发送的消息内容（必填）

## send_markdown_message
描述：向钉钉群发送 Markdown 格式消息  
用法：dingtalk send_markdown_message --webhook <webhook_url> --title "标题" --md "Markdown内容"  
参数：
- webhook: 钉钉群自定义机器人 webhook 地址（必填）
- title: 消息标题（必填）
- md: Markdown 格式内容（必填）

## send_action_card
描述：发送带按钮的 ActionCard 消息  
用法：dingtalk send_action_card --webhook <webhook_url> --title "标题" --text "内容" --btns "按钮配置"  
参数：
- webhook: 钉钉群自定义机器人 webhook 地址（必填）
- title: 消息标题（必填）
- text: 消息内容（必填）
- btns: 按钮配置，格式为JSON数组（必填）

---
