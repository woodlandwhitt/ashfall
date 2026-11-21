# Runs the quest, dialogue and world-object logic that tools/logic.mjs converted from the WebView build. Each function
# there is an ESTree syntax tree; this walks it with JavaScript's rules for the parts the game uses (truthiness,
# strict equality, string concatenation, arrow functions and closures, a handful of Array/String/Math methods).
# Host objects (the G game API, the player P, sfx...) are plain Objects: a member read calls js_get(key) on them and
# a method call calls the GDScript method of that name.
class_name JsVM
extends RefCounted

class Fn:
	var node: Dictionary
	var scope: Scope
	func _init(n: Dictionary, s: Scope) -> void:
		node = n
		scope = s

class Scope:
	var vars := {}
	var parent: Scope = null
	func _init(p: Scope = null) -> void:
		parent = p
	func find(name: String) -> Scope:
		var s := self
		while s != null:
			if s.vars.has(name):
				return s
			s = s.parent
		return null

class Ret:
	var v
	func _init(x) -> void:
		v = x

var globals := Scope.new()
var errors := 0
var last_error := ""

func define(name: String, v) -> void:
	globals.vars[name] = v

# ---------------------------------------------------------------- entry points
# a stored value is either plain data or {"$fn": tree}; fn_or_value() gives back the value, calling the function
func is_fn(v) -> bool:
	return v is Dictionary and v.has("$fn")

func fn_of(v) -> Fn:
	if v is Fn:
		return v
	if is_fn(v):
		if not v.has("_fn"):
			v["_fn"] = Fn.new(v["$fn"], globals)
		return v["_fn"]
	return null

func call_value(v, args: Array = []):
	var f := fn_of(v)
	if f != null:
		return call_fn(f, args)
	if v is Callable:
		return v.callv(args)
	return v

# a value that might be a function of G (a dialogue line, a stage text): resolve it
func val(v, args: Array = []):
	if is_fn(v) or v is Fn:
		return call_value(v, args)
	return v

func call_fn(f: Fn, args: Array):
	var n: Dictionary = f.node
	var s := Scope.new(f.scope)
	var params: Array = n.get("params", [])
	for i in params.size():
		_bind(params[i], args[i] if i < args.size() else null, s)
	var body: Dictionary = n.body
	if body.type == "BlockStatement":
		var r = _block(body.body, s)
		return r.v if r is Ret else null
	return ev(body, s)

func _bind(p: Dictionary, v, s: Scope) -> void:
	match p.type:
		"Identifier": s.vars[p.name] = v
		"AssignmentPattern": _bind(p.left, ev(p.right, s) if v == null else v, s)
		"ObjectPattern":
			for q in p.properties:
				_bind(q.value, get_member(v, _key(q, s)), s)
		"ArrayPattern":
			for i in p.elements.size():
				if p.elements[i] != null:
					_bind(p.elements[i], get_member(v, i), s)
		_: _err("pattern " + p.type)

# ---------------------------------------------------------------- statements
func _block(list: Array, s: Scope):
	for st in list:
		var r = _exec(st, s)
		if r is Ret:
			return r
	return null

func _exec(st: Dictionary, s: Scope):
	match st.type:
		"ExpressionStatement": ev(st.expression, s)
		"BlockStatement": return _block(st.body, Scope.new(s))
		"IfStatement":
			if truthy(ev(st.test, s)):
				return _exec(st.consequent, s)
			elif st.get("alternate") != null:
				return _exec(st.alternate, s)
		"ReturnStatement": return Ret.new(ev(st.argument, s) if st.get("argument") != null else null)
		"VariableDeclaration":
			for d in st.declarations:
				_bind(d.id, ev(d.init, s) if d.get("init") != null else null, s)
		"ForOfStatement":
			var it = ev(st.right, s)
			for x in (it if it is Array else []):
				var inner := Scope.new(s)
				_bind(st.left.declarations[0].id, x, inner)
				var r = _exec(st.body, inner)
				if r is Ret:
					return r
		"EmptyStatement": pass
		_: _err("statement " + st.type)
	return null

