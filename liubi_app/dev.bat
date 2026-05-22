@echo off
chcp 65001 >nul 2>&1
echo ========================================
echo   留笔 App - 开发热重载模式
echo ========================================
echo.
echo 使用说明:
echo   r = 热重载 (Hot Reload) - 保留状态，快速更新UI
echo   R = 热重启 (Hot Restart) - 重启应用，重置状态
echo   q = 退出应用
echo.
echo 提示: 修改代码后按 r 即可看到变化，无需重新编译！
echo ========================================
echo.

cd /d "%~dp0"
flutter run
