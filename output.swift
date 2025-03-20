//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"binaryLiteral":	("/-?0b[0-1][0-1_]*/",	/-?0b[0-1][0-1_]*/,	false,	false),
	"extendedMultilineStringLiteral":	("/#+\"\"\"(?s).*?\"\"\"#+/",	/#+"""(?s).*?"""#+/,	false,	false),
	"multilineStringLiteral":	("/\"\"\"(?:\\\\#*\\([^)]*\\)|\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]+\\}|\\\\#*\\s*\\n|[^\\\\])*\"\"\"/",	/"""(?:\\#*\([^)]*\)|\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]+\}|\\#*\s*\n|[^\\])*"""/,	false,	false),
	"macroIdentifier":	("/#\\p{XID_Start}\\p{XID_Continue}*/",	/#\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"dotOperator":	("/\\.[\\.\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]+/",	/\.[\.\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]+/,	false,	false),
	"propertyWrapperProjection":	("/\\$\\p{XID_Continue}+/",	/\$\p{XID_Continue}+/,	false,	false),
	"extendedRegularExpressionLiteral":	("/#+\\/(?:[^\\/\\\\]|\\\\.)+\\/#+/",	/#+\/(?:[^\/\\]|\\.)+\/#+/,	false,	false),
	"decimalFloatingPointLiteral":	("/-?[0-9][0-9_]*(?:\\.[0-9][0-9_]*)(?:[eE][+-]?[0-9][0-9_]*)?/",	/-?[0-9][0-9_]*(?:\.[0-9][0-9_]*)(?:[eE][+-]?[0-9][0-9_]*)?/,	false,	false),
	"escapedIdentifier":	("/`\\p{XID_Start}\\p{XID_Continue}*`/",	/`\p{XID_Start}\p{XID_Continue}*`/,	false,	false),
	"plainIdentifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"decimalNumber":	("/-?[0-9][0-9_]*/",	/-?[0-9][0-9_]*/,	false,	false),
	"singlelineStringLiteral":	("/\"(?:(?:[^\\\\\"]+)|(?:\\\\\\([^\\\\\\)]+\\))|(?:\\\\u\\{[0-9a-fA-F]+\\})|(?:\\\\[0\\\\tnr\"\']))*\"/",	/"(?:(?:[^\\"]+)|(?:\\\([^\\\)]+\))|(?:\\u\{[0-9a-fA-F]+\})|(?:\\[0\\tnr"']))*"/,	false,	false),
	"hexadecimalLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*/,	false,	false),
	"octalLiteral":	("/-?0o[0-7][0-7_]*/",	/-?0o[0-7][0-7_]*/,	false,	false),
	"plainRegularExpressionLiteral":	("/\\/(?:[^\\/\\\\\\n]|\\\\.)+\\//",	/\/(?:[^\/\\\n]|\\.)+\//,	false,	false),
	"comment":	("/\\/\\/.*\\r?\\n?/",	/\/\/.*\r?\n?/,	false,	true),
	"multilineComment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"hexadecimalFloatingPointLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/,	false,	false),
	"plainOperator":	("/[\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}][\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]*/",	/[\/=+\-*%!&|^~?<>\p{Sm}\p{So}][\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]*/,	false,	false),
	"extendedSinglelineStringLiteral":	("/#+\".*?\"#+/",	/#+".*?"#+/,	false,	false),
	"implicitParameterName":	("/\\$[0-9]+/",	/\$[0-9]+/,	false,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"tvOSApplicationExtension":	("tvOSApplicationExtension",	Regex { "tvOSApplicationExtension" },	true,	false),
	"operator":	("operator",	Regex { "operator" },	true,	false),
	"protocol":	("protocol",	Regex { "protocol" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"targetEnvironment":	("targetEnvironment",	Regex { "targetEnvironment" },	true,	false),
	"self":	("self",	Regex { "self" },	true,	false),
	"override":	("override",	Regex { "override" },	true,	false),
	"optional":	("optional",	Regex { "optional" },	true,	false),
	"!":	("!",	Regex { "!" },	true,	false),
	"&&":	("&&",	Regex { "&&" },	true,	false),
	"each":	("each",	Regex { "each" },	true,	false),
	"deinit":	("deinit",	Regex { "deinit" },	true,	false),
	"mutating":	("mutating",	Regex { "mutating" },	true,	false),
	"\\":	("\\",	Regex { "\\" },	true,	false),
	"os":	("os",	Regex { "os" },	true,	false),
	"dynamic":	("dynamic",	Regex { "dynamic" },	true,	false),
	"^":	("^",	Regex { "^" },	true,	false),
	"in":	("in",	Regex { "in" },	true,	false),
	"struct":	("struct",	Regex { "struct" },	true,	false),
	"any":	("any",	Regex { "any" },	true,	false),
	"#else":	("#else",	Regex { "#else" },	true,	false),
	"swift":	("swift",	Regex { "swift" },	true,	false),
	"line:":	("line:",	Regex { "line:" },	true,	false),
	"willSet":	("willSet",	Regex { "willSet" },	true,	false),
	"fallthrough":	("fallthrough",	Regex { "fallthrough" },	true,	false),
	"lowerThan":	("lowerThan",	Regex { "lowerThan" },	true,	false),
	"switch":	("switch",	Regex { "switch" },	true,	false),
	"macCatalyst":	("macCatalyst",	Regex { "macCatalyst" },	true,	false),
	"arm":	("arm",	Regex { "arm" },	true,	false),
	"resourceName":	("resourceName",	Regex { "resourceName" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"throw":	("throw",	Regex { "throw" },	true,	false),
	"none":	("none",	Regex { "none" },	true,	false),
	"left":	("left",	Regex { "left" },	true,	false),
	"required":	("required",	Regex { "required" },	true,	false),
	"-":	("-",	Regex { "-" },	true,	false),
	"didSet":	("didSet",	Regex { "didSet" },	true,	false),
	"as":	("as",	Regex { "as" },	true,	false),
	"safe":	("safe",	Regex { "safe" },	true,	false),
	"#keyPath":	("#keyPath",	Regex { "#keyPath" },	true,	false),
	"some":	("some",	Regex { "some" },	true,	false),
	"func":	("func",	Regex { "func" },	true,	false),
	"~":	("~",	Regex { "~" },	true,	false),
	"move":	("move",	Regex { "move" },	true,	false),
	"iOSApplicationExtension":	("iOSApplicationExtension",	Regex { "iOSApplicationExtension" },	true,	false),
	"watchOS":	("watchOS",	Regex { "watchOS" },	true,	false),
	"#":	("#",	Regex { "#" },	true,	false),
	"#endif":	("#endif",	Regex { "#endif" },	true,	false),
	"alpha":	("alpha",	Regex { "alpha" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"infix":	("infix",	Regex { "infix" },	true,	false),
	"x86_64":	("x86_64",	Regex { "x86_64" },	true,	false),
	"var":	("var",	Regex { "var" },	true,	false),
	"==":	("==",	Regex { "==" },	true,	false),
	"getter:":	("getter:",	Regex { "getter:" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"isolated":	("isolated",	Regex { "isolated" },	true,	false),
	"while":	("while",	Regex { "while" },	true,	false),
	"tvOS":	("tvOS",	Regex { "tvOS" },	true,	false),
	"case":	("case",	Regex { "case" },	true,	false),
	"return":	("return",	Regex { "return" },	true,	false),
	"watchOSApplicationExtension":	("watchOSApplicationExtension",	Regex { "watchOSApplicationExtension" },	true,	false),
	"Self":	("Self",	Regex { "Self" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	"discard":	("discard",	Regex { "discard" },	true,	false),
	"higherThan":	("higherThan",	Regex { "higherThan" },	true,	false),
	"iOS":	("iOS",	Regex { "iOS" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"get":	("get",	Regex { "get" },	true,	false),
	"associativity":	("associativity",	Regex { "associativity" },	true,	false),
	"postfix":	("postfix",	Regex { "postfix" },	true,	false),
	"enum":	("enum",	Regex { "enum" },	true,	false),
	",":	(",",	Regex { "," },	true,	false),
	"nil":	("nil",	Regex { "nil" },	true,	false),
	"#error":	("#error",	Regex { "#error" },	true,	false),
	"arch":	("arch",	Regex { "arch" },	true,	false),
	"weak":	("weak",	Regex { "weak" },	true,	false),
	"&":	("&",	Regex { "&" },	true,	false),
	"true":	("true",	Regex { "true" },	true,	false),
	"try":	("try",	Regex { "try" },	true,	false),
	"rethrows":	("rethrows",	Regex { "rethrows" },	true,	false),
	"default":	("default",	Regex { "default" },	true,	false),
	"#sourceLocation":	("#sourceLocation",	Regex { "#sourceLocation" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"unowned(safe)":	("unowned(safe)",	Regex { "unowned(safe)" },	true,	false),
	"static":	("static",	Regex { "static" },	true,	false),
	"let":	("let",	Regex { "let" },	true,	false),
	"macOSApplicationExtension":	("macOSApplicationExtension",	Regex { "macOSApplicationExtension" },	true,	false),
	"arm64":	("arm64",	Regex { "arm64" },	true,	false),
	"_":	("_",	Regex { "_" },	true,	false),
	"green":	("green",	Regex { "green" },	true,	false),
	"async":	("async",	Regex { "async" },	true,	false),
	"i386":	("i386",	Regex { "i386" },	true,	false),
	"macCatalystApplicationExtension":	("macCatalystApplicationExtension",	Regex { "macCatalystApplicationExtension" },	true,	false),
	"_unsafeInheritExecutor":	("_unsafeInheritExecutor",	Regex { "_unsafeInheritExecutor" },	true,	false),
	"convenience":	("convenience",	Regex { "convenience" },	true,	false),
	"Any":	("Any",	Regex { "Any" },	true,	false),
	"#if":	("#if",	Regex { "#if" },	true,	false),
	"#colorLiteral":	("#colorLiteral",	Regex { "#colorLiteral" },	true,	false),
	"nonisolated":	("nonisolated",	Regex { "nonisolated" },	true,	false),
	"setter:":	("setter:",	Regex { "setter:" },	true,	false),
	"blue":	("blue",	Regex { "blue" },	true,	false),
	"macro":	("macro",	Regex { "macro" },	true,	false),
	"canImport":	("canImport",	Regex { "canImport" },	true,	false),
	"#imageLiteral":	("#imageLiteral",	Regex { "#imageLiteral" },	true,	false),
	"import":	("import",	Regex { "import" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	">=":	(">=",	Regex { ">=" },	true,	false),
	";":	(";",	Regex { ";" },	true,	false),
	"right":	("right",	Regex { "right" },	true,	false),
	"Windows":	("Windows",	Regex { "Windows" },	true,	false),
	"red":	("red",	Regex { "red" },	true,	false),
	"file:":	("file:",	Regex { "file:" },	true,	false),
	"visionOSApplicationExtension":	("visionOSApplicationExtension",	Regex { "visionOSApplicationExtension" },	true,	false),
	"simulator":	("simulator",	Regex { "simulator" },	true,	false),
	"Type":	("Type",	Regex { "Type" },	true,	false),
	"#fileLiteral":	("#fileLiteral",	Regex { "#fileLiteral" },	true,	false),
	"for":	("for",	Regex { "for" },	true,	false),
	"#unavailable":	("#unavailable",	Regex { "#unavailable" },	true,	false),
	"indirect":	("indirect",	Regex { "indirect" },	true,	false),
	"repeat":	("repeat",	Regex { "repeat" },	true,	false),
	"assignment":	("assignment",	Regex { "assignment" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	"catch":	("catch",	Regex { "catch" },	true,	false),
	"class":	("class",	Regex { "class" },	true,	false),
	"super":	("super",	Regex { "super" },	true,	false),
	"lazy":	("lazy",	Regex { "lazy" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"typealias":	("typealias",	Regex { "typealias" },	true,	false),
	"throws":	("throws",	Regex { "throws" },	true,	false),
	"open":	("open",	Regex { "open" },	true,	false),
	"#elseif":	("#elseif",	Regex { "#elseif" },	true,	false),
	"inout":	("inout",	Regex { "inout" },	true,	false),
	"subscript":	("subscript",	Regex { "subscript" },	true,	false),
	"is":	("is",	Regex { "is" },	true,	false),
	"await":	("await",	Regex { "await" },	true,	false),
	"compiler":	("compiler",	Regex { "compiler" },	true,	false),
	"/":	("/",	Regex { "/" },	true,	false),
	"unowned(unsafe)":	("unowned(unsafe)",	Regex { "unowned(unsafe)" },	true,	false),
	"borrowing":	("borrowing",	Regex { "borrowing" },	true,	false),
	"fileprivate":	("fileprivate",	Regex { "fileprivate" },	true,	false),
	"consuming":	("consuming",	Regex { "consuming" },	true,	false),
	"unsafe":	("unsafe",	Regex { "unsafe" },	true,	false),
	"else":	("else",	Regex { "else" },	true,	false),
	"private":	("private",	Regex { "private" },	true,	false),
	"where":	("where",	Regex { "where" },	true,	false),
	"Linux":	("Linux",	Regex { "Linux" },	true,	false),
	"do":	("do",	Regex { "do" },	true,	false),
	"public":	("public",	Regex { "public" },	true,	false),
	"guard":	("guard",	Regex { "guard" },	true,	false),
	"associatedtype":	("associatedtype",	Regex { "associatedtype" },	true,	false),
	"@":	("@",	Regex { "@" },	true,	false),
	"break":	("break",	Regex { "break" },	true,	false),
	"defer":	("defer",	Regex { "defer" },	true,	false),
	"precedencegroup":	("precedencegroup",	Regex { "precedencegroup" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"Protocol":	("Protocol",	Regex { "Protocol" },	true,	false),
	"final":	("final",	Regex { "final" },	true,	false),
	"...":	("...",	Regex { "..." },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"#selector":	("#selector",	Regex { "#selector" },	true,	false),
	"set":	("set",	Regex { "set" },	true,	false),
	"init":	("init",	Regex { "init" },	true,	false),
	"||":	("||",	Regex { "||" },	true,	false),
	"extension":	("extension",	Regex { "extension" },	true,	false),
	"if":	("if",	Regex { "if" },	true,	false),
	"#warning":	("#warning",	Regex { "#warning" },	true,	false),
	"package":	("package",	Regex { "package" },	true,	false),
	"continue":	("continue",	Regex { "continue" },	true,	false),
	"actor":	("actor",	Regex { "actor" },	true,	false),
	"visionOS":	("visionOS",	Regex { "visionOS" },	true,	false),
	"prefix":	("prefix",	Regex { "prefix" },	true,	false),
	"yield":	("yield",	Regex { "yield" },	true,	false),
	"internal":	("internal",	Regex { "internal" },	true,	false),
	"nonmutating":	("nonmutating",	Regex { "nonmutating" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"%":	("%",	Regex { "%" },	true,	false),
	"unowned":	("unowned",	Regex { "unowned" },	true,	false),
	"copy":	("copy",	Regex { "copy" },	true,	false),
	"#available":	("#available",	Regex { "#available" },	true,	false),
	"macOS":	("macOS",	Regex { "macOS" },	true,	false),
	"false":	("false",	Regex { "false" },	true,	false),
]
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
func conditionalOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["?"])
}
func conditionalCompilationBlock() {
	if token.type = .ALT {
		ifDirectiveClause()
		// OPT
	}
	expect(["#if"])
}
func trailingClosures() {
	if token.type = .ALT {
		closureExpression()
		// OPT
	}
	expect(["{"])
}
func postfixSelfExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["binaryLiteral", "extendedSinglelineStringLiteral", "self", "_", "implicitParameterName", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "super", ".", "\\\\", "octalLiteral", "#keyPath", "#fileLiteral", "[", "singlelineStringLiteral", "decimalFloatingPointLiteral", "false", "decimalNumber", "macroIdentifier", "(", "hexadecimalLiteral", "nil", "hexadecimalFloatingPointLiteral", "escapedIdentifier", "true", "extendedMultilineStringLiteral", "plainIdentifier", "#imageLiteral", "#colorLiteral", "multilineStringLiteral", "{", "switch", "if", "#selector", "plainRegularExpressionLiteral"])
}
func decimalDigits() {
	if token.type = .ALT {
		next()
	}
	expect(["decimalNumber"])
}
func protocolName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func protocolPropertyDeclaration() {
	if token.type = .ALT {
		variableDeclarationHead()
		variableName()
		typeAnnotation()
		getterSetterKeywordBlock()
		// END
	}
	expect(["fileprivate", "dynamic", "var", "override", "private", "lazy", "class", "@", "static", "internal", "nonisolated", "prefix", "nonmutating", "public", "unowned", "convenience", "optional", "mutating", "postfix", "package", "open", "infix", "weak", "required", "final"])
}
func macroDefinition() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func genericArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
}
func keyPathExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["\\\\"])
}
func captureList() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
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
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func whereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func switchElseifDirectiveClause() {
	if token.type = .ALT {
		elseifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#elseif"])
}
func parameterTypeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func initializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["postfix", "internal", "private", "class", "nonisolated", "nonmutating", "convenience", "open", "override", "weak", "unowned", "prefix", "mutating", "required", "init", "final", "public", "fileprivate", "static", "optional", "lazy", "@", "dynamic", "infix", "package"])
}
func protocolCompositionContinuation() {
	if token.type = .ALT {
		typeIdentifier()
		// END
	} else if token.type = .ALT {
		typeIdentifier()
		// END
	}
	expect(["plainIdentifier", "implicitParameterName", "_", "propertyWrapperProjection", "escapedIdentifier"])
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
	expect(["if", ".", "extendedSinglelineStringLiteral", "_", "try", "plainRegularExpressionLiteral", "#colorLiteral", "decimalFloatingPointLiteral", "propertyWrapperProjection", "plainOperator", "escapedIdentifier", "dotOperator", "\\\\", "switch", "#selector", "binaryLiteral", "extendedMultilineStringLiteral", "[", "#fileLiteral", "extendedRegularExpressionLiteral", "self", "&", "singlelineStringLiteral", "true", "nil", "hexadecimalLiteral", "#imageLiteral", "implicitParameterName", "hexadecimalFloatingPointLiteral", "macroIdentifier", "plainIdentifier", "#keyPath", "{", "(", "await", "octalLiteral", "false", "multilineStringLiteral", "decimalNumber", "super"])
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
func functionDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["infix", "postfix", "nonmutating", "lazy", "mutating", "prefix", "required", "fileprivate", "package", "private", "@", "static", "internal", "weak", "optional", "final", "override", "dynamic", "unowned", "convenience", "nonisolated", "class", "open", "public", "func"])
}
func actorIsolationModifier() {
	if token.type = .ALT {
		next()
	}
	expect(["nonisolated"])
}
func switchExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["switch"])
}
func enumDeclaration() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["enum", "fileprivate", "internal", "public", "private", "open", "package", "indirect", "@"])
}
func regularExpressionLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["plainRegularExpressionLiteral"])
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
func whereExpression() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["if", ".", "extendedSinglelineStringLiteral", "_", "try", "plainRegularExpressionLiteral", "#colorLiteral", "decimalFloatingPointLiteral", "propertyWrapperProjection", "plainOperator", "escapedIdentifier", "dotOperator", "\\\\", "switch", "#selector", "binaryLiteral", "extendedMultilineStringLiteral", "[", "#fileLiteral", "extendedRegularExpressionLiteral", "self", "&", "singlelineStringLiteral", "true", "nil", "hexadecimalLiteral", "#imageLiteral", "implicitParameterName", "hexadecimalFloatingPointLiteral", "macroIdentifier", "plainIdentifier", "#keyPath", "{", "(", "await", "octalLiteral", "false", "multilineStringLiteral", "decimalNumber", "super"])
}
func switchIfDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
}
func initializerBody() {
	if token.type = .ALT {
		codeBlock()
		// END
	}
	expect(["{"])
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
	expect(["@", "import"])
}
func deinitializerDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "deinit"])
}
func sameTypeRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "implicitParameterName", "_", "propertyWrapperProjection", "escapedIdentifier"])
}
func catchClauses() {
	if token.type = .ALT {
		catchClause()
		// OPT
	}
	expect(["catch"])
}
func importDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "import"])
}
func structName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func functionTypeArgumentClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func attributeArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func typeInheritanceClause() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func keyPathComponents() {
	if token.type = .ALT {
		keyPathComponent()
		// END
	} else if token.type = .ALT {
		keyPathComponent()
		// END
	}
	expect(["!", "_", "?", "plainIdentifier", "escapedIdentifier", "self", "[", "implicitParameterName", "propertyWrapperProjection"])
}
func getterSetterKeywordBlock() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
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
func lineControlStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#sourceLocation"])
}
func closureExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func deferStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["defer"])
}
func typealiasName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func precedenceGroupDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["precedencegroup"])
}
func filePath() {
	if token.type = .ALT {
		staticStringLiteral()
		// END
	}
	expect(["multilineStringLiteral", "extendedSinglelineStringLiteral", "extendedMultilineStringLiteral", "singlelineStringLiteral"])
}
func rawValueAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
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
	expect(["tvOS", "macOS", "iOS", "watchOSApplicationExtension", "visionOS", "macCatalystApplicationExtension", "tvOSApplicationExtension", "visionOSApplicationExtension", "iOSApplicationExtension", "macOSApplicationExtension", "macCatalyst", "watchOS"])
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
func opaqueType() {
	if token.type = .ALT {
		next()
	}
	expect(["some"])
}
func extensionDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["open", "public", "fileprivate", "package", "extension", "@", "internal", "private"])
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
	expect(["override", "nonmutating", "convenience", "fileprivate", "package", "private", "@", "prefix", "struct", "subscript", "extension", "unowned", "optional", "deinit", "import", "final", "required", "mutating", "weak", "precedencegroup", "postfix", "enum", "public", "var", "static", "lazy", "dynamic", "typealias", "let", "nonisolated", "internal", "open", "class", "protocol", "actor", "indirect", "infix", "init", "func"])
}
func functionTypeArgument() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["some", "@", "escapedIdentifier", "Self", "Any", "implicitParameterName", "plainIdentifier", "inout", "propertyWrapperProjection", "(", "_", "["])
}
func arrayLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func tuplePatternElementList() {
	if token.type = .ALT {
		tuplePatternElement()
		// END
	} else if token.type = .ALT {
		tuplePatternElement()
		// END
	}
	expect(["let", "escapedIdentifier", "#keyPath", "extendedMultilineStringLiteral", "plainRegularExpressionLiteral", "self", "#colorLiteral", ".", "await", "multilineStringLiteral", "switch", "macroIdentifier", "#fileLiteral", "extendedRegularExpressionLiteral", "plainIdentifier", "true", "#selector", "is", "#imageLiteral", "{", "_", "dotOperator", "super", "hexadecimalFloatingPointLiteral", "(", "nil", "[", "false", "octalLiteral", "var", "implicitParameterName", "decimalNumber", "decimalFloatingPointLiteral", "try", "singlelineStringLiteral", "&", "plainOperator", "propertyWrapperProjection", "\\\\", "binaryLiteral", "hexadecimalLiteral", "extendedSinglelineStringLiteral", "if"])
}
func protocolSubscriptDeclaration() {
	if token.type = .ALT {
		subscriptHead()
		subscriptResult()
		// OPT
	}
	expect(["dynamic", "mutating", "lazy", "@", "subscript", "fileprivate", "override", "unowned", "optional", "final", "postfix", "class", "private", "prefix", "convenience", "static", "open", "nonisolated", "internal", "weak", "nonmutating", "package", "public", "required", "infix"])
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
func typealiasAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func balancedTokens() {
	if token.type = .ALT {
		balancedToken()
		// OPT
	}
	expect(["subscript", "try", "copy", "where", "nonisolated", "singlelineStringLiteral", "(", "{", "defer", "borrowing", "dynamic", "propertyWrapperProjection", "higherThan", ":", "implicitParameterName", "decimalNumber", "plainOperator", "package", "prefix", ">", "self", "#unavailable", "do", "false", "~", "async", "associativity", "extendedMultilineStringLiteral", "extendedRegularExpressionLiteral", "import", "static", "catch", "true", "Self", "switch", "protocol", "!", "willSet", "%", "var", "#warning", "init", "operator", "_", "override", "#else", "public", "required", "#selector", "rethrows", "lazy", "@", "optional", "some", "yield", "binaryLiteral", "^", "fileprivate", "private", "Any", "extendedSinglelineStringLiteral", "unowned", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "|", "isolated", ";", "return", "consuming", "-", "/", "multilineStringLiteral", "#endif", "#imageLiteral", "await", "throw", "#fileLiteral", "for", "while", "_unsafeInheritExecutor", "typealias", "in", "#elseif", "plainRegularExpressionLiteral", "get", "none", "mutating", "+", "&", "indirect", "set", "left", "repeat", "weak", "plainIdentifier", "?", ".", "actor", "postfix", "final", "else", "super", "open", "throws", "didSet", ",", "*", "lowerThan", "hexadecimalLiteral", "discard", "class", "each", "#", "break", "inout", "octalLiteral", "#sourceLocation", "#available", "func", "as", "guard", "#keyPath", "=", "default", "#error", "nil", "dotOperator", "nonmutating", "#if", "<", "internal", "continue", "if", "struct", "precedencegroup", "deinit", "fallthrough", "case", "#colorLiteral", "associatedtype", "extension", "let", "escapedIdentifier", "[", "is", "right", "convenience", "enum", "move"])
}
func interpolatedStringLiteral() {
	if token.type = .ALT {
		stringLiteral()
		// END
	}
	expect(["extendedMultilineStringLiteral", "singlelineStringLiteral", "multilineStringLiteral", "extendedSinglelineStringLiteral"])
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
	expect(["propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "_", "implicitParameterName"])
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
func protocolBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func infixOperatorGroup() {
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
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func switchElseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
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
	expect(["plainIdentifier", "implicitParameterName", "_", "propertyWrapperProjection", "escapedIdentifier"])
}
func subscriptResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func labelName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
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
	expect(["_", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier", "plainIdentifier"])
}
func classMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["override", "nonmutating", "convenience", "fileprivate", "package", "private", "@", "prefix", "struct", "subscript", "extension", "unowned", "optional", "deinit", "import", "final", "required", "mutating", "weak", "precedencegroup", "postfix", "enum", "public", "var", "static", "lazy", "dynamic", "typealias", "let", "nonisolated", "internal", "open", "class", "protocol", "actor", "indirect", "infix", "init", "func"])
}
func rawValueStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "case"])
}
func protocolMethodDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["infix", "postfix", "nonmutating", "lazy", "mutating", "prefix", "required", "fileprivate", "package", "private", "@", "static", "internal", "weak", "optional", "final", "override", "dynamic", "unowned", "convenience", "nonisolated", "class", "open", "public", "func"])
}
func extensionMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["override", "nonmutating", "convenience", "fileprivate", "package", "private", "@", "prefix", "struct", "subscript", "extension", "unowned", "optional", "deinit", "import", "final", "required", "mutating", "weak", "precedencegroup", "postfix", "enum", "public", "var", "static", "lazy", "dynamic", "typealias", "let", "nonisolated", "internal", "open", "class", "protocol", "actor", "indirect", "infix", "init", "func"])
}
func precedenceGroupAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["assignment"])
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
func enumCasePattern() {
	if token.type = .ALT {
		// OPT
	}
	expect(["_", ".", "plainIdentifier", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier"])
}
func selfMethodExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func arrayLiteralItems() {
	if token.type = .ALT {
		arrayLiteralItem()
		// OPT
	} else if token.type = .ALT {
		arrayLiteralItem()
		// OPT
	}
	expect(["self", "decimalNumber", "#colorLiteral", "extendedMultilineStringLiteral", "extendedRegularExpressionLiteral", "escapedIdentifier", "hexadecimalLiteral", "[", "plainOperator", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "(", "plainRegularExpressionLiteral", "binaryLiteral", "multilineStringLiteral", "await", "true", "_", "implicitParameterName", "nil", "{", "extendedSinglelineStringLiteral", "#selector", "macroIdentifier", "dotOperator", "#imageLiteral", "#keyPath", "false", "\\\\", "singlelineStringLiteral", "#fileLiteral", "&", "super", "switch", "if", "octalLiteral", ".", "propertyWrapperProjection", "try", "plainIdentifier"])
}
func tupleTypeElementList() {
	if token.type = .ALT {
		tupleTypeElement()
		// END
	} else if token.type = .ALT {
		tupleTypeElement()
		// END
	}
	expect(["some", "Self", "escapedIdentifier", "@", "propertyWrapperProjection", "(", "_", "Any", "implicitParameterName", "plainIdentifier", "["])
}
func requirement() {
	if token.type = .ALT {
		conformanceRequirement()
		// END
	} else if token.type = .ALT {
		conformanceRequirement()
		// END
	}
	expect(["propertyWrapperProjection", "_", "implicitParameterName", "plainIdentifier", "escapedIdentifier"])
}
func functionType() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "("])
}
func keyPathStringExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["#keyPath"])
}
func closureParameter() {
	if token.type = .ALT {
		closureParameterName()
		// OPT
	} else if token.type = .ALT {
		closureParameterName()
		// OPT
	}
	expect(["_", "propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "implicitParameterName"])
}
func initializerExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	} else if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["binaryLiteral", "extendedSinglelineStringLiteral", "self", "_", "implicitParameterName", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "super", ".", "\\\\", "octalLiteral", "#keyPath", "#fileLiteral", "[", "singlelineStringLiteral", "decimalFloatingPointLiteral", "false", "decimalNumber", "macroIdentifier", "(", "hexadecimalLiteral", "nil", "hexadecimalFloatingPointLiteral", "escapedIdentifier", "true", "extendedMultilineStringLiteral", "plainIdentifier", "#imageLiteral", "#colorLiteral", "multilineStringLiteral", "{", "switch", "if", "#selector", "plainRegularExpressionLiteral"])
}
func rawValueStyleEnumCaseList() {
	if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	} else if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	}
	expect(["implicitParameterName", "escapedIdentifier", "_", "propertyWrapperProjection", "plainIdentifier"])
}
func elseDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#else"])
}
func protocolInitializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["postfix", "internal", "private", "class", "nonisolated", "nonmutating", "convenience", "open", "override", "weak", "unowned", "prefix", "mutating", "required", "init", "final", "public", "fileprivate", "static", "optional", "lazy", "@", "dynamic", "infix", "package"])
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
	expect(["optional", "required", "internal", "package", "unowned", "@", "override", "open", "lazy", "nonmutating", "weak", "nonisolated", "infix", "postfix", "class", "private", "var", "prefix", "dynamic", "convenience", "public", "final", "mutating", "static", "fileprivate"])
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
func classBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func Operator() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["plainOperator"])
}
func superclassMethodExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func arrayLiteralItem() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["if", ".", "extendedSinglelineStringLiteral", "_", "try", "plainRegularExpressionLiteral", "#colorLiteral", "decimalFloatingPointLiteral", "propertyWrapperProjection", "plainOperator", "escapedIdentifier", "dotOperator", "\\\\", "switch", "#selector", "binaryLiteral", "extendedMultilineStringLiteral", "[", "#fileLiteral", "extendedRegularExpressionLiteral", "self", "&", "singlelineStringLiteral", "true", "nil", "hexadecimalLiteral", "#imageLiteral", "implicitParameterName", "hexadecimalFloatingPointLiteral", "macroIdentifier", "plainIdentifier", "#keyPath", "{", "(", "await", "octalLiteral", "false", "multilineStringLiteral", "decimalNumber", "super"])
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
func stringLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["singlelineStringLiteral"])
}
func forInStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["for"])
}
func functionBody() {
	if token.type = .ALT {
		codeBlock()
		// END
	}
	expect(["{"])
}
func didSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["didSet", "@"])
}
func parameterList() {
	if token.type = .ALT {
		parameter()
		// END
	} else if token.type = .ALT {
		parameter()
		// END
	}
	expect(["escapedIdentifier", "propertyWrapperProjection", "implicitParameterName", "plainIdentifier", "_"])
}
func whileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["while"])
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
	expect(["if", ".", "extendedSinglelineStringLiteral", "_", "try", "plainRegularExpressionLiteral", "#colorLiteral", "decimalFloatingPointLiteral", "propertyWrapperProjection", "plainOperator", "escapedIdentifier", "dotOperator", "\\\\", "switch", "#selector", "binaryLiteral", "extendedMultilineStringLiteral", "[", "#fileLiteral", "extendedRegularExpressionLiteral", "self", "&", "singlelineStringLiteral", "true", "nil", "hexadecimalLiteral", "#imageLiteral", "implicitParameterName", "hexadecimalFloatingPointLiteral", "macroIdentifier", "plainIdentifier", "#keyPath", "{", "(", "await", "octalLiteral", "false", "multilineStringLiteral", "decimalNumber", "super"])
}
func swiftVersion() {
	if token.type = .ALT {
		decimalDigits()
		// OPT
	}
	expect(["decimalNumber"])
}
func assignmentOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func dictionaryLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["["])
}
func argumentName() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func externalParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
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
	expect(["binaryLiteral", "octalLiteral", "hexadecimalLiteral", "decimalFloatingPointLiteral", "hexadecimalFloatingPointLiteral", "decimalNumber"])
}
func structMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["override", "nonmutating", "convenience", "fileprivate", "package", "private", "@", "prefix", "struct", "subscript", "extension", "unowned", "optional", "deinit", "import", "final", "required", "mutating", "weak", "precedencegroup", "postfix", "enum", "public", "var", "static", "lazy", "dynamic", "typealias", "let", "nonisolated", "internal", "open", "class", "protocol", "actor", "indirect", "infix", "init", "func"])
}
func prefixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["prefix"])
}
func conformanceRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	} else if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "implicitParameterName", "_", "propertyWrapperProjection", "escapedIdentifier"])
}
func arrayType() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func anyType() {
	if token.type = .ALT {
		next()
	}
	expect(["Any"])
}
func macroFunctionSignatureResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func infixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["infix"])
}
func attributes() {
	if token.type = .ALT {
		attribute()
		// OPT
	}
	expect(["@"])
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
	expect(["propertyWrapperProjection", "escapedIdentifier", "implicitParameterName", "_", "plainIdentifier"])
}
func diagnosticStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#warning"])
}
func willSetDidSetBlock() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func swiftVersionContinuation() {
	if token.type = .ALT {
		next()
	}
	expect(["."])
}
func keyPathPostfixes() {
	if token.type = .ALT {
		keyPathPostfix()
		// OPT
	}
	expect(["self", "[", "?", "!"])
}
func genericArgumentList() {
	if token.type = .ALT {
		genericArgument()
		// END
	} else if token.type = .ALT {
		genericArgument()
		// END
	}
	expect(["implicitParameterName", "Self", "plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "Any", "@", "(", "_", "[", "some"])
}
func metatypeType() {
	if token.type = .ALT {
		type()
		next()
	} else if token.type = .ALT {
		type()
		next()
	}
	expect(["plainIdentifier", "implicitParameterName", "_", "escapedIdentifier", "Self", "some", "propertyWrapperProjection", "@", "[", "Any", "("])
}
func unionStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["case", "@", "indirect"])
}
func switchExpressionCases() {
	if token.type = .ALT {
		switchExpressionCase()
		// OPT
	}
	expect(["@", "default", "case"])
}
func classDeclaration() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["internal", "private", "class", "final", "package", "@", "fileprivate", "open", "public"])
}
func protocolDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["public", "internal", "@", "private", "open", "fileprivate", "package", "protocol"])
}
func selfInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func availabilityCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#available"])
}
func elementName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func guardStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["guard"])
}
func typeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func postfixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["plainOperator", "dotOperator"])
}
func actorBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
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
	expect(["binaryLiteral", "extendedSinglelineStringLiteral", "self", "_", "implicitParameterName", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "super", ".", "\\\\", "octalLiteral", "#keyPath", "#fileLiteral", "[", "singlelineStringLiteral", "decimalFloatingPointLiteral", "false", "decimalNumber", "macroIdentifier", "(", "hexadecimalLiteral", "nil", "hexadecimalFloatingPointLiteral", "escapedIdentifier", "true", "extendedMultilineStringLiteral", "plainIdentifier", "#imageLiteral", "#colorLiteral", "multilineStringLiteral", "{", "switch", "if", "#selector", "plainRegularExpressionLiteral"])
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
	expect(["self", "false", "true", "#fileLiteral", "plainIdentifier", "plainRegularExpressionLiteral", ".", "_", "octalLiteral", "#keyPath", "binaryLiteral", "extendedRegularExpressionLiteral", "{", "decimalFloatingPointLiteral", "super", "#colorLiteral", "\\\\", "nil", "extendedSinglelineStringLiteral", "singlelineStringLiteral", "decimalNumber", "switch", "propertyWrapperProjection", "macroIdentifier", "if", "multilineStringLiteral", "extendedMultilineStringLiteral", "#selector", "hexadecimalLiteral", "[", "(", "implicitParameterName", "hexadecimalFloatingPointLiteral", "escapedIdentifier", "#imageLiteral"])
}
func staticStringLiteral() {
	if token.type = .ALT {
		stringLiteral()
		// END
	}
	expect(["extendedMultilineStringLiteral", "singlelineStringLiteral", "multilineStringLiteral", "extendedSinglelineStringLiteral"])
}
func tuplePatternElement() {
	if token.type = .ALT {
		pattern()
		// END
	} else if token.type = .ALT {
		pattern()
		// END
	}
	expect([".", "switch", "\\\\", "false", "dotOperator", "hexadecimalFloatingPointLiteral", "hexadecimalLiteral", "true", "implicitParameterName", "multilineStringLiteral", "#imageLiteral", "macroIdentifier", "#selector", "try", "#keyPath", "plainRegularExpressionLiteral", "nil", "#colorLiteral", "let", "(", "{", "_", "singlelineStringLiteral", "if", "plainOperator", "&", "super", "[", "await", "octalLiteral", "extendedSinglelineStringLiteral", "escapedIdentifier", "self", "plainIdentifier", "decimalNumber", "binaryLiteral", "extendedMultilineStringLiteral", "decimalFloatingPointLiteral", "#fileLiteral", "var", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "is"])
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
func dictionaryType() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
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
func postfixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["postfix"])
}
func enumName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
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
func parenthesizedExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func tuplePattern() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
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
func statements() {
	if token.type = .ALT {
		statement()
		// OPT
	}
	expect(["for", "multilineStringLiteral", "try", "return", "mutating", "extendedRegularExpressionLiteral", "protocol", "weak", "[", "singlelineStringLiteral", "postfix", "switch", "dotOperator", "struct", "private", "let", "class", ".", "&", "while", "var", "#error", "fallthrough", "continue", "plainOperator", "repeat", "escapedIdentifier", "#imageLiteral", "plainIdentifier", "{", "do", "override", "subscript", "throw", "if", "required", "break", "decimalNumber", "#warning", "public", "binaryLiteral", "extension", "enum", "#keyPath", "static", "indirect", "extendedSinglelineStringLiteral", "import", "#if", "package", "macroIdentifier", "octalLiteral", "guard", "extendedMultilineStringLiteral", "decimalFloatingPointLiteral", "open", "nonmutating", "convenience", "plainRegularExpressionLiteral", "infix", "func", "prefix", "#selector", "unowned", "lazy", "dynamic", "fileprivate", "true", "final", "\\\\", "await", "optional", "implicitParameterName", "nil", "precedencegroup", "_", "#colorLiteral", "actor", "internal", "@", "#fileLiteral", "init", "hexadecimalFloatingPointLiteral", "self", "#sourceLocation", "false", "super", "nonisolated", "propertyWrapperProjection", "typealias", "defer", "deinit", "hexadecimalLiteral", "("])
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
func closureParameterList() {
	if token.type = .ALT {
		closureParameter()
		// END
	} else if token.type = .ALT {
		closureParameter()
		// END
	}
	expect(["_", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "plainIdentifier"])
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
	expect(["compiler", "arch", "canImport", "targetEnvironment", "os", "swift"])
}
func throwStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["throw"])
}
func protocolMember() {
	if token.type = .ALT {
		protocolMemberDeclaration()
		// END
	} else if token.type = .ALT {
		protocolMemberDeclaration()
		// END
	}
	expect(["associatedtype", "class", "open", "package", "final", "nonmutating", "private", "init", "@", "unowned", "weak", "postfix", "subscript", "override", "dynamic", "prefix", "internal", "fileprivate", "required", "convenience", "var", "public", "static", "nonisolated", "typealias", "optional", "infix", "func", "lazy", "mutating"])
}
func numericLiteral() {
	if token.type = .ALT {
		integerLiteral()
		// END
	} else if token.type = .ALT {
		integerLiteral()
		// END
	}
	expect(["binaryLiteral", "decimalNumber", "octalLiteral", "hexadecimalLiteral"])
}
func structMembers() {
	if token.type = .ALT {
		structMember()
		// OPT
	}
	expect(["subscript", "enum", "required", "weak", "static", "mutating", "infix", "dynamic", "deinit", "open", "var", "@", "package", "postfix", "precedencegroup", "init", "class", "#if", "func", "extension", "#warning", "#sourceLocation", "let", "override", "nonmutating", "protocol", "nonisolated", "fileprivate", "lazy", "internal", "private", "convenience", "final", "actor", "import", "indirect", "typealias", "prefix", "public", "struct", "optional", "#error", "unowned"])
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
func valueBindingPattern() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["var"])
}
func willSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "willSet"])
}
func forcedValueExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["binaryLiteral", "extendedSinglelineStringLiteral", "self", "_", "implicitParameterName", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "super", ".", "\\\\", "octalLiteral", "#keyPath", "#fileLiteral", "[", "singlelineStringLiteral", "decimalFloatingPointLiteral", "false", "decimalNumber", "macroIdentifier", "(", "hexadecimalLiteral", "nil", "hexadecimalFloatingPointLiteral", "escapedIdentifier", "true", "extendedMultilineStringLiteral", "plainIdentifier", "#imageLiteral", "#colorLiteral", "multilineStringLiteral", "{", "switch", "if", "#selector", "plainRegularExpressionLiteral"])
}
func setterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "nonmutating", "set", "mutating"])
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
func variableDeclarationHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["static", "infix", "final", "public", "package", "var", "lazy", "override", "prefix", "open", "weak", "postfix", "optional", "nonmutating", "@", "class", "internal", "private", "unowned", "mutating", "required", "convenience", "fileprivate", "nonisolated", "dynamic"])
}
func variableName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
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
func unionStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["implicitParameterName", "escapedIdentifier", "propertyWrapperProjection", "_", "plainIdentifier"])
}
func attribute() {
	if token.type = .ALT {
		next()
	}
	expect(["@"])
}
func captureListItems() {
	if token.type = .ALT {
		captureListItem()
		// END
	} else if token.type = .ALT {
		captureListItem()
		// END
	}
	expect(["weak", "unowned(unsafe)", "unowned", "_", "self", "unowned(safe)", "implicitParameterName", "propertyWrapperProjection", "plainIdentifier", "escapedIdentifier"])
}
func catchPattern() {
	if token.type = .ALT {
		pattern()
		// OPT
	}
	expect([".", "switch", "\\\\", "false", "dotOperator", "hexadecimalFloatingPointLiteral", "hexadecimalLiteral", "true", "implicitParameterName", "multilineStringLiteral", "#imageLiteral", "macroIdentifier", "#selector", "try", "#keyPath", "plainRegularExpressionLiteral", "nil", "#colorLiteral", "let", "(", "{", "_", "singlelineStringLiteral", "if", "plainOperator", "&", "super", "[", "await", "octalLiteral", "extendedSinglelineStringLiteral", "escapedIdentifier", "self", "plainIdentifier", "decimalNumber", "binaryLiteral", "extendedMultilineStringLiteral", "decimalFloatingPointLiteral", "#fileLiteral", "var", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "is"])
}
func availabilityArguments() {
	if token.type = .ALT {
		availabilityArgument()
		// END
	} else if token.type = .ALT {
		availabilityArgument()
		// END
	}
	expect(["tvOSApplicationExtension", "macCatalystApplicationExtension", "macCatalyst", "macOSApplicationExtension", "watchOS", "iOS", "visionOSApplicationExtension", "watchOSApplicationExtension", "iOSApplicationExtension", "visionOS", "macOS", "*", "tvOS"])
}
func prefixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["plainOperator", "dotOperator"])
}
func extensionMembers() {
	if token.type = .ALT {
		extensionMember()
		// OPT
	}
	expect(["optional", "weak", "indirect", "infix", "prefix", "struct", "fileprivate", "#warning", "dynamic", "private", "import", "class", "required", "subscript", "func", "#sourceLocation", "typealias", "#error", "nonisolated", "final", "precedencegroup", "init", "var", "let", "extension", "mutating", "static", "override", "nonmutating", "lazy", "#if", "public", "deinit", "convenience", "@", "unowned", "actor", "internal", "package", "postfix", "protocol", "enum", "open"])
}
func typeInheritanceList() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["_", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "@", "plainIdentifier"])
}
func getterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["mutating", "get", "nonmutating", "@"])
}
func caseItemList() {
	if token.type = .ALT {
		pattern()
		// OPT
	} else if token.type = .ALT {
		pattern()
		// OPT
	}
	expect([".", "switch", "\\\\", "false", "dotOperator", "hexadecimalFloatingPointLiteral", "hexadecimalLiteral", "true", "implicitParameterName", "multilineStringLiteral", "#imageLiteral", "macroIdentifier", "#selector", "try", "#keyPath", "plainRegularExpressionLiteral", "nil", "#colorLiteral", "let", "(", "{", "_", "singlelineStringLiteral", "if", "plainOperator", "&", "super", "[", "await", "octalLiteral", "extendedSinglelineStringLiteral", "escapedIdentifier", "self", "plainIdentifier", "decimalNumber", "binaryLiteral", "extendedMultilineStringLiteral", "decimalFloatingPointLiteral", "#fileLiteral", "var", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "is"])
}
func enumCaseName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func initializerHead() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["internal", "class", "private", "final", "convenience", "infix", "required", "init", "fileprivate", "nonmutating", "public", "mutating", "nonisolated", "static", "package", "unowned", "postfix", "prefix", "@", "override", "lazy", "open", "weak", "dynamic", "optional"])
}
func switchStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["switch"])
}
func codeBlock() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
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
	expect(["override", "nonmutating", "convenience", "fileprivate", "package", "private", "@", "prefix", "struct", "subscript", "extension", "unowned", "optional", "deinit", "import", "final", "required", "mutating", "weak", "precedencegroup", "postfix", "enum", "public", "var", "static", "lazy", "dynamic", "typealias", "let", "nonisolated", "internal", "open", "class", "protocol", "actor", "indirect", "infix", "init", "func"])
}
func infixExpressions() {
	if token.type = .ALT {
		infixExpression()
		// OPT
	}
	expect(["is", "as", "dotOperator", "plainOperator", "=", "?"])
}
func switchCases() {
	if token.type = .ALT {
		switchCase()
		// OPT
	}
	expect(["case", "@", "#if", "default"])
}
func repeatWhileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["repeat"])
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
	expect(["binaryLiteral", "octalLiteral", "hexadecimalLiteral", "decimalFloatingPointLiteral", "hexadecimalFloatingPointLiteral", "decimalNumber"])
}
func selfSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func patternInitializerList() {
	if token.type = .ALT {
		patternInitializer()
		// END
	} else if token.type = .ALT {
		patternInitializer()
		// END
	}
	expect(["propertyWrapperProjection", "self", "try", "true", "singlelineStringLiteral", "hexadecimalFloatingPointLiteral", "plainRegularExpressionLiteral", "var", "\\\\", "await", "extendedSinglelineStringLiteral", "#fileLiteral", "binaryLiteral", "(", "if", "macroIdentifier", "switch", "escapedIdentifier", "_", ".", "let", "multilineStringLiteral", "plainOperator", "hexadecimalLiteral", "plainIdentifier", "#imageLiteral", "#colorLiteral", "#selector", "extendedRegularExpressionLiteral", "extendedMultilineStringLiteral", "#keyPath", "decimalNumber", "dotOperator", "super", "implicitParameterName", "false", "&", "{", "octalLiteral", "decimalFloatingPointLiteral", "nil", "is", "["])
}
func optionalBindingCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["let"])
}
func ifStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
}
func mutationModifier() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["mutating"])
}
func continueStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["continue"])
}
func inOutExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["&"])
}
func localParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func protocolMembers() {
	if token.type = .ALT {
		protocolMember()
		// OPT
	}
	expect(["#warning", "open", "optional", "infix", "unowned", "postfix", "public", "class", "static", "#if", "typealias", "#sourceLocation", "func", "nonisolated", "prefix", "weak", "#error", "fileprivate", "override", "nonmutating", "convenience", "internal", "init", "mutating", "package", "dynamic", "required", "lazy", "private", "@", "var", "final", "associatedtype", "subscript"])
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
	expect(["binaryLiteral", "extendedSinglelineStringLiteral", "self", "_", "implicitParameterName", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "super", ".", "\\\\", "octalLiteral", "#keyPath", "#fileLiteral", "[", "singlelineStringLiteral", "decimalFloatingPointLiteral", "false", "decimalNumber", "macroIdentifier", "(", "hexadecimalLiteral", "nil", "hexadecimalFloatingPointLiteral", "escapedIdentifier", "true", "extendedMultilineStringLiteral", "plainIdentifier", "#imageLiteral", "#colorLiteral", "multilineStringLiteral", "{", "switch", "if", "#selector", "plainRegularExpressionLiteral"])
}
func ifExpressionTail() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
}
func attributeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func functionCallArgumentList() {
	if token.type = .ALT {
		functionCallArgument()
		// END
	} else if token.type = .ALT {
		functionCallArgument()
		// END
	}
	expect(["if", "binaryLiteral", "try", "dotOperator", "#fileLiteral", "(", "singlelineStringLiteral", "#imageLiteral", "\\\\", "#colorLiteral", "[", "escapedIdentifier", "multilineStringLiteral", "extendedRegularExpressionLiteral", "plainIdentifier", "false", ".", "nil", "hexadecimalLiteral", "_", "extendedMultilineStringLiteral", "super", "await", "hexadecimalFloatingPointLiteral", "switch", "&", "true", "octalLiteral", "#selector", "implicitParameterName", "propertyWrapperProjection", "macroIdentifier", "self", "#keyPath", "plainOperator", "decimalFloatingPointLiteral", "decimalNumber", "extendedSinglelineStringLiteral", "plainRegularExpressionLiteral", "{"])
}
func functionHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["nonmutating", "final", "weak", "static", "open", "internal", "package", "private", "convenience", "lazy", "infix", "prefix", "required", "override", "mutating", "func", "class", "dynamic", "@", "unowned", "postfix", "optional", "public", "nonisolated", "fileprivate"])
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
func fallthroughStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["fallthrough"])
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
func importPath() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func precedenceGroupRelation() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["higherThan"])
}
func keyPathComponent() {
	if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func conditionalSwitchCase() {
	if token.type = .ALT {
		switchIfDirectiveClause()
		// OPT
	}
	expect(["#if"])
}
func dictionaryLiteralItems() {
	if token.type = .ALT {
		dictionaryLiteralItem()
		// OPT
	} else if token.type = .ALT {
		dictionaryLiteralItem()
		// OPT
	}
	expect(["decimalFloatingPointLiteral", "dotOperator", "nil", "#imageLiteral", "multilineStringLiteral", "decimalNumber", "await", "implicitParameterName", "#selector", "hexadecimalLiteral", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "plainOperator", "hexadecimalFloatingPointLiteral", "if", "try", "true", "switch", "&", "octalLiteral", "_", "macroIdentifier", "{", "#colorLiteral", "false", "escapedIdentifier", "propertyWrapperProjection", ".", "\\\\", "plainIdentifier", "super", "#fileLiteral", "extendedMultilineStringLiteral", "binaryLiteral", "self", "#keyPath", "[", "singlelineStringLiteral", "extendedSinglelineStringLiteral", "("])
}
func parameterClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func optionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["plainIdentifier", "implicitParameterName", "_", "escapedIdentifier", "Self", "some", "propertyWrapperProjection", "@", "[", "Any", "("])
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
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func typeIdentifier() {
	if token.type = .ALT {
		typeName()
		// OPT
	} else if token.type = .ALT {
		typeName()
		// OPT
	}
	expect(["propertyWrapperProjection", "escapedIdentifier", "implicitParameterName", "_", "plainIdentifier"])
}
func unionStyleEnum() {
	if token.type = .ALT {
		// OPT
	}
	expect(["enum", "indirect"])
}
func rawValueStyleEnum() {
	if token.type = .ALT {
		next()
	}
	expect(["enum"])
}
func isPattern() {
	if token.type = .ALT {
		next()
	}
	expect(["is"])
}
func defaultArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func optionalPattern() {
	if token.type = .ALT {
		identifierPattern()
		next()
	}
	expect(["escapedIdentifier", "propertyWrapperProjection", "_", "implicitParameterName", "plainIdentifier"])
}
func tupleElement() {
	if token.type = .ALT {
		expression()
		// END
	} else if token.type = .ALT {
		expression()
		// END
	}
	expect(["if", ".", "extendedSinglelineStringLiteral", "_", "try", "plainRegularExpressionLiteral", "#colorLiteral", "decimalFloatingPointLiteral", "propertyWrapperProjection", "plainOperator", "escapedIdentifier", "dotOperator", "\\\\", "switch", "#selector", "binaryLiteral", "extendedMultilineStringLiteral", "[", "#fileLiteral", "extendedRegularExpressionLiteral", "self", "&", "singlelineStringLiteral", "true", "nil", "hexadecimalLiteral", "#imageLiteral", "implicitParameterName", "hexadecimalFloatingPointLiteral", "macroIdentifier", "plainIdentifier", "#keyPath", "{", "(", "await", "octalLiteral", "false", "multilineStringLiteral", "decimalNumber", "super"])
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
	expect(["if", ".", "extendedSinglelineStringLiteral", "_", "try", "plainRegularExpressionLiteral", "#colorLiteral", "decimalFloatingPointLiteral", "propertyWrapperProjection", "plainOperator", "escapedIdentifier", "dotOperator", "\\\\", "switch", "#selector", "binaryLiteral", "extendedMultilineStringLiteral", "[", "#fileLiteral", "extendedRegularExpressionLiteral", "self", "&", "singlelineStringLiteral", "true", "nil", "hexadecimalLiteral", "#imageLiteral", "implicitParameterName", "hexadecimalFloatingPointLiteral", "macroIdentifier", "plainIdentifier", "#keyPath", "{", "(", "await", "octalLiteral", "false", "multilineStringLiteral", "decimalNumber", "super"])
}
func catchPatternList() {
	if token.type = .ALT {
		catchPattern()
		// END
	} else if token.type = .ALT {
		catchPattern()
		// END
	}
	expect(["if", "switch", "is", "decimalNumber", "#keyPath", "#selector", "try", "\\\\", "var", "#imageLiteral", "nil", "propertyWrapperProjection", "let", "[", "extendedMultilineStringLiteral", "multilineStringLiteral", "true", "plainRegularExpressionLiteral", "macroIdentifier", "plainIdentifier", "singlelineStringLiteral", "_", "extendedRegularExpressionLiteral", "extendedSinglelineStringLiteral", "hexadecimalLiteral", "octalLiteral", "self", "await", "escapedIdentifier", "super", "binaryLiteral", "#fileLiteral", "decimalFloatingPointLiteral", "plainOperator", "{", "dotOperator", "implicitParameterName", "&", "(", "false", ".", "#colorLiteral", "hexadecimalFloatingPointLiteral"])
}
func environment() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["simulator"])
}
func decimalLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["decimalNumber"])
}
func functionTypeArgumentList() {
	if token.type = .ALT {
		functionTypeArgument()
		// END
	} else if token.type = .ALT {
		functionTypeArgument()
		// END
	}
	expect(["inout", "(", "escapedIdentifier", "_", "propertyWrapperProjection", "some", "Any", "implicitParameterName", "Self", "plainIdentifier", "[", "@"])
}
func elseifDirectiveClause() {
	if token.type = .ALT {
		elseifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#elseif"])
}
func boxedProtocolType() {
	if token.type = .ALT {
		next()
	}
	expect(["any"])
}
func caseLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "case"])
}
func setterName() {
	if token.type = .ALT {
		next()
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
	expect(["escapedIdentifier", "propertyWrapperProjection", "implicitParameterName", "plainIdentifier", "_"])
}
func rawValueStyleEnumMembers() {
	if token.type = .ALT {
		rawValueStyleEnumMember()
		// OPT
	}
	expect(["lazy", "nonmutating", "nonisolated", "postfix", "open", "extension", "weak", "dynamic", "#error", "package", "public", "final", "actor", "case", "internal", "prefix", "var", "infix", "fileprivate", "class", "indirect", "private", "import", "static", "enum", "#if", "deinit", "precedencegroup", "#sourceLocation", "required", "@", "optional", "mutating", "typealias", "func", "override", "convenience", "struct", "subscript", "protocol", "init", "let", "#warning", "unowned"])
}
func rawValueStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["implicitParameterName", "escapedIdentifier", "propertyWrapperProjection", "_", "plainIdentifier"])
}
func actorMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["override", "nonmutating", "convenience", "fileprivate", "package", "private", "@", "prefix", "struct", "subscript", "extension", "unowned", "optional", "deinit", "import", "final", "required", "mutating", "weak", "precedencegroup", "postfix", "enum", "public", "var", "static", "lazy", "dynamic", "typealias", "let", "nonisolated", "internal", "open", "class", "protocol", "actor", "indirect", "infix", "init", "func"])
}
func superclassInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func prefixExpression() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["false", "#fileLiteral", "extendedMultilineStringLiteral", "extendedSinglelineStringLiteral", "switch", "\\\\", "escapedIdentifier", "binaryLiteral", ".", "{", "dotOperator", "nil", "extendedRegularExpressionLiteral", "octalLiteral", "super", "macroIdentifier", "#imageLiteral", "multilineStringLiteral", "self", "implicitParameterName", "propertyWrapperProjection", "decimalNumber", "hexadecimalFloatingPointLiteral", "#colorLiteral", "[", "plainRegularExpressionLiteral", "if", "(", "plainIdentifier", "_", "plainOperator", "singlelineStringLiteral", "true", "decimalFloatingPointLiteral", "hexadecimalLiteral", "#keyPath", "#selector"])
}
func infixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["plainOperator", "dotOperator"])
}
func protocolAssociatedTypeDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "package", "fileprivate", "open", "public", "associatedtype", "internal", "private"])
}
func macroDeclaration() {
	if token.type = .ALT {
		macroHead()
		identifier()
		// OPT
	}
	expect(["mutating", "open", "dynamic", "nonisolated", "fileprivate", "static", "public", "lazy", "class", "override", "convenience", "required", "optional", "infix", "weak", "final", "package", "nonmutating", "internal", "prefix", "@", "private", "postfix", "macro", "unowned"])
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
func selfType() {
	if token.type = .ALT {
		next()
	}
	expect(["Self"])
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
func tupleExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func structBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func elseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
}
func actorMembers() {
	if token.type = .ALT {
		actorMember()
		// OPT
	}
	expect(["func", "override", "mutating", "import", "internal", "#if", "deinit", "unowned", "lazy", "open", "struct", "precedencegroup", "postfix", "private", "infix", "package", "extension", "actor", "class", "required", "let", "prefix", "optional", "static", "dynamic", "var", "@", "indirect", "nonmutating", "init", "#sourceLocation", "final", "convenience", "enum", "#error", "subscript", "weak", "nonisolated", "#warning", "protocol", "public", "fileprivate", "typealias"])
}
func closureSignature() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["(", "escapedIdentifier", "_", "[", "propertyWrapperProjection", "plainIdentifier", "implicitParameterName"])
}
func wildcardExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["_"])
}
func genericWhereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func returnStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["return"])
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
func asPattern() {
	if token.type = .ALT {
		pattern()
		next()
	}
	expect([".", "switch", "\\\\", "false", "dotOperator", "hexadecimalFloatingPointLiteral", "hexadecimalLiteral", "true", "implicitParameterName", "multilineStringLiteral", "#imageLiteral", "macroIdentifier", "#selector", "try", "#keyPath", "plainRegularExpressionLiteral", "nil", "#colorLiteral", "let", "(", "{", "_", "singlelineStringLiteral", "if", "plainOperator", "&", "super", "[", "await", "octalLiteral", "extendedSinglelineStringLiteral", "escapedIdentifier", "self", "plainIdentifier", "decimalNumber", "binaryLiteral", "extendedMultilineStringLiteral", "decimalFloatingPointLiteral", "#fileLiteral", "var", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "is"])
}
func closureParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func genericParameterClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
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
func setterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["mutating", "nonmutating", "set", "@"])
}
func macroHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["required", "nonmutating", "weak", "private", "convenience", "nonisolated", "@", "mutating", "open", "class", "lazy", "public", "fileprivate", "postfix", "infix", "package", "optional", "static", "override", "unowned", "macro", "final", "internal", "dynamic", "prefix"])
}
func expression() {
	if token.type = .ALT {
		// OPT
	}
	expect(["[", "macroIdentifier", "await", "escapedIdentifier", "propertyWrapperProjection", "dotOperator", "\\\\", "#selector", "self", "implicitParameterName", "&", "(", "#fileLiteral", "extendedRegularExpressionLiteral", "_", "plainIdentifier", ".", "extendedSinglelineStringLiteral", "switch", "singlelineStringLiteral", "#keyPath", "super", "{", "hexadecimalLiteral", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "decimalNumber", "nil", "if", "#imageLiteral", "plainRegularExpressionLiteral", "#colorLiteral", "plainOperator", "binaryLiteral", "octalLiteral", "multilineStringLiteral", "true", "false", "extendedMultilineStringLiteral", "try"])
}
func topLevelDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["multilineStringLiteral", "typealias", "lazy", "convenience", "binaryLiteral", "class", "break", "#error", "package", "#warning", "while", "protocol", "decimalNumber", "@", "extendedSinglelineStringLiteral", "super", "import", "subscript", "plainRegularExpressionLiteral", "&", ".", "false", "", "extendedRegularExpressionLiteral", "#colorLiteral", "#sourceLocation", "extendedMultilineStringLiteral", "precedencegroup", "defer", "internal", "await", "for", "static", "let", "try", "plainOperator", "escapedIdentifier", "[", "unowned", "hexadecimalFloatingPointLiteral", "actor", "indirect", "(", "plainIdentifier", "hexadecimalLiteral", "dynamic", "required", "enum", "guard", "{", "#selector", "macroIdentifier", "#fileLiteral", "return", "continue", "#imageLiteral", "nonisolated", "fileprivate", "override", "nil", "extension", "final", "init", "var", "private", "if", "optional", "prefix", "infix", "weak", "repeat", "implicitParameterName", "#keyPath", "func", "dotOperator", "propertyWrapperProjection", "octalLiteral", "#if", "\\\\", "_", "throw", "self", "true", "do", "singlelineStringLiteral", "switch", "struct", "decimalFloatingPointLiteral", "open", "deinit", "mutating", "fallthrough", "postfix", "nonmutating", "public"])
}
func functionName() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
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
func statementLabel() {
	if token.type = .ALT {
		labelName()
		next()
	}
	expect(["_", "escapedIdentifier", "propertyWrapperProjection", "implicitParameterName", "plainIdentifier"])
}
func nilLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["nil"])
}
func tupleElementList() {
	if token.type = .ALT {
		tupleElement()
		// END
	} else if token.type = .ALT {
		tupleElement()
		// END
	}
	expect(["(", "plainIdentifier", "switch", "_", "#selector", "#keyPath", "if", "{", "decimalNumber", "dotOperator", "binaryLiteral", "&", "#imageLiteral", "plainRegularExpressionLiteral", "#fileLiteral", "extendedMultilineStringLiteral", "decimalFloatingPointLiteral", "propertyWrapperProjection", "false", "true", "macroIdentifier", "octalLiteral", ".", "[", "hexadecimalLiteral", "singlelineStringLiteral", "hexadecimalFloatingPointLiteral", "self", "await", "implicitParameterName", "\\\\", "escapedIdentifier", "try", "extendedRegularExpressionLiteral", "multilineStringLiteral", "#colorLiteral", "extendedSinglelineStringLiteral", "plainOperator", "nil", "super"])
}
func unionStyleEnumMembers() {
	if token.type = .ALT {
		unionStyleEnumMember()
		// OPT
	}
	expect(["weak", "public", "indirect", "prefix", "init", "dynamic", "extension", "package", "unowned", "optional", "enum", "func", "convenience", "class", "case", "struct", "protocol", "fileprivate", "infix", "internal", "@", "subscript", "var", "static", "lazy", "final", "#error", "import", "actor", "let", "open", "deinit", "override", "postfix", "precedencegroup", "nonisolated", "mutating", "#warning", "private", "nonmutating", "#if", "required", "#sourceLocation", "typealias"])
}
func lineNumber() {
	if token.type = .ALT {
		decimalDigits()
		// END
	}
	expect(["decimalNumber"])
}
func classMembers() {
	if token.type = .ALT {
		classMember()
		// OPT
	}
	expect(["mutating", "nonisolated", "package", "class", "init", "deinit", "convenience", "dynamic", "indirect", "typealias", "internal", "nonmutating", "protocol", "subscript", "required", "var", "enum", "prefix", "struct", "#warning", "func", "@", "#sourceLocation", "#error", "weak", "static", "precedencegroup", "override", "infix", "open", "optional", "lazy", "fileprivate", "#if", "public", "actor", "final", "unowned", "extension", "postfix", "private", "let", "import"])
}
func functionResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func switchElseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
}
func precedenceGroupNames() {
	if token.type = .ALT {
		precedenceGroupName()
		// END
	} else if token.type = .ALT {
		precedenceGroupName()
		// END
	}
	expect(["plainIdentifier", "_", "escapedIdentifier", "propertyWrapperProjection", "implicitParameterName"])
}
func genericParameterList() {
	if token.type = .ALT {
		genericParameter()
		// END
	} else if token.type = .ALT {
		genericParameter()
		// END
	}
	expect(["implicitParameterName", "_", "plainIdentifier", "propertyWrapperProjection", "escapedIdentifier"])
}
func wildcardPattern() {
	if token.type = .ALT {
		next()
	}
	expect(["_"])
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
	expect(["fileprivate", "dynamic", "var", "override", "private", "lazy", "class", "@", "static", "internal", "nonisolated", "prefix", "nonmutating", "public", "unowned", "convenience", "optional", "mutating", "postfix", "package", "open", "infix", "weak", "required", "final"])
}
func functionCallArgumentClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
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
	expect(["dynamic", "mutating", "lazy", "@", "subscript", "fileprivate", "override", "unowned", "optional", "final", "postfix", "class", "private", "prefix", "convenience", "static", "open", "nonisolated", "internal", "weak", "nonmutating", "package", "public", "required", "infix"])
}
func ifDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
}
func ifExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
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
func patternInitializer() {
	if token.type = .ALT {
		pattern()
		// OPT
	}
	expect([".", "switch", "\\\\", "false", "dotOperator", "hexadecimalFloatingPointLiteral", "hexadecimalLiteral", "true", "implicitParameterName", "multilineStringLiteral", "#imageLiteral", "macroIdentifier", "#selector", "try", "#keyPath", "plainRegularExpressionLiteral", "nil", "#colorLiteral", "let", "(", "{", "_", "singlelineStringLiteral", "if", "plainOperator", "&", "super", "[", "await", "octalLiteral", "extendedSinglelineStringLiteral", "escapedIdentifier", "self", "plainIdentifier", "decimalNumber", "binaryLiteral", "extendedMultilineStringLiteral", "decimalFloatingPointLiteral", "#fileLiteral", "var", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "is"])
}
func doStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["do"])
}
func identifierPattern() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func subscriptHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["infix", "lazy", "static", "prefix", "@", "class", "fileprivate", "internal", "weak", "nonmutating", "package", "optional", "unowned", "nonisolated", "open", "override", "private", "dynamic", "mutating", "convenience", "public", "postfix", "subscript", "final", "required"])
}
func conditionList() {
	if token.type = .ALT {
		condition()
		// END
	} else if token.type = .ALT {
		condition()
		// END
	}
	expect(["octalLiteral", "escapedIdentifier", "&", "plainIdentifier", "decimalNumber", "hexadecimalFloatingPointLiteral", "switch", "[", "var", "\\\\", "true", "try", "#selector", "await", "binaryLiteral", "extendedRegularExpressionLiteral", "hexadecimalLiteral", "propertyWrapperProjection", ".", "false", "plainRegularExpressionLiteral", "extendedMultilineStringLiteral", "macroIdentifier", "multilineStringLiteral", "_", "extendedSinglelineStringLiteral", "decimalFloatingPointLiteral", "dotOperator", "if", "let", "implicitParameterName", "plainOperator", "singlelineStringLiteral", "{", "#available", "nil", "self", "case", "#keyPath", "super", "#unavailable", "#fileLiteral", "#imageLiteral", "(", "#colorLiteral"])
}
func precedenceGroupName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func argumentLabel() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func breakStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["break"])
}
func implicitlyUnwrappedOptionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["plainIdentifier", "implicitParameterName", "_", "escapedIdentifier", "Self", "some", "propertyWrapperProjection", "@", "[", "Any", "("])
}
func subscriptExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["binaryLiteral", "extendedSinglelineStringLiteral", "self", "_", "implicitParameterName", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "super", ".", "\\\\", "octalLiteral", "#keyPath", "#fileLiteral", "[", "singlelineStringLiteral", "decimalFloatingPointLiteral", "false", "decimalNumber", "macroIdentifier", "(", "hexadecimalLiteral", "nil", "hexadecimalFloatingPointLiteral", "escapedIdentifier", "true", "extendedMultilineStringLiteral", "plainIdentifier", "#imageLiteral", "#colorLiteral", "multilineStringLiteral", "{", "switch", "if", "#selector", "plainRegularExpressionLiteral"])
}
func dictionaryLiteralItem() {
	if token.type = .ALT {
		expression()
		next()
	}
	expect(["if", ".", "extendedSinglelineStringLiteral", "_", "try", "plainRegularExpressionLiteral", "#colorLiteral", "decimalFloatingPointLiteral", "propertyWrapperProjection", "plainOperator", "escapedIdentifier", "dotOperator", "\\\\", "switch", "#selector", "binaryLiteral", "extendedMultilineStringLiteral", "[", "#fileLiteral", "extendedRegularExpressionLiteral", "self", "&", "singlelineStringLiteral", "true", "nil", "hexadecimalLiteral", "#imageLiteral", "implicitParameterName", "hexadecimalFloatingPointLiteral", "macroIdentifier", "plainIdentifier", "#keyPath", "{", "(", "await", "octalLiteral", "false", "multilineStringLiteral", "decimalNumber", "super"])
}
func initializer() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
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
func implicitMemberExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["."])
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
func elseClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
}
func elseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
}
func captureListItem() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["implicitParameterName", "unowned(unsafe)", "unowned", "escapedIdentifier", "weak", "_", "propertyWrapperProjection", "plainIdentifier", "unowned(safe)"])
}
func throwsClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["throws"])
}
func catchClause() {
	if token.type = .ALT {
		next()
	}
	expect(["catch"])
}
func optionalChainingExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["binaryLiteral", "extendedSinglelineStringLiteral", "self", "_", "implicitParameterName", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "super", ".", "\\\\", "octalLiteral", "#keyPath", "#fileLiteral", "[", "singlelineStringLiteral", "decimalFloatingPointLiteral", "false", "decimalNumber", "macroIdentifier", "(", "hexadecimalLiteral", "nil", "hexadecimalFloatingPointLiteral", "escapedIdentifier", "true", "extendedMultilineStringLiteral", "plainIdentifier", "#imageLiteral", "#colorLiteral", "multilineStringLiteral", "{", "switch", "if", "#selector", "plainRegularExpressionLiteral"])
}
func typealiasDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "package", "private", "typealias", "fileprivate", "public", "internal", "open"])
}
func expressionPattern() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["if", ".", "extendedSinglelineStringLiteral", "_", "try", "plainRegularExpressionLiteral", "#colorLiteral", "decimalFloatingPointLiteral", "propertyWrapperProjection", "plainOperator", "escapedIdentifier", "dotOperator", "\\\\", "switch", "#selector", "binaryLiteral", "extendedMultilineStringLiteral", "[", "#fileLiteral", "extendedRegularExpressionLiteral", "self", "&", "singlelineStringLiteral", "true", "nil", "hexadecimalLiteral", "#imageLiteral", "implicitParameterName", "hexadecimalFloatingPointLiteral", "macroIdentifier", "plainIdentifier", "#keyPath", "{", "(", "await", "octalLiteral", "false", "multilineStringLiteral", "decimalNumber", "super"])
}
func labeledTrailingClosures() {
	if token.type = .ALT {
		labeledTrailingClosure()
		// OPT
	}
	expect(["escapedIdentifier", "_", "propertyWrapperProjection", "plainIdentifier", "implicitParameterName"])
}
func awaitOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["await"])
}
func endifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#endif"])
}
func argumentNames() {
	if token.type = .ALT {
		argumentName()
		// OPT
	}
	expect(["escapedIdentifier", "implicitParameterName", "plainIdentifier", "propertyWrapperProjection", "_"])
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
func macroExpansionExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["macroIdentifier"])
}
func constantDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["final", "internal", "lazy", "public", "private", "unowned", "infix", "class", "nonmutating", "optional", "mutating", "fileprivate", "required", "open", "@", "override", "postfix", "prefix", "nonisolated", "convenience", "package", "weak", "let", "static", "dynamic"])
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
func precedenceGroupAttributes() {
	if token.type = .ALT {
		precedenceGroupAttribute()
		// OPT
	}
	expect(["assignment", "lowerThan", "higherThan", "associativity"])
}
func elseifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#elseif"])
}
func identifierList() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func superclassSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func unionStyleEnumCaseList() {
	if token.type = .ALT {
		unionStyleEnumCase()
		// END
	} else if token.type = .ALT {
		unionStyleEnumCase()
		// END
	}
	expect(["_", "implicitParameterName", "propertyWrapperProjection", "plainIdentifier", "escapedIdentifier"])
}
func declarationModifiers() {
	if token.type = .ALT {
		declarationModifier()
		// OPT
	}
	expect(["class", "mutating", "infix", "postfix", "public", "lazy", "final", "unowned", "convenience", "static", "required", "override", "nonisolated", "private", "nonmutating", "dynamic", "fileprivate", "optional", "open", "package", "weak", "internal", "prefix"])
}
func actorDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "private", "fileprivate", "package", "open", "public", "internal", "actor"])
}
func labeledTrailingClosure() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func getterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["nonmutating", "@", "mutating", "get"])
}
func typeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func structDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "public", "open", "struct", "fileprivate", "internal", "package", "private"])
}
func defaultLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "default"])
}
func actorName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func macroSignature() {
	if token.type = .ALT {
		parameterClause()
		// OPT
	}
	expect(["("])
}
func extensionBody() {
	if token.type = .ALT {
		next()
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
	expect(["hexadecimalLiteral", "extendedMultilineStringLiteral", "extendedSinglelineStringLiteral", "false", "extendedRegularExpressionLiteral", "binaryLiteral", "singlelineStringLiteral", "true", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "multilineStringLiteral", "nil", "plainRegularExpressionLiteral", "octalLiteral", "decimalNumber"])
}
func genericArgument() {
	if token.type = .ALT {
		type()
		// END
	}
	expect(["plainIdentifier", "implicitParameterName", "_", "escapedIdentifier", "Self", "some", "propertyWrapperProjection", "@", "[", "Any", "("])
}
func floatingPointLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["decimalFloatingPointLiteral"])
}