# ---------------------------------------------------------------- expressions
func ev(n, s: Scope):
	if n == null:
		return null
	match n.type:
		"Literal": return n.value
		"Identifier":
			var sc := s.find(n.name)
			return sc.vars[n.name] if sc else null
		"TemplateLiteral":
			var out := ""
			for i in n.quasis.size():
				out += String(n.quasis[i].value.cooked)
				if i < n.expressions.size():
					out += to_str(ev(n.expressions[i], s))
			return out
		"MemberExpression": return get_member(ev(n.object, s), _prop(n, s))
		"ChainExpression": return ev(n.expression, s)
		"CallExpression": return _call(n, s)
		"ArrowFunctionExpression", "FunctionExpression": return Fn.new(n, s)
		"UnaryExpression":
			if n.operator == "typeof":
				return type_of(ev(n.argument, s))
			if n.operator == "delete":
				var m: Dictionary = n.argument
				var o = ev(m.object, s)
				if o is Dictionary:
					o.erase(_prop(m, s))
				elif o is Object and o.has_method("js_delete"):
					o.js_delete(_prop(m, s))
				return true
			var a = ev(n.argument, s)
			match n.operator:
				"!": return not truthy(a)
				"-": return -num(a)
				"+": return num(a)
				"void": return null
		"BinaryExpression": return binop(n.operator, ev(n.left, s), ev(n.right, s))
		"LogicalExpression":
			var l = ev(n.left, s)
			match n.operator:
				"&&": return ev(n.right, s) if truthy(l) else l
				"||": return l if truthy(l) else ev(n.right, s)
				"??": return l if l != null else ev(n.right, s)
		"ConditionalExpression": return ev(n.consequent, s) if truthy(ev(n.test, s)) else ev(n.alternate, s)
		"AssignmentExpression":
			var v = ev(n.right, s)
			if n.operator != "=":
				v = binop(String(n.operator).trim_suffix("="), ev(n.left, s), v)
			_assign(n.left, v, s)
			return v
		"UpdateExpression":
			var old := num(ev(n.argument, s))
			var nv := old + (1.0 if n.operator == "++" else -1.0)
			_assign(n.argument, nv, s)
			return nv if n.prefix else old
		"ArrayExpression":
			var arr := []
			for e in n.elements:
				if e != null and e.type == "SpreadElement":
					arr.append_array(ev(e.argument, s))
				else:
					arr.append(ev(e, s))
			return arr
		"ObjectExpression":
			var o := {}
			for p in n.properties:
				if p.type == "SpreadElement":
					var src = ev(p.argument, s)
					if src is Dictionary:
						o.merge(src, true)
				else:
					o[_key(p, s)] = ev(p.value, s)
			return o
		"SequenceExpression":
			var last = null
			for e in n.expressions:
				last = ev(e, s)
			return last
	_err("expression " + str(n.type))
	return null

func _key(p: Dictionary, s: Scope) -> String:
	if p.get("computed", false):
		return to_str(ev(p.key, s))
	return String(p.key.name) if p.key.type == "Identifier" else to_str(p.key.value)

func _prop(m: Dictionary, s: Scope):
	if m.get("computed", false):
		return ev(m.property, s)
	return String(m.property.name)

func _assign(target: Dictionary, v, s: Scope) -> void:
	if target.type == "Identifier":
		var sc := s.find(target.name)
		(sc if sc else globals).vars[target.name] = v
		return
	if target.type == "MemberExpression":
		var o = ev(target.object, s)
		var k = _prop(target, s)
		if o is Dictionary:
			o[to_str(k) if not (k is String) else k] = v
		elif o is Array and (k is float or k is int):
			var i := int(k)
			while o.size() <= i:
				o.append(null)
			o[i] = v
		elif o is Object and o.has_method("js_set"):
			o.js_set(String(k), v)
		else:
			_err("assign to " + type_of(o) + "." + str(k))
		return
	_err("assign target " + target.type)

func _call(n: Dictionary, s: Scope):
	var args := []
	for a in n.arguments:
		if a.type == "SpreadElement":
			args.append_array(ev(a.argument, s))
		else:
			args.append(ev(a, s))
	var c: Dictionary = n.callee
	if c.type == "MemberExpression":
		var o = ev(c.object, s)
		var name = _prop(c, s)
		return call_method(o, String(name), args)
	var f = ev(c, s)
	if f is Fn:
		return call_fn(f, args)
	if f is Callable:
		return f.callv(args)
	if f == null and c.type == "Identifier":
		_err("no function " + c.name)
		return null
	_err("not callable")
	return null

