//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"lineNumber":	("/0*[1-9][0-9]*/",	/0*[1-9][0-9]*/,	false,	false),
	"binaryLiteral":	("/-?0b[0-1][0-1_]*/",	/-?0b[0-1][0-1_]*/,	false,	true),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"hexadecimalFloatingPointLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/,	false,	false),
	"innerBalancedToken":	("/[^()\\[\\]{}\\s]/",	/[^()\[\]{}\s]/,	false,	false),
	"multilineComment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"decimalDigits":	("/[0-9]+/",	/[0-9]+/,	false,	false),
	"dotOperator":	("/\\.[\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]+/",	/\.[\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]+/,	false,	false),
	"decimalFloatingPointLiteral":	("/-?[0-9][0-9_]*(?:\\.[0-9][0-9_]*)?(?:[eE][+-]?[0-9][0-9_]*)?/",	/-?[0-9][0-9_]*(?:\.[0-9][0-9_]*)?(?:[eE][+-]?[0-9][0-9_]*)?/,	false,	false),
	"interpolatedStringLiteral":	("/#*\"(?:\\\\#*\\([^)]*\\)|\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]{1,8}\\}|[^\"\\\\\\n\\r])*\"#*|#*\"\"\"(?:\\\\#*\\([^)]*\\)|\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]{1,8}\\}|\\\\#*\\s*\\n|[^\\\\])*\"\"\"#*/",	/#*"(?:\\#*\([^)]*\)|\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]{1,8}\}|[^"\\\n\r])*"#*|#*"""(?:\\#*\([^)]*\)|\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]{1,8}\}|\\#*\s*\n|[^\\])*"""#*/,	false,	false),
	"plainIdentifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"plainOperator":	("/[\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}][\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]*/",	/[\/=+\-*%!&|^~?<>\p{Sm}\p{So}][\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]*/,	false,	false),
	"implicitParameterName":	("/\\$[0-9]+/",	/\$[0-9]+/,	false,	false),
	"regularExpressionLiteral":	("/#*\\/(?:[^\\/\\\\]|\\\\.)*\\/#*/",	/#*\/(?:[^\/\\]|\\.)*\/#*/,	false,	false),
	"staticStringLiteral":	("/#*\"(?:\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]{1,8}\\}|[^\"\\\\\\n\\r])*\"#*|#*\"\"\"(?:\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]{1,8}\\}|\\\\#*\\s*\\n|[^\\\\])*\"\"\"#*/",	/#*"(?:\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]{1,8}\}|[^"\\\n\r])*"#*|#*"""(?:\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]{1,8}\}|\\#*\s*\n|[^\\])*"""#*/,	false,	false),
	"hexadecimalLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*/,	false,	true),
	"octalLiteral":	("/-?0o[0-7][0-7_]*/",	/-?0o[0-7][0-7_]*/,	false,	true),
	"decimalLiteral":	("/-?[0-9][0-9_]*/",	/-?[0-9][0-9_]*/,	false,	true),
	"propertyWrapperProjection":	("/\\$\\p{XID_Continue}+/",	/\$\p{XID_Continue}+/,	false,	false),
	"escapedIdentifier":	("/`\\p{XID_Start}\\p{XID_Continue}*`/",	/`\p{XID_Start}\p{XID_Continue}*`/,	false,	false),
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"#sourceLocation":	("#sourceLocation",	Regex { "#sourceLocation" },	true,	false),
	"os":	("os",	Regex { "os" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"enum":	("enum",	Regex { "enum" },	true,	false),
	"rethrows":	("rethrows",	Regex { "rethrows" },	true,	false),
	"watchOSApplicationExtension":	("watchOSApplicationExtension",	Regex { "watchOSApplicationExtension" },	true,	false),
	"#unavailable":	("#unavailable",	Regex { "#unavailable" },	true,	false),
	"protocol":	("protocol",	Regex { "protocol" },	true,	false),
	"borrowing":	("borrowing",	Regex { "borrowing" },	true,	false),
	"catch":	("catch",	Regex { "catch" },	true,	false),
	"#imageLiteral":	("#imageLiteral",	Regex { "#imageLiteral" },	true,	false),
	"let":	("let",	Regex { "let" },	true,	false),
	"resourceName":	("resourceName",	Regex { "resourceName" },	true,	false),
	"macOS":	("macOS",	Regex { "macOS" },	true,	false),
	"macCatalystApplicationExtension":	("macCatalystApplicationExtension",	Regex { "macCatalystApplicationExtension" },	true,	false),
	"getter:":	("getter:",	Regex { "getter:" },	true,	false),
	"var":	("var",	Regex { "var" },	true,	false),
	"Windows":	("Windows",	Regex { "Windows" },	true,	false),
	"tvOSApplicationExtension":	("tvOSApplicationExtension",	Regex { "tvOSApplicationExtension" },	true,	false),
	"get":	("get",	Regex { "get" },	true,	false),
	"extension":	("extension",	Regex { "extension" },	true,	false),
	"lowerThan":	("lowerThan",	Regex { "lowerThan" },	true,	false),
	"x86_64":	("x86_64",	Regex { "x86_64" },	true,	false),
	"defer":	("defer",	Regex { "defer" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"where":	("where",	Regex { "where" },	true,	false),
	"init":	("init",	Regex { "init" },	true,	false),
	"none":	("none",	Regex { "none" },	true,	false),
	"dynamic":	("dynamic",	Regex { "dynamic" },	true,	false),
	"#colorLiteral":	("#colorLiteral",	Regex { "#colorLiteral" },	true,	false),
	"lazy":	("lazy",	Regex { "lazy" },	true,	false),
	"override":	("override",	Regex { "override" },	true,	false),
	"unsafe":	("unsafe",	Regex { "unsafe" },	true,	false),
	"@":	("@",	Regex { "@" },	true,	false),
	"setter:":	("setter:",	Regex { "setter:" },	true,	false),
	"==":	("==",	Regex { "==" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"case":	("case",	Regex { "case" },	true,	false),
	"#error":	("#error",	Regex { "#error" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"\\":	("\\",	Regex { "\\" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	"in":	("in",	Regex { "in" },	true,	false),
	"unowned":	("unowned",	Regex { "unowned" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"return":	("return",	Regex { "return" },	true,	false),
	"struct":	("struct",	Regex { "struct" },	true,	false),
	"associatedtype":	("associatedtype",	Regex { "associatedtype" },	true,	false),
	"safe":	("safe",	Regex { "safe" },	true,	false),
	"set":	("set",	Regex { "set" },	true,	false),
	"open":	("open",	Regex { "open" },	true,	false),
	"as":	("as",	Regex { "as" },	true,	false),
	"canImport":	("canImport",	Regex { "canImport" },	true,	false),
	"optional":	("optional",	Regex { "optional" },	true,	false),
	"#else":	("#else",	Regex { "#else" },	true,	false),
	"private":	("private",	Regex { "private" },	true,	false),
	"||":	("||",	Regex { "||" },	true,	false),
	"nonmutating":	("nonmutating",	Regex { "nonmutating" },	true,	false),
	"compiler":	("compiler",	Regex { "compiler" },	true,	false),
	"left":	("left",	Regex { "left" },	true,	false),
	"is":	("is",	Regex { "is" },	true,	false),
	"simulator":	("simulator",	Regex { "simulator" },	true,	false),
	"indirect":	("indirect",	Regex { "indirect" },	true,	false),
	"weak":	("weak",	Regex { "weak" },	true,	false),
	"#elseif":	("#elseif",	Regex { "#elseif" },	true,	false),
	"visionOSApplicationExtension":	("visionOSApplicationExtension",	Regex { "visionOSApplicationExtension" },	true,	false),
	"prefix":	("prefix",	Regex { "prefix" },	true,	false),
	"mutating":	("mutating",	Regex { "mutating" },	true,	false),
	"#keyPath":	("#keyPath",	Regex { "#keyPath" },	true,	false),
	"nonisolated":	("nonisolated",	Regex { "nonisolated" },	true,	false),
	"default":	("default",	Regex { "default" },	true,	false),
	"Type":	("Type",	Regex { "Type" },	true,	false),
	"infix":	("infix",	Regex { "infix" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	";":	(";",	Regex { ";" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	",":	(",",	Regex { "," },	true,	false),
	"nil":	("nil",	Regex { "nil" },	true,	false),
	">=":	(">=",	Regex { ">=" },	true,	false),
	"#":	("#",	Regex { "#" },	true,	false),
	"visionOS":	("visionOS",	Regex { "visionOS" },	true,	false),
	"arm":	("arm",	Regex { "arm" },	true,	false),
	"file:":	("file:",	Regex { "file:" },	true,	false),
	"!":	("!",	Regex { "!" },	true,	false),
	"if":	("if",	Regex { "if" },	true,	false),
	"fallthrough":	("fallthrough",	Regex { "fallthrough" },	true,	false),
	"line:":	("line:",	Regex { "line:" },	true,	false),
	"alpha":	("alpha",	Regex { "alpha" },	true,	false),
	"willSet":	("willSet",	Regex { "willSet" },	true,	false),
	"postfix":	("postfix",	Regex { "postfix" },	true,	false),
	"higherThan":	("higherThan",	Regex { "higherThan" },	true,	false),
	"final":	("final",	Regex { "final" },	true,	false),
	"assignment":	("assignment",	Regex { "assignment" },	true,	false),
	"convenience":	("convenience",	Regex { "convenience" },	true,	false),
	"switch":	("switch",	Regex { "switch" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"package":	("package",	Regex { "package" },	true,	false),
	"public":	("public",	Regex { "public" },	true,	false),
	"await":	("await",	Regex { "await" },	true,	false),
	"some":	("some",	Regex { "some" },	true,	false),
	"#fileLiteral":	("#fileLiteral",	Regex { "#fileLiteral" },	true,	false),
	"iOS":	("iOS",	Regex { "iOS" },	true,	false),
	"throw":	("throw",	Regex { "throw" },	true,	false),
	"class":	("class",	Regex { "class" },	true,	false),
	"static":	("static",	Regex { "static" },	true,	false),
	"actor":	("actor",	Regex { "actor" },	true,	false),
	"while":	("while",	Regex { "while" },	true,	false),
	"repeat":	("repeat",	Regex { "repeat" },	true,	false),
	"false":	("false",	Regex { "false" },	true,	false),
	"unowned(safe)":	("unowned(safe)",	Regex { "unowned(safe)" },	true,	false),
	"#warning":	("#warning",	Regex { "#warning" },	true,	false),
	"blue":	("blue",	Regex { "blue" },	true,	false),
	"true":	("true",	Regex { "true" },	true,	false),
	"internal":	("internal",	Regex { "internal" },	true,	false),
	"#selector":	("#selector",	Regex { "#selector" },	true,	false),
	"_":	("_",	Regex { "_" },	true,	false),
	"#endif":	("#endif",	Regex { "#endif" },	true,	false),
	"for":	("for",	Regex { "for" },	true,	false),
	"&&":	("&&",	Regex { "&&" },	true,	false),
	"red":	("red",	Regex { "red" },	true,	false),
	"guard":	("guard",	Regex { "guard" },	true,	false),
	"throws":	("throws",	Regex { "throws" },	true,	false),
	"swift":	("swift",	Regex { "swift" },	true,	false),
	"&":	("&",	Regex { "&" },	true,	false),
	"macro":	("macro",	Regex { "macro" },	true,	false),
	"operator":	("operator",	Regex { "operator" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"right":	("right",	Regex { "right" },	true,	false),
	"Protocol":	("Protocol",	Regex { "Protocol" },	true,	false),
	"fileprivate":	("fileprivate",	Regex { "fileprivate" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	"consuming":	("consuming",	Regex { "consuming" },	true,	false),
	"unowned(unsafe)":	("unowned(unsafe)",	Regex { "unowned(unsafe)" },	true,	false),
	"try":	("try",	Regex { "try" },	true,	false),
	"Linux":	("Linux",	Regex { "Linux" },	true,	false),
	"targetEnvironment":	("targetEnvironment",	Regex { "targetEnvironment" },	true,	false),
	"super":	("super",	Regex { "super" },	true,	false),
	"async":	("async",	Regex { "async" },	true,	false),
	"i386":	("i386",	Regex { "i386" },	true,	false),
	"self":	("self",	Regex { "self" },	true,	false),
	"deinit":	("deinit",	Regex { "deinit" },	true,	false),
	"break":	("break",	Regex { "break" },	true,	false),
	"...":	("...",	Regex { "..." },	true,	false),
	"tvOS":	("tvOS",	Regex { "tvOS" },	true,	false),
	"any":	("any",	Regex { "any" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"macOSApplicationExtension":	("macOSApplicationExtension",	Regex { "macOSApplicationExtension" },	true,	false),
	"typealias":	("typealias",	Regex { "typealias" },	true,	false),
	"didSet":	("didSet",	Regex { "didSet" },	true,	false),
	"iOSApplicationExtension":	("iOSApplicationExtension",	Regex { "iOSApplicationExtension" },	true,	false),
	"do":	("do",	Regex { "do" },	true,	false),
	"green":	("green",	Regex { "green" },	true,	false),
	"precedencegroup":	("precedencegroup",	Regex { "precedencegroup" },	true,	false),
	"Any":	("Any",	Regex { "Any" },	true,	false),
	"Self":	("Self",	Regex { "Self" },	true,	false),
	"associativity":	("associativity",	Regex { "associativity" },	true,	false),
	"required":	("required",	Regex { "required" },	true,	false),
	"#if":	("#if",	Regex { "#if" },	true,	false),
	"continue":	("continue",	Regex { "continue" },	true,	false),
	"#available":	("#available",	Regex { "#available" },	true,	false),
	"import":	("import",	Regex { "import" },	true,	false),
	"func":	("func",	Regex { "func" },	true,	false),
	"arm64":	("arm64",	Regex { "arm64" },	true,	false),
	"inout":	("inout",	Regex { "inout" },	true,	false),
	"subscript":	("subscript",	Regex { "subscript" },	true,	false),
	"arch":	("arch",	Regex { "arch" },	true,	false),
	"else":	("else",	Regex { "else" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"watchOS":	("watchOS",	Regex { "watchOS" },	true,	false),
	"macCatalyst":	("macCatalyst",	Regex { "macCatalyst" },	true,	false),
]
func identifierList() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func functionCallArgumentClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func enumName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func nilLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["nil"])
}
func unionStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func guardStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["guard"])
}
func parameter() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["propertyWrapperProjection", "escapedIdentifier", "plainIdentifier", "", "implicitParameterName"])
}
func expression() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "try"])
}
func deferStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["defer"])
}
func actorIsolationModifier() {
	if token.type = .ALT {
		next()
	}
	expect(["nonisolated"])
}
func getterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func closureParameterList() {
	if token.type = .ALT {
		closureParameter()
		// END
	} else if token.type = .ALT {
		closureParameter()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier"])
}
func balancedTokens() {
	if token.type = .ALT {
		balancedToken()
		// OPT
	}
	expect(["(", "{", "[", "", "innerBalancedToken"])
}
func classBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func caseCondition() {
	if token.type = .ALT {
		next()
	}
	expect(["case"])
}
func attributeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func postfixSelfExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["\\\\", "staticStringLiteral", "true", ".", "implicitParameterName", "super", "if", "_", "octalLiteral", "decimalFloatingPointLiteral", "switch", "self", "nil", "#keyPath", "propertyWrapperProjection", "regularExpressionLiteral", "false", "{", "(", "escapedIdentifier", "decimalLiteral", "hexadecimalFloatingPointLiteral", "[", "#fileLiteral", "#colorLiteral", "#imageLiteral", "hexadecimalLiteral", "plainIdentifier", "#selector", "binaryLiteral", "#", "interpolatedStringLiteral"])
}
func requirementList() {
	if token.type = .ALT {
		requirement()
		// END
	} else if token.type = .ALT {
		requirement()
		// END
	}
	expect(["escapedIdentifier", "implicitParameterName", "plainIdentifier", "propertyWrapperProjection"])
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
	expect(["implicitParameterName", "propertyWrapperProjection", "#selector", "octalLiteral", "binaryLiteral", "decimalLiteral", "#colorLiteral", "#keyPath", "staticStringLiteral", "true", "escapedIdentifier", "regularExpressionLiteral", "plainIdentifier", "hexadecimalFloatingPointLiteral", "if", "decimalFloatingPointLiteral", "interpolatedStringLiteral", "#", "super", "#fileLiteral", "_", "[", "hexadecimalLiteral", "self", "{", "#imageLiteral", "(", "false", "\\\\", "switch", ".", "nil"])
}
func declarationModifiers() {
	if token.type = .ALT {
		declarationModifier()
		// OPT
	}
	expect(["override", "final", "postfix", "infix", "dynamic", "class", "unowned", "internal", "open", "prefix", "static", "required", "private", "nonmutating", "mutating", "fileprivate", "public", "nonisolated", "convenience", "lazy", "package", "optional", "weak"])
}
func structName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
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
func labeledTrailingClosure() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func defaultArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
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
	}
	expect(["plainIdentifier"])
}
func macroFunctionSignatureResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
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
	expect(["\\\\", "staticStringLiteral", "true", ".", "implicitParameterName", "super", "if", "_", "octalLiteral", "decimalFloatingPointLiteral", "switch", "self", "nil", "#keyPath", "propertyWrapperProjection", "regularExpressionLiteral", "false", "{", "(", "escapedIdentifier", "decimalLiteral", "hexadecimalFloatingPointLiteral", "[", "#fileLiteral", "#colorLiteral", "#imageLiteral", "hexadecimalLiteral", "plainIdentifier", "#selector", "binaryLiteral", "#", "interpolatedStringLiteral"])
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
	expect(["infix", "prefix", "", "precedencegroup", "@", "postfix"])
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
	expect(["try", ""])
}
func subscriptHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func typeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func functionResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func getterSetterKeywordBlock() {
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
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func tuplePattern() {
	if token.type = .ALT {
		next()
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
	expect(["is", "(", "try", "implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "let", "_", "", "var", "plainIdentifier"])
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
func switchElseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
}
func macroDeclaration() {
	if token.type = .ALT {
		macroHead()
		identifier()
		// OPT
	}
	expect(["@", ""])
}
func functionHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
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
func ifStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
}
func classMembers() {
	if token.type = .ALT {
		classMember()
		// OPT
	}
	expect(["@", "precedencegroup", "prefix", "#sourceLocation", "#if", "#error", "infix", "#warning", "postfix", ""])
}
func expressionPattern() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["try", ""])
}
func closureExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func returnStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["return"])
}
func infixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["dotOperator", "plainOperator"])
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
	expect(["false", "regularExpressionLiteral", "hexadecimalLiteral", "decimalFloatingPointLiteral", "binaryLiteral", "octalLiteral", "interpolatedStringLiteral", "nil", "staticStringLiteral", "decimalLiteral", "hexadecimalFloatingPointLiteral", "true"])
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
func valueBindingPattern() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["var"])
}
func genericArgumentList() {
	if token.type = .ALT {
		genericArgument()
		// END
	} else if token.type = .ALT {
		genericArgument()
		// END
	}
	expect(["[", "(", "Self", "some", "@", "implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "", "plainIdentifier", "Any"])
}
func Operator() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["plainOperator"])
}
func identifierPattern() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func swiftVersion() {
	if token.type = .ALT {
		next()
	}
	expect(["decimalDigits"])
}
func genericParameterClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
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
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func typealiasAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func unionStyleEnumCaseList() {
	if token.type = .ALT {
		unionStyleEnumCase()
		// END
	} else if token.type = .ALT {
		unionStyleEnumCase()
		// END
	}
	expect(["escapedIdentifier", "implicitParameterName", "plainIdentifier", "propertyWrapperProjection"])
}
func superclassSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func forInStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["for"])
}
func implicitMemberExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["."])
}
func variableDeclarationHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
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
	expect(["tvOS", "macCatalystApplicationExtension", "tvOSApplicationExtension", "visionOS", "watchOS", "iOSApplicationExtension", "macOS", "visionOSApplicationExtension", "macOSApplicationExtension", "iOS", "watchOSApplicationExtension", "macCatalyst"])
}
func rawValueAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func unionStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "plainIdentifier"])
}
func anyType() {
	if token.type = .ALT {
		next()
	}
	expect(["Any"])
}
func caseLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
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
	expect(["infix", "prefix", "", "precedencegroup", "@", "postfix"])
}
func infixOperatorGroup() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func wildcardPattern() {
	if token.type = .ALT {
		next()
	}
	expect(["_"])
}
func boxedProtocolType() {
	if token.type = .ALT {
		next()
	}
	expect(["any"])
}
func implicitlyUnwrappedOptionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["plainIdentifier", "some", "@", "[", "Any", "escapedIdentifier", "Self", "propertyWrapperProjection", "(", "implicitParameterName", ""])
}
func tupleElement() {
	if token.type = .ALT {
		expression()
		// END
	} else if token.type = .ALT {
		expression()
		// END
	}
	expect(["try", ""])
}
func topLevelDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["throw", "plainIdentifier", "infix", "switch", "repeat", "precedencegroup", "try", "fallthrough", "continue", "implicitParameterName", "", "while", "escapedIdentifier", "#warning", "return", "prefix", "#sourceLocation", "postfix", "@", "break", "guard", "propertyWrapperProjection", "if", "#if", "#error", "for", "do", "defer"])
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
func superclassInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func switchIfDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
}
func doStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["do"])
}
func requirement() {
	if token.type = .ALT {
		conformanceRequirement()
		// END
	} else if token.type = .ALT {
		conformanceRequirement()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "implicitParameterName"])
}
func switchStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["switch"])
}
func conformanceRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	} else if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection"])
}
func className() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func protocolCompositionContinuation() {
	if token.type = .ALT {
		typeIdentifier()
		// END
	} else if token.type = .ALT {
		typeIdentifier()
		// END
	}
	expect(["plainIdentifier", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection"])
}
func typealiasDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
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
func repeatWhileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["repeat"])
}
func prefixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["prefix"])
}
func initializerBody() {
	if token.type = .ALT {
		codeBlock()
		// END
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
	expect(["infix", "prefix", "", "precedencegroup", "@", "postfix"])
}
func captureListItem() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["weak", "unowned(safe)", "unowned(unsafe)", "unowned", ""])
}
func subscriptResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func setterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
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
	expect(["", "@"])
}
func throwStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["throw"])
}
func statementLabel() {
	if token.type = .ALT {
		labelName()
		next()
	}
	expect(["implicitParameterName", "plainIdentifier", "escapedIdentifier", "propertyWrapperProjection"])
}
func mutationModifier() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["mutating"])
}
func initializer() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
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
func precedenceGroupAttributes() {
	if token.type = .ALT {
		precedenceGroupAttribute()
		// OPT
	}
	expect(["lowerThan", "higherThan", "assignment", "associativity"])
}
func catchPatternList() {
	if token.type = .ALT {
		catchPattern()
		// END
	} else if token.type = .ALT {
		catchPattern()
		// END
	}
	expect(["(", "_", "", "propertyWrapperProjection", "escapedIdentifier", "implicitParameterName", "var", "is", "try", "let", "plainIdentifier"])
}
func argumentNames() {
	if token.type = .ALT {
		argumentName()
		// OPT
	}
	expect(["escapedIdentifier", "plainIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func optionalChainingExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["\\\\", "staticStringLiteral", "true", ".", "implicitParameterName", "super", "if", "_", "octalLiteral", "decimalFloatingPointLiteral", "switch", "self", "nil", "#keyPath", "propertyWrapperProjection", "regularExpressionLiteral", "false", "{", "(", "escapedIdentifier", "decimalLiteral", "hexadecimalFloatingPointLiteral", "[", "#fileLiteral", "#colorLiteral", "#imageLiteral", "hexadecimalLiteral", "plainIdentifier", "#selector", "binaryLiteral", "#", "interpolatedStringLiteral"])
}
func precedenceGroupRelation() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["higherThan"])
}
func tupleTypeElementList() {
	if token.type = .ALT {
		tupleTypeElement()
		// END
	} else if token.type = .ALT {
		tupleTypeElement()
		// END
	}
	expect(["", "Self", "some", "implicitParameterName", "Any", "@", "propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "[", "("])
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
func wildcardExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["_"])
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
	expect(["@", ""])
}
func awaitOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["await"])
}
func initializerExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	} else if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["\\\\", "staticStringLiteral", "true", ".", "implicitParameterName", "super", "if", "_", "octalLiteral", "decimalFloatingPointLiteral", "switch", "self", "nil", "#keyPath", "propertyWrapperProjection", "regularExpressionLiteral", "false", "{", "(", "escapedIdentifier", "decimalLiteral", "hexadecimalFloatingPointLiteral", "[", "#fileLiteral", "#colorLiteral", "#imageLiteral", "hexadecimalLiteral", "plainIdentifier", "#selector", "binaryLiteral", "#", "interpolatedStringLiteral"])
}
func keyPathComponents() {
	if token.type = .ALT {
		keyPathComponent()
		// END
	} else if token.type = .ALT {
		keyPathComponent()
		// END
	}
	expect(["[", "implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier", "!", "self", "?"])
}
func defaultLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func keyPathPostfixes() {
	if token.type = .ALT {
		keyPathPostfix()
		// OPT
	}
	expect(["self", "!", "?", "["])
}
func parameterClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
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
	expect(["hexadecimalLiteral", "octalLiteral", "decimalFloatingPointLiteral", "decimalLiteral", "binaryLiteral", "hexadecimalFloatingPointLiteral"])
}
func fallthroughStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["fallthrough"])
}
func keyPathStringExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["#keyPath"])
}
func argumentLabel() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func protocolSubscriptDeclaration() {
	if token.type = .ALT {
		subscriptHead()
		subscriptResult()
		// OPT
	}
	expect(["@", ""])
}
func availabilityArguments() {
	if token.type = .ALT {
		availabilityArgument()
		// END
	} else if token.type = .ALT {
		availabilityArgument()
		// END
	}
	expect(["visionOS", "macOSApplicationExtension", "macCatalyst", "tvOSApplicationExtension", "tvOS", "iOSApplicationExtension", "iOS", "watchOS", "*", "macOS", "visionOSApplicationExtension", "watchOSApplicationExtension", "macCatalystApplicationExtension"])
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
	expect(["", "@"])
}
func catchPattern() {
	if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["is", "(", "try", "implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "let", "_", "", "var", "plainIdentifier"])
}
func forcedValueExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["\\\\", "staticStringLiteral", "true", ".", "implicitParameterName", "super", "if", "_", "octalLiteral", "decimalFloatingPointLiteral", "switch", "self", "nil", "#keyPath", "propertyWrapperProjection", "regularExpressionLiteral", "false", "{", "(", "escapedIdentifier", "decimalLiteral", "hexadecimalFloatingPointLiteral", "[", "#fileLiteral", "#colorLiteral", "#imageLiteral", "hexadecimalLiteral", "plainIdentifier", "#selector", "binaryLiteral", "#", "interpolatedStringLiteral"])
}
func captureListItems() {
	if token.type = .ALT {
		captureListItem()
		// END
	} else if token.type = .ALT {
		captureListItem()
		// END
	}
	expect(["weak", "unowned(safe)", "unowned(unsafe)", "", "unowned"])
}
func typealiasName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func unionStyleEnum() {
	if token.type = .ALT {
		// OPT
	}
	expect(["indirect", ""])
}
func initializerHead() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
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
	expect(["\\\\", "staticStringLiteral", "true", ".", "implicitParameterName", "super", "if", "_", "octalLiteral", "decimalFloatingPointLiteral", "switch", "self", "nil", "#keyPath", "propertyWrapperProjection", "regularExpressionLiteral", "false", "{", "(", "escapedIdentifier", "decimalLiteral", "hexadecimalFloatingPointLiteral", "[", "#fileLiteral", "#colorLiteral", "#imageLiteral", "hexadecimalLiteral", "plainIdentifier", "#selector", "binaryLiteral", "#", "interpolatedStringLiteral"])
}
func swiftVersionContinuation() {
	if token.type = .ALT {
		next()
	}
	expect(["."])
}
func precedenceGroupName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func typeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func importDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func availabilityCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#available"])
}
func whereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func arrayLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func floatingPointLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["decimalFloatingPointLiteral"])
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
	expect(["dotOperator", "plainOperator"])
}
func rawValueStyleEnum() {
	if token.type = .ALT {
		next()
	}
	expect(["enum"])
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
func rawValueStyleEnumMembers() {
	if token.type = .ALT {
		rawValueStyleEnumMember()
		// OPT
	}
	expect(["@", "#if", "precedencegroup", "postfix", "#error", "infix", "#warning", "", "#sourceLocation", "prefix"])
}
func closureSignature() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["[", ""])
}
func precedenceGroupDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["precedencegroup"])
}
func postfixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["dotOperator", "plainOperator"])
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
	expect(["implicitParameterName", "escapedIdentifier", "plainIdentifier", "propertyWrapperProjection"])
}
func superclassMethodExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func arrayLiteralItems() {
	if token.type = .ALT {
		arrayLiteralItem()
		// OPT
	} else if token.type = .ALT {
		arrayLiteralItem()
		// OPT
	}
	expect(["", "try"])
}
func subscriptExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["\\\\", "staticStringLiteral", "true", ".", "implicitParameterName", "super", "if", "_", "octalLiteral", "decimalFloatingPointLiteral", "switch", "self", "nil", "#keyPath", "propertyWrapperProjection", "regularExpressionLiteral", "false", "{", "(", "escapedIdentifier", "decimalLiteral", "hexadecimalFloatingPointLiteral", "[", "#fileLiteral", "#colorLiteral", "#imageLiteral", "hexadecimalLiteral", "plainIdentifier", "#selector", "binaryLiteral", "#", "interpolatedStringLiteral"])
}
func optionalPattern() {
	if token.type = .ALT {
		identifierPattern()
		next()
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "implicitParameterName"])
}
func arrayLiteralItem() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["try", ""])
}
func getterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func functionBody() {
	if token.type = .ALT {
		codeBlock()
		// END
	}
	expect(["{"])
}
func closureParameter() {
	if token.type = .ALT {
		closureParameterName()
		// OPT
	} else if token.type = .ALT {
		closureParameterName()
		// OPT
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "implicitParameterName", "escapedIdentifier"])
}
func metatypeType() {
	if token.type = .ALT {
		type()
		next()
	} else if token.type = .ALT {
		type()
		next()
	}
	expect(["plainIdentifier", "some", "@", "[", "Any", "escapedIdentifier", "Self", "propertyWrapperProjection", "(", "implicitParameterName", ""])
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
func switchElseifDirectiveClause() {
	if token.type = .ALT {
		elseifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#elseif"])
}
func lineControlStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#sourceLocation"])
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
	expect(["try", ""])
}
func typeInheritanceList() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func elseDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#else"])
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
func breakStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["break"])
}
func actorDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
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
	expect(["os", "compiler", "swift", "canImport", "arch", "targetEnvironment"])
}
func rawValueStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "plainIdentifier"])
}
func ifExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
}
func selfMethodExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func environment() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["simulator"])
}
func keyPathExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["\\\\"])
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
func switchExpressionCases() {
	if token.type = .ALT {
		switchExpressionCase()
		// OPT
	}
	expect(["@", ""])
}
func elementName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
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
func functionDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["", "@"])
}
func selfType() {
	if token.type = .ALT {
		next()
	}
	expect(["Self"])
}
func classDeclaration() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func extensionBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func balancedToken() {
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
	}
	expect(["("])
}
func macroDefinition() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func asPattern() {
	if token.type = .ALT {
		pattern()
		next()
	}
	expect(["is", "(", "try", "implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "let", "_", "", "var", "plainIdentifier"])
}
func arrayType() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
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
	expect(["@", ""])
}
func parameterTypeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
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
func variableName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func prefixExpression() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["dotOperator", "", "plainOperator"])
}
func inOutExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["&"])
}
func conditionalSwitchCase() {
	if token.type = .ALT {
		switchIfDirectiveClause()
		// OPT
	}
	expect(["#if"])
}
func tuplePatternElementList() {
	if token.type = .ALT {
		tuplePatternElement()
		// END
	} else if token.type = .ALT {
		tuplePatternElement()
		// END
	}
	expect(["try", "propertyWrapperProjection", "(", "implicitParameterName", "let", "", "_", "is", "escapedIdentifier", "plainIdentifier", "var"])
}
func optionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["plainIdentifier", "some", "@", "[", "Any", "escapedIdentifier", "Self", "propertyWrapperProjection", "(", "implicitParameterName", ""])
}
func setterName() {
	if token.type = .ALT {
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
func unionStyleEnumMembers() {
	if token.type = .ALT {
		unionStyleEnumMember()
		// OPT
	}
	expect(["#if", "precedencegroup", "#warning", "@", "infix", "#error", "", "prefix", "#sourceLocation", "postfix"])
}
func macroExpansionExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["#"])
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
func sameTypeRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection"])
}
func extensionDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func willSetDidSetBlock() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func genericWhereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func postfixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["postfix"])
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
func filePath() {
	if token.type = .ALT {
		next()
	}
	expect(["staticStringLiteral"])
}
func argumentName() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func caseItemList() {
	if token.type = .ALT {
		pattern()
		// OPT
	} else if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["is", "(", "try", "implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "let", "_", "", "var", "plainIdentifier"])
}
func tupleElementList() {
	if token.type = .ALT {
		tupleElement()
		// END
	} else if token.type = .ALT {
		tupleElement()
		// END
	}
	expect(["propertyWrapperProjection", "try", "", "plainIdentifier", "escapedIdentifier", "implicitParameterName"])
}
func constantDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
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
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
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
func protocolPropertyDeclaration() {
	if token.type = .ALT {
		variableDeclarationHead()
		variableName()
		typeAnnotation()
		getterSetterKeywordBlock()
		// END
	}
	expect(["", "@"])
}
func assignmentOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func willSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
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
func typeIdentifier() {
	if token.type = .ALT {
		typeName()
		// OPT
	} else if token.type = .ALT {
		typeName()
		// OPT
	}
	expect(["implicitParameterName", "escapedIdentifier", "plainIdentifier", "propertyWrapperProjection"])
}
func structMembers() {
	if token.type = .ALT {
		structMember()
		// OPT
	}
	expect(["#sourceLocation", "#error", "#warning", "postfix", "@", "", "infix", "precedencegroup", "prefix", "#if"])
}
func dictionaryType() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func conditionalOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["?"])
}
func continueStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["continue"])
}
func protocolCompositionType() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection"])
}
func functionCallArgumentList() {
	if token.type = .ALT {
		functionCallArgument()
		// END
	} else if token.type = .ALT {
		functionCallArgument()
		// END
	}
	expect(["dotOperator", "plainIdentifier", "escapedIdentifier", "", "propertyWrapperProjection", "plainOperator", "implicitParameterName", "try"])
}
func externalParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func actorName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func prefixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["dotOperator", "plainOperator"])
}
func parameterList() {
	if token.type = .ALT {
		parameter()
		// END
	} else if token.type = .ALT {
		parameter()
		// END
	}
	expect(["escapedIdentifier", "propertyWrapperProjection", "plainIdentifier", "implicitParameterName", ""])
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
	expect(["hexadecimalLiteral", "octalLiteral", "decimalFloatingPointLiteral", "decimalLiteral", "binaryLiteral", "hexadecimalFloatingPointLiteral"])
}
func actorMembers() {
	if token.type = .ALT {
		actorMember()
		// OPT
	}
	expect(["postfix", "#if", "infix", "#error", "#warning", "#sourceLocation", "prefix", "precedencegroup", "", "@"])
}
func isPattern() {
	if token.type = .ALT {
		next()
	}
	expect(["is"])
}
func genericArgument() {
	if token.type = .ALT {
		type()
		// END
	}
	expect(["plainIdentifier", "some", "@", "[", "Any", "escapedIdentifier", "Self", "propertyWrapperProjection", "(", "implicitParameterName", ""])
}
func precedenceGroupAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["assignment"])
}
func infixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["infix"])
}
func protocolDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func attributes() {
	if token.type = .ALT {
		attribute()
		// OPT
	}
	expect(["@"])
}
func innerBalancedTokens() {
	if token.type = .ALT {
		next()
	}
	expect(["innerBalancedToken"])
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
func dictionaryLiteralItems() {
	if token.type = .ALT {
		dictionaryLiteralItem()
		// OPT
	} else if token.type = .ALT {
		dictionaryLiteralItem()
		// OPT
	}
	expect(["try", ""])
}
func functionTypeArgument() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func functionType() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func protocolMethodDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["", "@"])
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
func keyPathComponent() {
	if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func ifExpressionTail() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
}
func booleanLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["true"])
}
func ifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#if"])
}
func labelName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func functionTypeArgumentClause() {
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
	expect(["infix", "prefix", "", "precedencegroup", "@", "postfix"])
}
func closureParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func importPath() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func tupleExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func protocolMembers() {
	if token.type = .ALT {
		protocolMember()
		// OPT
	}
	expect(["#warning", "#if", "", "#sourceLocation", "#error", "@"])
}
func elseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
}
func conditionList() {
	if token.type = .ALT {
		condition()
		// END
	} else if token.type = .ALT {
		condition()
		// END
	}
	expect(["", "#available", "try", "#unavailable", "var", "case", "let"])
}
func stringLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["staticStringLiteral"])
}
func statements() {
	if token.type = .ALT {
		statement()
		// OPT
	}
	expect(["repeat", "postfix", "propertyWrapperProjection", "guard", "do", "while", "throw", "#sourceLocation", "@", "continue", "if", "for", "precedencegroup", "try", "defer", "#if", "fallthrough", "escapedIdentifier", "plainIdentifier", "#warning", "switch", "", "prefix", "break", "infix", "return", "implicitParameterName", "#error"])
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
func enumCasePattern() {
	if token.type = .ALT {
		// OPT
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "plainIdentifier", "", "escapedIdentifier"])
}
func ifDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
}
func actorBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func deinitializerDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func codeBlock() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func infixExpressions() {
	if token.type = .ALT {
		infixExpression()
		// OPT
	}
	expect(["plainOperator", "=", "dotOperator", "?", "as", "is"])
}
func protocolInitializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["@", ""])
}
func enumDeclaration() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
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
func conditionalCompilationBlock() {
	if token.type = .ALT {
		ifDirectiveClause()
		// OPT
	}
	expect(["#if"])
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
func dictionaryLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["["])
}
func patternInitializer() {
	if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["is", "(", "try", "implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "let", "_", "", "var", "plainIdentifier"])
}
func rawValueStyleEnumCaseList() {
	if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	} else if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "escapedIdentifier", "plainIdentifier"])
}
func whileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["while"])
}
func elseifDirective() {
	if token.type = .ALT {
		next()
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
	expect(["propertyWrapperProjection", "@", "implicitParameterName", "escapedIdentifier", "plainIdentifier", ""])
}
func parenthesizedExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func switchElseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
}
func structDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func classMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["infix", "prefix", "", "precedencegroup", "@", "postfix"])
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
	expect(["@", ""])
}
func dictionaryLiteralItem() {
	if token.type = .ALT {
		expression()
		next()
	}
	expect(["try", ""])
}
func genericParameterList() {
	if token.type = .ALT {
		genericParameter()
		// END
	} else if token.type = .ALT {
		genericParameter()
		// END
	}
	expect(["implicitParameterName", "escapedIdentifier", "plainIdentifier", "propertyWrapperProjection"])
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
	expect(["@", ""])
}
func extensionMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["infix", "prefix", "", "precedencegroup", "@", "postfix"])
}
func selfSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func typeInheritanceClause() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func structBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func labeledTrailingClosures() {
	if token.type = .ALT {
		labeledTrailingClosure()
		// OPT
	}
	expect(["plainIdentifier", "escapedIdentifier", "propertyWrapperProjection", "implicitParameterName"])
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
func elseClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
}
func switchCases() {
	if token.type = .ALT {
		switchCase()
		// OPT
	}
	expect(["", "#if", "@"])
}
func protocolBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func catchClause() {
	if token.type = .ALT {
		next()
	}
	expect(["catch"])
}
func catchClauses() {
	if token.type = .ALT {
		catchClause()
		// OPT
	}
	expect(["catch"])
}
func opaqueType() {
	if token.type = .ALT {
		next()
	}
	expect(["some"])
}
func throwsClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["throws"])
}
func tupleType() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
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
	expect(["", "@"])
}
func patternInitializerList() {
	if token.type = .ALT {
		patternInitializer()
		// END
	} else if token.type = .ALT {
		patternInitializer()
		// END
	}
	expect(["let", "escapedIdentifier", "_", "(", "plainIdentifier", "", "implicitParameterName", "propertyWrapperProjection", "var", "try", "is"])
}
func elseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
}
func captureList() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func attributeArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func numericLiteral() {
	if token.type = .ALT {
		integerLiteral()
		// END
	} else if token.type = .ALT {
		integerLiteral()
		// END
	}
	expect(["hexadecimalLiteral", "binaryLiteral", "decimalLiteral", "octalLiteral"])
}
func protocolName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func macroHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func attribute() {
	if token.type = .ALT {
		next()
	}
	expect(["@"])
}
func extensionMembers() {
	if token.type = .ALT {
		extensionMember()
		// OPT
	}
	expect(["#error", "", "#warning", "prefix", "#sourceLocation", "infix", "postfix", "#if", "precedencegroup", "@"])
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
	expect(["implicitParameterName", "escapedIdentifier", "propertyWrapperProjection", "plainIdentifier"])
}
func platformVersion() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["decimalDigits"])
}
func whereExpression() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["try", ""])
}
func setterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func localParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func genericArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
}
func macroSignature() {
	if token.type = .ALT {
		parameterClause()
		// OPT
	}
	expect(["("])
}
func functionName() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func protocolMember() {
	if token.type = .ALT {
		protocolMemberDeclaration()
		// END
	} else if token.type = .ALT {
		protocolMemberDeclaration()
		// END
	}
	expect(["@", ""])
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
func selfInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func diagnosticStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#warning"])
}
func protocolAssociatedTypeDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func initializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["@", ""])
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
	expect(["try", ""])
}
func precedenceGroupNames() {
	if token.type = .ALT {
		precedenceGroupName()
		// END
	} else if token.type = .ALT {
		precedenceGroupName()
		// END
	}
	expect(["implicitParameterName", "plainIdentifier", "escapedIdentifier", "propertyWrapperProjection"])
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
func switchExpression() {
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
func trailingClosures() {
	if token.type = .ALT {
		closureExpression()
		// OPT
	}
	expect(["{"])
}
func endifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#endif"])
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
func didSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func rawValueStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
