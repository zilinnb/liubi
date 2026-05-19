import paramiko
import os

HOST = "36.140.128.103"
USER = "root"

passwords = [
    "XiaoYu@20041128",
    "zzs5201314",
    "123456",
    "root",
    "admin",
    "XiaoYu20041128",
    "xiaoyu@20041128",
    "Xiaoyu@20041128",
]

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

for pwd in passwords:
    try:
        ssh.connect(HOST, username=USER, password=pwd, look_for_keys=False, allow_agent=False, timeout=15)
        print(f"SUCCESS! Password: {pwd}")
        ssh.close()
        break
    except paramiko.ssh_exception.AuthenticationException:
        print(f"Failed: {pwd}")
    except Exception as e:
        print(f"Error with {pwd}: {e}")
else:
    print("\nNone of the passwords worked!")

key_path = os.path.expanduser(r"~\.ssh\id_ed25519")
if os.path.exists(key_path):
    try:
        key = paramiko.Ed25519Key.from_private_key_file(key_path)
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(HOST, username=USER, pkey=key, look_for_keys=False, allow_agent=False, timeout=15)
        print(f"SUCCESS with id_ed25519 key!")
        ssh.close()
    except Exception as e:
        print(f"Key auth failed: {e}")
