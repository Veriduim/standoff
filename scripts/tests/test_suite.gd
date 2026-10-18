class_name TestSuite
extends Node
## The base for a test area: _section() names a test, _check() records one behaviour. A suite's run() calls every
## `_test_*` method in turn.

var tests := 0
var failed_tests := 0
var checks := 0
var failures := 0
var _name := ""
var _failed: Array[String] = []
var _count := 0


func run() -> void:
	for m in get_method_list():
		var n: String = m["name"]
		if n.begins_with("_test_"):
			await call(n)   # (a test may wait for real time - the rejoin's retries)
			_close()


func _section(title: String) -> void:
	_close()
	_name = title
	_failed.clear()
	_count = 0


func _check(label: String, ok: bool) -> void:
	checks += 1
	_count += 1
	if not ok:
		failures += 1
		_failed.append(label)


func _close() -> void:
	if _name.is_empty():
		return
	tests += 1
	if _failed.is_empty():
		print("  PASS: %s (%d)" % [_name, _count])
	else:
		failed_tests += 1
		print("  FAIL: %s (%d of %d checks failed)" % [_name, _failed.size(), _count])
		for f in _failed:
			print("        x " + f)
	_name = ""
