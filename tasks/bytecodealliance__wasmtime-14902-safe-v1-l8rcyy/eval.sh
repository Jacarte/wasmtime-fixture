#!/bin/bash
set -euo pipefail
cd /testbed
:
rm -f -- pepi_cli_contract.py
git apply - <<'SAFE_HIDDEN_PATCH'
diff --git a/pepi_cli_contract.py b/pepi_cli_contract.py
new file mode 100644
--- /dev/null
+++ b/pepi_cli_contract.py
@@ -0,0 +1,21 @@
+"""Exercise CLI parsing, without a cluster, inherited sockets, or network access."""
+import subprocess
+import sys
+
+binary='target/debug/wasmtime'
+def invoke(args):
+    return subprocess.run([binary,'serve',*args],capture_output=True,text=True,timeout=15)
+failed=False
+for name,args,check in [
+ ('serve_help_control',['--help'],lambda p:p.returncode==0 and '--addr' in p.stdout and '--systemd-listenfd' in p.stdout),
+ ('single_flags_control',['--addr','127.0.0.1:0','/tmp/pepi-absent-component.wasm'],lambda p:p.returncode!=0 and 'failed to open wasm module' in p.stderr and 'pepi-absent-component.wasm' in p.stderr),
+ ('conflicting_serve_flags',['--systemd-listenfd','--addr','127.0.0.1:0','/tmp/pepi-absent-component.wasm'],lambda p:p.returncode!=0 and all(x in p.stderr for x in ['cannot be used with','--addr','--systemd-listenfd']))]:
+    p=invoke(args)
+    ok=check(p)
+    if name=='single_flags_control':
+        q=invoke(['--systemd-listenfd','/tmp/pepi-absent-component.wasm'])
+        ok=ok and q.returncode!=0 and 'Failed to resolve inherited sockets' in q.stderr
+    print(name,'exit',p.returncode,'stderr:',p.stderr.strip(),flush=True)
+    print(f'test {name} ... {"ok" if ok else "FAILED"}',flush=True)
+    failed |= not ok
+sys.exit(int(failed))
SAFE_HIDDEN_PATCH
printf '%s\n' '>>>>> Start Test Output'
set +e
export CARGO_NET_OFFLINE=true
(
cargo build --locked --offline --bin wasmtime || exit $?
python3 pepi_cli_contract.py
)
status=$?
printf '%s\n' '>>>>> End Test Output'
exit "$status"
