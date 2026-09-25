#!/usr/bin/env python3
"""
EggHeist.rbxlx yasovchi.

src/ dagi ikkita Luau faylni o'qiydi va ularni Roblox Studio'da to'g'ridan-
to'g'ri ochiladigan `.rbxlx` (XML place) fayliga joylaydi.

Ishlatish:
    python3 build_rbxlx.py
"""

import html
from pathlib import Path

ROOT = Path(__file__).parent
SERVER_LUA = ROOT / "src" / "ServerScriptService" / "EggHeistServer.server.lua"
CLIENT_LUA = ROOT / "src" / "StarterPlayer" / "StarterPlayerScripts" / "EggHeistClient.client.lua"
OUT = ROOT / "EggHeist.rbxlx"


def cdata(source: str) -> str:
    # CDATA ichida "]]>" bo'lmasligi kerak; ehtiyot uchun ajratamiz.
    safe = source.replace("]]>", "]]]]><![CDATA[>")
    return f"<![CDATA[{safe}]]>"


def script_item(class_name: str, name: str, source: str, referent: str) -> str:
    return f"""      <Item class="{class_name}" referent="{referent}">
        <Properties>
          <string name="Name">{html.escape(name)}</string>
          <ProtectedString name="Source">{cdata(source)}</ProtectedString>
        </Properties>
      </Item>"""


def main() -> None:
    server_src = SERVER_LUA.read_text(encoding="utf-8")
    client_src = CLIENT_LUA.read_text(encoding="utf-8")

    server_item = script_item("Script", "EggHeistServer", server_src, "RBX_SERVER")
    client_item = script_item("LocalScript", "EggHeistClient", client_src, "RBX_CLIENT")

    xml = f"""<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
  <Item class="Workspace" referent="RBX_WORKSPACE">
    <Properties>
      <bool name="FilteringEnabled">true</bool>
    </Properties>
  </Item>
  <Item class="ServerScriptService" referent="RBX_SSS">
    <Properties>
      <string name="Name">ServerScriptService</string>
    </Properties>
{server_item}
  </Item>
  <Item class="StarterPlayer" referent="RBX_SP">
    <Properties>
      <string name="Name">StarterPlayer</string>
    </Properties>
    <Item class="StarterPlayerScripts" referent="RBX_SPS">
      <Properties>
        <string name="Name">StarterPlayerScripts</string>
      </Properties>
{client_item}
    </Item>
  </Item>
</roblox>
"""

    OUT.write_text(xml, encoding="utf-8")
    size_kb = OUT.stat().st_size / 1024
    print(f"[OK] {OUT.name} yasaldi ({size_kb:.1f} KB)")
    print(f"     Server: {len(server_src)} belgi")
    print(f"     Client: {len(client_src)} belgi")


if __name__ == "__main__":
    main()
