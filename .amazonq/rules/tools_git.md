# Git 工具

<!--
工具规则：
1. 当完成某个完整功能，并且已经完成语法检查和功能测试后，可以在非主分支完成本次变更的 commit（提交）。不需要执行 push 操作，push 由用户自行完成。你只需完成 commit。
-->

## commit
描述：提交代码到本地仓库  
用法：git commit -m "提交说明"  
参数：
- message: 提交说明（必填）

## push
描述：推送代码到远程仓库  
用法：git push [remote] [branch]  
参数：
- remote: 远程仓库名（可选，默认 origin）
- branch: 分支名（可选，默认当前分支）

## pull
描述：拉取远程仓库代码  
用法：git pull [remote] [branch]  
参数：
- remote: 远程仓库名（可选，默认 origin）
- branch: 分支名（可选，默认当前分支）

## status
描述：查看当前仓库状态  
用法：git status  
参数：无

## log
描述：查看提交历史  
用法：git log [选项]  
参数：
- options: 其他 git log 支持的参数（可选）

---
