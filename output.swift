//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"decimalNumber":	("/-?[0-9][0-9_]*/",	/-?[0-9][0-9_]*/,	false,	false),
	"comment":	("/\\/\\/.*\\r?\\n?/",	/\/\/.*\r?\n?/,	false,	true),
	"propertyWrapperProjection":	("/\\$\\p{XID_Continue}+/",	/\$\p{XID_Continue}+/,	false,	false),
	"macroIdentifier":	("/#\\p{XID_Start}\\p{XID_Continue}*/",	/#\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"stringLiteral":	("/#*\"(?:\\\\#*\\([^)]*\\)|\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]{1,8}\\}|\\\\#*\\s*\\n|[^\\\\])*\"#*|#*\"\"\"(?:\\\\#*\\([^)]*\\)|\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]{1,8}\\}|\\\\#*\\s*\\n|[^\\\\])*\"\"\"#*/",	/#*"(?:\\#*\([^)]*\)|\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]{1,8}\}|\\#*\s*\n|[^\\])*"#*|#*"""(?:\\#*\([^)]*\)|\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]{1,8}\}|\\#*\s*\n|[^\\])*"""#*/,	false,	false),
	"decimalFloatingPointLiteral":	("/-?[0-9][0-9_]*(?:\\.[0-9][0-9_]*)(?:[eE][+-]?[0-9][0-9_]*)?/",	/-?[0-9][0-9_]*(?:\.[0-9][0-9_]*)(?:[eE][+-]?[0-9][0-9_]*)?/,	false,	false),
	"plainIdentifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"escapedIdentifier":	("/`\\p{XID_Start}\\p{XID_Continue}*`/",	/`\p{XID_Start}\p{XID_Continue}*`/,	false,	false),
	"multilineComment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"octalLiteral":	("/-?0o[0-7][0-7_]*/",	/-?0o[0-7][0-7_]*/,	false,	false),
	"implicitParameterName":	("/\\$[0-9]+/",	/\$[0-9]+/,	false,	false),
	"extendedRegularExpressionLiteral":	("/#+\\/(?:[^\\/\\\\]|\\\\.)+\\/#+/",	/#+\/(?:[^\/\\]|\\.)+\/#+/,	false,	false),
	"dotOperator":	("/\\.[\\.\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]+/",	/\.[\.\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]+/,	false,	false),
	"plainOperator":	("/[\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}][\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]*/",	/[\/=+\-*%!&|^~?<>\p{Sm}\p{So}][\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]*/,	false,	false),
	"plainRegularExpressionLiteral":	("/\\/[^\\s](?:(?:[^\\/\\\\\\s]|\\\\.)*[^\\s])?\\//",	/\/[^\s](?:(?:[^\/\\\s]|\\.)*[^\s])?\//,	false,	false),
	"hexadecimalLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*/,	false,	false),
	"hexadecimalFloatingPointLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/,	false,	false),
	"binaryLiteral":	("/-?0b[0-1][0-1_]*/",	/-?0b[0-1][0-1_]*/,	false,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"#colorLiteral":	("#colorLiteral",	Regex { "#colorLiteral" },	true,	false),
	"public":	("public",	Regex { "public" },	true,	false),
	"each":	("each",	Regex { "each" },	true,	false),
	"get":	("get",	Regex { "get" },	true,	false),
	"enum":	("enum",	Regex { "enum" },	true,	false),
	"prefix":	("prefix",	Regex { "prefix" },	true,	false),
	"#elseif":	("#elseif",	Regex { "#elseif" },	true,	false),
	"precedencegroup":	("precedencegroup",	Regex { "precedencegroup" },	true,	false),
	"%":	("%",	Regex { "%" },	true,	false),
	"switch":	("switch",	Regex { "switch" },	true,	false),
	"iOS":	("iOS",	Regex { "iOS" },	true,	false),
	"isolated":	("isolated",	Regex { "isolated" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"required":	("required",	Regex { "required" },	true,	false),
	"private":	("private",	Regex { "private" },	true,	false),
	"safe":	("safe",	Regex { "safe" },	true,	false),
	"Any":	("Any",	Regex { "Any" },	true,	false),
	"any":	("any",	Regex { "any" },	true,	false),
	"subscript":	("subscript",	Regex { "subscript" },	true,	false),
	"super":	("super",	Regex { "super" },	true,	false),
	"as":	("as",	Regex { "as" },	true,	false),
	"getter:":	("getter:",	Regex { "getter:" },	true,	false),
	"#imageLiteral":	("#imageLiteral",	Regex { "#imageLiteral" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	"visionOS":	("visionOS",	Regex { "visionOS" },	true,	false),
	"alpha":	("alpha",	Regex { "alpha" },	true,	false),
	"throws":	("throws",	Regex { "throws" },	true,	false),
	"self":	("self",	Regex { "self" },	true,	false),
	"nonmutating":	("nonmutating",	Regex { "nonmutating" },	true,	false),
	"#if":	("#if",	Regex { "#if" },	true,	false),
	"lazy":	("lazy",	Regex { "lazy" },	true,	false),
	"package":	("package",	Regex { "package" },	true,	false),
	"fileprivate":	("fileprivate",	Regex { "fileprivate" },	true,	false),
	"postfix":	("postfix",	Regex { "postfix" },	true,	false),
	"borrowing":	("borrowing",	Regex { "borrowing" },	true,	false),
	"targetEnvironment":	("targetEnvironment",	Regex { "targetEnvironment" },	true,	false),
	"rethrows":	("rethrows",	Regex { "rethrows" },	true,	false),
	"#selector":	("#selector",	Regex { "#selector" },	true,	false),
	"#unavailable":	("#unavailable",	Regex { "#unavailable" },	true,	false),
	"if":	("if",	Regex { "if" },	true,	false),
	"x86_64":	("x86_64",	Regex { "x86_64" },	true,	false),
	"||":	("||",	Regex { "||" },	true,	false),
	"guard":	("guard",	Regex { "guard" },	true,	false),
	"yield":	("yield",	Regex { "yield" },	true,	false),
	";":	(";",	Regex { ";" },	true,	false),
	"move":	("move",	Regex { "move" },	true,	false),
	"...":	("...",	Regex { "..." },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"#warning":	("#warning",	Regex { "#warning" },	true,	false),
	"watchOSApplicationExtension":	("watchOSApplicationExtension",	Regex { "watchOSApplicationExtension" },	true,	false),
	"set":	("set",	Regex { "set" },	true,	false),
	"#":	("#",	Regex { "#" },	true,	false),
	"#else":	("#else",	Regex { "#else" },	true,	false),
	"Self":	("Self",	Regex { "Self" },	true,	false),
	"copy":	("copy",	Regex { "copy" },	true,	false),
	"-":	("-",	Regex { "-" },	true,	false),
	"nonisolated":	("nonisolated",	Regex { "nonisolated" },	true,	false),
	"arm64":	("arm64",	Regex { "arm64" },	true,	false),
	"deinit":	("deinit",	Regex { "deinit" },	true,	false),
	"willSet":	("willSet",	Regex { "willSet" },	true,	false),
	"Windows":	("Windows",	Regex { "Windows" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"==":	("==",	Regex { "==" },	true,	false),
	"resourceName":	("resourceName",	Regex { "resourceName" },	true,	false),
	"#fileLiteral":	("#fileLiteral",	Regex { "#fileLiteral" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"tvOSApplicationExtension":	("tvOSApplicationExtension",	Regex { "tvOSApplicationExtension" },	true,	false),
	"false":	("false",	Regex { "false" },	true,	false),
	"override":	("override",	Regex { "override" },	true,	false),
	"^":	("^",	Regex { "^" },	true,	false),
	"\\":	("\\",	Regex { "\\" },	true,	false),
	"internal":	("internal",	Regex { "internal" },	true,	false),
	"convenience":	("convenience",	Regex { "convenience" },	true,	false),
	"/":	("/",	Regex { "/" },	true,	false),
	"case":	("case",	Regex { "case" },	true,	false),
	"is":	("is",	Regex { "is" },	true,	false),
	"associatedtype":	("associatedtype",	Regex { "associatedtype" },	true,	false),
	"in":	("in",	Regex { "in" },	true,	false),
	",":	(",",	Regex { "," },	true,	false),
	">=":	(">=",	Regex { ">=" },	true,	false),
	"mutating":	("mutating",	Regex { "mutating" },	true,	false),
	"final":	("final",	Regex { "final" },	true,	false),
	"@":	("@",	Regex { "@" },	true,	false),
	"continue":	("continue",	Regex { "continue" },	true,	false),
	"visionOSApplicationExtension":	("visionOSApplicationExtension",	Regex { "visionOSApplicationExtension" },	true,	false),
	"await":	("await",	Regex { "await" },	true,	false),
	"right":	("right",	Regex { "right" },	true,	false),
	"unsafe":	("unsafe",	Regex { "unsafe" },	true,	false),
	"_unsafeInheritExecutor":	("_unsafeInheritExecutor",	Regex { "_unsafeInheritExecutor" },	true,	false),
	"class":	("class",	Regex { "class" },	true,	false),
	"operator":	("operator",	Regex { "operator" },	true,	false),
	"unowned":	("unowned",	Regex { "unowned" },	true,	false),
	"#available":	("#available",	Regex { "#available" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"Type":	("Type",	Regex { "Type" },	true,	false),
	"try":	("try",	Regex { "try" },	true,	false),
	"unowned(safe)":	("unowned(safe)",	Regex { "unowned(safe)" },	true,	false),
	"import":	("import",	Regex { "import" },	true,	false),
	"init":	("init",	Regex { "init" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	"Protocol":	("Protocol",	Regex { "Protocol" },	true,	false),
	"macCatalystApplicationExtension":	("macCatalystApplicationExtension",	Regex { "macCatalystApplicationExtension" },	true,	false),
	"break":	("break",	Regex { "break" },	true,	false),
	"green":	("green",	Regex { "green" },	true,	false),
	"watchOS":	("watchOS",	Regex { "watchOS" },	true,	false),
	"macro":	("macro",	Regex { "macro" },	true,	false),
	"weak":	("weak",	Regex { "weak" },	true,	false),
	"default":	("default",	Regex { "default" },	true,	false),
	"static":	("static",	Regex { "static" },	true,	false),
	"#keyPath":	("#keyPath",	Regex { "#keyPath" },	true,	false),
	"dynamic":	("dynamic",	Regex { "dynamic" },	true,	false),
	"arm":	("arm",	Regex { "arm" },	true,	false),
	"where":	("where",	Regex { "where" },	true,	false),
	"nil":	("nil",	Regex { "nil" },	true,	false),
	"macOSApplicationExtension":	("macOSApplicationExtension",	Regex { "macOSApplicationExtension" },	true,	false),
	"higherThan":	("higherThan",	Regex { "higherThan" },	true,	false),
	"line:":	("line:",	Regex { "line:" },	true,	false),
	"associativity":	("associativity",	Regex { "associativity" },	true,	false),
	"os":	("os",	Regex { "os" },	true,	false),
	"_":	("_",	Regex { "_" },	true,	false),
	"blue":	("blue",	Regex { "blue" },	true,	false),
	"while":	("while",	Regex { "while" },	true,	false),
	"discard":	("discard",	Regex { "discard" },	true,	false),
	"macCatalyst":	("macCatalyst",	Regex { "macCatalyst" },	true,	false),
	"var":	("var",	Regex { "var" },	true,	false),
	"swift":	("swift",	Regex { "swift" },	true,	false),
	"left":	("left",	Regex { "left" },	true,	false),
	"lowerThan":	("lowerThan",	Regex { "lowerThan" },	true,	false),
	"repeat":	("repeat",	Regex { "repeat" },	true,	false),
	"return":	("return",	Regex { "return" },	true,	false),
	"for":	("for",	Regex { "for" },	true,	false),
	"inout":	("inout",	Regex { "inout" },	true,	false),
	"assignment":	("assignment",	Regex { "assignment" },	true,	false),
	"struct":	("struct",	Regex { "struct" },	true,	false),
	"simulator":	("simulator",	Regex { "simulator" },	true,	false),
	"fallthrough":	("fallthrough",	Regex { "fallthrough" },	true,	false),
	"~":	("~",	Regex { "~" },	true,	false),
	"typealias":	("typealias",	Regex { "typealias" },	true,	false),
	"didSet":	("didSet",	Regex { "didSet" },	true,	false),
	"let":	("let",	Regex { "let" },	true,	false),
	"file:":	("file:",	Regex { "file:" },	true,	false),
	"macOS":	("macOS",	Regex { "macOS" },	true,	false),
	"&&":	("&&",	Regex { "&&" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"!":	("!",	Regex { "!" },	true,	false),
	"async":	("async",	Regex { "async" },	true,	false),
	"infix":	("infix",	Regex { "infix" },	true,	false),
	"compiler":	("compiler",	Regex { "compiler" },	true,	false),
	"arch":	("arch",	Regex { "arch" },	true,	false),
	"func":	("func",	Regex { "func" },	true,	false),
	"defer":	("defer",	Regex { "defer" },	true,	false),
	"do":	("do",	Regex { "do" },	true,	false),
	"i386":	("i386",	Regex { "i386" },	true,	false),
	"extension":	("extension",	Regex { "extension" },	true,	false),
	"optional":	("optional",	Regex { "optional" },	true,	false),
	"none":	("none",	Regex { "none" },	true,	false),
	"catch":	("catch",	Regex { "catch" },	true,	false),
	"else":	("else",	Regex { "else" },	true,	false),
	"#error":	("#error",	Regex { "#error" },	true,	false),
	"red":	("red",	Regex { "red" },	true,	false),
	"setter:":	("setter:",	Regex { "setter:" },	true,	false),
	"#sourceLocation":	("#sourceLocation",	Regex { "#sourceLocation" },	true,	false),
	"#endif":	("#endif",	Regex { "#endif" },	true,	false),
	"open":	("open",	Regex { "open" },	true,	false),
	"&":	("&",	Regex { "&" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"unowned(unsafe)":	("unowned(unsafe)",	Regex { "unowned(unsafe)" },	true,	false),
	"canImport":	("canImport",	Regex { "canImport" },	true,	false),
	"some":	("some",	Regex { "some" },	true,	false),
	"Linux":	("Linux",	Regex { "Linux" },	true,	false),
	"indirect":	("indirect",	Regex { "indirect" },	true,	false),
	"throw":	("throw",	Regex { "throw" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"consuming":	("consuming",	Regex { "consuming" },	true,	false),
	"iOSApplicationExtension":	("iOSApplicationExtension",	Regex { "iOSApplicationExtension" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"protocol":	("protocol",	Regex { "protocol" },	true,	false),
	"true":	("true",	Regex { "true" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"actor":	("actor",	Regex { "actor" },	true,	false),
	"tvOS":	("tvOS",	Regex { "tvOS" },	true,	false),
]
func prefixExpression() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["[", "#selector", "_", "hexadecimalLiteral", "decimalFloatingPointLiteral", "implicitParameterName", "true", "#keyPath", "#fileLiteral", "stringLiteral", "false", "binaryLiteral", "if", "plainOperator", "(", "decimalNumber", "propertyWrapperProjection", "self", "octalLiteral", ".", "\\\\", "macroIdentifier", "escapedIdentifier", "#colorLiteral", "nil", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "{", "plainIdentifier", "dotOperator", "super", "switch", "hexadecimalFloatingPointLiteral", "#imageLiteral"])
}
func availabilityCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#available"])
}
func isPattern() {
	if token.type = .ALT {
		next()
	}
	expect(["is"])
}
func setterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["mutating", "set", "@", "nonmutating"])
}
func balancedTokens() {
	if token.type = .ALT {
		balancedToken()
		// OPT
	}
	expect(["lazy", "-", "plainOperator", "func", "_", "fallthrough", "/", "(", "subscript", "case", "*", "get", "struct", "#", "for", "#endif", "#fileLiteral", "#colorLiteral", "#unavailable", "public", "didSet", "enum", "deinit", "implicitParameterName", "higherThan", "try", "init", "protocol", "#selector", "|", "associatedtype", "right", "switch", "willSet", "postfix", "static", "await", "_unsafeInheritExecutor", "guard", "#warning", "[", "discard", "convenience", "#available", "mutating", "else", "nonisolated", "extendedRegularExpressionLiteral", "decimalNumber", "actor", "move", "typealias", "lowerThan", "Any", "some", "private", "indirect", "false", "dotOperator", "async", "class", "nil", "^", "weak", "!", "stringLiteral", "<", "while", "#keyPath", "#imageLiteral", ",", "=", "associativity", "#elseif", "#sourceLocation", "import", "?", "optional", "true", "if", "+", "internal", "repeat", "defer", "do", "escapedIdentifier", "inout", "prefix", "borrowing", "operator", ":", "let", "is", "#else", "continue", "in", "catch", "precedencegroup", "throw", ";", "set", "required", "dynamic", ".", ">", "&", "#error", "unowned", "{", "super", "package", "Self", "copy", "plainRegularExpressionLiteral", "left", "final", "consuming", "where", "as", "rethrows", "throws", "extension", "binaryLiteral", "isolated", "var", "fileprivate", "plainIdentifier", "~", "yield", "open", "hexadecimalLiteral", "@", "each", "return", "override", "nonmutating", "self", "none", "%", "propertyWrapperProjection", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "octalLiteral", "break", "#if", "default"])
}
func whereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func infixExpression() {
	if token.type = .ALT {
		infixOperator()
		prefixExpression()
		// END
	} else if token.type = .ALT {
		infixOperator()
		prefixExpression()
		// END
	} else if token.type = .ALT {
		infixOperator()
		prefixExpression()
		// END
	} else if token.type = .ALT {
		infixOperator()
		prefixExpression()
		// END
	}
	expect(["plainOperator", "dotOperator"])
}
func dictionaryType() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func functionCallArgument() {
	if token.type = .ALT {
		expression()
		// END
	} else if token.type = .ALT {
		expression()
		// END
	} else if token.type = .ALT {
		expression()
		// END
	} else if token.type = .ALT {
		expression()
		// END
	}
	expect(["self", "await", "nil", "stringLiteral", "propertyWrapperProjection", "try", "#imageLiteral", "true", "\\\\", "_", "(", "{", "escapedIdentifier", "#fileLiteral", "plainOperator", "plainIdentifier", "decimalFloatingPointLiteral", "&", "binaryLiteral", "switch", "super", "[", "dotOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "plainRegularExpressionLiteral", "#selector", "macroIdentifier", "false", "octalLiteral", "#keyPath", "if", "implicitParameterName", "#colorLiteral", ".", "decimalNumber", "hexadecimalLiteral"])
}
func implicitMemberExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["."])
}
func forcedValueExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["#keyPath", "hexadecimalLiteral", "switch", "macroIdentifier", "[", "_", "#colorLiteral", "octalLiteral", "#selector", "false", "escapedIdentifier", "nil", "self", "implicitParameterName", "\\\\", "decimalFloatingPointLiteral", "super", "propertyWrapperProjection", "stringLiteral", "hexadecimalFloatingPointLiteral", "if", "(", "plainRegularExpressionLiteral", "#imageLiteral", "{", "plainIdentifier", "#fileLiteral", "decimalNumber", "binaryLiteral", "extendedRegularExpressionLiteral", ".", "true"])
}
func protocolMembers() {
	if token.type = .ALT {
		protocolMember()
		// OPT
	}
	expect(["dynamic", "unowned", "infix", "@", "required", "nonmutating", "typealias", "prefix", "var", "#if", "static", "final", "convenience", "postfix", "func", "override", "package", "weak", "internal", "private", "associatedtype", "open", "public", "#error", "init", "optional", "#warning", "mutating", "fileprivate", "#sourceLocation", "class", "subscript", "lazy", "nonisolated"])
}
func labeledTrailingClosures() {
	if token.type = .ALT {
		labeledTrailingClosure()
		// OPT
	}
	expect(["escapedIdentifier", "_", "implicitParameterName", "plainIdentifier", "propertyWrapperProjection"])
}
func nilLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["nil"])
}
func getterSetterBlock() {
	if token.type = .ALT {
		codeBlock()
		// END
	} else if token.type = .ALT {
		codeBlock()
		// END
	} else if token.type = .ALT {
		codeBlock()
		// END
	}
	expect(["{"])
}
func rawValueStyleEnumCaseList() {
	if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	} else if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	}
	expect(["implicitParameterName", "plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_"])
}
func declarationModifiers() {
	if token.type = .ALT {
		declarationModifier()
		// OPT
	}
	expect(["nonisolated", "postfix", "infix", "optional", "open", "internal", "package", "unowned", "class", "fileprivate", "prefix", "weak", "mutating", "private", "override", "lazy", "required", "nonmutating", "public", "static", "dynamic", "convenience", "final"])
}
func sameTypeRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "_"])
}
func whereExpression() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["self", "await", "nil", "stringLiteral", "propertyWrapperProjection", "try", "#imageLiteral", "true", "\\\\", "_", "(", "{", "escapedIdentifier", "#fileLiteral", "plainOperator", "plainIdentifier", "decimalFloatingPointLiteral", "&", "binaryLiteral", "switch", "super", "[", "dotOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "plainRegularExpressionLiteral", "#selector", "macroIdentifier", "false", "octalLiteral", "#keyPath", "if", "implicitParameterName", "#colorLiteral", ".", "decimalNumber", "hexadecimalLiteral"])
}
func setterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["mutating", "set", "@", "nonmutating"])
}
func genericParameterClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
}
func genericArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
}
func closureParameter() {
	if token.type = .ALT {
		closureParameterName()
		// OPT
	} else if token.type = .ALT {
		closureParameterName()
		// OPT
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func postfixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["dotOperator", "plainOperator"])
}
func deferStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["defer"])
}
func rawValueLiteral() {
	if token.type = .ALT {
		numericLiteral()
		// END
	} else if token.type = .ALT {
		numericLiteral()
		// END
	} else if token.type = .ALT {
		numericLiteral()
		// END
	}
	expect(["decimalNumber", "octalLiteral", "hexadecimalLiteral", "binaryLiteral", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral"])
}
func opaqueType() {
	if token.type = .ALT {
		next()
	}
	expect(["some"])
}
func protocolPropertyDeclaration() {
	if token.type = .ALT {
		variableDeclarationHead()
		variableName()
		typeAnnotation()
		getterSetterKeywordBlock()
		// END
	}
	expect(["package", "private", "fileprivate", "mutating", "@", "unowned", "lazy", "final", "convenience", "required", "var", "nonisolated", "class", "optional", "postfix", "override", "infix", "static", "dynamic", "public", "prefix", "weak", "internal", "open", "nonmutating"])
}
func compilationCondition() {
	if token.type = .ALT {
		platformCondition()
		// END
	} else if token.type = .ALT {
		platformCondition()
		// END
	} else if token.type = .ALT {
		platformCondition()
		// END
	} else if token.type = .ALT {
		platformCondition()
		// END
	} else if token.type = .ALT {
		platformCondition()
		// END
	} else if token.type = .ALT {
		platformCondition()
		// END
	} else if token.type = .ALT {
		platformCondition()
		// END
	}
	expect(["swift", "canImport", "arch", "os", "compiler", "targetEnvironment"])
}
func precedenceGroupAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["assignment"])
}
func ifExpressionTail() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
}
func conditionalExpression() {
	if token.type = .ALT {
		ifExpression()
		// END
	} else if token.type = .ALT {
		ifExpression()
		// END
	}
	expect(["if"])
}
func Operator() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["plainOperator"])
}
func functionCallExpression() {
	if token.type = .ALT {
		postfixExpression()
		functionCallArgumentClause()
		// END
	} else if token.type = .ALT {
		postfixExpression()
		functionCallArgumentClause()
		// END
	}
	expect(["#keyPath", "hexadecimalLiteral", "switch", "macroIdentifier", "[", "_", "#colorLiteral", "octalLiteral", "#selector", "false", "escapedIdentifier", "nil", "self", "implicitParameterName", "\\\\", "decimalFloatingPointLiteral", "super", "propertyWrapperProjection", "stringLiteral", "hexadecimalFloatingPointLiteral", "if", "(", "plainRegularExpressionLiteral", "#imageLiteral", "{", "plainIdentifier", "#fileLiteral", "decimalNumber", "binaryLiteral", "extendedRegularExpressionLiteral", ".", "true"])
}
func precedenceGroupRelation() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["higherThan"])
}
func availabilityArguments() {
	if token.type = .ALT {
		availabilityArgument()
		// END
	} else if token.type = .ALT {
		availabilityArgument()
		// END
	}
	expect(["tvOS", "visionOS", "macOSApplicationExtension", "macOS", "watchOSApplicationExtension", "iOS", "iOSApplicationExtension", "watchOS", "macCatalystApplicationExtension", "macCatalyst", "tvOSApplicationExtension", "visionOSApplicationExtension", "*"])
}
func platformName() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["iOS"])
}
func architecture() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["i386"])
}
func controlTransferStatement() {
	if token.type = .ALT {
		breakStatement()
		// END
	} else if token.type = .ALT {
		breakStatement()
		// END
	} else if token.type = .ALT {
		breakStatement()
		// END
	} else if token.type = .ALT {
		breakStatement()
		// END
	} else if token.type = .ALT {
		breakStatement()
		// END
	}
	expect(["break"])
}
func compilerControlStatement() {
	if token.type = .ALT {
		conditionalCompilationBlock()
		// END
	} else if token.type = .ALT {
		conditionalCompilationBlock()
		// END
	} else if token.type = .ALT {
		conditionalCompilationBlock()
		// END
	}
	expect(["#if"])
}
func typeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func unionStyleEnumCaseList() {
	if token.type = .ALT {
		unionStyleEnumCase()
		// END
	} else if token.type = .ALT {
		unionStyleEnumCase()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "_", "escapedIdentifier", "implicitParameterName"])
}
func localParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func functionCallArgumentClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func switchExpressionCases() {
	if token.type = .ALT {
		switchExpressionCase()
		// OPT
	}
	expect(["@", "default", "case"])
}
func prefixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["dotOperator", "plainOperator"])
}
func typeInheritanceList() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["escapedIdentifier", "@", "propertyWrapperProjection", "_", "implicitParameterName", "plainIdentifier"])
}
func expressionPattern() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["self", "await", "nil", "stringLiteral", "propertyWrapperProjection", "try", "#imageLiteral", "true", "\\\\", "_", "(", "{", "escapedIdentifier", "#fileLiteral", "plainOperator", "plainIdentifier", "decimalFloatingPointLiteral", "&", "binaryLiteral", "switch", "super", "[", "dotOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "plainRegularExpressionLiteral", "#selector", "macroIdentifier", "false", "octalLiteral", "#keyPath", "if", "implicitParameterName", "#colorLiteral", ".", "decimalNumber", "hexadecimalLiteral"])
}
func functionCallArgumentList() {
	if token.type = .ALT {
		functionCallArgument()
		// END
	} else if token.type = .ALT {
		functionCallArgument()
		// END
	}
	expect(["await", "escapedIdentifier", "decimalFloatingPointLiteral", "propertyWrapperProjection", "{", "#imageLiteral", "[", "dotOperator", ".", "switch", "(", "#selector", "false", "implicitParameterName", "self", "try", "hexadecimalLiteral", "true", "stringLiteral", "#keyPath", "nil", "#colorLiteral", "_", "plainOperator", "macroIdentifier", "octalLiteral", "extendedRegularExpressionLiteral", "decimalNumber", "plainIdentifier", "hexadecimalFloatingPointLiteral", "if", "\\\\", "binaryLiteral", "&", "#fileLiteral", "super", "plainRegularExpressionLiteral"])
}
func implicitlyUnwrappedOptionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["Self", "plainIdentifier", "implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "[", "(", "@", "_", "some", "Any"])
}
func attributes() {
	if token.type = .ALT {
		attribute()
		// OPT
	}
	expect(["@"])
}
func protocolName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func precedenceGroupDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["precedencegroup"])
}
func protocolCompositionContinuation() {
	if token.type = .ALT {
		typeIdentifier()
		// END
	} else if token.type = .ALT {
		typeIdentifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "_"])
}
func caseItemList() {
	if token.type = .ALT {
		pattern()
		// OPT
	} else if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["extendedRegularExpressionLiteral", "let", "false", "#keyPath", "stringLiteral", "binaryLiteral", "implicitParameterName", "dotOperator", "hexadecimalLiteral", ".", "var", "try", "\\\\", "_", "true", "#colorLiteral", "(", "hexadecimalFloatingPointLiteral", "nil", "is", "super", "#fileLiteral", "escapedIdentifier", "plainOperator", "plainRegularExpressionLiteral", "{", "switch", "#imageLiteral", "propertyWrapperProjection", "macroIdentifier", "decimalFloatingPointLiteral", "octalLiteral", "decimalNumber", "[", "plainIdentifier", "&", "self", "#selector", "if", "await"])
}
func assignmentOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func awaitOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["await"])
}
func prefixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["prefix"])
}
func throwStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["throw"])
}
func regularExpressionLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["plainRegularExpressionLiteral"])
}
func protocolBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func functionType() {
	if token.type = .ALT {
		// OPT
	}
	expect(["(", "@"])
}
func argumentLabel() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func captureSpecifier() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["weak"])
}
func boxedProtocolType() {
	if token.type = .ALT {
		next()
	}
	expect(["any"])
}
func elseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
}
func integerLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["binaryLiteral"])
}
func arrayType() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func typealiasDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["private", "typealias", "public", "open", "@", "package", "fileprivate", "internal"])
}
func closureExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func defaultArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func selfSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func subscriptHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["fileprivate", "static", "required", "lazy", "public", "open", "mutating", "convenience", "override", "weak", "prefix", "nonmutating", "final", "nonisolated", "internal", "subscript", "@", "package", "unowned", "private", "class", "dynamic", "postfix", "optional", "infix"])
}
func guardStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["guard"])
}
func switchElseifDirectiveClause() {
	if token.type = .ALT {
		elseifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#elseif"])
}
func functionTypeArgumentList() {
	if token.type = .ALT {
		functionTypeArgument()
		// END
	} else if token.type = .ALT {
		functionTypeArgument()
		// END
	}
	expect(["Self", "@", "propertyWrapperProjection", "inout", "(", "Any", "_", "implicitParameterName", "plainIdentifier", "escapedIdentifier", "some", "["])
}
func infixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["infix"])
}
func filePath() {
	if token.type = .ALT {
		staticStringLiteral()
		// END
	}
	expect(["stringLiteral"])
}
func continueStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["continue"])
}
func elseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
}
func closureParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func typeInheritanceClause() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func unionStyleEnumMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["subscript", "nonmutating", "infix", "unowned", "internal", "deinit", "indirect", "precedencegroup", "fileprivate", "func", "class", "open", "static", "final", "required", "lazy", "import", "var", "postfix", "prefix", "nonisolated", "mutating", "package", "optional", "actor", "convenience", "extension", "protocol", "private", "typealias", "public", "@", "init", "weak", "struct", "dynamic", "enum", "override", "let"])
}
func superclassMethodExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func typeIdentifier() {
	if token.type = .ALT {
		typeName()
		// OPT
	} else if token.type = .ALT {
		typeName()
		// OPT
	}
	expect(["_", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier", "plainIdentifier"])
}
func structMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["subscript", "nonmutating", "infix", "unowned", "internal", "deinit", "indirect", "precedencegroup", "fileprivate", "func", "class", "open", "static", "final", "required", "lazy", "import", "var", "postfix", "prefix", "nonisolated", "mutating", "package", "optional", "actor", "convenience", "extension", "protocol", "private", "typealias", "public", "@", "init", "weak", "struct", "dynamic", "enum", "override", "let"])
}
func extensionMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["subscript", "nonmutating", "infix", "unowned", "internal", "deinit", "indirect", "precedencegroup", "fileprivate", "func", "class", "open", "static", "final", "required", "lazy", "import", "var", "postfix", "prefix", "nonisolated", "mutating", "package", "optional", "actor", "convenience", "extension", "protocol", "private", "typealias", "public", "@", "init", "weak", "struct", "dynamic", "enum", "override", "let"])
}
func rawValueStyleEnumMembers() {
	if token.type = .ALT {
		rawValueStyleEnumMember()
		// OPT
	}
	expect(["fileprivate", "func", "private", "#sourceLocation", "convenience", "weak", "infix", "package", "typealias", "open", "class", "var", "import", "mutating", "@", "subscript", "indirect", "case", "internal", "protocol", "enum", "extension", "precedencegroup", "init", "optional", "let", "#error", "#warning", "struct", "nonmutating", "final", "unowned", "required", "static", "actor", "lazy", "postfix", "nonisolated", "dynamic", "#if", "override", "deinit", "public", "prefix"])
}
func typeCastingPattern() {
	if token.type = .ALT {
		isPattern()
		// END
	} else if token.type = .ALT {
		isPattern()
		// END
	}
	expect(["is"])
}
func macroDefinition() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func diagnosticStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#warning"])
}
func switchExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["switch"])
}
func conditionList() {
	if token.type = .ALT {
		condition()
		// END
	} else if token.type = .ALT {
		condition()
		// END
	}
	expect(["_", "&", "binaryLiteral", "#keyPath", "await", "if", "implicitParameterName", "let", "dotOperator", "(", "[", "escapedIdentifier", "plainIdentifier", "case", "false", "var", "#available", "#fileLiteral", "decimalFloatingPointLiteral", "hexadecimalLiteral", "decimalNumber", "try", "#selector", "switch", "#colorLiteral", "\\\\", "plainRegularExpressionLiteral", "nil", "self", "super", "octalLiteral", "#unavailable", ".", "{", "propertyWrapperProjection", "true", "stringLiteral", "macroIdentifier", "#imageLiteral", "plainOperator", "extendedRegularExpressionLiteral", "hexadecimalFloatingPointLiteral"])
}
func externalParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func decimalDigits() {
	if token.type = .ALT {
		next()
	}
	expect(["decimalNumber"])
}
func attributeArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func conditionalCompilationBlock() {
	if token.type = .ALT {
		ifDirectiveClause()
		// OPT
	}
	expect(["#if"])
}
func rawValueStyleEnum() {
	if token.type = .ALT {
		next()
	}
	expect(["enum"])
}
func macroFunctionSignatureResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func requirement() {
	if token.type = .ALT {
		conformanceRequirement()
		// END
	} else if token.type = .ALT {
		conformanceRequirement()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func protocolDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["open", "@", "protocol", "private", "public", "internal", "package", "fileprivate"])
}
func expression() {
	if token.type = .ALT {
		// OPT
	}
	expect(["_", "hexadecimalFloatingPointLiteral", "[", "#selector", "plainOperator", "decimalNumber", "implicitParameterName", "nil", "await", "try", "extendedRegularExpressionLiteral", "false", "hexadecimalLiteral", "decimalFloatingPointLiteral", "#imageLiteral", "octalLiteral", "#keyPath", "dotOperator", "\\\\", "plainIdentifier", "binaryLiteral", "#colorLiteral", "super", "stringLiteral", "switch", "propertyWrapperProjection", "&", "escapedIdentifier", ".", "macroIdentifier", "if", "{", "self", "true", "(", "plainRegularExpressionLiteral", "#fileLiteral"])
}
func structName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func selfMethodExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func mutationModifier() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["mutating"])
}
func functionHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "prefix", "open", "optional", "fileprivate", "class", "unowned", "convenience", "nonisolated", "public", "package", "override", "lazy", "func", "final", "dynamic", "private", "infix", "weak", "internal", "required", "postfix", "nonmutating", "mutating", "static"])
}
func balancedToken() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func genericParameter() {
	if token.type = .ALT {
		typeName()
		// END
	} else if token.type = .ALT {
		typeName()
		// END
	} else if token.type = .ALT {
		typeName()
		// END
	}
	expect(["_", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier", "plainIdentifier"])
}
func ifDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
}
func typeCastingOperator() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["is"])
}
func typeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func operatorDeclaration() {
	if token.type = .ALT {
		prefixOperatorDeclaration()
		// END
	} else if token.type = .ALT {
		prefixOperatorDeclaration()
		// END
	} else if token.type = .ALT {
		prefixOperatorDeclaration()
		// END
	}
	expect(["prefix"])
}
func protocolCompositionType() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "_"])
}
func arrayLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func initializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["prefix", "package", "unowned", "optional", "internal", "lazy", "static", "convenience", "@", "public", "required", "class", "fileprivate", "private", "nonisolated", "override", "weak", "nonmutating", "final", "postfix", "dynamic", "mutating", "infix", "init", "open"])
}
func endifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#endif"])
}
func rawValueStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "case"])
}
func rawValueAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func macroDeclaration() {
	if token.type = .ALT {
		macroHead()
		identifier()
		// OPT
	}
	expect(["private", "prefix", "required", "class", "nonisolated", "package", "nonmutating", "public", "lazy", "static", "postfix", "dynamic", "override", "weak", "mutating", "macro", "infix", "internal", "fileprivate", "convenience", "optional", "unowned", "final", "open", "@"])
}
func genericParameterList() {
	if token.type = .ALT {
		genericParameter()
		// END
	} else if token.type = .ALT {
		genericParameter()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func elseClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
}
func actorMembers() {
	if token.type = .ALT {
		actorMember()
		// OPT
	}
	expect(["dynamic", "private", "convenience", "protocol", "internal", "indirect", "fileprivate", "class", "func", "typealias", "mutating", "open", "subscript", "var", "#warning", "#if", "enum", "lazy", "nonisolated", "weak", "override", "#sourceLocation", "@", "nonmutating", "public", "unowned", "prefix", "required", "extension", "postfix", "actor", "struct", "optional", "precedencegroup", "package", "infix", "deinit", "let", "final", "import", "#error", "init", "static"])
}
func elseifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#elseif"])
}
func captureList() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func unionStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["implicitParameterName", "plainIdentifier", "escapedIdentifier", "_", "propertyWrapperProjection"])
}
func unionStyleEnum() {
	if token.type = .ALT {
		// OPT
	}
	expect(["indirect", "enum"])
}
func dictionaryLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["["])
}
func type() {
	if token.type = .ALT {
		functionType()
		// END
	} else if token.type = .ALT {
		functionType()
		// END
	} else if token.type = .ALT {
		functionType()
		// END
	} else if token.type = .ALT {
		functionType()
		// END
	} else if token.type = .ALT {
		functionType()
		// END
	} else if token.type = .ALT {
		functionType()
		// END
	} else if token.type = .ALT {
		functionType()
		// END
	} else if token.type = .ALT {
		functionType()
		// END
	} else if token.type = .ALT {
		functionType()
		// END
	} else if token.type = .ALT {
		functionType()
		// END
	} else if token.type = .ALT {
		functionType()
		// END
	} else if token.type = .ALT {
		functionType()
		// END
	} else if token.type = .ALT {
		functionType()
		// END
	}
	expect(["(", "@"])
}
func protocolInitializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["prefix", "package", "unowned", "optional", "internal", "lazy", "static", "convenience", "@", "public", "required", "class", "fileprivate", "private", "nonisolated", "override", "weak", "nonmutating", "final", "postfix", "dynamic", "mutating", "infix", "init", "open"])
}
func returnStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["return"])
}
func swiftVersionContinuation() {
	if token.type = .ALT {
		next()
	}
	expect(["."])
}
func getterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "nonmutating", "mutating", "get"])
}
func deinitializerDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "deinit"])
}
func initializerBody() {
	if token.type = .ALT {
		codeBlock()
		// END
	}
	expect(["{"])
}
func keyPathStringExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["#keyPath"])
}
func actorIsolationModifier() {
	if token.type = .ALT {
		next()
	}
	expect(["nonisolated"])
}
func decimalLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["decimalNumber"])
}
func conditionalOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["?"])
}
func selfExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func functionBody() {
	if token.type = .ALT {
		codeBlock()
		// END
	}
	expect(["{"])
}
func attribute() {
	if token.type = .ALT {
		next()
	}
	expect(["@"])
}
func whileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["while"])
}
func enumCasePattern() {
	if token.type = .ALT {
		// OPT
	}
	expect([".", "escapedIdentifier", "_", "implicitParameterName", "propertyWrapperProjection", "plainIdentifier"])
}
func keyPathComponent() {
	if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func importPath() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func forInStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["for"])
}
func arrayLiteralItem() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["self", "await", "nil", "stringLiteral", "propertyWrapperProjection", "try", "#imageLiteral", "true", "\\\\", "_", "(", "{", "escapedIdentifier", "#fileLiteral", "plainOperator", "plainIdentifier", "decimalFloatingPointLiteral", "&", "binaryLiteral", "switch", "super", "[", "dotOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "plainRegularExpressionLiteral", "#selector", "macroIdentifier", "false", "octalLiteral", "#keyPath", "if", "implicitParameterName", "#colorLiteral", ".", "decimalNumber", "hexadecimalLiteral"])
}
func variableDeclaration() {
	if token.type = .ALT {
		variableDeclarationHead()
		patternInitializerList()
		// END
	} else if token.type = .ALT {
		variableDeclarationHead()
		patternInitializerList()
		// END
	} else if token.type = .ALT {
		variableDeclarationHead()
		patternInitializerList()
		// END
	} else if token.type = .ALT {
		variableDeclarationHead()
		patternInitializerList()
		// END
	} else if token.type = .ALT {
		variableDeclarationHead()
		patternInitializerList()
		// END
	} else if token.type = .ALT {
		variableDeclarationHead()
		patternInitializerList()
		// END
	}
	expect(["package", "private", "fileprivate", "mutating", "@", "unowned", "lazy", "final", "convenience", "required", "var", "nonisolated", "class", "optional", "postfix", "override", "infix", "static", "dynamic", "public", "prefix", "weak", "internal", "open", "nonmutating"])
}
func optionalPattern() {
	if token.type = .ALT {
		identifierPattern()
		next()
	}
	expect(["_", "escapedIdentifier", "implicitParameterName", "plainIdentifier", "propertyWrapperProjection"])
}
func statementLabel() {
	if token.type = .ALT {
		labelName()
		next()
	}
	expect(["plainIdentifier", "escapedIdentifier", "_", "implicitParameterName", "propertyWrapperProjection"])
}
func functionResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func primaryExpression() {
	if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func booleanLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["true"])
}
func superclassInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func captureListItem() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["weak", "plainIdentifier", "unowned", "implicitParameterName", "unowned(unsafe)", "propertyWrapperProjection", "escapedIdentifier", "unowned(safe)", "_"])
}
func setterName() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func declarationModifier() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["class"])
}
func actorBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func catchPattern() {
	if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["extendedRegularExpressionLiteral", "let", "false", "#keyPath", "stringLiteral", "binaryLiteral", "implicitParameterName", "dotOperator", "hexadecimalLiteral", ".", "var", "try", "\\\\", "_", "true", "#colorLiteral", "(", "hexadecimalFloatingPointLiteral", "nil", "is", "super", "#fileLiteral", "escapedIdentifier", "plainOperator", "plainRegularExpressionLiteral", "{", "switch", "#imageLiteral", "propertyWrapperProjection", "macroIdentifier", "decimalFloatingPointLiteral", "octalLiteral", "decimalNumber", "[", "plainIdentifier", "&", "self", "#selector", "if", "await"])
}
func anyType() {
	if token.type = .ALT {
		next()
	}
	expect(["Any"])
}
func parameterModifier() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["inout"])
}
func parenthesizedExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func platformCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["os"])
}
func structDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["struct", "open", "internal", "@", "public", "fileprivate", "private", "package"])
}
func optionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["Self", "plainIdentifier", "implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "[", "(", "@", "_", "some", "Any"])
}
func classMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["subscript", "nonmutating", "infix", "unowned", "internal", "deinit", "indirect", "precedencegroup", "fileprivate", "func", "class", "open", "static", "final", "required", "lazy", "import", "var", "postfix", "prefix", "nonisolated", "mutating", "package", "optional", "actor", "convenience", "extension", "protocol", "private", "typealias", "public", "@", "init", "weak", "struct", "dynamic", "enum", "override", "let"])
}
func actorName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func structBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func tupleElement() {
	if token.type = .ALT {
		expression()
		// END
	} else if token.type = .ALT {
		expression()
		// END
	}
	expect(["self", "await", "nil", "stringLiteral", "propertyWrapperProjection", "try", "#imageLiteral", "true", "\\\\", "_", "(", "{", "escapedIdentifier", "#fileLiteral", "plainOperator", "plainIdentifier", "decimalFloatingPointLiteral", "&", "binaryLiteral", "switch", "super", "[", "dotOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "plainRegularExpressionLiteral", "#selector", "macroIdentifier", "false", "octalLiteral", "#keyPath", "if", "implicitParameterName", "#colorLiteral", ".", "decimalNumber", "hexadecimalLiteral"])
}
func keyPathPostfixes() {
	if token.type = .ALT {
		keyPathPostfix()
		// OPT
	}
	expect(["!", "?", "self", "["])
}
func subscriptResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func tupleType() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func optionalBindingCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["let"])
}
func enumName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func protocolMemberDeclaration() {
	if token.type = .ALT {
		protocolPropertyDeclaration()
		// END
	} else if token.type = .ALT {
		protocolPropertyDeclaration()
		// END
	} else if token.type = .ALT {
		protocolPropertyDeclaration()
		// END
	} else if token.type = .ALT {
		protocolPropertyDeclaration()
		// END
	} else if token.type = .ALT {
		protocolPropertyDeclaration()
		// END
	} else if token.type = .ALT {
		protocolPropertyDeclaration()
		// END
	}
	expect(["class", "var", "nonmutating", "final", "internal", "public", "lazy", "unowned", "required", "open", "nonisolated", "package", "prefix", "optional", "private", "convenience", "fileprivate", "static", "override", "weak", "infix", "mutating", "@", "dynamic", "postfix"])
}
func macroExpansionExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["macroIdentifier"])
}
func statement() {
	if token.type = .ALT {
		expression()
		// OPT
	} else if token.type = .ALT {
		expression()
		// OPT
	} else if token.type = .ALT {
		expression()
		// OPT
	} else if token.type = .ALT {
		expression()
		// OPT
	} else if token.type = .ALT {
		expression()
		// OPT
	} else if token.type = .ALT {
		expression()
		// OPT
	} else if token.type = .ALT {
		expression()
		// OPT
	} else if token.type = .ALT {
		expression()
		// OPT
	} else if token.type = .ALT {
		expression()
		// OPT
	}
	expect(["self", "await", "nil", "stringLiteral", "propertyWrapperProjection", "try", "#imageLiteral", "true", "\\\\", "_", "(", "{", "escapedIdentifier", "#fileLiteral", "plainOperator", "plainIdentifier", "decimalFloatingPointLiteral", "&", "binaryLiteral", "switch", "super", "[", "dotOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "plainRegularExpressionLiteral", "#selector", "macroIdentifier", "false", "octalLiteral", "#keyPath", "if", "implicitParameterName", "#colorLiteral", ".", "decimalNumber", "hexadecimalLiteral"])
}
func closureSignature() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["plainIdentifier", "[", "propertyWrapperProjection", "escapedIdentifier", "(", "implicitParameterName", "_"])
}
func initializerHead() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["fileprivate", "convenience", "required", "optional", "unowned", "package", "final", "postfix", "public", "@", "init", "class", "prefix", "nonisolated", "nonmutating", "static", "private", "dynamic", "override", "infix", "internal", "lazy", "weak", "mutating", "open"])
}
func catchClauses() {
	if token.type = .ALT {
		catchClause()
		// OPT
	}
	expect(["catch"])
}
func valueBindingPattern() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["var"])
}
func rawValueStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["implicitParameterName", "plainIdentifier", "escapedIdentifier", "_", "propertyWrapperProjection"])
}
func ifExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
}
func importDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "import"])
}
func structMembers() {
	if token.type = .ALT {
		structMember()
		// OPT
	}
	expect(["deinit", "weak", "dynamic", "final", "unowned", "override", "public", "struct", "subscript", "func", "extension", "package", "class", "let", "required", "init", "convenience", "#sourceLocation", "enum", "prefix", "fileprivate", "typealias", "precedencegroup", "@", "nonmutating", "#if", "open", "internal", "postfix", "indirect", "protocol", "var", "#warning", "#error", "static", "lazy", "mutating", "optional", "infix", "import", "nonisolated", "actor", "private"])
}
func requirementList() {
	if token.type = .ALT {
		requirement()
		// END
	} else if token.type = .ALT {
		requirement()
		// END
	}
	expect(["propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier", "implicitParameterName"])
}
func switchCases() {
	if token.type = .ALT {
		switchCase()
		// OPT
	}
	expect(["case", "@", "default", "#if"])
}
func keyPathPostfix() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["?"])
}
func didSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["didSet", "@"])
}
func typealiasAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func elseDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#else"])
}
func switchCase() {
	if token.type = .ALT {
		caseLabel()
		statements()
		// END
	} else if token.type = .ALT {
		caseLabel()
		statements()
		// END
	} else if token.type = .ALT {
		caseLabel()
		statements()
		// END
	}
	expect(["case", "@"])
}
func postfixExpression() {
	if token.type = .ALT {
		primaryExpression()
		// END
	} else if token.type = .ALT {
		primaryExpression()
		// END
	} else if token.type = .ALT {
		primaryExpression()
		// END
	} else if token.type = .ALT {
		primaryExpression()
		// END
	} else if token.type = .ALT {
		primaryExpression()
		// END
	} else if token.type = .ALT {
		primaryExpression()
		// END
	} else if token.type = .ALT {
		primaryExpression()
		// END
	} else if token.type = .ALT {
		primaryExpression()
		// END
	} else if token.type = .ALT {
		primaryExpression()
		// END
	}
	expect(["#colorLiteral", "super", "nil", "switch", "#imageLiteral", ".", "decimalNumber", "implicitParameterName", "macroIdentifier", "plainRegularExpressionLiteral", "propertyWrapperProjection", "\\\\", "self", "stringLiteral", "false", "{", "binaryLiteral", "escapedIdentifier", "(", "hexadecimalLiteral", "#fileLiteral", "decimalFloatingPointLiteral", "#selector", "[", "_", "extendedRegularExpressionLiteral", "hexadecimalFloatingPointLiteral", "if", "#keyPath", "true", "plainIdentifier", "octalLiteral"])
}
func typealiasName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func functionSignature() {
	if token.type = .ALT {
		parameterClause()
		// OPT
	} else if token.type = .ALT {
		parameterClause()
		// OPT
	}
	expect(["("])
}
func parameterList() {
	if token.type = .ALT {
		parameter()
		// END
	} else if token.type = .ALT {
		parameter()
		// END
	}
	expect(["escapedIdentifier", "propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier"])
}
func protocolMethodDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["mutating", "unowned", "private", "func", "class", "weak", "internal", "static", "nonisolated", "required", "dynamic", "optional", "override", "public", "fileprivate", "lazy", "final", "convenience", "@", "nonmutating", "infix", "prefix", "open", "postfix", "package"])
}
func labelName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func protocolSubscriptDeclaration() {
	if token.type = .ALT {
		subscriptHead()
		subscriptResult()
		// OPT
	}
	expect(["class", "weak", "internal", "final", "@", "nonisolated", "lazy", "subscript", "postfix", "open", "package", "override", "convenience", "public", "unowned", "infix", "nonmutating", "private", "optional", "static", "fileprivate", "mutating", "required", "dynamic", "prefix"])
}
func extensionBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func fallthroughStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["fallthrough"])
}
func patternInitializerList() {
	if token.type = .ALT {
		patternInitializer()
		// END
	} else if token.type = .ALT {
		patternInitializer()
		// END
	}
	expect(["plainRegularExpressionLiteral", "let", "escapedIdentifier", "decimalNumber", "await", "extendedRegularExpressionLiteral", "is", "_", "false", "implicitParameterName", "octalLiteral", "if", "self", "(", "#fileLiteral", "dotOperator", "stringLiteral", "hexadecimalFloatingPointLiteral", "try", "\\\\", "macroIdentifier", "propertyWrapperProjection", "var", "&", "[", "hexadecimalLiteral", "decimalFloatingPointLiteral", "binaryLiteral", "#keyPath", "plainIdentifier", "plainOperator", "super", "nil", "{", "switch", ".", "true", "#selector", "#colorLiteral", "#imageLiteral"])
}
func declaration() {
	if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	} else if token.type = .ALT {
		importDeclaration()
		// END
	}
	expect(["import", "@"])
}
func parameterTypeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func enumDeclaration() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["indirect", "private", "@", "internal", "fileprivate", "package", "public", "enum", "open"])
}
func subscriptDeclaration() {
	if token.type = .ALT {
		subscriptHead()
		subscriptResult()
		// OPT
	} else if token.type = .ALT {
		subscriptHead()
		subscriptResult()
		// OPT
	} else if token.type = .ALT {
		subscriptHead()
		subscriptResult()
		// OPT
	}
	expect(["class", "weak", "internal", "final", "@", "nonisolated", "lazy", "subscript", "postfix", "open", "package", "override", "convenience", "public", "unowned", "infix", "nonmutating", "private", "optional", "static", "fileprivate", "mutating", "required", "dynamic", "prefix"])
}
func wildcardPattern() {
	if token.type = .ALT {
		next()
	}
	expect(["_"])
}
func parameterClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func closureParameterClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func identifierPattern() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func genericArgument() {
	if token.type = .ALT {
		type()
		// END
	}
	expect(["Self", "plainIdentifier", "implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "[", "(", "@", "_", "some", "Any"])
}
func caseLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "case"])
}
func interpolatedStringLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["stringLiteral"])
}
func accessLevelModifier() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["private"])
}
func identifier() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["_"])
}
func className() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func protocolMember() {
	if token.type = .ALT {
		protocolMemberDeclaration()
		// END
	} else if token.type = .ALT {
		protocolMemberDeclaration()
		// END
	}
	expect(["init", "prefix", "infix", "class", "nonisolated", "optional", "dynamic", "override", "internal", "package", "fileprivate", "var", "func", "unowned", "typealias", "static", "convenience", "mutating", "postfix", "@", "public", "nonmutating", "private", "subscript", "weak", "associatedtype", "open", "required", "lazy", "final"])
}
func breakStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["break"])
}
func staticStringLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["stringLiteral"])
}
func switchIfDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
}
func ifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#if"])
}
func tryOperator() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["try"])
}
func arrayLiteralItems() {
	if token.type = .ALT {
		arrayLiteralItem()
		// OPT
	} else if token.type = .ALT {
		arrayLiteralItem()
		// OPT
	}
	expect(["stringLiteral", "plainOperator", "decimalFloatingPointLiteral", "octalLiteral", "#colorLiteral", "#fileLiteral", "switch", ".", "binaryLiteral", "plainIdentifier", "hexadecimalLiteral", "plainRegularExpressionLiteral", "try", "implicitParameterName", "(", "false", "true", "macroIdentifier", "await", "dotOperator", "\\\\", "nil", "[", "&", "super", "#imageLiteral", "hexadecimalFloatingPointLiteral", "if", "propertyWrapperProjection", "self", "{", "_", "#keyPath", "decimalNumber", "extendedRegularExpressionLiteral", "#selector", "escapedIdentifier"])
}
func functionTypeArgument() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["inout", "plainIdentifier", "Any", "propertyWrapperProjection", "_", "some", "(", "escapedIdentifier", "[", "@", "Self", "implicitParameterName"])
}
func explicitMemberExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	} else if token.type = .ALT {
		postfixExpression()
		next()
	} else if token.type = .ALT {
		postfixExpression()
		next()
	} else if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["#keyPath", "hexadecimalLiteral", "switch", "macroIdentifier", "[", "_", "#colorLiteral", "octalLiteral", "#selector", "false", "escapedIdentifier", "nil", "self", "implicitParameterName", "\\\\", "decimalFloatingPointLiteral", "super", "propertyWrapperProjection", "stringLiteral", "hexadecimalFloatingPointLiteral", "if", "(", "plainRegularExpressionLiteral", "#imageLiteral", "{", "plainIdentifier", "#fileLiteral", "decimalNumber", "binaryLiteral", "extendedRegularExpressionLiteral", ".", "true"])
}
func importKind() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["typealias"])
}
func subscriptExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["#keyPath", "hexadecimalLiteral", "switch", "macroIdentifier", "[", "_", "#colorLiteral", "octalLiteral", "#selector", "false", "escapedIdentifier", "nil", "self", "implicitParameterName", "\\\\", "decimalFloatingPointLiteral", "super", "propertyWrapperProjection", "stringLiteral", "hexadecimalFloatingPointLiteral", "if", "(", "plainRegularExpressionLiteral", "#imageLiteral", "{", "plainIdentifier", "#fileLiteral", "decimalNumber", "binaryLiteral", "extendedRegularExpressionLiteral", ".", "true"])
}
func willSetDidSetBlock() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func enumCaseName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func keyPathComponents() {
	if token.type = .ALT {
		keyPathComponent()
		// END
	} else if token.type = .ALT {
		keyPathComponent()
		// END
	}
	expect(["propertyWrapperProjection", "[", "escapedIdentifier", "implicitParameterName", "plainIdentifier", "self", "_", "!", "?"])
}
func tupleExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func caseCondition() {
	if token.type = .ALT {
		next()
	}
	expect(["case"])
}
func literal() {
	if token.type = .ALT {
		numericLiteral()
		// END
	} else if token.type = .ALT {
		numericLiteral()
		// END
	} else if token.type = .ALT {
		numericLiteral()
		// END
	} else if token.type = .ALT {
		numericLiteral()
		// END
	} else if token.type = .ALT {
		numericLiteral()
		// END
	}
	expect(["decimalNumber", "octalLiteral", "hexadecimalLiteral", "binaryLiteral", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral"])
}
func functionDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["mutating", "unowned", "private", "func", "class", "weak", "internal", "static", "nonisolated", "required", "dynamic", "optional", "override", "public", "fileprivate", "lazy", "final", "convenience", "@", "nonmutating", "infix", "prefix", "open", "postfix", "package"])
}
func swiftVersion() {
	if token.type = .ALT {
		decimalDigits()
		// OPT
	}
	expect(["decimalNumber"])
}
func condition() {
	if token.type = .ALT {
		expression()
		// END
	} else if token.type = .ALT {
		expression()
		// END
	} else if token.type = .ALT {
		expression()
		// END
	} else if token.type = .ALT {
		expression()
		// END
	}
	expect(["self", "await", "nil", "stringLiteral", "propertyWrapperProjection", "try", "#imageLiteral", "true", "\\\\", "_", "(", "{", "escapedIdentifier", "#fileLiteral", "plainOperator", "plainIdentifier", "decimalFloatingPointLiteral", "&", "binaryLiteral", "switch", "super", "[", "dotOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "plainRegularExpressionLiteral", "#selector", "macroIdentifier", "false", "octalLiteral", "#keyPath", "if", "implicitParameterName", "#colorLiteral", ".", "decimalNumber", "hexadecimalLiteral"])
}
func precedenceGroupAssociativity() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["associativity"])
}
func precedenceGroupNames() {
	if token.type = .ALT {
		precedenceGroupName()
		// END
	} else if token.type = .ALT {
		precedenceGroupName()
		// END
	}
	expect(["propertyWrapperProjection", "_", "implicitParameterName", "plainIdentifier", "escapedIdentifier"])
}
func switchExpressionCase() {
	if token.type = .ALT {
		caseLabel()
		statement()
		// END
	} else if token.type = .ALT {
		caseLabel()
		statement()
		// END
	}
	expect(["case", "@"])
}
func variableName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func argumentNames() {
	if token.type = .ALT {
		argumentName()
		// OPT
	}
	expect(["implicitParameterName", "_", "plainIdentifier", "propertyWrapperProjection", "escapedIdentifier"])
}
func repeatWhileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["repeat"])
}
func functionTypeArgumentClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func macroHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["package", "private", "postfix", "dynamic", "class", "nonisolated", "weak", "nonmutating", "static", "@", "mutating", "required", "override", "public", "fileprivate", "lazy", "optional", "convenience", "macro", "internal", "open", "final", "prefix", "infix", "unowned"])
}
func postfixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["postfix"])
}
func labeledStatement() {
	if token.type = .ALT {
		statementLabel()
		loopStatement()
		// END
	} else if token.type = .ALT {
		statementLabel()
		loopStatement()
		// END
	} else if token.type = .ALT {
		statementLabel()
		loopStatement()
		// END
	} else if token.type = .ALT {
		statementLabel()
		loopStatement()
		// END
	}
	expect(["propertyWrapperProjection", "_", "escapedIdentifier", "implicitParameterName", "plainIdentifier"])
}
func lineNumber() {
	if token.type = .ALT {
		decimalDigits()
		// END
	}
	expect(["decimalNumber"])
}
func switchElseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
}
func trailingClosures() {
	if token.type = .ALT {
		closureExpression()
		// OPT
	}
	expect(["{"])
}
func catchClause() {
	if token.type = .ALT {
		next()
	}
	expect(["catch"])
}
func superclassSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func literalExpression() {
	if token.type = .ALT {
		literal()
		// END
	} else if token.type = .ALT {
		literal()
		// END
	} else if token.type = .ALT {
		literal()
		// END
	} else if token.type = .ALT {
		literal()
		// END
	}
	expect(["plainRegularExpressionLiteral", "stringLiteral", "nil", "hexadecimalFloatingPointLiteral", "false", "extendedRegularExpressionLiteral", "octalLiteral", "true", "decimalNumber", "hexadecimalLiteral", "binaryLiteral", "decimalFloatingPointLiteral"])
}
func selfType() {
	if token.type = .ALT {
		next()
	}
	expect(["Self"])
}
func constantDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["prefix", "lazy", "weak", "fileprivate", "mutating", "unowned", "nonisolated", "public", "final", "class", "optional", "required", "postfix", "package", "let", "private", "infix", "dynamic", "nonmutating", "internal", "override", "open", "static", "@", "convenience"])
}
func floatingPointLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["decimalFloatingPointLiteral"])
}
func topLevelDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["protocol", "@", "do", "prefix", "defer", "_", "nil", "plainOperator", "weak", "extendedRegularExpressionLiteral", "open", "decimalFloatingPointLiteral", "#colorLiteral", "init", "", "for", "required", "convenience", "true", "continue", "if", "break", "plainIdentifier", "#keyPath", "try", "private", "false", "&", "unowned", "binaryLiteral", "internal", "optional", "macroIdentifier", "let", "hexadecimalLiteral", "deinit", "func", "dynamic", "{", "dotOperator", "typealias", "mutating", "await", "plainRegularExpressionLiteral", "switch", "precedencegroup", "public", "throw", "#sourceLocation", "escapedIdentifier", "var", "subscript", "fileprivate", "indirect", "#warning", "enum", "#if", "hexadecimalFloatingPointLiteral", "nonisolated", "guard", "infix", "struct", "decimalNumber", "#imageLiteral", "lazy", "#error", "return", "postfix", "#fileLiteral", "octalLiteral", "actor", "super", ".", "repeat", "propertyWrapperProjection", "class", "implicitParameterName", "import", "#selector", "package", "while", "extension", "final", "nonmutating", "self", "static", "override", "stringLiteral", "[", "fallthrough", "\\\\", "("])
}
func metatypeType() {
	if token.type = .ALT {
		type()
		next()
	} else if token.type = .ALT {
		type()
		next()
	}
	expect(["Self", "plainIdentifier", "implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "[", "(", "@", "_", "some", "Any"])
}
func getterSetterKeywordBlock() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func identifierList() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func environment() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["simulator"])
}
func actorDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["private", "public", "@", "actor", "package", "open", "internal", "fileprivate"])
}
func branchStatement() {
	if token.type = .ALT {
		ifStatement()
		// END
	} else if token.type = .ALT {
		ifStatement()
		// END
	} else if token.type = .ALT {
		ifStatement()
		// END
	}
	expect(["if"])
}
func tupleElementList() {
	if token.type = .ALT {
		tupleElement()
		// END
	} else if token.type = .ALT {
		tupleElement()
		// END
	}
	expect(["\\\\", "#imageLiteral", "hexadecimalLiteral", "try", "decimalFloatingPointLiteral", "[", "macroIdentifier", "#fileLiteral", "escapedIdentifier", "binaryLiteral", "dotOperator", "switch", "octalLiteral", "plainIdentifier", "if", "plainRegularExpressionLiteral", "propertyWrapperProjection", "plainOperator", "{", ".", "(", "extendedRegularExpressionLiteral", "super", "hexadecimalFloatingPointLiteral", "await", "self", "_", "&", "nil", "false", "#colorLiteral", "implicitParameterName", "#selector", "stringLiteral", "#keyPath", "true", "decimalNumber"])
}
func operatingSystem() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["macOS"])
}
func precedenceGroupAttributes() {
	if token.type = .ALT {
		precedenceGroupAttribute()
		// OPT
	}
	expect(["assignment", "lowerThan", "associativity", "higherThan"])
}
func elementName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func codeBlock() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func tuplePatternElementList() {
	if token.type = .ALT {
		tuplePatternElement()
		// END
	} else if token.type = .ALT {
		tuplePatternElement()
		// END
	}
	expect(["nil", "await", "plainRegularExpressionLiteral", "hexadecimalLiteral", "octalLiteral", "&", "stringLiteral", "decimalFloatingPointLiteral", "implicitParameterName", "{", "plainOperator", "binaryLiteral", "super", "dotOperator", "extendedRegularExpressionLiteral", "#colorLiteral", "#fileLiteral", "try", "hexadecimalFloatingPointLiteral", "macroIdentifier", "let", "\\\\", "var", "(", "_", "false", "self", "switch", "plainIdentifier", "if", "#keyPath", "#imageLiteral", "[", "#selector", ".", "is", "decimalNumber", "true", "escapedIdentifier", "propertyWrapperProjection"])
}
func tupleTypeElementList() {
	if token.type = .ALT {
		tupleTypeElement()
		// END
	} else if token.type = .ALT {
		tupleTypeElement()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "some", "@", "Any", "Self", "(", "plainIdentifier", "_", "["])
}
func genericArgumentList() {
	if token.type = .ALT {
		genericArgument()
		// END
	} else if token.type = .ALT {
		genericArgument()
		// END
	}
	expect(["(", "some", "[", "Any", "plainIdentifier", "implicitParameterName", "@", "_", "Self", "propertyWrapperProjection", "escapedIdentifier"])
}
func selectorExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#selector"])
}
func infixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["dotOperator", "plainOperator"])
}
func conditionalSwitchCase() {
	if token.type = .ALT {
		switchIfDirectiveClause()
		// OPT
	}
	expect(["#if"])
}
func variableDeclarationHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["var", "optional", "unowned", "nonisolated", "@", "class", "public", "postfix", "infix", "lazy", "required", "open", "static", "weak", "override", "fileprivate", "private", "final", "mutating", "dynamic", "package", "nonmutating", "prefix", "internal", "convenience"])
}
func rawValueStyleEnumMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["subscript", "nonmutating", "infix", "unowned", "internal", "deinit", "indirect", "precedencegroup", "fileprivate", "func", "class", "open", "static", "final", "required", "lazy", "import", "var", "postfix", "prefix", "nonisolated", "mutating", "package", "optional", "actor", "convenience", "extension", "protocol", "private", "typealias", "public", "@", "init", "weak", "struct", "dynamic", "enum", "override", "let"])
}
func catchPatternList() {
	if token.type = .ALT {
		catchPattern()
		// END
	} else if token.type = .ALT {
		catchPattern()
		// END
	}
	expect(["try", "macroIdentifier", "decimalFloatingPointLiteral", "await", "escapedIdentifier", "plainIdentifier", "true", "binaryLiteral", "{", "let", "var", "dotOperator", "is", "extendedRegularExpressionLiteral", "false", "switch", "[", "hexadecimalLiteral", "decimalNumber", "#imageLiteral", "propertyWrapperProjection", "implicitParameterName", "self", "plainRegularExpressionLiteral", "hexadecimalFloatingPointLiteral", "#fileLiteral", "super", "#keyPath", "plainOperator", "nil", "\\\\", "&", "#selector", "stringLiteral", "if", "octalLiteral", ".", "_", "(", "#colorLiteral"])
}
func classDeclaration() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["package", "internal", "public", "final", "fileprivate", "class", "open", "@", "private"])
}
func lineControlStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#sourceLocation"])
}
func macroSignature() {
	if token.type = .ALT {
		parameterClause()
		// OPT
	}
	expect(["("])
}
func parameter() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["propertyWrapperProjection", "escapedIdentifier", "implicitParameterName", "plainIdentifier", "_"])
}
func precedenceGroupAttribute() {
	if token.type = .ALT {
		precedenceGroupRelation()
		// END
	} else if token.type = .ALT {
		precedenceGroupRelation()
		// END
	} else if token.type = .ALT {
		precedenceGroupRelation()
		// END
	}
	expect(["higherThan", "lowerThan"])
}
func tuplePattern() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func pattern() {
	if token.type = .ALT {
		wildcardPattern()
		// OPT
	} else if token.type = .ALT {
		wildcardPattern()
		// OPT
	} else if token.type = .ALT {
		wildcardPattern()
		// OPT
	} else if token.type = .ALT {
		wildcardPattern()
		// OPT
	} else if token.type = .ALT {
		wildcardPattern()
		// OPT
	} else if token.type = .ALT {
		wildcardPattern()
		// OPT
	} else if token.type = .ALT {
		wildcardPattern()
		// OPT
	} else if token.type = .ALT {
		wildcardPattern()
		// OPT
	}
	expect(["_"])
}
func patternInitializer() {
	if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["extendedRegularExpressionLiteral", "let", "false", "#keyPath", "stringLiteral", "binaryLiteral", "implicitParameterName", "dotOperator", "hexadecimalLiteral", ".", "var", "try", "\\\\", "_", "true", "#colorLiteral", "(", "hexadecimalFloatingPointLiteral", "nil", "is", "super", "#fileLiteral", "escapedIdentifier", "plainOperator", "plainRegularExpressionLiteral", "{", "switch", "#imageLiteral", "propertyWrapperProjection", "macroIdentifier", "decimalFloatingPointLiteral", "octalLiteral", "decimalNumber", "[", "plainIdentifier", "&", "self", "#selector", "if", "await"])
}
func doStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["do"])
}
func statements() {
	if token.type = .ALT {
		statement()
		// OPT
	}
	expect(["#fileLiteral", "infix", "actor", "binaryLiteral", "return", "try", "weak", "_", "decimalNumber", "postfix", "escapedIdentifier", "continue", "#warning", "#if", "{", "if", "switch", "break", "defer", "#selector", "#keyPath", "dotOperator", "hexadecimalFloatingPointLiteral", "open", "[", "#colorLiteral", ".", "octalLiteral", "nonisolated", "extension", "fileprivate", "func", "extendedRegularExpressionLiteral", "init", "mutating", "self", "&", "prefix", "\\\\", "while", "protocol", "enum", "optional", "deinit", "dynamic", "override", "convenience", "macroIdentifier", "internal", "#sourceLocation", "nil", "guard", "throw", "precedencegroup", "plainIdentifier", "indirect", "package", "propertyWrapperProjection", "for", "public", "static", "import", "fallthrough", "#error", "(", "super", "false", "required", "implicitParameterName", "class", "subscript", "#imageLiteral", "decimalFloatingPointLiteral", "var", "do", "true", "nonmutating", "final", "plainOperator", "typealias", "private", "@", "struct", "plainRegularExpressionLiteral", "await", "stringLiteral", "let", "hexadecimalLiteral", "lazy", "unowned", "repeat"])
}
func availabilityArgument() {
	if token.type = .ALT {
		platformName()
		platformVersion()
		// END
	} else if token.type = .ALT {
		platformName()
		platformVersion()
		// END
	}
	expect(["watchOS", "macCatalyst", "watchOSApplicationExtension", "macCatalystApplicationExtension", "iOS", "macOS", "macOSApplicationExtension", "visionOSApplicationExtension", "tvOS", "iOSApplicationExtension", "tvOSApplicationExtension", "visionOS"])
}
func tupleTypeElement() {
	if token.type = .ALT {
		elementName()
		typeAnnotation()
		// END
	} else if token.type = .ALT {
		elementName()
		typeAnnotation()
		// END
	}
	expect(["_", "plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "implicitParameterName"])
}
func closureParameterList() {
	if token.type = .ALT {
		closureParameter()
		// END
	} else if token.type = .ALT {
		closureParameter()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "plainIdentifier", "_", "escapedIdentifier"])
}
func getterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["mutating", "get", "@", "nonmutating"])
}
func captureListItems() {
	if token.type = .ALT {
		captureListItem()
		// END
	} else if token.type = .ALT {
		captureListItem()
		// END
	}
	expect(["weak", "implicitParameterName", "propertyWrapperProjection", "unowned(safe)", "_", "self", "plainIdentifier", "escapedIdentifier", "unowned", "unowned(unsafe)"])
}
func initializer() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func keyPathExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["\\\\"])
}
func argumentName() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func dictionaryLiteralItems() {
	if token.type = .ALT {
		dictionaryLiteralItem()
		// OPT
	} else if token.type = .ALT {
		dictionaryLiteralItem()
		// OPT
	}
	expect(["plainOperator", "#fileLiteral", "hexadecimalLiteral", "try", "true", "propertyWrapperProjection", "super", "_", "plainIdentifier", "&", "false", "self", "#colorLiteral", "binaryLiteral", "if", "implicitParameterName", "extendedRegularExpressionLiteral", "macroIdentifier", "switch", "dotOperator", "plainRegularExpressionLiteral", "\\\\", ".", "nil", "stringLiteral", "#keyPath", "#selector", "escapedIdentifier", "(", "await", "#imageLiteral", "decimalFloatingPointLiteral", "hexadecimalFloatingPointLiteral", "{", "octalLiteral", "decimalNumber", "["])
}
func attributeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func loopStatement() {
	if token.type = .ALT {
		forInStatement()
		// END
	} else if token.type = .ALT {
		forInStatement()
		// END
	} else if token.type = .ALT {
		forInStatement()
		// END
	}
	expect(["for"])
}
func wildcardExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["_"])
}
func initializerExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	} else if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["#keyPath", "hexadecimalLiteral", "switch", "macroIdentifier", "[", "_", "#colorLiteral", "octalLiteral", "#selector", "false", "escapedIdentifier", "nil", "self", "implicitParameterName", "\\\\", "decimalFloatingPointLiteral", "super", "propertyWrapperProjection", "stringLiteral", "hexadecimalFloatingPointLiteral", "if", "(", "plainRegularExpressionLiteral", "#imageLiteral", "{", "plainIdentifier", "#fileLiteral", "decimalNumber", "binaryLiteral", "extendedRegularExpressionLiteral", ".", "true"])
}
func infixExpressions() {
	if token.type = .ALT {
		infixExpression()
		// OPT
	}
	expect(["=", "?", "as", "is", "plainOperator", "dotOperator"])
}
func postfixSelfExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["#keyPath", "hexadecimalLiteral", "switch", "macroIdentifier", "[", "_", "#colorLiteral", "octalLiteral", "#selector", "false", "escapedIdentifier", "nil", "self", "implicitParameterName", "\\\\", "decimalFloatingPointLiteral", "super", "propertyWrapperProjection", "stringLiteral", "hexadecimalFloatingPointLiteral", "if", "(", "plainRegularExpressionLiteral", "#imageLiteral", "{", "plainIdentifier", "#fileLiteral", "decimalNumber", "binaryLiteral", "extendedRegularExpressionLiteral", ".", "true"])
}
func classMembers() {
	if token.type = .ALT {
		classMember()
		// OPT
	}
	expect(["protocol", "init", "func", "open", "prefix", "let", "optional", "enum", "postfix", "private", "infix", "static", "lazy", "mutating", "weak", "#if", "var", "indirect", "fileprivate", "nonmutating", "package", "unowned", "nonisolated", "import", "#error", "extension", "dynamic", "subscript", "required", "internal", "convenience", "override", "deinit", "class", "@", "#warning", "typealias", "struct", "#sourceLocation", "public", "final", "actor", "precedencegroup"])
}
func extensionDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["internal", "extension", "public", "@", "package", "private", "open", "fileprivate"])
}
func switchElseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
}
func numericLiteral() {
	if token.type = .ALT {
		integerLiteral()
		// END
	} else if token.type = .ALT {
		integerLiteral()
		// END
	}
	expect(["binaryLiteral", "octalLiteral", "decimalNumber", "hexadecimalLiteral"])
}
func throwsClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["throws"])
}
func switchStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["switch"])
}
func elseifDirectiveClause() {
	if token.type = .ALT {
		elseifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#elseif"])
}
func actorMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["subscript", "nonmutating", "infix", "unowned", "internal", "deinit", "indirect", "precedencegroup", "fileprivate", "func", "class", "open", "static", "final", "required", "lazy", "import", "var", "postfix", "prefix", "nonisolated", "mutating", "package", "optional", "actor", "convenience", "extension", "protocol", "private", "typealias", "public", "@", "init", "weak", "struct", "dynamic", "enum", "override", "let"])
}
func protocolAssociatedTypeDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["internal", "associatedtype", "package", "public", "private", "open", "fileprivate", "@"])
}
func functionName() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func extensionMembers() {
	if token.type = .ALT {
		extensionMember()
		// OPT
	}
	expect(["var", "infix", "postfix", "let", "static", "dynamic", "import", "optional", "init", "actor", "fileprivate", "package", "internal", "public", "final", "weak", "override", "prefix", "deinit", "nonmutating", "indirect", "@", "class", "required", "typealias", "protocol", "private", "lazy", "enum", "#warning", "precedencegroup", "extension", "unowned", "subscript", "#sourceLocation", "convenience", "#if", "func", "#error", "struct", "open", "nonisolated", "mutating"])
}
func inOutExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["&"])
}
func dictionaryLiteralItem() {
	if token.type = .ALT {
		expression()
		next()
	}
	expect(["self", "await", "nil", "stringLiteral", "propertyWrapperProjection", "try", "#imageLiteral", "true", "\\\\", "_", "(", "{", "escapedIdentifier", "#fileLiteral", "plainOperator", "plainIdentifier", "decimalFloatingPointLiteral", "&", "binaryLiteral", "switch", "super", "[", "dotOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "plainRegularExpressionLiteral", "#selector", "macroIdentifier", "false", "octalLiteral", "#keyPath", "if", "implicitParameterName", "#colorLiteral", ".", "decimalNumber", "hexadecimalLiteral"])
}
func precedenceGroupName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func asPattern() {
	if token.type = .ALT {
		pattern()
		next()
	}
	expect(["extendedRegularExpressionLiteral", "let", "false", "#keyPath", "stringLiteral", "binaryLiteral", "implicitParameterName", "dotOperator", "hexadecimalLiteral", ".", "var", "try", "\\\\", "_", "true", "#colorLiteral", "(", "hexadecimalFloatingPointLiteral", "nil", "is", "super", "#fileLiteral", "escapedIdentifier", "plainOperator", "plainRegularExpressionLiteral", "{", "switch", "#imageLiteral", "propertyWrapperProjection", "macroIdentifier", "decimalFloatingPointLiteral", "octalLiteral", "decimalNumber", "[", "plainIdentifier", "&", "self", "#selector", "if", "await"])
}
func superclassExpression() {
	if token.type = .ALT {
		superclassMethodExpression()
		// END
	} else if token.type = .ALT {
		superclassMethodExpression()
		// END
	} else if token.type = .ALT {
		superclassMethodExpression()
		// END
	}
	expect(["super"])
}
func keywordMinusBrackets() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["actor"])
}
func classBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func willSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "willSet"])
}
func unionStyleEnumMembers() {
	if token.type = .ALT {
		unionStyleEnumMember()
		// OPT
	}
	expect(["subscript", "postfix", "lazy", "public", "nonisolated", "nonmutating", "actor", "typealias", "optional", "struct", "fileprivate", "override", "init", "mutating", "weak", "precedencegroup", "#if", "indirect", "case", "final", "infix", "@", "unowned", "extension", "var", "required", "protocol", "enum", "class", "deinit", "prefix", "package", "#error", "let", "convenience", "internal", "#warning", "open", "import", "#sourceLocation", "func", "dynamic", "private", "static"])
}
func playgroundLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#colorLiteral"])
}
func labeledTrailingClosure() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier", "escapedIdentifier"])
}
func platformVersion() {
	if token.type = .ALT {
		decimalDigits()
		// END
	} else if token.type = .ALT {
		decimalDigits()
		// END
	} else if token.type = .ALT {
		decimalDigits()
		// END
	}
	expect(["decimalNumber"])
}
func optionalChainingExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["#keyPath", "hexadecimalLiteral", "switch", "macroIdentifier", "[", "_", "#colorLiteral", "octalLiteral", "#selector", "false", "escapedIdentifier", "nil", "self", "implicitParameterName", "\\\\", "decimalFloatingPointLiteral", "super", "propertyWrapperProjection", "stringLiteral", "hexadecimalFloatingPointLiteral", "if", "(", "plainRegularExpressionLiteral", "#imageLiteral", "{", "plainIdentifier", "#fileLiteral", "decimalNumber", "binaryLiteral", "extendedRegularExpressionLiteral", ".", "true"])
}
func infixOperatorGroup() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func genericWhereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func defaultLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "default"])
}
func ifStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
}
func selfInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func tuplePatternElement() {
	if token.type = .ALT {
		pattern()
		// END
	} else if token.type = .ALT {
		pattern()
		// END
	}
	expect(["extendedRegularExpressionLiteral", "let", "false", "#keyPath", "stringLiteral", "binaryLiteral", "implicitParameterName", "dotOperator", "hexadecimalLiteral", ".", "var", "try", "\\\\", "_", "true", "#colorLiteral", "(", "hexadecimalFloatingPointLiteral", "nil", "is", "super", "#fileLiteral", "escapedIdentifier", "plainOperator", "plainRegularExpressionLiteral", "{", "switch", "#imageLiteral", "propertyWrapperProjection", "macroIdentifier", "decimalFloatingPointLiteral", "octalLiteral", "decimalNumber", "[", "plainIdentifier", "&", "self", "#selector", "if", "await"])
}
func conformanceRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	} else if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "_"])
}
func unionStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "indirect", "case"])
}