func call_method(o, name: String, args: Array):
	if o is Object:
		if o is Fn:
			return call_fn(o, args)
		if o.has_method(name):
			return o.callv(name, _fit(o, name, args))
		if o.has_method("js_call"):
			return o.js_call(name, args)
		_err("no method " + name)
		return null
	if o is Dictionary:
		var f = o.get(name)
		if f is Fn:
			return call_fn(f, args)
		if f is Callable:
			return f.callv(args)
		match name:
			"hasOwnProperty": return o.has(to_str(args[0]))
		_err("dict method " + name)
		return null
	if o is Array:
		return _array_method(o, name, args)
	if o is String:
		return _string_method(o, name, args)
	if o is float or o is int:
		match name:
			"toFixed": return String.num(float(o), int(num(args[0])) if args.size() else 0)
			"toString": return to_str(o)
	_err("method " + name + " on " + type_of(o))
	return null

# Godot refuses calls with too many arguments; JavaScript ignores the extras
func _fit(o: Object, name: String, args: Array) -> Array:
	for m in o.get_method_list():
		if m.name == name:
			var mx: int = m.args.size()
			return args.slice(0, mx) if args.size() > mx else args
	return args

func _array_method(a: Array, name: String, args: Array):
	var f = args[0] if args.size() else null
	match name:
		"some":
			for i in a.size():
				if truthy(call_value(f, [a[i], i])): return true
			return false
		"every":
			for i in a.size():
				if not truthy(call_value(f, [a[i], i])): return false
			return true
		"filter":
			var out := []
			for i in a.size():
				if truthy(call_value(f, [a[i], i])): out.append(a[i])
			return out
		"find":
			for i in a.size():
				if truthy(call_value(f, [a[i], i])): return a[i]
			return null
		"findIndex":
			for i in a.size():
				if truthy(call_value(f, [a[i], i])): return i
			return -1
		"map":
			var out := []
			for i in a.size():
				out.append(call_value(f, [a[i], i]))
			return out
		"forEach":
			for i in a.size():
				call_value(f, [a[i], i])
			return null
		"reduce":
			var acc = args[1] if args.size() > 1 else null
			for i in a.size():
				acc = call_value(f, [acc, a[i], i])
			return acc
		"includes": return _index(a, f) >= 0
		"indexOf": return _index(a, f)
		"join":
			var sep := String(f) if f != null else ","
			return sep.join(a.map(func(x): return to_str(x)))
		"slice":
			var b := int(num(args[0])) if args.size() else 0
			var e := int(num(args[1])) if args.size() > 1 else a.size()
			if b < 0: b += a.size()
			if e < 0: e += a.size()
			return a.slice(b, e)
		"push":
			a.append_array(args)
			return a.size()
		"concat":
			var out := a.duplicate()
			for x in args:
				if x is Array: out.append_array(x)
				else: out.append(x)
			return out
	_err("array method " + name)
	return null

func _index(a: Array, x) -> int:
	for i in a.size():
		if js_eq(a[i], x):
			return i
	return -1

func _string_method(t: String, name: String, args: Array):
	var a0 = args[0] if args.size() else null
	match name:
		"startsWith": return t.begins_with(to_str(a0))
		"endsWith": return t.ends_with(to_str(a0))
		"includes": return t.contains(to_str(a0))
		"indexOf": return t.find(to_str(a0))
		"slice", "substring":
			var b := int(num(a0)) if a0 != null else 0
			var e := int(num(args[1])) if args.size() > 1 else t.length()
			if b < 0: b += t.length()
			if e < 0: e += t.length()
			return t.substr(b, maxi(0, e - b))
		"replace", "replaceAll": return t.replace(to_str(a0), to_str(args[1]) if args.size() > 1 else "")
		"toUpperCase": return t.to_upper()
		"toLowerCase": return t.to_lower()
		"trim": return t.strip_edges()
		"split": return Array(t.split(to_str(a0)))
		"charAt": return t[int(num(a0))] if int(num(a0)) < t.length() else ""
		"repeat": return t.repeat(int(num(a0)))
		"padStart": return t.lpad(int(num(a0)), to_str(args[1]) if args.size() > 1 else " ")
	_err("string method " + name)
	return null

