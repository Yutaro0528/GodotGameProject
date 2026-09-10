extends SceneTree

## 全 .tscn / .tres を検証する。Claude がシーンとリソースをテキスト編集する
## 運用における最重要のガード。
##
## 2 段階で検査する:
##   1. 実行時検査 — load() と instantiate() が通るか
##   2. 構造検査   — .tscn/.tres のテキストを解析し、parent= の解決先、
##                   ExtResource/SubResource の参照先、load_steps を確認する
##
## 構造検査が必要な理由: parent= が存在しないノードを指していても
## Godot は警告を出すだけで instantiate() は成功してしまうため、
## 実行時検査だけでは最も起きやすい破損を検出できない。
##
## 実行:
##   godot --headless --path . --script res://tools/validate_scenes.gd

const SCENE_DIRS: PackedStringArray = ["res://scenes"]
const RESOURCE_DIRS: PackedStringArray = ["res://resources"]

var _failures: int = 0
var _checked: int = 0


func _init() -> void:
	for dir_path in SCENE_DIRS:
		for path in _collect(dir_path, ".tscn"):
			_checked += 1
			_check_scene_runtime(path)
			_check_text_structure(path, true)

	for dir_path in RESOURCE_DIRS:
		for path in _collect(dir_path, ".tres"):
			_checked += 1
			_check_resource_runtime(path)
			_check_text_structure(path, false)

	if _failures > 0:
		printerr("validate_scenes: FAILED — %d problem(s) in %d asset(s)" % [_failures, _checked])
	else:
		print("validate_scenes: %d asset(s) OK" % _checked)
	quit(1 if _failures > 0 else 0)


func _fail(path: String, message: String) -> void:
	_failures += 1
	printerr("  [FAIL] %s: %s" % [path, message])


func _warn(path: String, message: String) -> void:
	print("  [warn] %s: %s" % [path, message])


# --- 実行時検査 -------------------------------------------------------------

func _check_scene_runtime(path: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_fail(path, "load() failed")
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		_fail(path, "instantiate() failed")
		return
	instance.free()


func _check_resource_runtime(path: String) -> void:
	if load(path) == null:
		_fail(path, "load() failed")


# --- 構造検査 ---------------------------------------------------------------

func _check_text_structure(path: String, is_scene: bool) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_fail(path, "file is empty or unreadable")
		return

	var ext_ids := _collect_ids(text, "(?m)^\\[ext_resource\\b.*\\bid=\"([^\"]+)\"")
	var sub_ids := _collect_ids(text, "(?m)^\\[sub_resource\\b.*\\bid=\"([^\"]+)\"")

	_check_references(path, text, "ExtResource", ext_ids)
	_check_references(path, text, "SubResource", sub_ids)
	_check_load_steps(path, text, ext_ids.size() + sub_ids.size())

	if is_scene:
		_check_node_tree(path, text)


func _collect_ids(text: String, pattern: String) -> PackedStringArray:
	var ids := PackedStringArray()
	var re := RegEx.new()
	re.compile(pattern)
	for m in re.search_all(text):
		ids.append(m.get_string(1))
	return ids


## ExtResource("id") / SubResource("id") の参照先が宣言済みか確認する。
## 「ExtResource("3") のように連番だけで参照してしまう」典型ミスもここで落ちる。
func _check_references(path: String, text: String, kind: String, declared: PackedStringArray) -> void:
	var re := RegEx.new()
	re.compile("%s\\(\\s*\"([^\"]*)\"\\s*\\)" % kind)
	for m in re.search_all(text):
		var referenced := m.get_string(1)
		if not declared.has(referenced):
			_fail(path, "%s(\"%s\") references an id that is not declared in this file" % [kind, referenced])


## load_steps は「ext_resource + sub_resource の総数 + 1」。
## ずれても Godot は復旧するため警告に留めるが、差分が汚れるので直すこと。
func _check_load_steps(path: String, text: String, resource_count: int) -> void:
	var re := RegEx.new()
	re.compile("(?m)^\\[gd_(?:scene|resource)\\b[^\\]]*\\bload_steps=(\\d+)")
	var m := re.search(text)
	if m == null:
		# load_steps は省略可能（参照が 0 件のとき）。参照があるのに無ければ警告。
		if resource_count > 0:
			_warn(path, "load_steps is missing but %d resource(s) are declared (expected %d)"
				% [resource_count, resource_count + 1])
		return
	var actual := m.get_string(1).to_int()
	var expected := resource_count + 1
	if actual != expected:
		_warn(path, "load_steps=%d but expected %d (ext_resource + sub_resource + 1)" % [actual, expected])


## 各 [node] の parent= が、それより前に宣言されたノードを指しているか確認する。
## ノードを消したときの参照残り、親より先に子を書いてしまうミス、
## parent= にノード「型」を書いてしまうミスをここで検出する。
func _check_node_tree(path: String, text: String) -> void:
	var node_re := RegEx.new()
	node_re.compile("(?m)^\\[node\\b[^\\]]*\\]")
	var name_re := RegEx.new()
	name_re.compile("\\bname=\"([^\"]*)\"")
	var parent_re := RegEx.new()
	parent_re.compile("\\bparent=\"([^\"]*)\"")

	var known := {}
	var has_root := false

	for m in node_re.search_all(text):
		var line := m.get_string(0)
		var name_match := name_re.search(line)
		if name_match == null:
			_fail(path, "node declaration without a name: %s" % line)
			continue
		var node_name := name_match.get_string(1)
		var parent_match := parent_re.search(line)

		if parent_match == null:
			if has_root:
				_fail(path, "node \"%s\" has no parent= but the root node is already declared" % node_name)
				continue
			has_root = true
			known["."] = true
			continue

		var parent_path := parent_match.get_string(1)
		if not known.has(parent_path):
			_fail(path, "node \"%s\" has parent=\"%s\" which is not a declared node path (check the node NAME, and that the parent appears earlier in the file)"
				% [node_name, parent_path])
			continue
		known[node_name if parent_path == "." else parent_path + "/" + node_name] = true

	if not has_root:
		_fail(path, "no root node declared")


# --- 収集 -------------------------------------------------------------------

func _collect(dir_path: String, suffix: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			result.append_array(_collect(full, suffix))
		elif entry.ends_with(suffix):
			result.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return result
