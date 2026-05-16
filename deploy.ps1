$ServerIP = "36.140.128.103"
$ServerUser = "root"
$ServerPass = "Zzs5201314."
$RemotePath = "/www/wwwroot/liubi/server"
$LocalPath = "c:\Users\XiaoYu\Desktop\liubi\server"

Import-Module Posh-SSH

function Deploy-Server {
    param(
        [string]$Action = "deploy"
    )

    $secPwd = ConvertTo-SecureString $ServerPass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($ServerUser, $secPwd)

    switch ($Action) {
        "deploy" {
            Write-Host "=== Deploying server code ===" -ForegroundColor Green
            cd $LocalPath
            tar -czf ..\server_deploy.tar.gz --exclude=node_modules --exclude=.git --exclude=uploads .
            $sftp = New-SFTPSession -ComputerName $ServerIP -Credential $cred -AcceptKey -Force
            Set-SFTPItem -SessionId $sftp.SessionId -Path "$LocalPath\..\server_deploy.tar.gz" -Destination '/tmp' -Force
            Remove-SFTPSession -SessionId $sftp.SessionId | Out-Null
            $session = New-SSHSession -ComputerName $ServerIP -Credential $cred -AcceptKey -Force
            Invoke-SSHCommand -SessionId $session.SessionId -Command "cd $RemotePath && tar -xzf /tmp/server_deploy.tar.gz && npm install --registry=https://registry.npmmirror.com && pm2 restart liubi" -TimeOut 600 | Out-Null
            Remove-SSHSession -SessionId $session.SessionId | Out-Null
            Write-Host "=== Deploy complete ===" -ForegroundColor Green
        }
        "logs" {
            $session = New-SSHSession -ComputerName $ServerIP -Credential $cred -AcceptKey -Force
            $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "pm2 logs liubi --lines 30 --nostream" -TimeOut 30
            Write-Host $result.Output
            Remove-SSHSession -SessionId $session.SessionId | Out-Null
        }
        "status" {
            $session = New-SSHSession -ComputerName $ServerIP -Credential $cred -AcceptKey -Force
            $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "pm2 status && echo '---' && systemctl status nginx --no-pager | head -5 && echo '---' && systemctl status mariadb --no-pager | head -5" -TimeOut 30
            Write-Host $result.Output
            Remove-SSHSession -SessionId $session.SessionId | Out-Null
        }
        "restart" {
            $session = New-SSHSession -ComputerName $ServerIP -Credential $cred -AcceptKey -Force
            $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "pm2 restart liubi" -TimeOut 30
            Write-Host $result.Output
            Remove-SSHSession -SessionId $session.SessionId | Out-Null
        }
        "db" {
            $session = New-SSHSession -ComputerName $ServerIP -Credential $cred -AcceptKey -Force
            $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "mysql -u root -e 'USE liubi; SHOW TABLES;' 2>&1" -TimeOut 30
            Write-Host $result.Output
            Remove-SSHSession -SessionId $session.SessionId | Out-Null
        }
        "ssh" {
            Write-Host "Use: ssh root@$ServerIP" -ForegroundColor Yellow
        }
        default {
            Write-Host "Usage: .\deploy.ps1 -Action [deploy|logs|status|restart|db|ssh]" -ForegroundColor Yellow
        }
    }
}

Deploy-Server -Action $args[0]
