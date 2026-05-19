import paramiko
import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

HOST = "36.140.128.103"
USER = "root"
PASSWORD = "Zzs5201314."
REMOTE_BASE = "/www/wwwroot/liubi/server"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

ssh.connect(HOST, username=USER, password=PASSWORD, look_for_keys=False, allow_agent=False, timeout=15)
print("Connected!")

print("Restarting PM2 process...")
stdin, stdout, stderr = ssh.exec_command(f"cd {REMOTE_BASE} && pm2 restart liubi")
out = stdout.read().decode('utf-8', errors='replace')
err = stderr.read().decode('utf-8', errors='replace')
print("PM2 stdout:", out)
if err:
    print("PM2 stderr:", err)

print("\nChecking PM2 status...")
stdin, stdout, stderr = ssh.exec_command("pm2 list")
out = stdout.read().decode('utf-8', errors='replace')
err = stderr.read().decode('utf-8', errors='replace')
print(out)
if err:
    print("PM2 stderr:", err)

ssh.close()
print("Done!")
