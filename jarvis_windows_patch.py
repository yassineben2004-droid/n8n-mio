"""
JARVIS Windows Patch — esegui questo script dentro la cartella jarvis.
Sostituisce automaticamente i file macOS-only con versioni Windows-compatibili.

Uso:
    cd C:\\percorso\\alla\\cartella\\jarvis
    python jarvis_windows_patch.py
"""

import sys
from pathlib import Path

ROOT = Path(__file__).parent

files = {}

files["actions.py"] = '''"""
JARVIS Action Executor - Windows-compatible system actions.
"""

import asyncio
import logging
import os
import re
import subprocess
import time
import webbrowser
from pathlib import Path
from urllib.parse import quote

log = logging.getLogger("jarvis.actions")

DESKTOP_PATH = Path.home() / "Desktop"

_SKIP_PERMISSIONS = os.getenv("JARVIS_SKIP_PERMISSIONS", "true").lower() not in ("0", "false", "no")


def applescript_escape(s: str) -> str:
    return s.replace("\\\\", "\\\\\\\\").replace(\'"\', \'\\\\"\').replace("\\r", "").replace("\\n", " ")


async def open_terminal(command: str = "") -> dict:
    try:
        if command:
            subprocess.Popen(["cmd.exe", "/K", command], creationflags=subprocess.CREATE_NEW_CONSOLE)
        else:
            subprocess.Popen(["cmd.exe"], creationflags=subprocess.CREATE_NEW_CONSOLE)
        return {"success": True, "confirmation": "Terminal is open, sir."}
    except Exception as e:
        log.error(f"open_terminal failed: {e}")
        return {"success": False, "confirmation": "I had trouble opening Terminal, sir."}


async def open_browser(url: str, browser: str = "chrome") -> dict:
    try:
        webbrowser.open(url)
        return {"success": True, "confirmation": "Pulled that up in your browser, sir."}
    except Exception as e:
        log.error(f"open_browser failed: {e}")
        return {"success": False, "confirmation": "The browser ran into a problem, sir."}


async def open_chrome(url: str) -> dict:
    return await open_browser(url, "chrome")


async def open_claude_in_project(project_dir: str, prompt: str) -> dict:
    claude_md = Path(project_dir) / "CLAUDE.md"
    claude_md.write_text(f"# Task\\n\\n{prompt}\\n\\nBuild this completely. If web app, make index.html work standalone.\\n")
    skip_flag = " --dangerously-skip-permissions" if _SKIP_PERMISSIONS else ""
    cmd = f\'cd /d "{project_dir}" && claude{skip_flag}\'
    try:
        subprocess.Popen(["cmd.exe", "/K", cmd], creationflags=subprocess.CREATE_NEW_CONSOLE)
        return {"success": True, "confirmation": "Claude Code is running in Terminal, sir. You can watch the progress."}
    except Exception as e:
        log.error(f"open_claude_in_project failed: {e}")
        return {"success": False, "confirmation": "Had trouble spawning Claude Code, sir."}


async def prompt_existing_terminal(project_name: str, prompt: str) -> dict:
    return {"success": False, "confirmation": f"Sending prompts to existing terminals is not supported on Windows, sir. Please type directly into the Claude Code session for {project_name}."}


async def get_chrome_tab_info() -> dict:
    return {}


async def monitor_build(project_dir: str, ws=None, synthesize_fn=None) -> None:
    import base64
    output_file = Path(project_dir) / ".jarvis_output.txt"
    start = time.time()
    timeout = 600
    while time.time() - start < timeout:
        await asyncio.sleep(5)
        if output_file.exists():
            content = output_file.read_text()
            if "--- JARVIS TASK COMPLETE ---" in content:
                log.info(f"Build complete in {project_dir}")
                if ws and synthesize_fn:
                    try:
                        msg = "The build is complete, sir."
                        audio_bytes = await synthesize_fn(msg)
                        if audio_bytes:
                            encoded = base64.b64encode(audio_bytes).decode()
                            await ws.send_json({"type": "status", "state": "speaking"})
                            await ws.send_json({"type": "audio", "data": encoded, "text": msg})
                            await ws.send_json({"type": "status", "state": "idle"})
                    except Exception as e:
                        log.warning(f"Build notification failed: {e}")
                return
    log.warning(f"Build timed out in {project_dir}")


async def execute_action(intent: dict, projects: list = None) -> dict:
    action = intent.get("action", "chat")
    target = intent.get("target", "")
    if action == "open_terminal":
        claude_cmd = "claude --dangerously-skip-permissions" if _SKIP_PERMISSIONS else "claude"
        result = await open_terminal(claude_cmd)
        result["project_dir"] = None
        return result
    elif action == "browse":
        url = target if target.startswith("http") else f"https://www.google.com/search?q={quote(target)}"
        result = await open_browser(url)
        result["project_dir"] = None
        return result
    elif action == "build":
        project_name = _generate_project_name(target)
        project_dir = str(DESKTOP_PATH / project_name)
        os.makedirs(project_dir, exist_ok=True)
        result = await open_claude_in_project(project_dir, target)
        result["project_dir"] = project_dir
        return result
    else:
        return {"success": False, "confirmation": "", "project_dir": None}


def _generate_project_name(prompt: str) -> str:
    quoted = re.search(r\'"([^"]+)"\', prompt)
    if quoted:
        name = re.sub(r"[^a-zA-Z0-9\\s-]", "", quoted.group(1).strip()).strip()
        if name:
            return re.sub(r"[\\s]+", "-", name.lower())
    called = re.search(r\'(?:called|named)\\s+(\\S+(?:[-_]\\S+)*)\'\, prompt, re.IGNORECASE)
    if called:
        name = re.sub(r"[^a-zA-Z0-9-]", "", called.group(1))
        if len(name) > 3:
            return name.lower()
    words = re.sub(r"[^a-zA-Z0-9\\s]", "", prompt.lower()).split()
    skip = {"a","the","an","me","build","create","make","for","with","and","to","of","i","want","need","new","project","directory","called","on","desktop","that","application","app","full","stack","simple","web","page","site","named"}
    meaningful = [w for w in words if w not in skip and len(w) > 2][:4]
    return "-".join(meaningful) if meaningful else "jarvis-project"
'''

