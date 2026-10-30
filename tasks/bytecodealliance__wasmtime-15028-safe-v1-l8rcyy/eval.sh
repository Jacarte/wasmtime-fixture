#!/bin/bash
set -euo pipefail
cd /testbed
git checkout ec63b69f3da9783db784eef6ba67635385926a2a -- crates/test-programs/src/bin/p2_cli_serve_hello_world.rs crates/test-programs/src/bin/p3_cli_serve_hello_world.rs tests/all/cli_tests.rs
:
git apply - <<'SAFE_HIDDEN_PATCH'
diff --git a/crates/test-programs/src/bin/p2_cli_serve_hello_world.rs b/crates/test-programs/src/bin/p2_cli_serve_hello_world.rs
index cd7c789..1db3b51 100644
--- a/crates/test-programs/src/bin/p2_cli_serve_hello_world.rs
+++ b/crates/test-programs/src/bin/p2_cli_serve_hello_world.rs
@@ -8,7 +8,7 @@ struct T;
 proxy::export!(T);
 
 impl proxy::exports::wasi::http::incoming_handler::Guest for T {
-    fn handle(_: IncomingRequest, outparam: ResponseOutparam) {
+    fn handle(request: IncomingRequest, outparam: ResponseOutparam) {
         let fields = Fields::new();
         let resp = OutgoingResponse::new(fields);
         let body = resp.body().expect("outgoing response");
@@ -19,6 +19,10 @@ impl proxy::exports::wasi::http::incoming_handler::Guest for T {
         out.blocking_write_and_flush(b"Hello, WASI!")
             .expect("writing response");
 
+        if request.path_with_query().as_deref() == Some("/trap") {
+            unreachable!();
+        }
+
         drop(out);
         OutgoingBody::finish(body, None).expect("outgoing-body.finish");
     }
diff --git a/crates/test-programs/src/bin/p3_cli_serve_hello_world.rs b/crates/test-programs/src/bin/p3_cli_serve_hello_world.rs
index a7d9e77..98a51d7 100644
--- a/crates/test-programs/src/bin/p3_cli_serve_hello_world.rs
+++ b/crates/test-programs/src/bin/p3_cli_serve_hello_world.rs
@@ -6,16 +6,20 @@ struct T;
 service::export!(T);
 
 impl service::exports::wasi::http::handler::Guest for T {
-    async fn handle(_request: Request) -> Result<Response, ErrorCode> {
+    async fn handle(request: Request) -> Result<Response, ErrorCode> {
         let (mut body_tx, body_rx) = wit_stream::new();
         let (body_result_tx, body_result_rx) = wit_future::new(|| Ok(None));
         let (response, _future_result) =
             Response::new(Fields::new(), Some(body_rx), body_result_rx);
-        drop(body_result_tx);
+        let trap = request.get_path_with_query().as_deref() == Some("/trap");
 
         wit_bindgen::spawn_local(async move {
             let remaining = body_tx.write_all(b"Hello, WASI!".to_vec()).await;
             assert!(remaining.is_empty());
+            if trap {
+                unreachable!();
+            }
+            drop(body_result_tx);
         });
         Ok(response)
     }
diff --git a/tests/all/cli_tests.rs b/tests/all/cli_tests.rs
index 43c4634..4fd8af2 100644
--- a/tests/all/cli_tests.rs
+++ b/tests/all/cli_tests.rs
@@ -2864,6 +2864,48 @@ start a print 1234
         .await
     }
 
+    #[tokio::test]
+    #[cfg_attr(not(feature = "component-model-async"), ignore)]
+    async fn p3_cli_serve_trap_mid_body() -> Result<()> {
+        cli_serve_trap_mid_body(P3_CLI_SERVE_HELLO_WORLD_COMPONENT, |cmd| {
+            cmd.arg("-Wcomponent-model-async");
+            cmd.arg("-Sp3,cli");
+        })
+        .await
+    }
+
+    #[tokio::test]
+    async fn p2_cli_serve_trap_mid_body() -> Result<()> {
+        cli_serve_trap_mid_body(P2_CLI_SERVE_HELLO_WORLD_COMPONENT, |cmd| {
+            cmd.arg("-Scli");
+        })
+        .await
+    }
+
+    /// A guest trapping while streaming a chunked response body must not
+    /// produce a response that looks complete to the client.
+    async fn cli_serve_trap_mid_body(
+        component: &str,
+        configure: impl FnOnce(&mut Command),
+    ) -> Result<()> {
+        let server = WasmtimeServe::new(component, configure)?;
+        let result = server
+            .send_request(
+                hyper::Request::builder()
+                    .uri("http://localhost/trap")
+                    .body(String::new())
+                    .context("failed to make request")?,
+            )
+            .await;
+        assert!(
+            result.is_err(),
+            "truncated body looked complete: {result:?}"
+        );
+        let (_, stderr) = server.finish()?;
+        assert!(stderr.contains("unreachable"), "{stderr}");
+        Ok(())
+    }
+
     const CONNECTION_COUNT_MANY: usize = 20;
     const REQUESTS_PER_CONNECTION_MANY: usize = 5;
 
SAFE_HIDDEN_PATCH
printf '%s\n' '>>>>> Start Test Output'
set +e
export CARGO_NET_OFFLINE=true
(
cargo test --locked --offline --test all --features component-model-async cli_serve_trap_mid_body -- --test-threads=1
a=$?
cargo test --locked --offline --test all --features component-model-async cli_tests::test_programs::p2_cli_serve_hello_world -- --exact --test-threads=1
b=$?
cargo test --locked --offline --test all --features component-model-async cli_tests::test_programs::p3_cli_serve_hello_world -- --exact --test-threads=1
c=$?
exit $((a || b || c))
)
status=$?
printf '%s\n' '>>>>> End Test Output'
exit "$status"
