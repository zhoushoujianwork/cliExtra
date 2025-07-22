# cliExtra Namespace 协作 Workflow 配置指南

本指南介绍如何在 cliExtra 的 namespace 级别支持协作 workflow 配置，便于多角色、多技术栈团队高效协作，并为 AI 理解和自动化提供结构化基础。

---

## 1. 文件结构与存放位置

- 每个 namespace 目录下建议维护一个 `workflow.yaml` 或 `workflow.json` 文件。
- 推荐路径：
  ```
  $CLIEXTRA_NAMESPACES_DIR/<namespace>/workflow.yaml
  ```

---

## 2. 推荐内容结构（YAML 示例）

```yaml
project:
  name: cliExtra
  description: Shell+Flask 协作开发
roles:
  - name: shell-engineer
    description: Shell 脚本开发
  - name: fullstack-engineer
    description: Flask 前端/后端
collaboration:
  - from: shell-engineer
    to: fullstack-engineer
    trigger: shell 脚本接口变更
    action: 通知适配
workflow:
  - step: shell 脚本开发
    owner: shell-engineer
  - step: flask 适配
    owner: fullstack-engineer
```

---

## 3. Shell 约定与函数建议

在 `cliExtra-common.sh` 中建议增加如下函数：

```bash
# 获取 namespace 的 workflow 文件路径
get_ns_workflow_file() {
    local ns_name="$1"
    echo "$(get_namespace_dir "$ns_name")/workflow.yaml"
}

# 读取 workflow 文件内容
read_ns_workflow() {
    local ns_name="$1"
    local workflow_file
    workflow_file="$(get_ns_workflow_file "$ns_name")"
    if [[ -f "$workflow_file" ]]; then
        cat "$workflow_file"
    else
        echo "未找到 workflow 文件: $workflow_file"
        return 1
    fi
}
```

---

## 4. AI 理解与 prompt 建议

- 结构化的 roles、collaboration、workflow 字段，便于 AI 自动解析协作关系。
- 可在 prompt 中引用 workflow 文件内容，自动推理需求流转、角色分工。
- 支持自动生成通知、任务分配、协同开发建议等。

---

## 5. 示例场景

> Shell 脚本开发完成后，自动通知全栈工程师进行 Flask 适配。

AI 可根据 workflow.yaml 自动识别流转关系，生成协作消息或任务。

---

## 6. 总结

- 每个 namespace 独立维护 workflow 配置，支持灵活协作。
- 结构化数据便于自动化和 AI 理解。
- 推荐结合 cliExtra 脚本函数进行读取和集成。 