files["calendar_access.py"] = '''"""
JARVIS Calendar Access - NOT AVAILABLE on Windows.
"""
import logging
log = logging.getLogger("jarvis.calendar")

async def refresh_cache(): pass
async def get_todays_events() -> list[dict]: return []
async def get_upcoming_events(hours: int = 4) -> list[dict]: return []
async def get_next_event() -> dict | None: return None
async def get_calendar_names() -> list[str]: return []
def format_events_for_context(events: list[dict]) -> str: return "Calendar integration is not available on Windows, sir."
def format_schedule_summary(events: list[dict]) -> str: return "Calendar access requires macOS, sir. I\'m afraid I can\'t check your schedule."
'''

files["mail_access.py"] = '''"""
JARVIS Mail Access - NOT AVAILABLE on Windows.
"""
import logging
log = logging.getLogger("jarvis.mail")

async def get_accounts() -> list[str]: return []
async def get_unread_count() -> dict: return {"total": 0, "accounts": {}}
async def get_recent_messages(count: int = 10) -> list[dict]: return []
async def get_unread_messages(count: int = 10) -> list[dict]: return []
async def get_messages_from_account(account_name: str, count: int = 10) -> list[dict]: return []
async def search_mail(query: str, count: int = 10) -> list[dict]: return []
async def read_message(subject_match: str) -> dict | None: return None
def format_unread_summary(unread: dict) -> str: return "Mail integration is not available on Windows, sir."
def format_messages_for_context(messages: list[dict], label: str = "Recent emails") -> str: return "Mail integration requires macOS, sir."
def format_messages_for_voice(messages: list[dict]) -> str: return "I\'m afraid mail access requires macOS, sir."
'''

files["notes_access.py"] = '''"""
JARVIS Notes Access - NOT AVAILABLE on Windows.
Use the built-in memory system for notes on Windows.
"""
import logging
log = logging.getLogger("jarvis.notes")

async def get_recent_notes(count: int = 10) -> list[dict]: return []
async def read_note(title_match: str) -> dict | None: return None
async def search_notes_apple(query: str, count: int = 5) -> list[dict]: return []
async def create_apple_note(title: str, body: str, folder: str = "Notes") -> bool:
    log.info(f"Apple Notes not available on Windows. Note \'{title}\' not saved.")
    return False
def _body_to_html(body: str) -> str: return body
async def get_note_folders() -> list[str]: return []
'''