# ---------------------------------------------------------------- JavaScript value rules
func get_member(o, k):
	if o == null:
		return null
	if o is Dictionary:
		var key = k if k is String else to_str(k)
		return o.get(key)
	if o is Array:
		if k is String:
			if k == "length": return o.size()
			return null
		var i := int(k)
		return o[i] if i >= 0 and i < o.size() else null
	if o is String:
		if k is String:
			return o.length() if k == "length" else null
		var i := int(k)
		return o[i] if i >= 0 and i < o.length() else null
	if o is Object and o.has_method("js_get"):
		return o.js_get(String(k))
	return null

func truthy(v) -> bool:
	if v == null:
		return false
	match typeof(v):
		TYPE_BOOL: return v
		TYPE_INT, TYPE_FLOAT: return v != 0 and not is_nan(float(v))
		TYPE_STRING, TYPE_STRING_NAME: return String(v) != ""
	return true

func num(v) -> float:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT: return float(v)
		TYPE_BOOL: return 1.0 if v else 0.0
		TYPE_NIL: return 0.0
		TYPE_STRING: return float(v) if String(v).is_valid_float() else NAN
	return NAN

func is_num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

func to_str(v) -> String:
	match typeof(v):
		TYPE_NIL: return "undefined"
		TYPE_FLOAT:
			if is_finite(v) and float(v) == floorf(v) and absf(v) < 1e15:
				return str(int(v))
			return str(v)
		TYPE_BOOL: return "true" if v else "false"
		TYPE_ARRAY: return ",".join(v.map(func(x): return "" if x == null else to_str(x)))
		TYPE_DICTIONARY: return "[object Object]"
	return str(v)

func type_of(v) -> String:
	match typeof(v):
		TYPE_NIL: return "undefined"
		TYPE_BOOL: return "boolean"
		TYPE_INT, TYPE_FLOAT: return "number"
		TYPE_STRING, TYPE_STRING_NAME: return "string"
	if v is Fn or v is Callable:
		return "function"
	return "object"

func js_eq(a, b) -> bool:
	if a == null or b == null:
		return a == null and b == null
	if is_num(a) and is_num(b):
		return float(a) == float(b)
	if typeof(a) != typeof(b):
		var sa := typeof(a) == TYPE_STRING or typeof(a) == TYPE_STRING_NAME
		var sb := typeof(b) == TYPE_STRING or typeof(b) == TYPE_STRING_NAME
		return sa and sb and String(a) == String(b)
	if a is Object or a is Array or a is Dictionary:
		return is_same(a, b)
	return a == b

func binop(op: String, a, b):
	match op:
		"===", "==": return js_eq(a, b)
		"!==", "!=": return not js_eq(a, b)
		"+":
			if typeof(a) == TYPE_STRING or typeof(b) == TYPE_STRING:
				return to_str(a) + to_str(b)
			return num(a) + num(b)
		"-": return num(a) - num(b)
		"*": return num(a) * num(b)
		"/": return num(a) / num(b) if num(b) != 0.0 else (INF if num(a) >= 0.0 else -INF)
		"%": return fmod(num(a), num(b))
		"<", ">", "<=", ">=":
			if typeof(a) == TYPE_STRING and typeof(b) == TYPE_STRING:
				match op:
					"<": return a < b
					">": return a > b
					"<=": return a <= b
					">=": return a >= b
			var x := num(a)
			var y := num(b)
			match op:
				"<": return x < y
				">": return x > y
				"<=": return x <= y
				">=": return x >= y
		"in":
			if b is Dictionary: return b.has(to_str(a))
			if b is Object and b.has_method("js_get"): return b.js_get(to_str(a)) != null
			return false
	_err("operator " + op)
	return null

func _err(t: String) -> void:
	errors += 1
	last_error = t
	if errors < 40:
		push_warning("JsVM: " + t)
