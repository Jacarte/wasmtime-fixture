#!/bin/bash
set -euo pipefail
cd /testbed
git checkout 65e9dcc3e3399ba5bf76e9d76d8aa6a8ad4f20df -- crates/wasi-http/tests/all/p3/mod.rs
rm -f -- pepi_benchmark_contract.py
git apply - <<'SAFE_HIDDEN_PATCH'
diff --git a/crates/wasi-http/tests/all/p3/mod.rs b/crates/wasi-http/tests/all/p3/mod.rs
--- a/crates/wasi-http/tests/all/p3/mod.rs
+++ b/crates/wasi-http/tests/all/p3/mod.rs
@@ -1217,3 +1217,36 @@
     )
     .await
 }
+
+// Evaluator calls the requested guest interface; it does not provide its implementation.
+#[test_log::test(tokio::test(flavor = "multi_thread"))]
+async fn p3_http_api_bench() -> Result<()> {
+    // Existing artifact location is stable on base; the new guest is found at runtime.
+    let path = Path::new(P3_HTTP_PROXY_COMPONENT).with_file_name("p3_http_api_bench.component.wasm");
+    assert!(path.is_file(), "requested p3_http_api_bench guest workload is absent");
+    let engine = test_programs_artifacts::engine(|c| { c.wasm_component_model_async(true); });
+    let component = Component::from_file(&engine, path)?;
+    let mut linker = Linker::new(&engine);
+    wasmtime_wasi::p2::add_to_linker_async(&mut linker)?;
+    wasmtime_wasi::p3::add_to_linker(&mut linker)?;
+    wasmtime_wasi_http::p3::add_to_linker(&mut linker)?;
+    for api in ["request.new", "response.consume-body", "client.send"] {
+        for count in ["0", "1"] {
+            let stdout = wasmtime_wasi::p2::pipe::MemoryOutputPipe::new(1024);
+            // Keep the receiver alive so the standard test hook can send the request.
+            let (tx, _rx) = oneshot::channel();
+            let mut ctx = Ctx::new(tx);
+            ctx.wasi = WasiCtxBuilder::new().args(&["p3_http_api_bench", api, count]).stdout(stdout.clone()).build();
+            let mut store = Store::new(&engine, ctx);
+            let command = Command::instantiate_async(&mut store, &component, &linker).await?;
+            store.run_concurrent(async |store| command.wasi_cli_run().call_run(store).await).await??
+                .map_err(|()| format_err!("benchmark command returned failure"))?;
+            let output = stdout.contents();
+            let text = std::str::from_utf8(&output).unwrap().trim();
+            assert!(!text.is_empty() && text.bytes().all(|b| b.is_ascii_digit()), "expected unsigned nanoseconds: {text:?}");
+            let duration: u64 = text.parse().unwrap();
+            if count == "0" { assert_eq!(duration, 0); }
+        }
+    }
+    Ok(())
+}
diff --git a/pepi_benchmark_contract.py b/pepi_benchmark_contract.py
new file mode 100644
--- /dev/null
+++ b/pepi_benchmark_contract.py
@@ -0,0 +1,23 @@
+"""Verify benchmark registration and deterministic smoke output, not elapsed-time thresholds."""
+import subprocess
+import sys
+
+def run(args):
+    p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
+    print(p.stdout,flush=True)
+    return p
+features=['--features','test-programs-artifacts/release-artifacts']
+listing=run(['cargo','bench','--locked','--offline','--profile','dev','-p','wasmtime-wasi-http','--bench','p3_http_proxy',*features,'--','--list'])
+if listing.returncode:
+    raise SystemExit('SETUP FAILURE: benchmark target failed to build/list')
+proxy=run(['cargo','bench','--locked','--offline','--profile','dev','-p','wasmtime-wasi-http','--bench','p3_http_proxy',*features,'--','--test','wasi-http/p3_http_proxy'])
+control='wasi-http/p3_http_proxy' in listing.stdout and proxy.returncode==0 and 'Success' in proxy.stdout
+registered=all('wasi-http/p3-api/'+api in listing.stdout for api in ['request.new','response.consume-body','client.send'])
+print(f'test proxy_benchmark_control ... {"ok" if control else "FAILED"}',flush=True)
+print(f'test benchmark_registration ... {"ok" if registered else "FAILED"}',flush=True)
+smoke=run(['cargo','test','--locked','--offline','-p','wasmtime-wasi-http',*features,'--test','all','p3::p3_http_api_bench','--','--exact','--test-threads=1'])
+if smoke.returncode and 'requested p3_http_api_bench guest workload is absent' not in smoke.stdout:
+    raise SystemExit('SETUP OR RUNTIME FAILURE: see smoke output; absence is not established')
+if '1 passed' not in smoke.stdout and '1 failed' not in smoke.stdout:
+    raise SystemExit('SETUP FAILURE: no smoke assertion executed')
+sys.exit(0 if control and registered and smoke.returncode==0 else 1)
SAFE_HIDDEN_PATCH
printf '%s\n' '>>>>> Start Test Output'
set +e
export CARGO_NET_OFFLINE=true
(
python3 pepi_benchmark_contract.py
)
status=$?
printf '%s\n' '>>>>> End Test Output'
exit "$status"