files["screen.py"] = '''"""
JARVIS Screen Awareness - Windows-compatible implementation.
"""
import asyncio
import base64
import json
import logging
import subprocess

log = logging.getLogger("jarvis.screen")


async def get_active_windows() -> list[dict]:
    try:
        result = await asyncio.get_event_loop().run_in_executor(
            None,
            lambda: subprocess.run(
                ["powershell", "-NoProfile", "-Command",
                 "Get-Process | Where-Object {$_.MainWindowTitle -ne \'\'\'\'\'} | Select-Object Name, MainWindowTitle | ConvertTo-Json -Compress"],
                capture_output=True, text=True, timeout=5,
            ),
        )
        if result.returncode != 0 or not result.stdout.strip():
            return []
        raw = json.loads(result.stdout.strip())
        if isinstance(raw, dict):
            raw = [raw]
        return [{"app": p.get("Name", ""), "title": p.get("MainWindowTitle", ""), "frontmost": i == 0} for i, p in enumerate(raw)]
    except Exception as e:
        log.warning(f"get_active_windows error: {e}")
        return []


async def get_running_apps() -> list[str]:
    try:
        result = await asyncio.get_event_loop().run_in_executor(
            None,
            lambda: subprocess.run(
                ["powershell", "-NoProfile", "-Command",
                 "Get-Process | Where-Object {$_.MainWindowTitle -ne \'\'\'\'\'} | Select-Object -ExpandProperty Name | Sort-Object -Unique"],
                capture_output=True, text=True, timeout=5,
            ),
        )
        if result.returncode == 0:
            return [a.strip() for a in result.stdout.strip().split("\\n") if a.strip()]
    except Exception as e:
        log.warning(f"get_running_apps error: {e}")
    return []


async def take_screenshot(display_only: bool = True) -> str | None:
    try:
        from PIL import ImageGrab
        import io
        def _capture():
            img = ImageGrab.grab()
            buf = io.BytesIO()
            img.save(buf, format="PNG")
            return buf.getvalue()
        data = await asyncio.get_event_loop().run_in_executor(None, _capture)
        return base64.b64encode(data).decode()
    except ImportError:
        log.warning("Pillow not installed. Run: pip install Pillow")
        return None
    except Exception as e:
        log.warning(f"Screenshot error: {e}")
        return None


async def describe_screen(anthropic_client) -> str:
    screenshot_b64 = await take_screenshot()
    if screenshot_b64 and anthropic_client:
        try:
            response = await anthropic_client.messages.create(
                model="claude-haiku-4-5-20251001", max_tokens=300,
                system="You are JARVIS analyzing a screenshot. Describe what you see: apps open, what user is working on. 2-4 sentences. No markdown.",
                messages=[{"role": "user", "content": [{"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": screenshot_b64}}, {"type": "text", "text": "What\'s on my screen?"}]}],
            )
            return response.content[0].text
        except Exception as e:
            log.warning(f"Vision call failed: {e}")
    windows = await get_active_windows()
    apps = await get_running_apps()
    if not windows and not apps:
        return "I wasn\'t able to see your screen, sir."
    if windows:
        active = next((w for w in windows if w["frontmost"]), None)
        result = f"You have {len(windows)} windows open."
        if active:
            result += f" Currently focused on {active[\'app\']}: {active[\'title\']}." 
        return result
    return f"Running apps: {\', \'.join(apps)}."


def format_windows_for_context(windows: list[dict]) -> str:
    if not windows:
        return ""
    lines = ["Currently open on your desktop:"]
    for w in windows:
        marker = " (active)" if w["frontmost"] else ""
        lines.append(f"  - {w[\'app\']}: {w[\'title\']}{marker}")
    return "\\n".join(lines)
'''

files["requirements.txt"] = """anthropic>=0.39.0
httpx>=0.27.0
fastapi>=0.115.0
uvicorn[standard]>=0.32.0
pydantic>=2.0.0
websockets>=13.0
playwright>=1.40.0
pyyaml>=6.0
Pillow>=10.0.0
"""


def main():
    # Controlla che siamo nella cartella giusta
    if not (ROOT / "server.py").exists():
        print("ERRORE: Esegui questo script dentro la cartella jarvis!")
        print(f"Cartella attuale: {ROOT}")
        sys.exit(1)

    print("Applicando patch Windows a JARVIS...\n")
    for filename, content in files.items():
        path = ROOT / filename
        path.write_text(content, encoding="utf-8")
        print(f"  OK  {filename}")

    print("\nPatch completata! JARVIS e' ora compatibile con Windows 10.")
    print("\nProssimo passo: installa le dipendenze con:")
    print("  pip install -r requirements.txt")


if __name__ == "__main__":
    main()
