import paramiko
import os

HOSTS = [
    ("36.140.128.103", 22),
    ("36.140.128.103", 2222),
    ("36.140.128.103", 10022),
    ("38.55.198.185", 22),
    ("38.55.198.185", 2222),
]
USER = "root"
PASSWORD = "XiaoYu@20041128"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

connected = False
for host, port in HOSTS:
    for key_name in ['id_ed25519', 'liubi_server']:
        key_path = os.path.expanduser(rf"~\.ssh\{key_name}")
        if not os.path.exists(key_path):
            continue
        try:
            key = paramiko.Ed25519Key.from_private_key_file(key_path)
            print(f"Trying {key_name} on {host}:{port}...")
            ssh.connect(host, port=port, username=USER, pkey=key, look_for_keys=False, allow_agent=False, timeout=10)
            print(f"Connected with {key_name} on {host}:{port}!")
            connected = True
            break
        except Exception as e:
            print(f"  Failed: {e}")
    if connected:
        break

if not connected:
    for host, port in HOSTS:
        try:
            print(f"Trying password on {host}:{port}...")
            ssh.connect(host, port=port, username=USER, password=PASSWORD, look_for_keys=False, allow_agent=False, timeout=10)
            print(f"Connected with password on {host}:{port}!")
            connected = True
            break
        except Exception as e:
            print(f"  Failed: {e}")

if not connected:
    print("All connection methods failed!")
    exit(1)

print("Connected! Running migration check...")
stdin, stdout, stderr = ssh.exec_command("cd /www/wwwroot/liubi/server && pm2 list")
out = stdout.read().decode()
print(out)

ssh.close()
print("Test complete!")
