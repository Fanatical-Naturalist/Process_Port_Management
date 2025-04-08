# Process & TCP port management script (Powershell)
# 进程与占用TCP端口管理脚本  


## 主要功能  
### 1. 显示列表：进程/PID/TCP Port;
### 2. 强制kill特定PID的进程;
### 3. 强制kill占用特定端口的进程；





*code was generated using Deepseek;  
*also used to learn git / github;


## 最新版本更新记录v5.0

1. 移除 search 功能
  - 删除 search 命令的所有代码分支。
  - 更新命令提示列表，不再显示 search [PORT] 选项。
2. 优化 exit 命令
  - 将 exit 分支中的 return 改为 exit，确保输入 exit 后直接退出脚本。
  - 操作示例：输入 exit 立即终止程序，无需二次确认。
3. 保持其他功能稳定
  - kill、clean、filter、refresh 功能逻辑不变。
  - 列表仅在手动刷新时更新。
