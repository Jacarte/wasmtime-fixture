#!/bin/bash
set -euo pipefail
cd /testbed
:
rm -f -- crates/wast/tests/pepi_safe_bool.wast crates/wast/tests/pepi_safe_char.wast crates/wast/tests/pepi_safe_enum.wast crates/wast/tests/pepi_safe_flags.wast crates/wast/tests/pepi_safe_floats.wast crates/wast/tests/pepi_safe_integers.wast crates/wast/tests/pepi_safe.rs
git apply - <<'SAFE_HIDDEN_PATCH'
diff --git a/crates/wast/tests/pepi_safe_bool.wast b/crates/wast/tests/pepi_safe_bool.wast
new file mode 100644
--- /dev/null
+++ b/crates/wast/tests/pepi_safe_bool.wast
@@ -0,0 +1,179 @@
+;;! component_model_gc = true
+;;! gc = true
+
+;; Tests for the component model `bool` type under the GC data model, where
+;; `bool` lowers to a core `i32` value.
+;;
+;; See https://github.com/WebAssembly/component-model/issues/525.
+
+;; Both sides use the GC data model.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" bool) (result bool)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" bool) (result bool)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (bool.const false)) (bool.const false))
+(assert_return (invoke "g" (bool.const true)) (bool.const true))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (memory (export "m") 1)
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" bool) (result bool)
+      (canon lift (core func $i "f") (memory (core memory $i "m"))))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" bool) (result bool)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (bool.const false)) (bool.const false))
+(assert_return (invoke "g" (bool.const true)) (bool.const true))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" bool) (result bool)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core func $l (canon lower (func $af)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (memory (export "m") 1)
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" bool) (result bool)
+    (canon lift (core func $i "g") (memory (core memory $i "m"))))
+)
+
+(assert_return (invoke "g" (bool.const false)) (bool.const false))
+(assert_return (invoke "g" (bool.const true)) (bool.const true))
+
+;; `bool` is canonicalized: a zero byte lifts to `false`.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" bool) (result bool)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" bool) (result bool)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (bool.const false)) (bool.const false))
+
+;; Any non-zero value lifts to `true`, not just 1.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 0x2)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" bool) (result bool)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" bool) (result bool)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (bool.const false)) (bool.const true))
+
+;; All-ones likewise lifts to `true`.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 0xffffffff)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" bool) (result bool)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" bool) (result bool)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (bool.const false)) (bool.const true))
diff --git a/crates/wast/tests/pepi_safe_char.wast b/crates/wast/tests/pepi_safe_char.wast
new file mode 100644
--- /dev/null
+++ b/crates/wast/tests/pepi_safe_char.wast
@@ -0,0 +1,191 @@
+;;! component_model_gc = true
+;;! gc = true
+
+;; Tests for the component model `char` type under the GC data model, where
+;; `char` lowers to a core `i32` value.
+;;
+;; See https://github.com/WebAssembly/component-model/issues/525.
+
+;; Both sides use the GC data model.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" char) (result char)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" char) (result char)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (char.const "a")) (char.const "a"))
+(assert_return (invoke "g" (char.const "\u{0}")) (char.const "\u{0}"))
+(assert_return (invoke "g" (char.const "\u{d7ff}")) (char.const "\u{d7ff}"))
+(assert_return (invoke "g" (char.const "\u{e000}")) (char.const "\u{e000}"))
+(assert_return (invoke "g" (char.const "\u{10ffff}")) (char.const "\u{10ffff}"))
+(assert_return (invoke "g" (char.const "🍰")) (char.const "🍰"))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (memory (export "m") 1)
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" char) (result char)
+      (canon lift (core func $i "f") (memory (core memory $i "m"))))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" char) (result char)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (char.const "a")) (char.const "a"))
+(assert_return (invoke "g" (char.const "\u{0}")) (char.const "\u{0}"))
+(assert_return (invoke "g" (char.const "\u{d7ff}")) (char.const "\u{d7ff}"))
+(assert_return (invoke "g" (char.const "\u{e000}")) (char.const "\u{e000}"))
+(assert_return (invoke "g" (char.const "\u{10ffff}")) (char.const "\u{10ffff}"))
+(assert_return (invoke "g" (char.const "🍰")) (char.const "🍰"))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" char) (result char)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core func $l (canon lower (func $af)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (memory (export "m") 1)
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" char) (result char)
+    (canon lift (core func $i "g") (memory (core memory $i "m"))))
+)
+
+(assert_return (invoke "g" (char.const "a")) (char.const "a"))
+(assert_return (invoke "g" (char.const "\u{0}")) (char.const "\u{0}"))
+(assert_return (invoke "g" (char.const "\u{d7ff}")) (char.const "\u{d7ff}"))
+(assert_return (invoke "g" (char.const "\u{e000}")) (char.const "\u{e000}"))
+(assert_return (invoke "g" (char.const "\u{10ffff}")) (char.const "\u{10ffff}"))
+(assert_return (invoke "g" (char.const "🍰")) (char.const "🍰"))
+
+;; A leading surrogate is not a valid `char`.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 0xd800)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" char) (result char)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" char) (result char)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_trap (invoke "g" (char.const "a")) "invalid `char` bit pattern")
+
+;; Nor is a trailing surrogate.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 0xdfff)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" char) (result char)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" char) (result char)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_trap (invoke "g" (char.const "a")) "invalid `char` bit pattern")
+
+;; Nor is a value at or above the maximum code point.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 0x110000)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" char) (result char)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" char) (result char)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_trap (invoke "g" (char.const "a")) "invalid `char` bit pattern")
diff --git a/crates/wast/tests/pepi_safe_enum.wast b/crates/wast/tests/pepi_safe_enum.wast
new file mode 100644
--- /dev/null
+++ b/crates/wast/tests/pepi_safe_enum.wast
@@ -0,0 +1,169 @@
+;;! component_model_gc = true
+;;! gc = true
+
+;; Tests for the component model `enum` type under the GC data model, where
+;; `enum` lowers to a core `i32` value.
+;;
+;; See https://github.com/WebAssembly/component-model/issues/525.
+
+;; Both sides use the GC data model.
+(component
+  (type $e (enum "red" "green" "blue"))
+  (component $A
+    (import "t" (type $t (eq $e)))
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" $t) (result $t)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A (with "t" (type $e))))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (export $te "t" (type $e))
+  (func (export "g") (param "a" $te) (result $te)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (enum.const "red")) (enum.const "red"))
+(assert_return (invoke "g" (enum.const "green")) (enum.const "green"))
+(assert_return (invoke "g" (enum.const "blue")) (enum.const "blue"))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (type $e (enum "red" "green" "blue"))
+  (component $A
+    (import "t" (type $t (eq $e)))
+    (core module $m
+      (memory (export "m") 1)
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" $t) (result $t)
+      (canon lift (core func $i "f") (memory (core memory $i "m"))))
+  )
+  (instance $a (instantiate $A (with "t" (type $e))))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (export $te "t" (type $e))
+  (func (export "g") (param "a" $te) (result $te)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (enum.const "red")) (enum.const "red"))
+(assert_return (invoke "g" (enum.const "green")) (enum.const "green"))
+(assert_return (invoke "g" (enum.const "blue")) (enum.const "blue"))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (type $e (enum "red" "green" "blue"))
+  (component $A
+    (import "t" (type $t (eq $e)))
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" $t) (result $t)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A (with "t" (type $e))))
+  (alias export $a "f" (func $af))
+
+  (core func $l (canon lower (func $af)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (memory (export "m") 1)
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (export $te "t" (type $e))
+  (func (export "g") (param "a" $te) (result $te)
+    (canon lift (core func $i "g") (memory (core memory $i "m"))))
+)
+
+(assert_return (invoke "g" (enum.const "red")) (enum.const "red"))
+(assert_return (invoke "g" (enum.const "green")) (enum.const "green"))
+(assert_return (invoke "g" (enum.const "blue")) (enum.const "blue"))
+
+;; An `enum` discriminant at the case count is out of range.
+(component
+  (type $e (enum "red" "green" "blue"))
+  (component $A
+    (import "t" (type $t (eq $e)))
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 3)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" $t) (result $t)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A (with "t" (type $e))))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (export $te "t" (type $e))
+  (func (export "g") (param "a" $te) (result $te)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_trap (invoke "g" (enum.const "red")) "invalid variant discriminant")
+
+;; A wildly out-of-range `enum` discriminant also traps.
+(component
+  (type $e (enum "red" "green" "blue"))
+  (component $A
+    (import "t" (type $t (eq $e)))
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 0xffffffff)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" $t) (result $t)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A (with "t" (type $e))))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (export $te "t" (type $e))
+  (func (export "g") (param "a" $te) (result $te)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_trap (invoke "g" (enum.const "red")) "invalid variant discriminant")
diff --git a/crates/wast/tests/pepi_safe_flags.wast b/crates/wast/tests/pepi_safe_flags.wast
new file mode 100644
--- /dev/null
+++ b/crates/wast/tests/pepi_safe_flags.wast
@@ -0,0 +1,411 @@
+;;! component_model_gc = true
+;;! gc = true
+
+;; Tests for the component model `flags` type under the GC data model, where
+;; `flags` lowers to a core `i32` value.
+;;
+;; See https://github.com/WebAssembly/component-model/issues/525.
+
+;; Both sides use the GC data model.
+(component
+  (type $f1 (flags "f0"))
+  (type $f8 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7"))
+  (type $f9 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8"))
+  (type $f16 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15"))
+  (type $f17 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16"))
+  (type $f32 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16" "f17" "f18" "f19" "f20" "f21" "f22" "f23" "f24" "f25" "f26" "f27" "f28" "f29" "f30" "f31"))
+
+  (component $A
+    (import "t1" (type $t1 (eq $f1)))
+    (import "t8" (type $t8 (eq $f8)))
+    (import "t9" (type $t9 (eq $f9)))
+    (import "t16" (type $t16 (eq $f16)))
+    (import "t17" (type $t17 (eq $f17)))
+    (import "t32" (type $t32 (eq $f32)))
+    (core module $m
+      (func (export "f1") (param i32) (result i32) local.get 0)
+      (func (export "f8") (param i32) (result i32) local.get 0)
+      (func (export "f9") (param i32) (result i32) local.get 0)
+      (func (export "f16") (param i32) (result i32) local.get 0)
+      (func (export "f17") (param i32) (result i32) local.get 0)
+      (func (export "f32") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f1") (param "a" $t1) (result $t1)
+      (canon lift (core func $i "f1") gc))
+    (func (export "f8") (param "a" $t8) (result $t8)
+      (canon lift (core func $i "f8") gc))
+    (func (export "f9") (param "a" $t9) (result $t9)
+      (canon lift (core func $i "f9") gc))
+    (func (export "f16") (param "a" $t16) (result $t16)
+      (canon lift (core func $i "f16") gc))
+    (func (export "f17") (param "a" $t17) (result $t17)
+      (canon lift (core func $i "f17") gc))
+    (func (export "f32") (param "a" $t32) (result $t32)
+      (canon lift (core func $i "f32") gc))
+  )
+  (instance $a (instantiate $A (with "t1" (type $f1)) (with "t8" (type $f8)) (with "t9" (type $f9)) (with "t16" (type $f16)) (with "t17" (type $f17)) (with "t32" (type $f32))))
+  (alias export $a "f1" (func $af1))
+  (alias export $a "f8" (func $af8))
+  (alias export $a "f9" (func $af9))
+  (alias export $a "f16" (func $af16))
+  (alias export $a "f17" (func $af17))
+  (alias export $a "f32" (func $af32))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l1 (canon lower (func $af1) gc (core-type $sig)))
+  (core func $l8 (canon lower (func $af8) gc (core-type $sig)))
+  (core func $l9 (canon lower (func $af9) gc (core-type $sig)))
+  (core func $l16 (canon lower (func $af16) gc (core-type $sig)))
+  (core func $l17 (canon lower (func $af17) gc (core-type $sig)))
+  (core func $l32 (canon lower (func $af32) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f1" (func $f1 (param i32) (result i32)))
+    (import "" "f8" (func $f8 (param i32) (result i32)))
+    (import "" "f9" (func $f9 (param i32) (result i32)))
+    (import "" "f16" (func $f16 (param i32) (result i32)))
+    (import "" "f17" (func $f17 (param i32) (result i32)))
+    (import "" "f32" (func $f32 (param i32) (result i32)))
+    (func (export "g1") (param i32) (result i32) local.get 0 call $f1)
+    (func (export "g8") (param i32) (result i32) local.get 0 call $f8)
+    (func (export "g9") (param i32) (result i32) local.get 0 call $f9)
+    (func (export "g16") (param i32) (result i32) local.get 0 call $f16)
+    (func (export "g17") (param i32) (result i32) local.get 0 call $f17)
+    (func (export "g32") (param i32) (result i32) local.get 0 call $f32)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f1" (func $l1)) (export "f8" (func $l8)) (export "f9" (func $l9)) (export "f16" (func $l16)) (export "f17" (func $l17)) (export "f32" (func $l32))))))
+
+  (export $e1 "t1" (type $f1))
+  (export $e8 "t8" (type $f8))
+  (export $e9 "t9" (type $f9))
+  (export $e16 "t16" (type $f16))
+  (export $e17 "t17" (type $f17))
+  (export $e32 "t32" (type $f32))
+  (func (export "g1") (param "a" $e1) (result $e1)
+    (canon lift (core func $i "g1") gc))
+  (func (export "g8") (param "a" $e8) (result $e8)
+    (canon lift (core func $i "g8") gc))
+  (func (export "g9") (param "a" $e9) (result $e9)
+    (canon lift (core func $i "g9") gc))
+  (func (export "g16") (param "a" $e16) (result $e16)
+    (canon lift (core func $i "g16") gc))
+  (func (export "g17") (param "a" $e17) (result $e17)
+    (canon lift (core func $i "g17") gc))
+  (func (export "g32") (param "a" $e32) (result $e32)
+    (canon lift (core func $i "g32") gc))
+)
+
+(assert_return (invoke "g1" (flags.const)) (flags.const))
+(assert_return (invoke "g1" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g1" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g1" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g8" (flags.const)) (flags.const))
+(assert_return (invoke "g8" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g8" (flags.const "f7")) (flags.const "f7"))
+(assert_return (invoke "g8" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7"))
+(assert_return (invoke "g9" (flags.const)) (flags.const))
+(assert_return (invoke "g9" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g9" (flags.const "f8")) (flags.const "f8"))
+(assert_return (invoke "g9" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8"))
+(assert_return (invoke "g16" (flags.const)) (flags.const))
+(assert_return (invoke "g16" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g16" (flags.const "f15")) (flags.const "f15"))
+(assert_return (invoke "g16" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15"))
+(assert_return (invoke "g17" (flags.const)) (flags.const))
+(assert_return (invoke "g17" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g17" (flags.const "f16")) (flags.const "f16"))
+(assert_return (invoke "g17" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16"))
+(assert_return (invoke "g32" (flags.const)) (flags.const))
+(assert_return (invoke "g32" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g32" (flags.const "f31")) (flags.const "f31"))
+(assert_return (invoke "g32" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16" "f17" "f18" "f19" "f20" "f21" "f22" "f23" "f24" "f25" "f26" "f27" "f28" "f29" "f30" "f31")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16" "f17" "f18" "f19" "f20" "f21" "f22" "f23" "f24" "f25" "f26" "f27" "f28" "f29" "f30" "f31"))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (type $f1 (flags "f0"))
+  (type $f8 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7"))
+  (type $f9 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8"))
+  (type $f16 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15"))
+  (type $f17 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16"))
+  (type $f32 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16" "f17" "f18" "f19" "f20" "f21" "f22" "f23" "f24" "f25" "f26" "f27" "f28" "f29" "f30" "f31"))
+
+  (component $A
+    (import "t1" (type $t1 (eq $f1)))
+    (import "t8" (type $t8 (eq $f8)))
+    (import "t9" (type $t9 (eq $f9)))
+    (import "t16" (type $t16 (eq $f16)))
+    (import "t17" (type $t17 (eq $f17)))
+    (import "t32" (type $t32 (eq $f32)))
+    (core module $m
+      (func (export "f1") (param i32) (result i32) local.get 0)
+      (func (export "f8") (param i32) (result i32) local.get 0)
+      (func (export "f9") (param i32) (result i32) local.get 0)
+      (func (export "f16") (param i32) (result i32) local.get 0)
+      (func (export "f17") (param i32) (result i32) local.get 0)
+      (func (export "f32") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f1") (param "a" $t1) (result $t1)
+      (canon lift (core func $i "f1")))
+    (func (export "f8") (param "a" $t8) (result $t8)
+      (canon lift (core func $i "f8")))
+    (func (export "f9") (param "a" $t9) (result $t9)
+      (canon lift (core func $i "f9")))
+    (func (export "f16") (param "a" $t16) (result $t16)
+      (canon lift (core func $i "f16")))
+    (func (export "f17") (param "a" $t17) (result $t17)
+      (canon lift (core func $i "f17")))
+    (func (export "f32") (param "a" $t32) (result $t32)
+      (canon lift (core func $i "f32")))
+  )
+  (instance $a (instantiate $A (with "t1" (type $f1)) (with "t8" (type $f8)) (with "t9" (type $f9)) (with "t16" (type $f16)) (with "t17" (type $f17)) (with "t32" (type $f32))))
+  (alias export $a "f1" (func $af1))
+  (alias export $a "f8" (func $af8))
+  (alias export $a "f9" (func $af9))
+  (alias export $a "f16" (func $af16))
+  (alias export $a "f17" (func $af17))
+  (alias export $a "f32" (func $af32))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l1 (canon lower (func $af1) gc (core-type $sig)))
+  (core func $l8 (canon lower (func $af8) gc (core-type $sig)))
+  (core func $l9 (canon lower (func $af9) gc (core-type $sig)))
+  (core func $l16 (canon lower (func $af16) gc (core-type $sig)))
+  (core func $l17 (canon lower (func $af17) gc (core-type $sig)))
+  (core func $l32 (canon lower (func $af32) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f1" (func $f1 (param i32) (result i32)))
+    (import "" "f8" (func $f8 (param i32) (result i32)))
+    (import "" "f9" (func $f9 (param i32) (result i32)))
+    (import "" "f16" (func $f16 (param i32) (result i32)))
+    (import "" "f17" (func $f17 (param i32) (result i32)))
+    (import "" "f32" (func $f32 (param i32) (result i32)))
+    (func (export "g1") (param i32) (result i32) local.get 0 call $f1)
+    (func (export "g8") (param i32) (result i32) local.get 0 call $f8)
+    (func (export "g9") (param i32) (result i32) local.get 0 call $f9)
+    (func (export "g16") (param i32) (result i32) local.get 0 call $f16)
+    (func (export "g17") (param i32) (result i32) local.get 0 call $f17)
+    (func (export "g32") (param i32) (result i32) local.get 0 call $f32)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f1" (func $l1)) (export "f8" (func $l8)) (export "f9" (func $l9)) (export "f16" (func $l16)) (export "f17" (func $l17)) (export "f32" (func $l32))))))
+
+  (export $e1 "t1" (type $f1))
+  (export $e8 "t8" (type $f8))
+  (export $e9 "t9" (type $f9))
+  (export $e16 "t16" (type $f16))
+  (export $e17 "t17" (type $f17))
+  (export $e32 "t32" (type $f32))
+  (func (export "g1") (param "a" $e1) (result $e1)
+    (canon lift (core func $i "g1") gc))
+  (func (export "g8") (param "a" $e8) (result $e8)
+    (canon lift (core func $i "g8") gc))
+  (func (export "g9") (param "a" $e9) (result $e9)
+    (canon lift (core func $i "g9") gc))
+  (func (export "g16") (param "a" $e16) (result $e16)
+    (canon lift (core func $i "g16") gc))
+  (func (export "g17") (param "a" $e17) (result $e17)
+    (canon lift (core func $i "g17") gc))
+  (func (export "g32") (param "a" $e32) (result $e32)
+    (canon lift (core func $i "g32") gc))
+)
+
+(assert_return (invoke "g1" (flags.const)) (flags.const))
+(assert_return (invoke "g1" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g1" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g1" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g8" (flags.const)) (flags.const))
+(assert_return (invoke "g8" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g8" (flags.const "f7")) (flags.const "f7"))
+(assert_return (invoke "g8" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7"))
+(assert_return (invoke "g9" (flags.const)) (flags.const))
+(assert_return (invoke "g9" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g9" (flags.const "f8")) (flags.const "f8"))
+(assert_return (invoke "g9" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8"))
+(assert_return (invoke "g16" (flags.const)) (flags.const))
+(assert_return (invoke "g16" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g16" (flags.const "f15")) (flags.const "f15"))
+(assert_return (invoke "g16" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15"))
+(assert_return (invoke "g17" (flags.const)) (flags.const))
+(assert_return (invoke "g17" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g17" (flags.const "f16")) (flags.const "f16"))
+(assert_return (invoke "g17" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16"))
+(assert_return (invoke "g32" (flags.const)) (flags.const))
+(assert_return (invoke "g32" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g32" (flags.const "f31")) (flags.const "f31"))
+(assert_return (invoke "g32" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16" "f17" "f18" "f19" "f20" "f21" "f22" "f23" "f24" "f25" "f26" "f27" "f28" "f29" "f30" "f31")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16" "f17" "f18" "f19" "f20" "f21" "f22" "f23" "f24" "f25" "f26" "f27" "f28" "f29" "f30" "f31"))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (type $f1 (flags "f0"))
+  (type $f8 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7"))
+  (type $f9 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8"))
+  (type $f16 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15"))
+  (type $f17 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16"))
+  (type $f32 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16" "f17" "f18" "f19" "f20" "f21" "f22" "f23" "f24" "f25" "f26" "f27" "f28" "f29" "f30" "f31"))
+
+  (component $A
+    (import "t1" (type $t1 (eq $f1)))
+    (import "t8" (type $t8 (eq $f8)))
+    (import "t9" (type $t9 (eq $f9)))
+    (import "t16" (type $t16 (eq $f16)))
+    (import "t17" (type $t17 (eq $f17)))
+    (import "t32" (type $t32 (eq $f32)))
+    (core module $m
+      (func (export "f1") (param i32) (result i32) local.get 0)
+      (func (export "f8") (param i32) (result i32) local.get 0)
+      (func (export "f9") (param i32) (result i32) local.get 0)
+      (func (export "f16") (param i32) (result i32) local.get 0)
+      (func (export "f17") (param i32) (result i32) local.get 0)
+      (func (export "f32") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f1") (param "a" $t1) (result $t1)
+      (canon lift (core func $i "f1") gc))
+    (func (export "f8") (param "a" $t8) (result $t8)
+      (canon lift (core func $i "f8") gc))
+    (func (export "f9") (param "a" $t9) (result $t9)
+      (canon lift (core func $i "f9") gc))
+    (func (export "f16") (param "a" $t16) (result $t16)
+      (canon lift (core func $i "f16") gc))
+    (func (export "f17") (param "a" $t17) (result $t17)
+      (canon lift (core func $i "f17") gc))
+    (func (export "f32") (param "a" $t32) (result $t32)
+      (canon lift (core func $i "f32") gc))
+  )
+  (instance $a (instantiate $A (with "t1" (type $f1)) (with "t8" (type $f8)) (with "t9" (type $f9)) (with "t16" (type $f16)) (with "t17" (type $f17)) (with "t32" (type $f32))))
+  (alias export $a "f1" (func $af1))
+  (alias export $a "f8" (func $af8))
+  (alias export $a "f9" (func $af9))
+  (alias export $a "f16" (func $af16))
+  (alias export $a "f17" (func $af17))
+  (alias export $a "f32" (func $af32))
+
+  (core func $l1 (canon lower (func $af1) ))
+  (core func $l8 (canon lower (func $af8) ))
+  (core func $l9 (canon lower (func $af9) ))
+  (core func $l16 (canon lower (func $af16) ))
+  (core func $l17 (canon lower (func $af17) ))
+  (core func $l32 (canon lower (func $af32) ))
+
+  (core module $m
+    (import "" "f1" (func $f1 (param i32) (result i32)))
+    (import "" "f8" (func $f8 (param i32) (result i32)))
+    (import "" "f9" (func $f9 (param i32) (result i32)))
+    (import "" "f16" (func $f16 (param i32) (result i32)))
+    (import "" "f17" (func $f17 (param i32) (result i32)))
+    (import "" "f32" (func $f32 (param i32) (result i32)))
+    (func (export "g1") (param i32) (result i32) local.get 0 call $f1)
+    (func (export "g8") (param i32) (result i32) local.get 0 call $f8)
+    (func (export "g9") (param i32) (result i32) local.get 0 call $f9)
+    (func (export "g16") (param i32) (result i32) local.get 0 call $f16)
+    (func (export "g17") (param i32) (result i32) local.get 0 call $f17)
+    (func (export "g32") (param i32) (result i32) local.get 0 call $f32)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f1" (func $l1)) (export "f8" (func $l8)) (export "f9" (func $l9)) (export "f16" (func $l16)) (export "f17" (func $l17)) (export "f32" (func $l32))))))
+
+  (export $e1 "t1" (type $f1))
+  (export $e8 "t8" (type $f8))
+  (export $e9 "t9" (type $f9))
+  (export $e16 "t16" (type $f16))
+  (export $e17 "t17" (type $f17))
+  (export $e32 "t32" (type $f32))
+  (func (export "g1") (param "a" $e1) (result $e1)
+    (canon lift (core func $i "g1")))
+  (func (export "g8") (param "a" $e8) (result $e8)
+    (canon lift (core func $i "g8")))
+  (func (export "g9") (param "a" $e9) (result $e9)
+    (canon lift (core func $i "g9")))
+  (func (export "g16") (param "a" $e16) (result $e16)
+    (canon lift (core func $i "g16")))
+  (func (export "g17") (param "a" $e17) (result $e17)
+    (canon lift (core func $i "g17")))
+  (func (export "g32") (param "a" $e32) (result $e32)
+    (canon lift (core func $i "g32")))
+)
+
+(assert_return (invoke "g1" (flags.const)) (flags.const))
+(assert_return (invoke "g1" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g1" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g1" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g8" (flags.const)) (flags.const))
+(assert_return (invoke "g8" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g8" (flags.const "f7")) (flags.const "f7"))
+(assert_return (invoke "g8" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7"))
+(assert_return (invoke "g9" (flags.const)) (flags.const))
+(assert_return (invoke "g9" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g9" (flags.const "f8")) (flags.const "f8"))
+(assert_return (invoke "g9" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8"))
+(assert_return (invoke "g16" (flags.const)) (flags.const))
+(assert_return (invoke "g16" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g16" (flags.const "f15")) (flags.const "f15"))
+(assert_return (invoke "g16" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15"))
+(assert_return (invoke "g17" (flags.const)) (flags.const))
+(assert_return (invoke "g17" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g17" (flags.const "f16")) (flags.const "f16"))
+(assert_return (invoke "g17" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16"))
+(assert_return (invoke "g32" (flags.const)) (flags.const))
+(assert_return (invoke "g32" (flags.const "f0")) (flags.const "f0"))
+(assert_return (invoke "g32" (flags.const "f31")) (flags.const "f31"))
+(assert_return (invoke "g32" (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16" "f17" "f18" "f19" "f20" "f21" "f22" "f23" "f24" "f25" "f26" "f27" "f28" "f29" "f30" "f31")) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16" "f17" "f18" "f19" "f20" "f21" "f22" "f23" "f24" "f25" "f26" "f27" "f28" "f29" "f30" "f31"))
+
+;; The callee returns an all-ones core `i32`. Lifting that back into a
+;; `flags` value must mask off every bit at or above the flag count, so none
+;; of the undefined high bits are observable.
+(component
+  (type $f1 (flags "f0"))
+  (type $f9 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8"))
+  (type $f17 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16"))
+
+  (component $A
+    (import "t1" (type $t1 (eq $f1)))
+    (import "t9" (type $t9 (eq $f9)))
+    (import "t17" (type $t17 (eq $f17)))
+    (core module $m
+      (func (export "f1") (param i32) (result i32) i32.const -1)
+      (func (export "f9") (param i32) (result i32) i32.const -1)
+      (func (export "f17") (param i32) (result i32) i32.const -1)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f1") (param "a" $t1) (result $t1)
+      (canon lift (core func $i "f1") gc))
+    (func (export "f9") (param "a" $t9) (result $t9)
+      (canon lift (core func $i "f9") gc))
+    (func (export "f17") (param "a" $t17) (result $t17)
+      (canon lift (core func $i "f17") gc))
+  )
+  (instance $a (instantiate $A (with "t1" (type $f1)) (with "t9" (type $f9)) (with "t17" (type $f17))))
+  (alias export $a "f1" (func $af1))
+  (alias export $a "f9" (func $af9))
+  (alias export $a "f17" (func $af17))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l1 (canon lower (func $af1) gc (core-type $sig)))
+  (core func $l9 (canon lower (func $af9) gc (core-type $sig)))
+  (core func $l17 (canon lower (func $af17) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f1" (func $f1 (param i32) (result i32)))
+    (import "" "f9" (func $f9 (param i32) (result i32)))
+    (import "" "f17" (func $f17 (param i32) (result i32)))
+    (func (export "g1") (param i32) (result i32) local.get 0 call $f1)
+    (func (export "g9") (param i32) (result i32) local.get 0 call $f9)
+    (func (export "g17") (param i32) (result i32) local.get 0 call $f17)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f1" (func $l1)) (export "f9" (func $l9)) (export "f17" (func $l17))))))
+
+  (export $e1 "t1" (type $f1))
+  (export $e9 "t9" (type $f9))
+  (export $e17 "t17" (type $f17))
+  (func (export "g1") (param "a" $e1) (result $e1)
+    (canon lift (core func $i "g1") gc))
+  (func (export "g9") (param "a" $e9) (result $e9)
+    (canon lift (core func $i "g9") gc))
+  (func (export "g17") (param "a" $e17) (result $e17)
+    (canon lift (core func $i "g17") gc))
+)
+
+(assert_return (invoke "g1" (flags.const)) (flags.const "f0"))
+(assert_return (invoke "g9" (flags.const)) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8"))
+(assert_return (invoke "g17" (flags.const)) (flags.const "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8" "f9" "f10" "f11" "f12" "f13" "f14" "f15" "f16"))
diff --git a/crates/wast/tests/pepi_safe_floats.wast b/crates/wast/tests/pepi_safe_floats.wast
new file mode 100644
--- /dev/null
+++ b/crates/wast/tests/pepi_safe_floats.wast
@@ -0,0 +1,294 @@
+;;! component_model_gc = true
+;;! gc = true
+
+;; Tests for the component model float types under the GC data model, where
+;; `f32` and `f64` lower to core `f32` and `f64` values.
+;;
+;; See https://github.com/WebAssembly/component-model/issues/525.
+;;
+;; The `wast` harness cannot pass a bare float to a component function: a
+;; top-level `(f32.const ...)` always parses as a core value. So these tests
+;; hand the value across as a bit pattern, reinterpret it inside wasm, send
+;; the float through the adapter, and report whether it came back bit-exact.
+
+;; `f32`
+
+;; Both sides use the GC data model.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param f32) (result f32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" f32) (result f32)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param f32) (result f32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param f32) (result f32)))
+    ;; Round-trip the bit pattern and report whether it survived exactly.
+    (func (export "g") (param i32) (result i32)
+      local.get 0
+      f32.reinterpret_i32
+      call $f
+      i32.reinterpret_f32
+      local.get 0
+      i32.eq)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s32) (result bool)
+    (canon lift (core func $i "g") gc))
+)
+
+;; +/-0.0, +/-1.5, the smallest subnormal, the largest finite value,
+;; +/-inf, a quiet NaN, and a signaling NaN.
+(assert_return (invoke "g" (s32.const 0x00000000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x80000000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x3fc00000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0xbfc00000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x00000001)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x7f7fffff)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x7f800000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0xff800000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x7fc00000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x7f800001)) (bool.const true))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (memory (export "m") 1)
+      (func (export "f") (param f32) (result f32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" f32) (result f32)
+      (canon lift (core func $i "f") (memory (core memory $i "m"))))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param f32) (result f32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param f32) (result f32)))
+    ;; Round-trip the bit pattern and report whether it survived exactly.
+    (func (export "g") (param i32) (result i32)
+      local.get 0
+      f32.reinterpret_i32
+      call $f
+      i32.reinterpret_f32
+      local.get 0
+      i32.eq)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s32) (result bool)
+    (canon lift (core func $i "g") gc))
+)
+
+;; +/-0.0, +/-1.5, the smallest subnormal, the largest finite value,
+;; +/-inf, a quiet NaN, and a signaling NaN.
+(assert_return (invoke "g" (s32.const 0x00000000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x80000000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x3fc00000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0xbfc00000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x00000001)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x7f7fffff)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x7f800000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0xff800000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x7fc00000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x7f800001)) (bool.const true))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param f32) (result f32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" f32) (result f32)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core func $l (canon lower (func $af)))
+
+  (core module $m
+    (import "" "f" (func $f (param f32) (result f32)))
+    (memory (export "m") 1)
+    ;; Round-trip the bit pattern and report whether it survived exactly.
+    (func (export "g") (param i32) (result i32)
+      local.get 0
+      f32.reinterpret_i32
+      call $f
+      i32.reinterpret_f32
+      local.get 0
+      i32.eq)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s32) (result bool)
+    (canon lift (core func $i "g") (memory (core memory $i "m"))))
+)
+
+;; +/-0.0, +/-1.5, the smallest subnormal, the largest finite value,
+;; +/-inf, a quiet NaN, and a signaling NaN.
+(assert_return (invoke "g" (s32.const 0x00000000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x80000000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x3fc00000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0xbfc00000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x00000001)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x7f7fffff)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x7f800000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0xff800000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x7fc00000)) (bool.const true))
+(assert_return (invoke "g" (s32.const 0x7f800001)) (bool.const true))
+
+;; `f64`
+
+;; Both sides use the GC data model.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param f64) (result f64) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" f64) (result f64)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param f64) (result f64)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param f64) (result f64)))
+    ;; Round-trip the bit pattern and report whether it survived exactly.
+    (func (export "g") (param i64) (result i32)
+      local.get 0
+      f64.reinterpret_i64
+      call $f
+      i64.reinterpret_f64
+      local.get 0
+      i64.eq)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s64) (result bool)
+    (canon lift (core func $i "g") gc))
+)
+
+;; +/-0.0, +/-1.5, the smallest subnormal, the largest finite value,
+;; +/-inf, a quiet NaN, and a signaling NaN.
+(assert_return (invoke "g" (s64.const 0x0000000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x8000000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x3ff8000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0xbff8000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x0000000000000001)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x7fefffffffffffff)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x7ff0000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0xfff0000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x7ff8000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x7ff0000000000001)) (bool.const true))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (memory (export "m") 1)
+      (func (export "f") (param f64) (result f64) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" f64) (result f64)
+      (canon lift (core func $i "f") (memory (core memory $i "m"))))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param f64) (result f64)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param f64) (result f64)))
+    ;; Round-trip the bit pattern and report whether it survived exactly.
+    (func (export "g") (param i64) (result i32)
+      local.get 0
+      f64.reinterpret_i64
+      call $f
+      i64.reinterpret_f64
+      local.get 0
+      i64.eq)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s64) (result bool)
+    (canon lift (core func $i "g") gc))
+)
+
+;; +/-0.0, +/-1.5, the smallest subnormal, the largest finite value,
+;; +/-inf, a quiet NaN, and a signaling NaN.
+(assert_return (invoke "g" (s64.const 0x0000000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x8000000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x3ff8000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0xbff8000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x0000000000000001)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x7fefffffffffffff)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x7ff0000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0xfff0000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x7ff8000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x7ff0000000000001)) (bool.const true))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param f64) (result f64) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" f64) (result f64)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core func $l (canon lower (func $af)))
+
+  (core module $m
+    (import "" "f" (func $f (param f64) (result f64)))
+    (memory (export "m") 1)
+    ;; Round-trip the bit pattern and report whether it survived exactly.
+    (func (export "g") (param i64) (result i32)
+      local.get 0
+      f64.reinterpret_i64
+      call $f
+      i64.reinterpret_f64
+      local.get 0
+      i64.eq)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s64) (result bool)
+    (canon lift (core func $i "g") (memory (core memory $i "m"))))
+)
+
+;; +/-0.0, +/-1.5, the smallest subnormal, the largest finite value,
+;; +/-inf, a quiet NaN, and a signaling NaN.
+(assert_return (invoke "g" (s64.const 0x0000000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x8000000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x3ff8000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0xbff8000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x0000000000000001)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x7fefffffffffffff)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x7ff0000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0xfff0000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x7ff8000000000000)) (bool.const true))
+(assert_return (invoke "g" (s64.const 0x7ff0000000000001)) (bool.const true))
diff --git a/crates/wast/tests/pepi_safe_integers.wast b/crates/wast/tests/pepi_safe_integers.wast
new file mode 100644
--- /dev/null
+++ b/crates/wast/tests/pepi_safe_integers.wast
@@ -0,0 +1,965 @@
+;;! component_model_gc = true
+;;! gc = true
+
+;; Tests for the component model integer types under the GC data model.
+;; `{s,u}{8,16,32}` lower to a core `i32` value and `{s,u}64` lower to a
+;; core `i64` value.
+;;
+;; See https://github.com/WebAssembly/component-model/issues/525.
+
+;; `u8`
+
+;; Both sides use the GC data model.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u8) (result u8)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u8) (result u8)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (u8.const 0)) (u8.const 0))
+(assert_return (invoke "g" (u8.const 1)) (u8.const 1))
+(assert_return (invoke "g" (u8.const 127)) (u8.const 127))
+(assert_return (invoke "g" (u8.const 128)) (u8.const 128))
+(assert_return (invoke "g" (u8.const 255)) (u8.const 255))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (memory (export "m") 1)
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u8) (result u8)
+      (canon lift (core func $i "f") (memory (core memory $i "m"))))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u8) (result u8)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (u8.const 0)) (u8.const 0))
+(assert_return (invoke "g" (u8.const 1)) (u8.const 1))
+(assert_return (invoke "g" (u8.const 127)) (u8.const 127))
+(assert_return (invoke "g" (u8.const 128)) (u8.const 128))
+(assert_return (invoke "g" (u8.const 255)) (u8.const 255))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u8) (result u8)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core func $l (canon lower (func $af)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (memory (export "m") 1)
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u8) (result u8)
+    (canon lift (core func $i "g") (memory (core memory $i "m"))))
+)
+
+(assert_return (invoke "g" (u8.const 0)) (u8.const 0))
+(assert_return (invoke "g" (u8.const 1)) (u8.const 1))
+(assert_return (invoke "g" (u8.const 127)) (u8.const 127))
+(assert_return (invoke "g" (u8.const 128)) (u8.const 128))
+(assert_return (invoke "g" (u8.const 255)) (u8.const 255))
+
+;; `s8`
+
+;; Both sides use the GC data model.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s8) (result s8)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s8) (result s8)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (s8.const 0)) (s8.const 0))
+(assert_return (invoke "g" (s8.const 1)) (s8.const 1))
+(assert_return (invoke "g" (s8.const -1)) (s8.const -1))
+(assert_return (invoke "g" (s8.const 127)) (s8.const 127))
+(assert_return (invoke "g" (s8.const -128)) (s8.const -128))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (memory (export "m") 1)
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s8) (result s8)
+      (canon lift (core func $i "f") (memory (core memory $i "m"))))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s8) (result s8)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (s8.const 0)) (s8.const 0))
+(assert_return (invoke "g" (s8.const 1)) (s8.const 1))
+(assert_return (invoke "g" (s8.const -1)) (s8.const -1))
+(assert_return (invoke "g" (s8.const 127)) (s8.const 127))
+(assert_return (invoke "g" (s8.const -128)) (s8.const -128))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s8) (result s8)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core func $l (canon lower (func $af)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (memory (export "m") 1)
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s8) (result s8)
+    (canon lift (core func $i "g") (memory (core memory $i "m"))))
+)
+
+(assert_return (invoke "g" (s8.const 0)) (s8.const 0))
+(assert_return (invoke "g" (s8.const 1)) (s8.const 1))
+(assert_return (invoke "g" (s8.const -1)) (s8.const -1))
+(assert_return (invoke "g" (s8.const 127)) (s8.const 127))
+(assert_return (invoke "g" (s8.const -128)) (s8.const -128))
+
+;; `u16`
+
+;; Both sides use the GC data model.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u16) (result u16)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u16) (result u16)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (u16.const 0)) (u16.const 0))
+(assert_return (invoke "g" (u16.const 1)) (u16.const 1))
+(assert_return (invoke "g" (u16.const 32767)) (u16.const 32767))
+(assert_return (invoke "g" (u16.const 32768)) (u16.const 32768))
+(assert_return (invoke "g" (u16.const 65535)) (u16.const 65535))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (memory (export "m") 1)
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u16) (result u16)
+      (canon lift (core func $i "f") (memory (core memory $i "m"))))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u16) (result u16)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (u16.const 0)) (u16.const 0))
+(assert_return (invoke "g" (u16.const 1)) (u16.const 1))
+(assert_return (invoke "g" (u16.const 32767)) (u16.const 32767))
+(assert_return (invoke "g" (u16.const 32768)) (u16.const 32768))
+(assert_return (invoke "g" (u16.const 65535)) (u16.const 65535))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u16) (result u16)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core func $l (canon lower (func $af)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (memory (export "m") 1)
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u16) (result u16)
+    (canon lift (core func $i "g") (memory (core memory $i "m"))))
+)
+
+(assert_return (invoke "g" (u16.const 0)) (u16.const 0))
+(assert_return (invoke "g" (u16.const 1)) (u16.const 1))
+(assert_return (invoke "g" (u16.const 32767)) (u16.const 32767))
+(assert_return (invoke "g" (u16.const 32768)) (u16.const 32768))
+(assert_return (invoke "g" (u16.const 65535)) (u16.const 65535))
+
+;; `s16`
+
+;; Both sides use the GC data model.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s16) (result s16)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s16) (result s16)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (s16.const 0)) (s16.const 0))
+(assert_return (invoke "g" (s16.const 1)) (s16.const 1))
+(assert_return (invoke "g" (s16.const -1)) (s16.const -1))
+(assert_return (invoke "g" (s16.const 32767)) (s16.const 32767))
+(assert_return (invoke "g" (s16.const -32768)) (s16.const -32768))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (memory (export "m") 1)
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s16) (result s16)
+      (canon lift (core func $i "f") (memory (core memory $i "m"))))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s16) (result s16)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (s16.const 0)) (s16.const 0))
+(assert_return (invoke "g" (s16.const 1)) (s16.const 1))
+(assert_return (invoke "g" (s16.const -1)) (s16.const -1))
+(assert_return (invoke "g" (s16.const 32767)) (s16.const 32767))
+(assert_return (invoke "g" (s16.const -32768)) (s16.const -32768))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s16) (result s16)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core func $l (canon lower (func $af)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (memory (export "m") 1)
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s16) (result s16)
+    (canon lift (core func $i "g") (memory (core memory $i "m"))))
+)
+
+(assert_return (invoke "g" (s16.const 0)) (s16.const 0))
+(assert_return (invoke "g" (s16.const 1)) (s16.const 1))
+(assert_return (invoke "g" (s16.const -1)) (s16.const -1))
+(assert_return (invoke "g" (s16.const 32767)) (s16.const 32767))
+(assert_return (invoke "g" (s16.const -32768)) (s16.const -32768))
+
+;; `u32`
+
+;; Both sides use the GC data model.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u32) (result u32)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u32) (result u32)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (u32.const 0)) (u32.const 0))
+(assert_return (invoke "g" (u32.const 1)) (u32.const 1))
+(assert_return (invoke "g" (u32.const 2147483648)) (u32.const 2147483648))
+(assert_return (invoke "g" (u32.const 4294967295)) (u32.const 4294967295))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (memory (export "m") 1)
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u32) (result u32)
+      (canon lift (core func $i "f") (memory (core memory $i "m"))))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u32) (result u32)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (u32.const 0)) (u32.const 0))
+(assert_return (invoke "g" (u32.const 1)) (u32.const 1))
+(assert_return (invoke "g" (u32.const 2147483648)) (u32.const 2147483648))
+(assert_return (invoke "g" (u32.const 4294967295)) (u32.const 4294967295))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u32) (result u32)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core func $l (canon lower (func $af)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (memory (export "m") 1)
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u32) (result u32)
+    (canon lift (core func $i "g") (memory (core memory $i "m"))))
+)
+
+(assert_return (invoke "g" (u32.const 0)) (u32.const 0))
+(assert_return (invoke "g" (u32.const 1)) (u32.const 1))
+(assert_return (invoke "g" (u32.const 2147483648)) (u32.const 2147483648))
+(assert_return (invoke "g" (u32.const 4294967295)) (u32.const 4294967295))
+
+;; `s32`
+
+;; Both sides use the GC data model.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s32) (result s32)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s32) (result s32)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (s32.const 0)) (s32.const 0))
+(assert_return (invoke "g" (s32.const 1)) (s32.const 1))
+(assert_return (invoke "g" (s32.const -1)) (s32.const -1))
+(assert_return (invoke "g" (s32.const 2147483647)) (s32.const 2147483647))
+(assert_return (invoke "g" (s32.const -2147483648)) (s32.const -2147483648))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (memory (export "m") 1)
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s32) (result s32)
+      (canon lift (core func $i "f") (memory (core memory $i "m"))))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s32) (result s32)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (s32.const 0)) (s32.const 0))
+(assert_return (invoke "g" (s32.const 1)) (s32.const 1))
+(assert_return (invoke "g" (s32.const -1)) (s32.const -1))
+(assert_return (invoke "g" (s32.const 2147483647)) (s32.const 2147483647))
+(assert_return (invoke "g" (s32.const -2147483648)) (s32.const -2147483648))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s32) (result s32)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core func $l (canon lower (func $af)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (memory (export "m") 1)
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s32) (result s32)
+    (canon lift (core func $i "g") (memory (core memory $i "m"))))
+)
+
+(assert_return (invoke "g" (s32.const 0)) (s32.const 0))
+(assert_return (invoke "g" (s32.const 1)) (s32.const 1))
+(assert_return (invoke "g" (s32.const -1)) (s32.const -1))
+(assert_return (invoke "g" (s32.const 2147483647)) (s32.const 2147483647))
+(assert_return (invoke "g" (s32.const -2147483648)) (s32.const -2147483648))
+
+;; `u64`
+
+;; Both sides use the GC data model.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i64) (result i64) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u64) (result u64)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i64) (result i64)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i64) (result i64)))
+    (func (export "g") (param i64) (result i64) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u64) (result u64)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (u64.const 0)) (u64.const 0))
+(assert_return (invoke "g" (u64.const 1)) (u64.const 1))
+(assert_return (invoke "g" (u64.const 9223372036854775807)) (u64.const 9223372036854775807))
+(assert_return (invoke "g" (u64.const 9223372036854775808)) (u64.const 9223372036854775808))
+(assert_return (invoke "g" (u64.const 18446744073709551615)) (u64.const 18446744073709551615))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (memory (export "m") 1)
+      (func (export "f") (param i64) (result i64) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u64) (result u64)
+      (canon lift (core func $i "f") (memory (core memory $i "m"))))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i64) (result i64)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i64) (result i64)))
+    (func (export "g") (param i64) (result i64) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u64) (result u64)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (u64.const 0)) (u64.const 0))
+(assert_return (invoke "g" (u64.const 1)) (u64.const 1))
+(assert_return (invoke "g" (u64.const 9223372036854775807)) (u64.const 9223372036854775807))
+(assert_return (invoke "g" (u64.const 9223372036854775808)) (u64.const 9223372036854775808))
+(assert_return (invoke "g" (u64.const 18446744073709551615)) (u64.const 18446744073709551615))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i64) (result i64) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u64) (result u64)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core func $l (canon lower (func $af)))
+
+  (core module $m
+    (import "" "f" (func $f (param i64) (result i64)))
+    (memory (export "m") 1)
+    (func (export "g") (param i64) (result i64) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u64) (result u64)
+    (canon lift (core func $i "g") (memory (core memory $i "m"))))
+)
+
+(assert_return (invoke "g" (u64.const 0)) (u64.const 0))
+(assert_return (invoke "g" (u64.const 1)) (u64.const 1))
+(assert_return (invoke "g" (u64.const 9223372036854775807)) (u64.const 9223372036854775807))
+(assert_return (invoke "g" (u64.const 9223372036854775808)) (u64.const 9223372036854775808))
+(assert_return (invoke "g" (u64.const 18446744073709551615)) (u64.const 18446744073709551615))
+
+;; `s64`
+
+;; Both sides use the GC data model.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i64) (result i64) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s64) (result s64)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i64) (result i64)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i64) (result i64)))
+    (func (export "g") (param i64) (result i64) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s64) (result s64)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (s64.const 0)) (s64.const 0))
+(assert_return (invoke "g" (s64.const 1)) (s64.const 1))
+(assert_return (invoke "g" (s64.const -1)) (s64.const -1))
+(assert_return (invoke "g" (s64.const 9223372036854775807)) (s64.const 9223372036854775807))
+(assert_return (invoke "g" (s64.const -9223372036854775808)) (s64.const -9223372036854775808))
+
+;; A GC-lowered caller calling a linear-memory-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (memory (export "m") 1)
+      (func (export "f") (param i64) (result i64) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s64) (result s64)
+      (canon lift (core func $i "f") (memory (core memory $i "m"))))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i64) (result i64)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i64) (result i64)))
+    (func (export "g") (param i64) (result i64) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s64) (result s64)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (s64.const 0)) (s64.const 0))
+(assert_return (invoke "g" (s64.const 1)) (s64.const 1))
+(assert_return (invoke "g" (s64.const -1)) (s64.const -1))
+(assert_return (invoke "g" (s64.const 9223372036854775807)) (s64.const 9223372036854775807))
+(assert_return (invoke "g" (s64.const -9223372036854775808)) (s64.const -9223372036854775808))
+
+;; A linear-memory-lowered caller calling a GC-lifted callee.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i64) (result i64) local.get 0)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s64) (result s64)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core func $l (canon lower (func $af)))
+
+  (core module $m
+    (import "" "f" (func $f (param i64) (result i64)))
+    (memory (export "m") 1)
+    (func (export "g") (param i64) (result i64) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s64) (result s64)
+    (canon lift (core func $i "g") (memory (core memory $i "m"))))
+)
+
+(assert_return (invoke "g" (s64.const 0)) (s64.const 0))
+(assert_return (invoke "g" (s64.const 1)) (s64.const 1))
+(assert_return (invoke "g" (s64.const -1)) (s64.const -1))
+(assert_return (invoke "g" (s64.const 9223372036854775807)) (s64.const 9223372036854775807))
+(assert_return (invoke "g" (s64.const -9223372036854775808)) (s64.const -9223372036854775808))
+
+;; `u8` masks off everything above bit 7.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 0xffffff01)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u8) (result u8)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u8) (result u8)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (u8.const 0)) (u8.const 1))
+
+;; `s8` sign-extends from bit 7.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 0xffffff80)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s8) (result s8)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s8) (result s8)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (s8.const 0)) (s8.const -128))
+
+;; A positive `s8` keeps its value.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 0x0000007f)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s8) (result s8)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s8) (result s8)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (s8.const 0)) (s8.const 127))
+
+;; `u16` masks off everything above bit 15.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 0xffff0001)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" u16) (result u16)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" u16) (result u16)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (u16.const 0)) (u16.const 1))
+
+;; `s16` sign-extends from bit 15.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 0xffff8000)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s16) (result s16)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s16) (result s16)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (s16.const 0)) (s16.const -32768))
+
+;; A positive `s16` keeps its value.
+(component
+  (component $A
+    (core module $m
+      (func (export "f") (param i32) (result i32) i32.const 0x00007fff)
+    )
+    (core instance $i (instantiate $m))
+    (func (export "f") (param "a" s16) (result s16)
+      (canon lift (core func $i "f") gc))
+  )
+  (instance $a (instantiate $A))
+  (alias export $a "f" (func $af))
+
+  (core type $sig (func (param i32) (result i32)))
+  (core func $l (canon lower (func $af) gc (core-type $sig)))
+
+  (core module $m
+    (import "" "f" (func $f (param i32) (result i32)))
+    (func (export "g") (param i32) (result i32) local.get 0 call $f)
+  )
+  (core instance $i (instantiate $m (with "" (instance (export "f" (func $l))))))
+
+  (func (export "g") (param "a" s16) (result s16)
+    (canon lift (core func $i "g") gc))
+)
+
+(assert_return (invoke "g" (s16.const 0)) (s16.const 32767))
diff --git a/crates/wast/tests/pepi_safe.rs b/crates/wast/tests/pepi_safe.rs
new file mode 100644
--- /dev/null
+++ b/crates/wast/tests/pepi_safe.rs
@@ -0,0 +1,40 @@
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
+fn isolated(name: &str, test: impl FnOnce()) {
+    if std::env::var_os("PEPI_SCALAR_CHILD").is_some() { test(); return; }
+    let output = std::process::Command::new(std::env::current_exe().unwrap())
+        .args(["--exact", name, "--test-threads=1"])
+        .env("PEPI_SCALAR_CHILD", "1").output().unwrap();
+    let stdout = String::from_utf8_lossy(&output.stdout);
+    let stderr = String::from_utf8_lossy(&output.stderr);
+    assert!(output.status.success() && stdout.contains("1 passed"),
+        "scalar behavior subprocess failed: {}\n{}\n{}", output.status, stdout, stderr);
+}
+#[test]
+fn check_bool() { isolated("check_bool", || run(include_bytes!("pepi_safe_bool.wast"), true)); }
+#[test]
+fn check_char() { isolated("check_char", || run(include_bytes!("pepi_safe_char.wast"), true)); }
+#[test]
+fn check_enum() { isolated("check_enum", || run(include_bytes!("pepi_safe_enum.wast"), true)); }
+#[test]
+fn check_flags() { isolated("check_flags", || run(include_bytes!("pepi_safe_flags.wast"), true)); }
+#[test]
+fn check_floats() { isolated("check_floats", || run(include_bytes!("pepi_safe_floats.wast"), true)); }
+#[test]
+fn check_integers() { isolated("check_integers", || run(include_bytes!("pepi_safe_integers.wast"), true)); }
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
