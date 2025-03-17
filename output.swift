//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"dotOperator":	("/\\.[\\.\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]+/",	/\.[\.\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]+/,	false,	false),
	"multilineComment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"macroIdentifier":	("/#\\p{XID_Start}\\p{XID_Continue}*/",	/#\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"hexadecimalFloatingPointLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/,	false,	false),
	"plainIdentifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"comment":	("/\\/\\/.*\\r?\\n?/",	/\/\/.*\r?\n?/,	false,	true),
	"stringLiteral":	("/#*\"(?:\\\\#*\\([^)]*\\)|\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]{1,8}\\}|[^\"\\\\\\n\\r])*\"#*|#*\"\"\"(?:\\\\#*\\([^)]*\\)|\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]{1,8}\\}|\\\\#*\\s*\\n|[^\\\\])*\"\"\"#*/",	/#*"(?:\\#*\([^)]*\)|\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]{1,8}\}|[^"\\\n\r])*"#*|#*"""(?:\\#*\([^)]*\)|\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]{1,8}\}|\\#*\s*\n|[^\\])*"""#*/,	false,	false),
	"propertyWrapperProjection":	("/\\$\\p{XID_Continue}+/",	/\$\p{XID_Continue}+/,	false,	false),
	"octalLiteral":	("/-?0o[0-7][0-7_]*/",	/-?0o[0-7][0-7_]*/,	false,	false),
	"binaryLiteral":	("/-?0b[0-1][0-1_]*/",	/-?0b[0-1][0-1_]*/,	false,	false),
	"hexadecimalLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*/,	false,	false),
	"plainOperator":	("/[\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}][\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]*/",	/[\/=+\-*%!&|^~?<>\p{Sm}\p{So}][\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]*/,	false,	false),
	"extendedRegularExpressionLiteral":	("/#+\\/(?:[^\\/\\\\]|\\\\.)+\\/#+/",	/#+\/(?:[^\/\\]|\\.)+\/#+/,	false,	false),
	"escapedIdentifier":	("/`\\p{XID_Start}\\p{XID_Continue}*`/",	/`\p{XID_Start}\p{XID_Continue}*`/,	false,	false),
	"decimalNumber":	("/-?[0-9][0-9_]*/",	/-?[0-9][0-9_]*/,	false,	false),
	"decimalFloatingPointLiteral":	("/-?[0-9][0-9_]*(?:\\.[0-9][0-9_]*)(?:[eE][+-]?[0-9][0-9_]*)?/",	/-?[0-9][0-9_]*(?:\.[0-9][0-9_]*)(?:[eE][+-]?[0-9][0-9_]*)?/,	false,	false),
	"plainRegularExpressionLiteral":	("/\\/[^\\s](?:(?:[^\\/\\\\\\s]|\\\\.)*[^\\s])?\\//",	/\/[^\s](?:(?:[^\/\\\s]|\\.)*[^\s])?\//,	false,	false),
	"implicitParameterName":	("/\\$[0-9]+/",	/\$[0-9]+/,	false,	false),
	"#warning":	("#warning",	Regex { "#warning" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"prefix":	("prefix",	Regex { "prefix" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"right":	("right",	Regex { "right" },	true,	false),
	"operator":	("operator",	Regex { "operator" },	true,	false),
	"defer":	("defer",	Regex { "defer" },	true,	false),
	"assignment":	("assignment",	Regex { "assignment" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"i386":	("i386",	Regex { "i386" },	true,	false),
	"#unavailable":	("#unavailable",	Regex { "#unavailable" },	true,	false),
	"compiler":	("compiler",	Regex { "compiler" },	true,	false),
	"init":	("init",	Regex { "init" },	true,	false),
	"#selector":	("#selector",	Regex { "#selector" },	true,	false),
	"_unsafeInheritExecutor":	("_unsafeInheritExecutor",	Regex { "_unsafeInheritExecutor" },	true,	false),
	"macCatalyst":	("macCatalyst",	Regex { "macCatalyst" },	true,	false),
	"infix":	("infix",	Regex { "infix" },	true,	false),
	"repeat":	("repeat",	Regex { "repeat" },	true,	false),
	"some":	("some",	Regex { "some" },	true,	false),
	"yield":	("yield",	Regex { "yield" },	true,	false),
	"import":	("import",	Regex { "import" },	true,	false),
	"red":	("red",	Regex { "red" },	true,	false),
	"none":	("none",	Regex { "none" },	true,	false),
	"actor":	("actor",	Regex { "actor" },	true,	false),
	"public":	("public",	Regex { "public" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"nonisolated":	("nonisolated",	Regex { "nonisolated" },	true,	false),
	"&&":	("&&",	Regex { "&&" },	true,	false),
	"each":	("each",	Regex { "each" },	true,	false),
	"default":	("default",	Regex { "default" },	true,	false),
	"_":	("_",	Regex { "_" },	true,	false),
	"isolated":	("isolated",	Regex { "isolated" },	true,	false),
	"consuming":	("consuming",	Regex { "consuming" },	true,	false),
	"^":	("^",	Regex { "^" },	true,	false),
	"safe":	("safe",	Regex { "safe" },	true,	false),
	"#error":	("#error",	Regex { "#error" },	true,	false),
	"is":	("is",	Regex { "is" },	true,	false),
	"Windows":	("Windows",	Regex { "Windows" },	true,	false),
	"false":	("false",	Regex { "false" },	true,	false),
	"watchOSApplicationExtension":	("watchOSApplicationExtension",	Regex { "watchOSApplicationExtension" },	true,	false),
	"#imageLiteral":	("#imageLiteral",	Regex { "#imageLiteral" },	true,	false),
	"required":	("required",	Regex { "required" },	true,	false),
	"line:":	("line:",	Regex { "line:" },	true,	false),
	"func":	("func",	Regex { "func" },	true,	false),
	"unowned(unsafe)":	("unowned(unsafe)",	Regex { "unowned(unsafe)" },	true,	false),
	"class":	("class",	Regex { "class" },	true,	false),
	"for":	("for",	Regex { "for" },	true,	false),
	"\\":	("\\",	Regex { "\\" },	true,	false),
	"targetEnvironment":	("targetEnvironment",	Regex { "targetEnvironment" },	true,	false),
	"move":	("move",	Regex { "move" },	true,	false),
	"#available":	("#available",	Regex { "#available" },	true,	false),
	"try":	("try",	Regex { "try" },	true,	false),
	"extension":	("extension",	Regex { "extension" },	true,	false),
	"macCatalystApplicationExtension":	("macCatalystApplicationExtension",	Regex { "macCatalystApplicationExtension" },	true,	false),
	"while":	("while",	Regex { "while" },	true,	false),
	"Linux":	("Linux",	Regex { "Linux" },	true,	false),
	"tvOS":	("tvOS",	Regex { "tvOS" },	true,	false),
	"#endif":	("#endif",	Regex { "#endif" },	true,	false),
	"await":	("await",	Regex { "await" },	true,	false),
	"canImport":	("canImport",	Regex { "canImport" },	true,	false),
	"rethrows":	("rethrows",	Regex { "rethrows" },	true,	false),
	"catch":	("catch",	Regex { "catch" },	true,	false),
	"tvOSApplicationExtension":	("tvOSApplicationExtension",	Regex { "tvOSApplicationExtension" },	true,	false),
	"...":	("...",	Regex { "..." },	true,	false),
	"Type":	("Type",	Regex { "Type" },	true,	false),
	"dynamic":	("dynamic",	Regex { "dynamic" },	true,	false),
	"left":	("left",	Regex { "left" },	true,	false),
	"precedencegroup":	("precedencegroup",	Regex { "precedencegroup" },	true,	false),
	"arch":	("arch",	Regex { "arch" },	true,	false),
	"postfix":	("postfix",	Regex { "postfix" },	true,	false),
	"simulator":	("simulator",	Regex { "simulator" },	true,	false),
	"fallthrough":	("fallthrough",	Regex { "fallthrough" },	true,	false),
	"#":	("#",	Regex { "#" },	true,	false),
	"Any":	("Any",	Regex { "Any" },	true,	false),
	"/":	("/",	Regex { "/" },	true,	false),
	"package":	("package",	Regex { "package" },	true,	false),
	"throws":	("throws",	Regex { "throws" },	true,	false),
	"switch":	("switch",	Regex { "switch" },	true,	false),
	"open":	("open",	Regex { "open" },	true,	false),
	"associatedtype":	("associatedtype",	Regex { "associatedtype" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	"!":	("!",	Regex { "!" },	true,	false),
	"struct":	("struct",	Regex { "struct" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"lowerThan":	("lowerThan",	Regex { "lowerThan" },	true,	false),
	"protocol":	("protocol",	Regex { "protocol" },	true,	false),
	"var":	("var",	Regex { "var" },	true,	false),
	"deinit":	("deinit",	Regex { "deinit" },	true,	false),
	"throw":	("throw",	Regex { "throw" },	true,	false),
	"self":	("self",	Regex { "self" },	true,	false),
	"blue":	("blue",	Regex { "blue" },	true,	false),
	"arm":	("arm",	Regex { "arm" },	true,	false),
	"==":	("==",	Regex { "==" },	true,	false),
	"||":	("||",	Regex { "||" },	true,	false),
	"optional":	("optional",	Regex { "optional" },	true,	false),
	"as":	("as",	Regex { "as" },	true,	false),
	"final":	("final",	Regex { "final" },	true,	false),
	"static":	("static",	Regex { "static" },	true,	false),
	"willSet":	("willSet",	Regex { "willSet" },	true,	false),
	"nil":	("nil",	Regex { "nil" },	true,	false),
	"unowned(safe)":	("unowned(safe)",	Regex { "unowned(safe)" },	true,	false),
	"discard":	("discard",	Regex { "discard" },	true,	false),
	"arm64":	("arm64",	Regex { "arm64" },	true,	false),
	"copy":	("copy",	Regex { "copy" },	true,	false),
	"-":	("-",	Regex { "-" },	true,	false),
	"guard":	("guard",	Regex { "guard" },	true,	false),
	"macOSApplicationExtension":	("macOSApplicationExtension",	Regex { "macOSApplicationExtension" },	true,	false),
	"watchOS":	("watchOS",	Regex { "watchOS" },	true,	false),
	"#keyPath":	("#keyPath",	Regex { "#keyPath" },	true,	false),
	"do":	("do",	Regex { "do" },	true,	false),
	"nonmutating":	("nonmutating",	Regex { "nonmutating" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"iOS":	("iOS",	Regex { "iOS" },	true,	false),
	"#sourceLocation":	("#sourceLocation",	Regex { "#sourceLocation" },	true,	false),
	";":	(";",	Regex { ";" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"#elseif":	("#elseif",	Regex { "#elseif" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	"#else":	("#else",	Regex { "#else" },	true,	false),
	"x86_64":	("x86_64",	Regex { "x86_64" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	"where":	("where",	Regex { "where" },	true,	false),
	"#fileLiteral":	("#fileLiteral",	Regex { "#fileLiteral" },	true,	false),
	"true":	("true",	Regex { "true" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"break":	("break",	Regex { "break" },	true,	false),
	",":	(",",	Regex { "," },	true,	false),
	"#if":	("#if",	Regex { "#if" },	true,	false),
	"async":	("async",	Regex { "async" },	true,	false),
	"&":	("&",	Regex { "&" },	true,	false),
	"set":	("set",	Regex { "set" },	true,	false),
	"typealias":	("typealias",	Regex { "typealias" },	true,	false),
	"super":	("super",	Regex { "super" },	true,	false),
	"iOSApplicationExtension":	("iOSApplicationExtension",	Regex { "iOSApplicationExtension" },	true,	false),
	"macro":	("macro",	Regex { "macro" },	true,	false),
	"associativity":	("associativity",	Regex { "associativity" },	true,	false),
	"enum":	("enum",	Regex { "enum" },	true,	false),
	"visionOS":	("visionOS",	Regex { "visionOS" },	true,	false),
	"green":	("green",	Regex { "green" },	true,	false),
	"continue":	("continue",	Regex { "continue" },	true,	false),
	"case":	("case",	Regex { "case" },	true,	false),
	"if":	("if",	Regex { "if" },	true,	false),
	"fileprivate":	("fileprivate",	Regex { "fileprivate" },	true,	false),
	"subscript":	("subscript",	Regex { "subscript" },	true,	false),
	"else":	("else",	Regex { "else" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"macOS":	("macOS",	Regex { "macOS" },	true,	false),
	">=":	(">=",	Regex { ">=" },	true,	false),
	"borrowing":	("borrowing",	Regex { "borrowing" },	true,	false),
	"mutating":	("mutating",	Regex { "mutating" },	true,	false),
	"setter:":	("setter:",	Regex { "setter:" },	true,	false),
	"didSet":	("didSet",	Regex { "didSet" },	true,	false),
	"let":	("let",	Regex { "let" },	true,	false),
	"weak":	("weak",	Regex { "weak" },	true,	false),
	"any":	("any",	Regex { "any" },	true,	false),
	"Self":	("Self",	Regex { "Self" },	true,	false),
	"private":	("private",	Regex { "private" },	true,	false),
	"indirect":	("indirect",	Regex { "indirect" },	true,	false),
	"internal":	("internal",	Regex { "internal" },	true,	false),
	"resourceName":	("resourceName",	Regex { "resourceName" },	true,	false),
	"swift":	("swift",	Regex { "swift" },	true,	false),
	"%":	("%",	Regex { "%" },	true,	false),
	"visionOSApplicationExtension":	("visionOSApplicationExtension",	Regex { "visionOSApplicationExtension" },	true,	false),
	"return":	("return",	Regex { "return" },	true,	false),
	"Protocol":	("Protocol",	Regex { "Protocol" },	true,	false),
	"convenience":	("convenience",	Regex { "convenience" },	true,	false),
	"override":	("override",	Regex { "override" },	true,	false),
	"unsafe":	("unsafe",	Regex { "unsafe" },	true,	false),
	"~":	("~",	Regex { "~" },	true,	false),
	"inout":	("inout",	Regex { "inout" },	true,	false),
	"unowned":	("unowned",	Regex { "unowned" },	true,	false),
	"in":	("in",	Regex { "in" },	true,	false),
	"get":	("get",	Regex { "get" },	true,	false),
	"@":	("@",	Regex { "@" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"alpha":	("alpha",	Regex { "alpha" },	true,	false),
	"file:":	("file:",	Regex { "file:" },	true,	false),
	"getter:":	("getter:",	Regex { "getter:" },	true,	false),
	"#colorLiteral":	("#colorLiteral",	Regex { "#colorLiteral" },	true,	false),
	"higherThan":	("higherThan",	Regex { "higherThan" },	true,	false),
	"lazy":	("lazy",	Regex { "lazy" },	true,	false),
	"os":	("os",	Regex { "os" },	true,	false),
]
func infixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["infix"])
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
	expect(["implicitParameterName", "propertyWrapperProjection", "_", "plainIdentifier", "escapedIdentifier"])
}
func arrayType() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
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
	expect(["hexadecimalLiteral", "#keyPath", "plainIdentifier", "extendedRegularExpressionLiteral", "{", "hexadecimalFloatingPointLiteral", "false", "_", "octalLiteral", "\\\\", "[", "#selector", "stringLiteral", "#imageLiteral", "escapedIdentifier", "true", "super", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "nil", "macroIdentifier", "switch", "decimalFloatingPointLiteral", "binaryLiteral", "self", "plainRegularExpressionLiteral", "decimalNumber", "implicitParameterName", "(", "if", "."])
}
func captureList() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func labeledTrailingClosures() {
	if token.type = .ALT {
		labeledTrailingClosure()
		// OPT
	}
	expect(["escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "_", "plainIdentifier"])
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
func inOutExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["&"])
}
func parameterTypeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func catchPattern() {
	if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["await", "#keyPath", "binaryLiteral", "try", "(", "if", "implicitParameterName", "#colorLiteral", "{", "decimalNumber", "plainOperator", "macroIdentifier", "let", "&", ".", "dotOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "#selector", "is", "#imageLiteral", "_", "propertyWrapperProjection", "decimalFloatingPointLiteral", "plainRegularExpressionLiteral", "var", "true", "escapedIdentifier", "\\\\", "stringLiteral", "octalLiteral", "super", "false", "self", "switch", "hexadecimalLiteral", "plainIdentifier", "[", "nil", "#fileLiteral"])
}
func throwsClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["throws"])
}
func dictionaryLiteralItems() {
	if token.type = .ALT {
		dictionaryLiteralItem()
		// OPT
	} else if token.type = .ALT {
		dictionaryLiteralItem()
		// OPT
	}
	expect(["implicitParameterName", "\\\\", "#selector", "&", "super", "self", "plainOperator", "{", "#fileLiteral", "extendedRegularExpressionLiteral", "[", "true", "octalLiteral", "plainRegularExpressionLiteral", "false", "switch", "_", "plainIdentifier", "binaryLiteral", "#keyPath", "try", "await", "#colorLiteral", "decimalNumber", "hexadecimalFloatingPointLiteral", "hexadecimalLiteral", "stringLiteral", "propertyWrapperProjection", ".", "nil", "(", "if", "decimalFloatingPointLiteral", "escapedIdentifier", "dotOperator", "#imageLiteral", "macroIdentifier"])
}
func classDeclaration() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["class", "package", "private", "internal", "public", "open", "final", "fileprivate", "@"])
}
func declarationModifiers() {
	if token.type = .ALT {
		declarationModifier()
		// OPT
	}
	expect(["infix", "internal", "lazy", "package", "postfix", "required", "dynamic", "private", "class", "weak", "fileprivate", "nonisolated", "open", "optional", "public", "mutating", "convenience", "override", "static", "final", "nonmutating", "prefix", "unowned"])
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
func topLevelDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["#sourceLocation", "binaryLiteral", "init", "@", "propertyWrapperProjection", "#colorLiteral", "subscript", "plainIdentifier", "defer", "func", "#warning", "#imageLiteral", "_", "optional", "decimalNumber", "continue", "switch", "#fileLiteral", "override", "convenience", "class", "unowned", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "open", "#selector", "\\\\", "return", "#keyPath", "typealias", ".", "var", "let", "self", "stringLiteral", "lazy", "fileprivate", "required", "nonisolated", "internal", "false", "[", "extension", "throw", "guard", "super", "static", "final", "for", "protocol", "prefix", "do", "macroIdentifier", "nil", "hexadecimalLiteral", "#error", "weak", "precedencegroup", "infix", "actor", "public", "private", "if", "postfix", "escapedIdentifier", "extendedRegularExpressionLiteral", "nonmutating", "mutating", "octalLiteral", "fallthrough", "", "package", "(", "deinit", "implicitParameterName", "import", "indirect", "while", "try", "struct", "&", "dotOperator", "plainOperator", "break", "enum", "true", "{", "dynamic", "plainRegularExpressionLiteral", "#if", "repeat", "await"])
}
func boxedProtocolType() {
	if token.type = .ALT {
		next()
	}
	expect(["any"])
}
func classMembers() {
	if token.type = .ALT {
		classMember()
		// OPT
	}
	expect(["var", "nonmutating", "convenience", "fileprivate", "package", "struct", "weak", "#sourceLocation", "extension", "lazy", "actor", "#error", "subscript", "mutating", "postfix", "#warning", "#if", "let", "indirect", "class", "private", "infix", "override", "required", "optional", "@", "public", "import", "deinit", "internal", "dynamic", "open", "unowned", "final", "prefix", "static", "protocol", "nonisolated", "func", "precedencegroup", "enum", "typealias", "init"])
}
func infixOperatorGroup() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func postfixSelfExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["hexadecimalLiteral", "#keyPath", "plainIdentifier", "extendedRegularExpressionLiteral", "{", "hexadecimalFloatingPointLiteral", "false", "_", "octalLiteral", "\\\\", "[", "#selector", "stringLiteral", "#imageLiteral", "escapedIdentifier", "true", "super", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "nil", "macroIdentifier", "switch", "decimalFloatingPointLiteral", "binaryLiteral", "self", "plainRegularExpressionLiteral", "decimalNumber", "implicitParameterName", "(", "if", "."])
}
func importPath() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func attributes() {
	if token.type = .ALT {
		attribute()
		// OPT
	}
	expect(["@"])
}
func availabilityArguments() {
	if token.type = .ALT {
		availabilityArgument()
		// END
	} else if token.type = .ALT {
		availabilityArgument()
		// END
	}
	expect(["iOS", "watchOSApplicationExtension", "visionOS", "watchOS", "macOSApplicationExtension", "tvOSApplicationExtension", "macOS", "iOSApplicationExtension", "tvOS", "visionOSApplicationExtension", "macCatalyst", "macCatalystApplicationExtension", "*"])
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
func optionalPattern() {
	if token.type = .ALT {
		identifierPattern()
		next()
	}
	expect(["propertyWrapperProjection", "escapedIdentifier", "implicitParameterName", "_", "plainIdentifier"])
}
func structMembers() {
	if token.type = .ALT {
		structMember()
		// OPT
	}
	expect(["postfix", "@", "final", "public", "#error", "internal", "class", "#warning", "init", "let", "mutating", "actor", "static", "open", "infix", "weak", "struct", "func", "nonisolated", "nonmutating", "var", "subscript", "typealias", "dynamic", "optional", "unowned", "#if", "indirect", "required", "import", "extension", "deinit", "#sourceLocation", "override", "private", "prefix", "package", "protocol", "fileprivate", "convenience", "lazy", "enum", "precedencegroup"])
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
func metatypeType() {
	if token.type = .ALT {
		type()
		next()
	} else if token.type = .ALT {
		type()
		next()
	}
	expect(["implicitParameterName", "Any", "propertyWrapperProjection", "(", "@", "plainIdentifier", "some", "escapedIdentifier", "_", "Self", "["])
}
func Operator() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["plainOperator"])
}
func forInStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["for"])
}
func patternInitializerList() {
	if token.type = .ALT {
		patternInitializer()
		// END
	} else if token.type = .ALT {
		patternInitializer()
		// END
	}
	expect(["switch", "[", "macroIdentifier", "decimalFloatingPointLiteral", "nil", "octalLiteral", "var", "escapedIdentifier", "_", "super", "extendedRegularExpressionLiteral", "#keyPath", ".", "if", "true", "is", "decimalNumber", "\\\\", "dotOperator", "propertyWrapperProjection", "let", "hexadecimalFloatingPointLiteral", "implicitParameterName", "(", "#fileLiteral", "binaryLiteral", "false", "#colorLiteral", "{", "#selector", "stringLiteral", "hexadecimalLiteral", "plainIdentifier", "#imageLiteral", "self", "plainOperator", "plainRegularExpressionLiteral", "&", "try", "await"])
}
func subscriptResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func argumentNames() {
	if token.type = .ALT {
		argumentName()
		// OPT
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "plainIdentifier", "escapedIdentifier", "_"])
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
	expect(["_", "plainIdentifier", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection"])
}
func closureParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func prefixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["plainOperator", "dotOperator"])
}
func keyPathComponent() {
	if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func switchIfDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
}
func floatingPointLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["decimalFloatingPointLiteral"])
}
func captureListItems() {
	if token.type = .ALT {
		captureListItem()
		// END
	} else if token.type = .ALT {
		captureListItem()
		// END
	}
	expect(["propertyWrapperProjection", "_", "weak", "unowned(safe)", "unowned(unsafe)", "unowned", "self", "escapedIdentifier", "plainIdentifier", "implicitParameterName"])
}
func assignmentOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func switchStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["switch"])
}
func switchExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["switch"])
}
func unionStyleEnumCaseList() {
	if token.type = .ALT {
		unionStyleEnumCase()
		// END
	} else if token.type = .ALT {
		unionStyleEnumCase()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func switchCases() {
	if token.type = .ALT {
		switchCase()
		// OPT
	}
	expect(["@", "case", "#if", "default"])
}
func whereExpression() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["{", "decimalFloatingPointLiteral", "nil", "#selector", "self", "#colorLiteral", "octalLiteral", "implicitParameterName", "super", "switch", "_", "macroIdentifier", "true", "try", "escapedIdentifier", "await", "stringLiteral", "\\\\", "dotOperator", "&", "#fileLiteral", "false", "propertyWrapperProjection", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "[", "if", "hexadecimalFloatingPointLiteral", "decimalNumber", ".", "#imageLiteral", "plainOperator", "#keyPath", "hexadecimalLiteral", "(", "plainIdentifier", "binaryLiteral"])
}
func rawValueStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["case", "@"])
}
func protocolCompositionContinuation() {
	if token.type = .ALT {
		typeIdentifier()
		// END
	} else if token.type = .ALT {
		typeIdentifier()
		// END
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "_", "implicitParameterName"])
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
	expect(["stringLiteral", "decimalFloatingPointLiteral", "plainRegularExpressionLiteral", "hexadecimalFloatingPointLiteral", "nil", "octalLiteral", "hexadecimalLiteral", "false", "true", "extendedRegularExpressionLiteral", "decimalNumber", "binaryLiteral"])
}
func protocolPropertyDeclaration() {
	if token.type = .ALT {
		variableDeclarationHead()
		variableName()
		typeAnnotation()
		getterSetterKeywordBlock()
		// END
	}
	expect(["unowned", "prefix", "class", "dynamic", "private", "infix", "package", "static", "@", "var", "internal", "convenience", "weak", "mutating", "open", "override", "fileprivate", "nonmutating", "nonisolated", "postfix", "final", "required", "public", "lazy", "optional"])
}
func superclassInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func typealiasName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func elseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
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
	expect(["unowned", "override", "mutating", "private", "postfix", "nonmutating", "lazy", "subscript", "package", "infix", "@", "open", "static", "dynamic", "nonisolated", "internal", "class", "public", "weak", "final", "optional", "prefix", "required", "fileprivate", "convenience"])
}
func precedenceGroupAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["assignment"])
}
func sameTypeRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "_", "implicitParameterName"])
}
func functionCallArgumentList() {
	if token.type = .ALT {
		functionCallArgument()
		// END
	} else if token.type = .ALT {
		functionCallArgument()
		// END
	}
	expect(["await", "_", "#selector", "escapedIdentifier", "plainIdentifier", "extendedRegularExpressionLiteral", "implicitParameterName", "#colorLiteral", "#keyPath", "try", "hexadecimalLiteral", "decimalFloatingPointLiteral", "[", "propertyWrapperProjection", "#imageLiteral", "binaryLiteral", "\\\\", "false", "true", "#fileLiteral", "super", "&", ".", "octalLiteral", "macroIdentifier", "if", "plainRegularExpressionLiteral", "plainOperator", "stringLiteral", "nil", "self", "dotOperator", "hexadecimalFloatingPointLiteral", "{", "(", "decimalNumber", "switch"])
}
func ifDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
}
func externalParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
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
func endifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#endif"])
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
	expect(["nonisolated", "@", "lazy", "package", "convenience", "dynamic", "unowned", "infix", "required", "override", "static", "mutating", "optional", "internal", "final", "postfix", "fileprivate", "open", "private", "var", "class", "weak", "prefix", "public", "nonmutating"])
}
func ifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#if"])
}
func tupleType() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func tupleExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func lineNumber() {
	if token.type = .ALT {
		decimalDigits()
		// END
	}
	expect(["decimalNumber"])
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
func ifStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
}
func continueStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["continue"])
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
	expect(["static", "open", "postfix", "deinit", "optional", "init", "unowned", "public", "dynamic", "var", "lazy", "internal", "extension", "import", "precedencegroup", "func", "package", "prefix", "enum", "@", "infix", "typealias", "subscript", "final", "actor", "override", "weak", "required", "struct", "private", "nonmutating", "indirect", "mutating", "fileprivate", "protocol", "nonisolated", "class", "convenience", "let"])
}
func conditionalOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["?"])
}
func elementName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func decimalLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["decimalNumber"])
}
func postfixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["plainOperator", "dotOperator"])
}
func elseifDirectiveClause() {
	if token.type = .ALT {
		elseifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#elseif"])
}
func subscriptHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["final", "internal", "class", "convenience", "static", "postfix", "lazy", "mutating", "optional", "dynamic", "nonisolated", "fileprivate", "override", "private", "unowned", "weak", "subscript", "prefix", "nonmutating", "package", "@", "infix", "open", "required", "public"])
}
func classBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func initializer() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func extensionDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["fileprivate", "@", "internal", "extension", "open", "package", "private", "public"])
}
func superclassSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func infixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["plainOperator", "dotOperator"])
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
func attributeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func asPattern() {
	if token.type = .ALT {
		pattern()
		next()
	}
	expect(["await", "#keyPath", "binaryLiteral", "try", "(", "if", "implicitParameterName", "#colorLiteral", "{", "decimalNumber", "plainOperator", "macroIdentifier", "let", "&", ".", "dotOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "#selector", "is", "#imageLiteral", "_", "propertyWrapperProjection", "decimalFloatingPointLiteral", "plainRegularExpressionLiteral", "var", "true", "escapedIdentifier", "\\\\", "stringLiteral", "octalLiteral", "super", "false", "self", "switch", "hexadecimalLiteral", "plainIdentifier", "[", "nil", "#fileLiteral"])
}
func tupleTypeElementList() {
	if token.type = .ALT {
		tupleTypeElement()
		// END
	} else if token.type = .ALT {
		tupleTypeElement()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "[", "Self", "_", "@", "propertyWrapperProjection", "some", "Any", "(", "implicitParameterName"])
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
	expect(["{", "decimalFloatingPointLiteral", "nil", "#selector", "self", "#colorLiteral", "octalLiteral", "implicitParameterName", "super", "switch", "_", "macroIdentifier", "true", "try", "escapedIdentifier", "await", "stringLiteral", "\\\\", "dotOperator", "&", "#fileLiteral", "false", "propertyWrapperProjection", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "[", "if", "hexadecimalFloatingPointLiteral", "decimalNumber", ".", "#imageLiteral", "plainOperator", "#keyPath", "hexadecimalLiteral", "(", "plainIdentifier", "binaryLiteral"])
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
func arrayLiteralItems() {
	if token.type = .ALT {
		arrayLiteralItem()
		// OPT
	} else if token.type = .ALT {
		arrayLiteralItem()
		// OPT
	}
	expect(["dotOperator", "macroIdentifier", "super", "decimalNumber", "{", "decimalFloatingPointLiteral", "implicitParameterName", "binaryLiteral", "(", "#colorLiteral", "try", "propertyWrapperProjection", "escapedIdentifier", "nil", "hexadecimalLiteral", "#keyPath", ".", "[", "self", "await", "#selector", "true", "octalLiteral", "false", "hexadecimalFloatingPointLiteral", "#fileLiteral", "if", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "_", "#imageLiteral", "&", "switch", "\\\\", "plainOperator", "plainIdentifier", "stringLiteral"])
}
func opaqueType() {
	if token.type = .ALT {
		next()
	}
	expect(["some"])
}
func prefixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["prefix"])
}
func precedenceGroupRelation() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["higherThan"])
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
func tupleElementList() {
	if token.type = .ALT {
		tupleElement()
		// END
	} else if token.type = .ALT {
		tupleElement()
		// END
	}
	expect([".", "[", "nil", "try", "hexadecimalFloatingPointLiteral", "(", "_", "false", "plainOperator", "extendedRegularExpressionLiteral", "hexadecimalLiteral", "switch", "escapedIdentifier", "self", "plainIdentifier", "{", "#keyPath", "\\\\", "#selector", "dotOperator", "#colorLiteral", "plainRegularExpressionLiteral", "propertyWrapperProjection", "decimalFloatingPointLiteral", "if", "octalLiteral", "stringLiteral", "macroIdentifier", "binaryLiteral", "true", "#fileLiteral", "super", "implicitParameterName", "#imageLiteral", "await", "decimalNumber", "&"])
}
func conditionalSwitchCase() {
	if token.type = .ALT {
		switchIfDirectiveClause()
		// OPT
	}
	expect(["#if"])
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
	expect(["unowned", "prefix", "class", "dynamic", "private", "infix", "package", "static", "@", "var", "internal", "convenience", "weak", "mutating", "open", "override", "fileprivate", "nonmutating", "nonisolated", "postfix", "final", "required", "public", "lazy", "optional"])
}
func extensionMembers() {
	if token.type = .ALT {
		extensionMember()
		// OPT
	}
	expect(["dynamic", "nonmutating", "precedencegroup", "#error", "func", "#sourceLocation", "static", "protocol", "final", "public", "private", "infix", "weak", "deinit", "nonisolated", "#warning", "lazy", "class", "subscript", "extension", "unowned", "actor", "convenience", "init", "open", "required", "@", "fileprivate", "import", "mutating", "#if", "prefix", "enum", "package", "optional", "indirect", "struct", "internal", "let", "var", "override", "typealias", "postfix"])
}
func breakStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["break"])
}
func defaultLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "default"])
}
func setterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["nonmutating", "@", "set", "mutating"])
}
func functionType() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "("])
}
func initializerBody() {
	if token.type = .ALT {
		codeBlock()
		// END
	}
	expect(["{"])
}
func identifierPattern() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func elseifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#elseif"])
}
func regularExpressionLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["plainRegularExpressionLiteral"])
}
func tuplePattern() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func macroExpansionExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["macroIdentifier"])
}
func prefixExpression() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["binaryLiteral", "#fileLiteral", "if", "#colorLiteral", "plainIdentifier", "#selector", "super", "switch", "decimalNumber", ".", "extendedRegularExpressionLiteral", "self", "nil", "#keyPath", "plainOperator", "{", "true", "plainRegularExpressionLiteral", "#imageLiteral", "decimalFloatingPointLiteral", "[", "implicitParameterName", "propertyWrapperProjection", "(", "octalLiteral", "stringLiteral", "hexadecimalLiteral", "hexadecimalFloatingPointLiteral", "false", "escapedIdentifier", "dotOperator", "_", "\\\\", "macroIdentifier"])
}
func caseItemList() {
	if token.type = .ALT {
		pattern()
		// OPT
	} else if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["await", "#keyPath", "binaryLiteral", "try", "(", "if", "implicitParameterName", "#colorLiteral", "{", "decimalNumber", "plainOperator", "macroIdentifier", "let", "&", ".", "dotOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "#selector", "is", "#imageLiteral", "_", "propertyWrapperProjection", "decimalFloatingPointLiteral", "plainRegularExpressionLiteral", "var", "true", "escapedIdentifier", "\\\\", "stringLiteral", "octalLiteral", "super", "false", "self", "switch", "hexadecimalLiteral", "plainIdentifier", "[", "nil", "#fileLiteral"])
}
func optionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["implicitParameterName", "Any", "propertyWrapperProjection", "(", "@", "plainIdentifier", "some", "escapedIdentifier", "_", "Self", "["])
}
func environment() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["simulator"])
}
func parameterClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func actorMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["static", "open", "postfix", "deinit", "optional", "init", "unowned", "public", "dynamic", "var", "lazy", "internal", "extension", "import", "precedencegroup", "func", "package", "prefix", "enum", "@", "infix", "typealias", "subscript", "final", "actor", "override", "weak", "required", "struct", "private", "nonmutating", "indirect", "mutating", "fileprivate", "protocol", "nonisolated", "class", "convenience", "let"])
}
func enumCasePattern() {
	if token.type = .ALT {
		// OPT
	}
	expect(["implicitParameterName", "escapedIdentifier", "plainIdentifier", "propertyWrapperProjection", "_", "."])
}
func rawValueStyleEnumMembers() {
	if token.type = .ALT {
		rawValueStyleEnumMember()
		// OPT
	}
	expect(["mutating", "infix", "fileprivate", "weak", "protocol", "static", "deinit", "precedencegroup", "override", "nonisolated", "enum", "open", "private", "case", "optional", "postfix", "init", "var", "#warning", "class", "let", "@", "dynamic", "actor", "#if", "package", "typealias", "required", "internal", "prefix", "public", "struct", "extension", "final", "func", "#error", "import", "indirect", "subscript", "lazy", "convenience", "#sourceLocation", "nonmutating", "unowned"])
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
func willSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["willSet", "@"])
}
func closureParameterList() {
	if token.type = .ALT {
		closureParameter()
		// END
	} else if token.type = .ALT {
		closureParameter()
		// END
	}
	expect(["plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier"])
}
func importDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["import", "@"])
}
func statementLabel() {
	if token.type = .ALT {
		labelName()
		next()
	}
	expect(["_", "propertyWrapperProjection", "implicitParameterName", "plainIdentifier", "escapedIdentifier"])
}
func repeatWhileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["repeat"])
}
func booleanLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["true"])
}
func protocolCompositionType() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "_", "implicitParameterName"])
}
func wildcardPattern() {
	if token.type = .ALT {
		next()
	}
	expect(["_"])
}
func unionStyleEnumMembers() {
	if token.type = .ALT {
		unionStyleEnumMember()
		// OPT
	}
	expect(["actor", "mutating", "indirect", "deinit", "import", "prefix", "extension", "init", "package", "unowned", "public", "optional", "lazy", "open", "nonmutating", "#error", "@", "protocol", "infix", "final", "dynamic", "subscript", "var", "precedencegroup", "weak", "nonisolated", "enum", "fileprivate", "func", "class", "private", "#warning", "#sourceLocation", "case", "override", "static", "required", "typealias", "struct", "#if", "convenience", "let", "internal", "postfix"])
}
func implicitlyUnwrappedOptionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["implicitParameterName", "Any", "propertyWrapperProjection", "(", "@", "plainIdentifier", "some", "escapedIdentifier", "_", "Self", "["])
}
func filePath() {
	if token.type = .ALT {
		staticStringLiteral()
		// END
	}
	expect(["stringLiteral"])
}
func typeInheritanceList() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["_", "plainIdentifier", "@", "escapedIdentifier", "propertyWrapperProjection", "implicitParameterName"])
}
func diagnosticStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#warning"])
}
func rawValueStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["escapedIdentifier", "propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier"])
}
func protocolBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func macroDeclaration() {
	if token.type = .ALT {
		macroHead()
		identifier()
		// OPT
	}
	expect(["open", "unowned", "nonmutating", "lazy", "nonisolated", "override", "required", "weak", "private", "class", "convenience", "public", "static", "macro", "internal", "dynamic", "@", "optional", "package", "final", "fileprivate", "prefix", "infix", "postfix", "mutating"])
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
func selfSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func precedenceGroupAttributes() {
	if token.type = .ALT {
		precedenceGroupAttribute()
		// OPT
	}
	expect(["lowerThan", "higherThan", "associativity", "assignment"])
}
func expressionPattern() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["{", "decimalFloatingPointLiteral", "nil", "#selector", "self", "#colorLiteral", "octalLiteral", "implicitParameterName", "super", "switch", "_", "macroIdentifier", "true", "try", "escapedIdentifier", "await", "stringLiteral", "\\\\", "dotOperator", "&", "#fileLiteral", "false", "propertyWrapperProjection", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "[", "if", "hexadecimalFloatingPointLiteral", "decimalNumber", ".", "#imageLiteral", "plainOperator", "#keyPath", "hexadecimalLiteral", "(", "plainIdentifier", "binaryLiteral"])
}
func variableName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func swiftVersionContinuation() {
	if token.type = .ALT {
		next()
	}
	expect(["."])
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
func switchElseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
}
func patternInitializer() {
	if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["await", "#keyPath", "binaryLiteral", "try", "(", "if", "implicitParameterName", "#colorLiteral", "{", "decimalNumber", "plainOperator", "macroIdentifier", "let", "&", ".", "dotOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "#selector", "is", "#imageLiteral", "_", "propertyWrapperProjection", "decimalFloatingPointLiteral", "plainRegularExpressionLiteral", "var", "true", "escapedIdentifier", "\\\\", "stringLiteral", "octalLiteral", "super", "false", "self", "switch", "hexadecimalLiteral", "plainIdentifier", "[", "nil", "#fileLiteral"])
}
func keyPathPostfixes() {
	if token.type = .ALT {
		keyPathPostfix()
		// OPT
	}
	expect(["[", "self", "!", "?"])
}
func functionDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["postfix", "mutating", "open", "final", "internal", "infix", "class", "func", "unowned", "prefix", "private", "fileprivate", "package", "@", "override", "public", "static", "nonmutating", "optional", "required", "lazy", "nonisolated", "dynamic", "weak", "convenience"])
}
func functionHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["private", "nonmutating", "func", "nonisolated", "infix", "convenience", "required", "package", "public", "mutating", "override", "final", "prefix", "static", "postfix", "@", "class", "lazy", "unowned", "open", "dynamic", "fileprivate", "weak", "internal", "optional"])
}
func protocolSubscriptDeclaration() {
	if token.type = .ALT {
		subscriptHead()
		subscriptResult()
		// OPT
	}
	expect(["unowned", "override", "mutating", "private", "postfix", "nonmutating", "lazy", "subscript", "package", "infix", "@", "open", "static", "dynamic", "nonisolated", "internal", "class", "public", "weak", "final", "optional", "prefix", "required", "fileprivate", "convenience"])
}
func macroFunctionSignatureResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func precedenceGroupDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["precedencegroup"])
}
func genericParameterList() {
	if token.type = .ALT {
		genericParameter()
		// END
	} else if token.type = .ALT {
		genericParameter()
		// END
	}
	expect(["_", "propertyWrapperProjection", "implicitParameterName", "plainIdentifier", "escapedIdentifier"])
}
func elseClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
}
func unionStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["case", "@", "indirect"])
}
func actorDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["public", "fileprivate", "open", "private", "actor", "package", "@", "internal"])
}
func isPattern() {
	if token.type = .ALT {
		next()
	}
	expect(["is"])
}
func valueBindingPattern() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["var"])
}
func catchClauses() {
	if token.type = .ALT {
		catchClause()
		// OPT
	}
	expect(["catch"])
}
func captureListItem() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["weak", "plainIdentifier", "unowned", "unowned(safe)", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "unowned(unsafe)", "_"])
}
func codeBlock() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func typealiasDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["open", "public", "package", "fileprivate", "internal", "typealias", "@", "private"])
}
func constantDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["dynamic", "unowned", "final", "class", "required", "let", "prefix", "postfix", "mutating", "nonmutating", "internal", "open", "fileprivate", "lazy", "weak", "private", "nonisolated", "convenience", "optional", "override", "public", "infix", "package", "static", "@"])
}
func implicitMemberExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["."])
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
	expect(["targetEnvironment", "swift", "compiler", "os", "arch", "canImport"])
}
func argumentName() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func tupleElement() {
	if token.type = .ALT {
		expression()
		// END
	} else if token.type = .ALT {
		expression()
		// END
	}
	expect(["{", "decimalFloatingPointLiteral", "nil", "#selector", "self", "#colorLiteral", "octalLiteral", "implicitParameterName", "super", "switch", "_", "macroIdentifier", "true", "try", "escapedIdentifier", "await", "stringLiteral", "\\\\", "dotOperator", "&", "#fileLiteral", "false", "propertyWrapperProjection", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "[", "if", "hexadecimalFloatingPointLiteral", "decimalNumber", ".", "#imageLiteral", "plainOperator", "#keyPath", "hexadecimalLiteral", "(", "plainIdentifier", "binaryLiteral"])
}
func parenthesizedExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func functionTypeArgument() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["implicitParameterName", "@", "Any", "_", "escapedIdentifier", "inout", "some", "[", "propertyWrapperProjection", "(", "Self", "plainIdentifier"])
}
func closureParameter() {
	if token.type = .ALT {
		closureParameterName()
		// OPT
	} else if token.type = .ALT {
		closureParameterName()
		// OPT
	}
	expect(["implicitParameterName", "escapedIdentifier", "_", "propertyWrapperProjection", "plainIdentifier"])
}
func switchElseifDirectiveClause() {
	if token.type = .ALT {
		elseifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#elseif"])
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
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func functionCallArgumentClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
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
func actorMembers() {
	if token.type = .ALT {
		actorMember()
		// OPT
	}
	expect(["public", "postfix", "required", "enum", "protocol", "subscript", "nonmutating", "#warning", "#sourceLocation", "import", "convenience", "weak", "lazy", "internal", "typealias", "unowned", "actor", "#if", "private", "open", "fileprivate", "#error", "class", "static", "func", "precedencegroup", "var", "mutating", "infix", "final", "deinit", "dynamic", "prefix", "struct", "nonisolated", "indirect", "package", "let", "@", "init", "override", "extension", "optional"])
}
func genericArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
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
func interpolatedStringLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["stringLiteral"])
}
func balancedTokens() {
	if token.type = .ALT {
		balancedToken()
		// OPT
	}
	expect(["final", "defer", "Any", "weak", "in", "protocol", "throw", "break", "else", "#imageLiteral", "move", "typealias", "#warning", "#elseif", "left", "nonisolated", "_unsafeInheritExecutor", "let", "right", "{", "inout", "#sourceLocation", "implicitParameterName", "postfix", "prefix", "rethrows", "borrowing", "|", "precedencegroup", "copy", "open", "propertyWrapperProjection", "hexadecimalLiteral", "override", "plainIdentifier", "return", "didSet", "#colorLiteral", "=", "willSet", "%", "indirect", "var", "<", "actor", "plainOperator", "[", "#", "enum", "associatedtype", "lazy", "package", "lowerThan", "true", "operator", "(", "false", "plainRegularExpressionLiteral", "?", "!", "deinit", "decimalFloatingPointLiteral", "required", ":", "continue", "private", "unowned", "fileprivate", ";", "higherThan", "init", "is", ".", "#selector", "self", "extendedRegularExpressionLiteral", "none", "binaryLiteral", "#endif", "super", "/", "subscript", "set", "static", "hexadecimalFloatingPointLiteral", "each", "mutating", "default", "throws", "optional", "consuming", "class", "@", "guard", "#fileLiteral", "octalLiteral", "#available", "fallthrough", "switch", "if", "extension", "~", "where", "public", "func", "convenience", ",", "case", "nil", "#keyPath", "async", "await", "Self", "try", "dotOperator", "internal", "^", "some", "yield", "struct", "escapedIdentifier", "#unavailable", "catch", "import", "get", "#else", ">", "+", "for", "do", "*", "as", "while", "discard", "_", "associativity", "stringLiteral", "isolated", "repeat", "-", "dynamic", "#if", "&", "nonmutating", "#error", "decimalNumber"])
}
func genericParameterClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
}
func initializerExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	} else if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["hexadecimalLiteral", "#keyPath", "plainIdentifier", "extendedRegularExpressionLiteral", "{", "hexadecimalFloatingPointLiteral", "false", "_", "octalLiteral", "\\\\", "[", "#selector", "stringLiteral", "#imageLiteral", "escapedIdentifier", "true", "super", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "nil", "macroIdentifier", "switch", "decimalFloatingPointLiteral", "binaryLiteral", "self", "plainRegularExpressionLiteral", "decimalNumber", "implicitParameterName", "(", "if", "."])
}
func attributeArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func whereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func enumDeclaration() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["enum", "indirect", "private", "fileprivate", "internal", "@", "public", "package", "open"])
}
func setterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["nonmutating", "@", "set", "mutating"])
}
func protocolMembers() {
	if token.type = .ALT {
		protocolMember()
		// OPT
	}
	expect(["unowned", "postfix", "required", "package", "class", "subscript", "override", "#if", "private", "prefix", "#sourceLocation", "fileprivate", "func", "nonmutating", "#warning", "mutating", "@", "dynamic", "static", "weak", "final", "optional", "init", "var", "typealias", "internal", "#error", "associatedtype", "infix", "convenience", "open", "nonisolated", "lazy", "public"])
}
func fallthroughStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["fallthrough"])
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
func dictionaryType() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func classMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["static", "open", "postfix", "deinit", "optional", "init", "unowned", "public", "dynamic", "var", "lazy", "internal", "extension", "import", "precedencegroup", "func", "package", "prefix", "enum", "@", "infix", "typealias", "subscript", "final", "actor", "override", "weak", "required", "struct", "private", "nonmutating", "indirect", "mutating", "fileprivate", "protocol", "nonisolated", "class", "convenience", "let"])
}
func macroDefinition() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func functionName() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func functionBody() {
	if token.type = .ALT {
		codeBlock()
		// END
	}
	expect(["{"])
}
func labelName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func deinitializerDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["deinit", "@"])
}
func conformanceRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	} else if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "_", "implicitParameterName"])
}
func actorIsolationModifier() {
	if token.type = .ALT {
		next()
	}
	expect(["nonisolated"])
}
func superclassMethodExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func getterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "nonmutating", "get", "mutating"])
}
func macroSignature() {
	if token.type = .ALT {
		parameterClause()
		// OPT
	}
	expect(["("])
}
func tuplePatternElement() {
	if token.type = .ALT {
		pattern()
		// END
	} else if token.type = .ALT {
		pattern()
		// END
	}
	expect(["await", "#keyPath", "binaryLiteral", "try", "(", "if", "implicitParameterName", "#colorLiteral", "{", "decimalNumber", "plainOperator", "macroIdentifier", "let", "&", ".", "dotOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "#selector", "is", "#imageLiteral", "_", "propertyWrapperProjection", "decimalFloatingPointLiteral", "plainRegularExpressionLiteral", "var", "true", "escapedIdentifier", "\\\\", "stringLiteral", "octalLiteral", "super", "false", "self", "switch", "hexadecimalLiteral", "plainIdentifier", "[", "nil", "#fileLiteral"])
}
func optionalChainingExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["hexadecimalLiteral", "#keyPath", "plainIdentifier", "extendedRegularExpressionLiteral", "{", "hexadecimalFloatingPointLiteral", "false", "_", "octalLiteral", "\\\\", "[", "#selector", "stringLiteral", "#imageLiteral", "escapedIdentifier", "true", "super", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "nil", "macroIdentifier", "switch", "decimalFloatingPointLiteral", "binaryLiteral", "self", "plainRegularExpressionLiteral", "decimalNumber", "implicitParameterName", "(", "if", "."])
}
func extensionMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["static", "open", "postfix", "deinit", "optional", "init", "unowned", "public", "dynamic", "var", "lazy", "internal", "extension", "import", "precedencegroup", "func", "package", "prefix", "enum", "@", "infix", "typealias", "subscript", "final", "actor", "override", "weak", "required", "struct", "private", "nonmutating", "indirect", "mutating", "fileprivate", "protocol", "nonisolated", "class", "convenience", "let"])
}
func rawValueStyleEnum() {
	if token.type = .ALT {
		next()
	}
	expect(["enum"])
}
func keyPathExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["\\\\"])
}
func actorBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
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
	expect(["{", "decimalFloatingPointLiteral", "nil", "#selector", "self", "#colorLiteral", "octalLiteral", "implicitParameterName", "super", "switch", "_", "macroIdentifier", "true", "try", "escapedIdentifier", "await", "stringLiteral", "\\\\", "dotOperator", "&", "#fileLiteral", "false", "propertyWrapperProjection", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "[", "if", "hexadecimalFloatingPointLiteral", "decimalNumber", ".", "#imageLiteral", "plainOperator", "#keyPath", "hexadecimalLiteral", "(", "plainIdentifier", "binaryLiteral"])
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
func catchPatternList() {
	if token.type = .ALT {
		catchPattern()
		// END
	} else if token.type = .ALT {
		catchPattern()
		// END
	}
	expect(["decimalNumber", "decimalFloatingPointLiteral", "self", "escapedIdentifier", "var", "is", "super", "[", ".", "if", "binaryLiteral", "await", "hexadecimalLiteral", "hexadecimalFloatingPointLiteral", "switch", "#imageLiteral", "nil", "macroIdentifier", "stringLiteral", "true", "dotOperator", "try", "&", "false", "#fileLiteral", "octalLiteral", "#selector", "#colorLiteral", "plainIdentifier", "propertyWrapperProjection", "(", "\\\\", "plainOperator", "implicitParameterName", "{", "_", "extendedRegularExpressionLiteral", "plainRegularExpressionLiteral", "let", "#keyPath"])
}
func parameter() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["escapedIdentifier", "_", "propertyWrapperProjection", "implicitParameterName", "plainIdentifier"])
}
func protocolMethodDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["postfix", "mutating", "open", "final", "internal", "infix", "class", "func", "unowned", "prefix", "private", "fileprivate", "package", "@", "override", "public", "static", "nonmutating", "optional", "required", "lazy", "nonisolated", "dynamic", "weak", "convenience"])
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
func initializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["required", "postfix", "public", "static", "open", "override", "weak", "convenience", "nonisolated", "prefix", "optional", "internal", "package", "@", "infix", "fileprivate", "dynamic", "init", "lazy", "final", "private", "nonmutating", "mutating", "class", "unowned"])
}
func typealiasAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func precedenceGroupName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func caseCondition() {
	if token.type = .ALT {
		next()
	}
	expect(["case"])
}
func didSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["didSet", "@"])
}
func wildcardExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["_"])
}
func doStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["do"])
}
func availabilityCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#available"])
}
func rawValueAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func getterSetterKeywordBlock() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func arrayLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func deferStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["defer"])
}
func arrayLiteralItem() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["{", "decimalFloatingPointLiteral", "nil", "#selector", "self", "#colorLiteral", "octalLiteral", "implicitParameterName", "super", "switch", "_", "macroIdentifier", "true", "try", "escapedIdentifier", "await", "stringLiteral", "\\\\", "dotOperator", "&", "#fileLiteral", "false", "propertyWrapperProjection", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "[", "if", "hexadecimalFloatingPointLiteral", "decimalNumber", ".", "#imageLiteral", "plainOperator", "#keyPath", "hexadecimalLiteral", "(", "plainIdentifier", "binaryLiteral"])
}
func structBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func selfMethodExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func attribute() {
	if token.type = .ALT {
		next()
	}
	expect(["@"])
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
func elseDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#else"])
}
func enumName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func enumCaseName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func switchExpressionCases() {
	if token.type = .ALT {
		switchExpressionCase()
		// OPT
	}
	expect(["default", "case", "@"])
}
func variableDeclarationHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["nonmutating", "optional", "required", "package", "public", "lazy", "open", "@", "final", "unowned", "weak", "var", "prefix", "infix", "nonisolated", "internal", "class", "mutating", "postfix", "convenience", "static", "fileprivate", "dynamic", "private", "override"])
}
func protocolDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "internal", "package", "private", "fileprivate", "open", "protocol", "public"])
}
func forcedValueExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["hexadecimalLiteral", "#keyPath", "plainIdentifier", "extendedRegularExpressionLiteral", "{", "hexadecimalFloatingPointLiteral", "false", "_", "octalLiteral", "\\\\", "[", "#selector", "stringLiteral", "#imageLiteral", "escapedIdentifier", "true", "super", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "nil", "macroIdentifier", "switch", "decimalFloatingPointLiteral", "binaryLiteral", "self", "plainRegularExpressionLiteral", "decimalNumber", "implicitParameterName", "(", "if", "."])
}
func genericWhereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func selfInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
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
	expect(["static", "open", "postfix", "deinit", "optional", "init", "unowned", "public", "dynamic", "var", "lazy", "internal", "extension", "import", "precedencegroup", "func", "package", "prefix", "enum", "@", "infix", "typealias", "subscript", "final", "actor", "override", "weak", "required", "struct", "private", "nonmutating", "indirect", "mutating", "fileprivate", "protocol", "nonisolated", "class", "convenience", "let"])
}
func macroHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["convenience", "override", "nonisolated", "postfix", "infix", "@", "open", "static", "mutating", "macro", "lazy", "fileprivate", "dynamic", "unowned", "private", "weak", "package", "required", "internal", "class", "nonmutating", "public", "optional", "final", "prefix"])
}
func structDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["fileprivate", "private", "public", "internal", "@", "package", "open", "struct"])
}
func anyType() {
	if token.type = .ALT {
		next()
	}
	expect(["Any"])
}
func mutationModifier() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["mutating"])
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
func nilLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["nil"])
}
func unionStyleEnum() {
	if token.type = .ALT {
		// OPT
	}
	expect(["indirect", "enum"])
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
func protocolAssociatedTypeDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["package", "@", "open", "fileprivate", "public", "private", "associatedtype", "internal"])
}
func typeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func className() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func extensionBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func structMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["static", "open", "postfix", "deinit", "optional", "init", "unowned", "public", "dynamic", "var", "lazy", "internal", "extension", "import", "precedencegroup", "func", "package", "prefix", "enum", "@", "infix", "typealias", "subscript", "final", "actor", "override", "weak", "required", "struct", "private", "nonmutating", "indirect", "mutating", "fileprivate", "protocol", "nonisolated", "class", "convenience", "let"])
}
func typeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func parameterList() {
	if token.type = .ALT {
		parameter()
		// END
	} else if token.type = .ALT {
		parameter()
		// END
	}
	expect(["escapedIdentifier", "propertyWrapperProjection", "_", "implicitParameterName", "plainIdentifier"])
}
func genericArgumentList() {
	if token.type = .ALT {
		genericArgument()
		// END
	} else if token.type = .ALT {
		genericArgument()
		// END
	}
	expect(["Any", "(", "plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "some", "_", "Self", "implicitParameterName", "[", "@"])
}
func protocolInitializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["required", "postfix", "public", "static", "open", "override", "weak", "convenience", "nonisolated", "prefix", "optional", "internal", "package", "@", "infix", "fileprivate", "dynamic", "init", "lazy", "final", "private", "nonmutating", "mutating", "class", "unowned"])
}
func typeIdentifier() {
	if token.type = .ALT {
		typeName()
		// OPT
	} else if token.type = .ALT {
		typeName()
		// OPT
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "_", "implicitParameterName", "escapedIdentifier"])
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
	expect(["if", "true", "{", "hexadecimalLiteral", "stringLiteral", "#imageLiteral", "switch", "octalLiteral", "propertyWrapperProjection", "escapedIdentifier", "(", "macroIdentifier", "#colorLiteral", "\\\\", "#fileLiteral", "#selector", "super", "nil", "implicitParameterName", "self", "#keyPath", "[", "hexadecimalFloatingPointLiteral", "binaryLiteral", "decimalNumber", "false", ".", "extendedRegularExpressionLiteral", "decimalFloatingPointLiteral", "plainRegularExpressionLiteral", "plainIdentifier", "_"])
}
func localParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
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
	expect(["@", "("])
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
func selfType() {
	if token.type = .ALT {
		next()
	}
	expect(["Self"])
}
func rawValueStyleEnumCaseList() {
	if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	} else if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "escapedIdentifier", "_", "plainIdentifier"])
}
func throwStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["throw"])
}
func numericLiteral() {
	if token.type = .ALT {
		integerLiteral()
		// END
	} else if token.type = .ALT {
		integerLiteral()
		// END
	}
	expect(["octalLiteral", "binaryLiteral", "hexadecimalLiteral", "decimalNumber"])
}
func unionStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["escapedIdentifier", "propertyWrapperProjection", "implicitParameterName", "_", "plainIdentifier"])
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
func ifExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
}
func protocolName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
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
func willSetDidSetBlock() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func typeInheritanceClause() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func functionTypeArgumentList() {
	if token.type = .ALT {
		functionTypeArgument()
		// END
	} else if token.type = .ALT {
		functionTypeArgument()
		// END
	}
	expect(["some", "_", "escapedIdentifier", "Any", "[", "@", "plainIdentifier", "propertyWrapperProjection", "Self", "(", "implicitParameterName", "inout"])
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
	expect(["hexadecimalFloatingPointLiteral", "decimalNumber", "binaryLiteral", "decimalFloatingPointLiteral", "octalLiteral", "hexadecimalLiteral"])
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
func awaitOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["await"])
}
func swiftVersion() {
	if token.type = .ALT {
		decimalDigits()
		// OPT
	}
	expect(["decimalNumber"])
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
	expect(["implicitParameterName", "propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "_"])
}
func catchClause() {
	if token.type = .ALT {
		next()
	}
	expect(["catch"])
}
func getterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["nonmutating", "@", "mutating", "get"])
}
func returnStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["return"])
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
func defaultArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func functionTypeArgumentClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func protocolMember() {
	if token.type = .ALT {
		protocolMemberDeclaration()
		// END
	} else if token.type = .ALT {
		protocolMemberDeclaration()
		// END
	}
	expect(["nonmutating", "unowned", "mutating", "var", "convenience", "dynamic", "infix", "final", "open", "class", "override", "subscript", "public", "optional", "@", "fileprivate", "internal", "package", "lazy", "postfix", "typealias", "func", "associatedtype", "prefix", "weak", "init", "private", "nonisolated", "required", "static"])
}
func postfixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["postfix"])
}
func requirement() {
	if token.type = .ALT {
		conformanceRequirement()
		// END
	} else if token.type = .ALT {
		conformanceRequirement()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "implicitParameterName", "propertyWrapperProjection", "_"])
}
func labeledTrailingClosure() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func expression() {
	if token.type = .ALT {
		// OPT
	}
	expect([".", "#imageLiteral", "#fileLiteral", "extendedRegularExpressionLiteral", "implicitParameterName", "#colorLiteral", "decimalNumber", "stringLiteral", "plainIdentifier", "#keyPath", "try", "{", "if", "await", "self", "octalLiteral", "escapedIdentifier", "dotOperator", "\\\\", "macroIdentifier", "super", "_", "#selector", "false", "hexadecimalLiteral", "[", "plainOperator", "binaryLiteral", "propertyWrapperProjection", "decimalFloatingPointLiteral", "&", "switch", "hexadecimalFloatingPointLiteral", "nil", "(", "plainRegularExpressionLiteral", "true"])
}
func tuplePatternElementList() {
	if token.type = .ALT {
		tuplePatternElement()
		// END
	} else if token.type = .ALT {
		tuplePatternElement()
		// END
	}
	expect(["_", "extendedRegularExpressionLiteral", "switch", "try", "#fileLiteral", "var", "escapedIdentifier", "super", "#imageLiteral", "[", "octalLiteral", "decimalFloatingPointLiteral", "(", "hexadecimalFloatingPointLiteral", "propertyWrapperProjection", "&", "macroIdentifier", "is", "{", "let", "await", "if", "#colorLiteral", "plainRegularExpressionLiteral", "true", "false", "stringLiteral", "plainOperator", "implicitParameterName", "\\\\", "hexadecimalLiteral", "#selector", "decimalNumber", ".", "#keyPath", "self", "nil", "plainIdentifier", "binaryLiteral", "dotOperator"])
}
func switchElseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
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
func dictionaryLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["["])
}
func closureExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
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
func trailingClosures() {
	if token.type = .ALT {
		closureExpression()
		// OPT
	}
	expect(["{"])
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
func lineControlStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#sourceLocation"])
}
func decimalDigits() {
	if token.type = .ALT {
		next()
	}
	expect(["decimalNumber"])
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
	expect(["iOS", "visionOS", "iOSApplicationExtension", "tvOSApplicationExtension", "macCatalyst", "macOS", "visionOSApplicationExtension", "watchOSApplicationExtension", "watchOS", "tvOS", "macOSApplicationExtension", "macCatalystApplicationExtension"])
}
func subscriptExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["hexadecimalLiteral", "#keyPath", "plainIdentifier", "extendedRegularExpressionLiteral", "{", "hexadecimalFloatingPointLiteral", "false", "_", "octalLiteral", "\\\\", "[", "#selector", "stringLiteral", "#imageLiteral", "escapedIdentifier", "true", "super", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "nil", "macroIdentifier", "switch", "decimalFloatingPointLiteral", "binaryLiteral", "self", "plainRegularExpressionLiteral", "decimalNumber", "implicitParameterName", "(", "if", "."])
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
	expect(["hexadecimalLiteral", "#keyPath", "plainIdentifier", "extendedRegularExpressionLiteral", "{", "hexadecimalFloatingPointLiteral", "false", "_", "octalLiteral", "\\\\", "[", "#selector", "stringLiteral", "#imageLiteral", "escapedIdentifier", "true", "super", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "nil", "macroIdentifier", "switch", "decimalFloatingPointLiteral", "binaryLiteral", "self", "plainRegularExpressionLiteral", "decimalNumber", "implicitParameterName", "(", "if", "."])
}
func identifierList() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func whileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["while"])
}
func dictionaryLiteralItem() {
	if token.type = .ALT {
		expression()
		next()
	}
	expect(["{", "decimalFloatingPointLiteral", "nil", "#selector", "self", "#colorLiteral", "octalLiteral", "implicitParameterName", "super", "switch", "_", "macroIdentifier", "true", "try", "escapedIdentifier", "await", "stringLiteral", "\\\\", "dotOperator", "&", "#fileLiteral", "false", "propertyWrapperProjection", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "[", "if", "hexadecimalFloatingPointLiteral", "decimalNumber", ".", "#imageLiteral", "plainOperator", "#keyPath", "hexadecimalLiteral", "(", "plainIdentifier", "binaryLiteral"])
}
func setterName() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func keyPathComponents() {
	if token.type = .ALT {
		keyPathComponent()
		// END
	} else if token.type = .ALT {
		keyPathComponent()
		// END
	}
	expect(["self", "propertyWrapperProjection", "_", "[", "escapedIdentifier", "implicitParameterName", "!", "plainIdentifier", "?"])
}
func closureSignature() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["(", "[", "propertyWrapperProjection", "_", "plainIdentifier", "escapedIdentifier", "implicitParameterName"])
}
func ifExpressionTail() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
}
func conditionalCompilationBlock() {
	if token.type = .ALT {
		ifDirectiveClause()
		// OPT
	}
	expect(["#if"])
}
func conditionList() {
	if token.type = .ALT {
		condition()
		// END
	} else if token.type = .ALT {
		condition()
		// END
	}
	expect(["#fileLiteral", "_", "escapedIdentifier", "nil", "true", "[", "extendedRegularExpressionLiteral", "octalLiteral", "var", "stringLiteral", "propertyWrapperProjection", "plainRegularExpressionLiteral", "{", "#selector", "(", "#unavailable", "macroIdentifier", "decimalFloatingPointLiteral", "plainIdentifier", "dotOperator", "self", "binaryLiteral", "&", "#colorLiteral", "false", "if", "hexadecimalFloatingPointLiteral", "#keyPath", "hexadecimalLiteral", "\\\\", "case", "try", "#available", "decimalNumber", "super", "plainOperator", "await", ".", "#imageLiteral", "switch", "implicitParameterName", "let"])
}
func infixExpressions() {
	if token.type = .ALT {
		infixExpression()
		// OPT
	}
	expect(["is", "?", "plainOperator", "=", "as", "dotOperator"])
}
func keyPathStringExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["#keyPath"])
}
func caseLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "case"])
}
func argumentLabel() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
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
	expect(["{", "decimalFloatingPointLiteral", "nil", "#selector", "self", "#colorLiteral", "octalLiteral", "implicitParameterName", "super", "switch", "_", "macroIdentifier", "true", "try", "escapedIdentifier", "await", "stringLiteral", "\\\\", "dotOperator", "&", "#fileLiteral", "false", "propertyWrapperProjection", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "[", "if", "hexadecimalFloatingPointLiteral", "decimalNumber", ".", "#imageLiteral", "plainOperator", "#keyPath", "hexadecimalLiteral", "(", "plainIdentifier", "binaryLiteral"])
}
func optionalBindingCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["let"])
}
func statements() {
	if token.type = .ALT {
		statement()
		// OPT
	}
	expect(["extendedRegularExpressionLiteral", "actor", "nonisolated", "guard", "octalLiteral", "enum", "decimalNumber", "#warning", "func", "break", "package", "hexadecimalLiteral", "stringLiteral", "public", "infix", "dotOperator", "(", "#selector", "macroIdentifier", "implicitParameterName", "weak", "true", "escapedIdentifier", "continue", "mutating", "#if", "binaryLiteral", "do", "init", "convenience", "private", "override", "{", "nil", "prefix", "super", "plainRegularExpressionLiteral", "plainIdentifier", "var", "subscript", "decimalFloatingPointLiteral", "await", "static", "final", "for", "optional", "try", "while", "#colorLiteral", "postfix", "typealias", "struct", "internal", "#keyPath", "unowned", "let", "indirect", "[", "propertyWrapperProjection", "protocol", "&", "#error", "fileprivate", "self", "repeat", "precedencegroup", "#sourceLocation", "nonmutating", "\\\\", "deinit", "#fileLiteral", "if", "class", "defer", "dynamic", "return", "switch", "false", "open", "throw", "hexadecimalFloatingPointLiteral", "#imageLiteral", "@", ".", "fallthrough", "extension", "plainOperator", "lazy", "required", "import", "_"])
}
func elseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
}
func staticStringLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["stringLiteral"])
}
func actorName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
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
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func requirementList() {
	if token.type = .ALT {
		requirement()
		// END
	} else if token.type = .ALT {
		requirement()
		// END
	}
	expect(["escapedIdentifier", "propertyWrapperProjection", "plainIdentifier", "_", "implicitParameterName"])
}
func genericArgument() {
	if token.type = .ALT {
		type()
		// END
	}
	expect(["implicitParameterName", "Any", "propertyWrapperProjection", "(", "@", "plainIdentifier", "some", "escapedIdentifier", "_", "Self", "["])
}
func structName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func functionResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func guardStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["guard"])
}
func initializerHead() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["static", "package", "private", "weak", "unowned", "infix", "final", "internal", "nonisolated", "required", "postfix", "nonmutating", "override", "dynamic", "init", "class", "public", "convenience", "prefix", "fileprivate", "optional", "lazy", "open", "mutating", "@"])
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
	expect(["hexadecimalFloatingPointLiteral", "decimalNumber", "binaryLiteral", "decimalFloatingPointLiteral", "octalLiteral", "hexadecimalLiteral"])
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
	expect(["propertyWrapperProjection", "plainIdentifier", "_", "implicitParameterName", "escapedIdentifier"])
}
