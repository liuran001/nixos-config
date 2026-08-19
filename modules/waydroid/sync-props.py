"""把期望的 Android 属性写进 waydroid.cfg，必要时重新生成 waydroid_base.prop。"""

import configparser
import subprocess
import sys

CFG = "/var/lib/waydroid/waydroid.cfg"
BASE_PROP = "/var/lib/waydroid/waydroid_base.prop"
WAYDROID = sys.argv[1]
DESIRED = dict(pair.split("=", 1) for pair in sys.argv[2:])

cfg = configparser.ConfigParser()
# 属性名区分大小写，configparser 默认会把 key 全转小写。
cfg.optionxform = str
cfg.read(CFG)

if not cfg.has_section("properties"):
    cfg.add_section("properties")

stale = [k for k, v in DESIRED.items() if cfg.get("properties", k, fallback=None) != v]

if stale:
    for key, value in DESIRED.items():
        cfg.set("properties", key, value)
    with open(CFG, "w") as handle:
        cfg.write(handle)
    print("waydroid.cfg updated:", ", ".join(stale))

# waydroid 只在 init/upgrade 时把 [properties] 展开进 waydroid_base.prop，
# 容器读的是后者，所以要单独确认它也跟上了。
try:
    with open(BASE_PROP) as handle:
        applied = handle.read().splitlines()
except FileNotFoundError:
    applied = []

if stale or any(k + "=" + v not in applied for k, v in DESIRED.items()):
    print("Regenerating waydroid_base.prop")
    # -o 只重建 host-permissions/LXC 配置/属性，不会去下载或替换镜像。
    subprocess.run([WAYDROID, "upgrade", "-o"], check=True)
