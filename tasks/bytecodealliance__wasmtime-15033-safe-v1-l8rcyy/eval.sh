#!/bin/bash
set -euo pipefail
cd /testbed
:
rm -f -- crates/wast/tests/pepi_safe_core_import_func_subtype.wast crates/wast/tests/pepi_safe.rs
git apply - <<'SAFE_HIDDEN_PATCH'
diff --git a/crates/wast/tests/pepi_safe_core_import_func_subtype.wast b/crates/wast/tests/pepi_safe_core_import_func_subtype.wast
new file mode 100644
--- /dev/null
+++ b/crates/wast/tests/pepi_safe_core_import_func_subtype.wast
@@ -0,0 +1,19 @@
+;;! gc = true
+
+;; A core instance inside a component may satisfy a function import of type
+;; `$super` with a function whose type is a declared subtype of `$super`.
+(component
+  (core module $a
+    (type $super (sub (func (result i32))))
+    (type $sub (sub $super (func (result i32))))
+    (func (export "f") (type $sub) i32.const 42))
+  (core module $b
+    (type $super (sub (func (result i32))))
+    (type $g (func (result i32)))
+    (import "a" "f" (func $f (type $super)))
+    (func (export "g") (type $g) call $f))
+  (core instance $a (instantiate $a))
+  (core instance $b (instantiate $b (with "a" (instance $a))))
+  (func (export "g") (result s32) (canon lift (core func $b "g"))))
+
+(assert_return (invoke "g") (s32.const 42))
diff --git a/crates/wast/tests/pepi_safe.rs b/crates/wast/tests/pepi_safe.rs
new file mode 100644
--- /dev/null
+++ b/crates/wast/tests/pepi_safe.rs
@@ -0,0 +1,20 @@
+use wasmtime::{Config, Engine};
+use wasmtime_wast::{Async, WastContext};
+fn run(text: &[u8], gc_model: bool) {
+    let mut config = Config::new();
+    config.wasm_gc(true).wasm_function_references(true).wasm_component_model(true);
+    config.wasm_component_model_gc(gc_model);
+    let engine = Engine::new(&config).unwrap();
+    let mut context = WastContext::new(&engine, Async::No, |_| {});
+    context.run_wast("oracle.wast", text).unwrap();
+}
+#[test]
+fn ordinary_component_control() {
+    run(br#"(component
+      (core module $m (func (export "f") (result i32) i32.const 17))
+      (core instance $i (instantiate $m))
+      (func (export "f") (result s32) (canon lift (core func $i "f"))))
+      (assert_return (invoke "f") (s32.const 17))"#, false);
+}
+#[test]
+fn check_core_import_func_subtype() { run(include_bytes!("pepi_safe_core_import_func_subtype.wast"), false); }
SAFE_HIDDEN_PATCH
printf '%s\n' '>>>>> Start Test Output'
set +e
export CARGO_NET_OFFLINE=true
(
cargo test --locked --offline -p wasmtime-wast --features component-model,component-model-async,wasmtime/default --test pepi_safe -- --test-threads=1
)
status=$?
printf '%s\n' '>>>>> End Test Output'
exit "$status"
