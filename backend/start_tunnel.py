#!/usr/bin/env python3
"""
EcoScrap Cloudflare Tunnel Manager.

Starts cloudflared pointing to http://127.0.0.1:8000, extracts the public
HTTPS URL, saves it to tunnel_url.txt, and displays Flutter launch instructions.
"""

import os
import re
import sys
import shutil
import subprocess
import threading

import argparse
import json
import os
import re
import sys
import shutil
import subprocess
import threading

PORT = int(os.getenv("ECOSCRAP_PORT", "8000"))
TARGET_URL = f"http://127.0.0.1:{PORT}"
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TUNNEL_FILE = os.path.join(ROOT_DIR, "tunnel_url.txt")
CONFIG_JSON = os.path.join(ROOT_DIR, "frontend", "assets", "config.json")


def find_cloudflared() -> str:
    # 1. System PATH
    cmd = shutil.which("cloudflared")
    if cmd:
        return cmd

    # 2. Windows known locations
    paths = [
        r"C:\Program Files (x86)\cloudflared\cloudflared.exe",
        r"C:\Program Files\cloudflared\cloudflared.exe",
        os.path.expandvars(r"%LOCALAPPDATA%\Programs\cloudflared\cloudflared.exe"),
        os.path.expandvars(r"%APPDATA%\npm\cloudflared.cmd"),
    ]
    for p in paths:
        if os.path.exists(p):
            return p

    print("[!] cloudflared not found in PATH or standard paths.")
    print("    Please install cloudflared from: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/")
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="EcoScrap Cloudflare Tunnel Manager")
    parser.add_argument("--named", type=str, default="attenda", help="Name of static Cloudflare tunnel (default: attenda)")
    parser.add_argument("--domain", type=str, default="ecoscrap.srishakthicgpa.in", help="Static domain hostname")
    parser.add_argument("--quick", action="store_true", help="Force ephemeral Quick Tunnel (*.trycloudflare.com)")
    args = parser.parse_args()

    binary = find_cloudflared()
    print("=" * 60)
    print("       EcoScrap Cloudflare Tunnel Launcher (Python)     ")
    print("=" * 60)
    print(f"[+] Using cloudflared: {binary}")
    print(f"[+] Forwarding target: {TARGET_URL}")

    # Static named tunnel mode (default when not forced to quick)
    if not args.quick and args.named:
        static_url = f"https://{args.domain}"
        api_url = f"{static_url}/api"
        with open(TUNNEL_FILE, "w", encoding="utf-8") as f:
            f.write(static_url)

        if os.path.exists(os.path.dirname(CONFIG_JSON)):
            with open(CONFIG_JSON, "w", encoding="utf-8") as f:
                json.dump({
                    "api_url": api_url,
                    "fallback_url": f"http://127.0.0.1:{PORT}/api",
                    "tunnel_domain": args.domain,
                    "environment": "production"
                }, f, indent=2)

        print("\n" + "=" * 60)
        print("  CLOUDFLARE STATIC DOMAIN ACTIVE!  ")
        print("=" * 60)
        print(f"  Static Domain:  {static_url}")
        print(f"  API Endpoint:   {api_url}")
        print(f"  Tunnel Name:    {args.named}")
        print(f"  Config Bundled: {CONFIG_JSON}")
        print("-" * 60)
        print("  Reachable across ANY network (mobile 4G/5G, remote Wi-Fi)")
        print("=" * 60 + "\n")

        try:
            subprocess.run([binary, "tunnel", "run", args.named])
        except KeyboardInterrupt:
            print("\n[*] Stopping Cloudflare Tunnel...")
        return

    print("[+] Starting Cloudflare Quick Tunnel...\n")

    if os.path.exists(TUNNEL_FILE):
        try:
            os.remove(TUNNEL_FILE)
        except OSError:
            pass

    proc = subprocess.Popen(
        [binary, "tunnel", "--url", TARGET_URL],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )

    url_regex = re.compile(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com")
    found_tunnel = False

    def reader(pipe, name):
        nonlocal found_tunnel
        for line in iter(pipe.readline, ""):
            print(f"[{name}] {line.strip()}")
            match = url_regex.search(line)
            if match and not found_tunnel:
                found_tunnel = True
                url = match.group(0)
                api_url = f"{url}/api"
                with open(TUNNEL_FILE, "w", encoding="utf-8") as f:
                    f.write(url)
                if os.path.exists(os.path.dirname(CONFIG_JSON)):
                    with open(CONFIG_JSON, "w", encoding="utf-8") as f:
                        json.dump({
                            "api_url": api_url,
                            "fallback_url": f"http://127.0.0.1:{PORT}/api",
                            "tunnel_domain": url.replace("https://", ""),
                            "environment": "development"
                        }, f, indent=2)
                print("\n" + "=" * 60)
                print("  CLOUDFLARE PUBLIC TUNNEL ACTIVE!  ")
                print("=" * 60)
                print(f"  Public Tunnel:  {url}")
                print(f"  API Endpoint:   {api_url}")
                print(f"  Saved to:       {TUNNEL_FILE}")
                print(f"  Config Bundled: {CONFIG_JSON}")
                print("-" * 60)
                print("  Flutter Launch Commands:")
                print(f"    flutter run --dart-define=API_URL={api_url}")
                print("  Or click the Server Settings (Cloud/Network) icon inside the app.")
                print("=" * 60 + "\n")

    t1 = threading.Thread(target=reader, args=(proc.stdout, "OUT"), daemon=True)
    t2 = threading.Thread(target=reader, args=(proc.stderr, "ERR"), daemon=True)
    t1.start()
    t2.start()

    try:
        proc.wait()
    except KeyboardInterrupt:
        print("\n[*] Stopping Cloudflare Tunnel...")
        proc.terminate()
        proc.wait()


if __name__ == "__main__":
    main()
