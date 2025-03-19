//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"comment":	("/\\/\\/.*\\r?\\n?/",	/\/\/.*\r?\n?/,	false,	true),
	"plainRegularExpressionLiteral":	("/\\/[^\\s](?:(?:[^\\/\\\\\\s]|\\\\.)*[^\\s])?\\//",	/\/[^\s](?:(?:[^\/\\\s]|\\.)*[^\s])?\//,	false,	false),
	"plainIdentifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"decimalNumber":	("/-?[0-9][0-9_]*/",	/-?[0-9][0-9_]*/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"stringLiteral":	("/#*\"(?:\\\\#*\\([^)]*\\)|\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]{1,8}\\}|\\\\#*\\s*\\n|[^\\\\])*\"#*|#*\"\"\"(?:\\\\#*\\([^)]*\\)|\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]{1,8}\\}|\\\\#*\\s*\\n|[^\\\\])*\"\"\"#*/",	/#*"(?:\\#*\([^)]*\)|\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]{1,8}\}|\\#*\s*\n|[^\\])*"#*|#*"""(?:\\#*\([^)]*\)|\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]{1,8}\}|\\#*\s*\n|[^\\])*"""#*/,	false,	false),
	"multilineComment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"octalLiteral":	("/-?0o[0-7][0-7_]*/",	/-?0o[0-7][0-7_]*/,	false,	false),
	"escapedIdentifier":	("/`\\p{XID_Start}\\p{XID_Continue}*`/",	/`\p{XID_Start}\p{XID_Continue}*`/,	false,	false),
	"hexadecimalFloatingPointLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/,	false,	false),
	"extendedRegularExpressionLiteral":	("/#+\\/(?:[^\\/\\\\]|\\\\.)+\\/#+/",	/#+\/(?:[^\/\\]|\\.)+\/#+/,	false,	false),
	"macroIdentifier":	("/#\\p{XID_Start}\\p{XID_Continue}*/",	/#\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"dotOperator":	("/\\.[\\.\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]+/",	/\.[\.\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]+/,	false,	false),
	"binaryLiteral":	("/-?0b[0-1][0-1_]*/",	/-?0b[0-1][0-1_]*/,	false,	false),
	"implicitParameterName":	("/\\$[0-9]+/",	/\$[0-9]+/,	false,	false),
	"propertyWrapperProjection":	("/\\$\\p{XID_Continue}+/",	/\$\p{XID_Continue}+/,	false,	false),
	"plainOperator":	("/[\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}][\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]*/",	/[\/=+\-*%!&|^~?<>\p{Sm}\p{So}][\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]*/,	false,	false),
	"decimalFloatingPointLiteral":	("/-?[0-9][0-9_]*(?:\\.[0-9][0-9_]*)(?:[eE][+-]?[0-9][0-9_]*)?/",	/-?[0-9][0-9_]*(?:\.[0-9][0-9_]*)(?:[eE][+-]?[0-9][0-9_]*)?/,	false,	false),
	"hexadecimalLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*/,	false,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"#warning":	("#warning",	Regex { "#warning" },	true,	false),
	"file:":	("file:",	Regex { "file:" },	true,	false),
	"Protocol":	("Protocol",	Regex { "Protocol" },	true,	false),
	"as":	("as",	Regex { "as" },	true,	false),
	"#sourceLocation":	("#sourceLocation",	Regex { "#sourceLocation" },	true,	false),
	"~":	("~",	Regex { "~" },	true,	false),
	"switch":	("switch",	Regex { "switch" },	true,	false),
	"==":	("==",	Regex { "==" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	"#else":	("#else",	Regex { "#else" },	true,	false),
	"compiler":	("compiler",	Regex { "compiler" },	true,	false),
	"unsafe":	("unsafe",	Regex { "unsafe" },	true,	false),
	"resourceName":	("resourceName",	Regex { "resourceName" },	true,	false),
	"line:":	("line:",	Regex { "line:" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"required":	("required",	Regex { "required" },	true,	false),
	"#fileLiteral":	("#fileLiteral",	Regex { "#fileLiteral" },	true,	false),
	"lowerThan":	("lowerThan",	Regex { "lowerThan" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"willSet":	("willSet",	Regex { "willSet" },	true,	false),
	"^":	("^",	Regex { "^" },	true,	false),
	"some":	("some",	Regex { "some" },	true,	false),
	"i386":	("i386",	Regex { "i386" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"watchOSApplicationExtension":	("watchOSApplicationExtension",	Regex { "watchOSApplicationExtension" },	true,	false),
	"tvOS":	("tvOS",	Regex { "tvOS" },	true,	false),
	"watchOS":	("watchOS",	Regex { "watchOS" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"lazy":	("lazy",	Regex { "lazy" },	true,	false),
	"right":	("right",	Regex { "right" },	true,	false),
	"blue":	("blue",	Regex { "blue" },	true,	false),
	"struct":	("struct",	Regex { "struct" },	true,	false),
	"open":	("open",	Regex { "open" },	true,	false),
	"break":	("break",	Regex { "break" },	true,	false),
	"return":	("return",	Regex { "return" },	true,	false),
	"...":	("...",	Regex { "..." },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"_unsafeInheritExecutor":	("_unsafeInheritExecutor",	Regex { "_unsafeInheritExecutor" },	true,	false),
	"@":	("@",	Regex { "@" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	"final":	("final",	Regex { "final" },	true,	false),
	"class":	("class",	Regex { "class" },	true,	false),
	"false":	("false",	Regex { "false" },	true,	false),
	"#colorLiteral":	("#colorLiteral",	Regex { "#colorLiteral" },	true,	false),
	"else":	("else",	Regex { "else" },	true,	false),
	"mutating":	("mutating",	Regex { "mutating" },	true,	false),
	"macCatalyst":	("macCatalyst",	Regex { "macCatalyst" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"tvOSApplicationExtension":	("tvOSApplicationExtension",	Regex { "tvOSApplicationExtension" },	true,	false),
	"#keyPath":	("#keyPath",	Regex { "#keyPath" },	true,	false),
	"default":	("default",	Regex { "default" },	true,	false),
	"throw":	("throw",	Regex { "throw" },	true,	false),
	"visionOSApplicationExtension":	("visionOSApplicationExtension",	Regex { "visionOSApplicationExtension" },	true,	false),
	"getter:":	("getter:",	Regex { "getter:" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	"associativity":	("associativity",	Regex { "associativity" },	true,	false),
	"\\":	("\\",	Regex { "\\" },	true,	false),
	"arch":	("arch",	Regex { "arch" },	true,	false),
	"while":	("while",	Regex { "while" },	true,	false),
	"left":	("left",	Regex { "left" },	true,	false),
	"throws":	("throws",	Regex { "throws" },	true,	false),
	"import":	("import",	Regex { "import" },	true,	false),
	"static":	("static",	Regex { "static" },	true,	false),
	";":	(";",	Regex { ";" },	true,	false),
	"inout":	("inout",	Regex { "inout" },	true,	false),
	"guard":	("guard",	Regex { "guard" },	true,	false),
	"async":	("async",	Regex { "async" },	true,	false),
	"public":	("public",	Regex { "public" },	true,	false),
	"await":	("await",	Regex { "await" },	true,	false),
	"self":	("self",	Regex { "self" },	true,	false),
	"isolated":	("isolated",	Regex { "isolated" },	true,	false),
	"fallthrough":	("fallthrough",	Regex { "fallthrough" },	true,	false),
	"init":	("init",	Regex { "init" },	true,	false),
	"move":	("move",	Regex { "move" },	true,	false),
	"weak":	("weak",	Regex { "weak" },	true,	false),
	"canImport":	("canImport",	Regex { "canImport" },	true,	false),
	"typealias":	("typealias",	Regex { "typealias" },	true,	false),
	"x86_64":	("x86_64",	Regex { "x86_64" },	true,	false),
	"unowned(unsafe)":	("unowned(unsafe)",	Regex { "unowned(unsafe)" },	true,	false),
	"Self":	("Self",	Regex { "Self" },	true,	false),
	"#endif":	("#endif",	Regex { "#endif" },	true,	false),
	"assignment":	("assignment",	Regex { "assignment" },	true,	false),
	",":	(",",	Regex { "," },	true,	false),
	"macOSApplicationExtension":	("macOSApplicationExtension",	Regex { "macOSApplicationExtension" },	true,	false),
	"if":	("if",	Regex { "if" },	true,	false),
	"safe":	("safe",	Regex { "safe" },	true,	false),
	"var":	("var",	Regex { "var" },	true,	false),
	"unowned":	("unowned",	Regex { "unowned" },	true,	false),
	"Windows":	("Windows",	Regex { "Windows" },	true,	false),
	"yield":	("yield",	Regex { "yield" },	true,	false),
	"iOS":	("iOS",	Regex { "iOS" },	true,	false),
	"#imageLiteral":	("#imageLiteral",	Regex { "#imageLiteral" },	true,	false),
	"nonisolated":	("nonisolated",	Regex { "nonisolated" },	true,	false),
	"unowned(safe)":	("unowned(safe)",	Regex { "unowned(safe)" },	true,	false),
	"!":	("!",	Regex { "!" },	true,	false),
	"alpha":	("alpha",	Regex { "alpha" },	true,	false),
	"in":	("in",	Regex { "in" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"Linux":	("Linux",	Regex { "Linux" },	true,	false),
	"borrowing":	("borrowing",	Regex { "borrowing" },	true,	false),
	"precedencegroup":	("precedencegroup",	Regex { "precedencegroup" },	true,	false),
	"none":	("none",	Regex { "none" },	true,	false),
	"&&":	("&&",	Regex { "&&" },	true,	false),
	"visionOS":	("visionOS",	Regex { "visionOS" },	true,	false),
	"let":	("let",	Regex { "let" },	true,	false),
	"os":	("os",	Regex { "os" },	true,	false),
	"defer":	("defer",	Regex { "defer" },	true,	false),
	"protocol":	("protocol",	Regex { "protocol" },	true,	false),
	"Any":	("Any",	Regex { "Any" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"case":	("case",	Regex { "case" },	true,	false),
	"#elseif":	("#elseif",	Regex { "#elseif" },	true,	false),
	"#":	("#",	Regex { "#" },	true,	false),
	"didSet":	("didSet",	Regex { "didSet" },	true,	false),
	"true":	("true",	Regex { "true" },	true,	false),
	"&":	("&",	Regex { "&" },	true,	false),
	"arm64":	("arm64",	Regex { "arm64" },	true,	false),
	"convenience":	("convenience",	Regex { "convenience" },	true,	false),
	"catch":	("catch",	Regex { "catch" },	true,	false),
	"func":	("func",	Regex { "func" },	true,	false),
	"override":	("override",	Regex { "override" },	true,	false),
	"continue":	("continue",	Regex { "continue" },	true,	false),
	"try":	("try",	Regex { "try" },	true,	false),
	"super":	("super",	Regex { "super" },	true,	false),
	"each":	("each",	Regex { "each" },	true,	false),
	"macOS":	("macOS",	Regex { "macOS" },	true,	false),
	"#if":	("#if",	Regex { "#if" },	true,	false),
	"for":	("for",	Regex { "for" },	true,	false),
	"package":	("package",	Regex { "package" },	true,	false),
	"-":	("-",	Regex { "-" },	true,	false),
	"actor":	("actor",	Regex { "actor" },	true,	false),
	"macCatalystApplicationExtension":	("macCatalystApplicationExtension",	Regex { "macCatalystApplicationExtension" },	true,	false),
	"fileprivate":	("fileprivate",	Regex { "fileprivate" },	true,	false),
	"#selector":	("#selector",	Regex { "#selector" },	true,	false),
	"infix":	("infix",	Regex { "infix" },	true,	false),
	"associatedtype":	("associatedtype",	Regex { "associatedtype" },	true,	false),
	"postfix":	("postfix",	Regex { "postfix" },	true,	false),
	"internal":	("internal",	Regex { "internal" },	true,	false),
	"indirect":	("indirect",	Regex { "indirect" },	true,	false),
	"%":	("%",	Regex { "%" },	true,	false),
	"deinit":	("deinit",	Regex { "deinit" },	true,	false),
	"higherThan":	("higherThan",	Regex { "higherThan" },	true,	false),
	"private":	("private",	Regex { "private" },	true,	false),
	"operator":	("operator",	Regex { "operator" },	true,	false),
	"red":	("red",	Regex { "red" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"Type":	("Type",	Regex { "Type" },	true,	false),
	"_":	("_",	Regex { "_" },	true,	false),
	"/":	("/",	Regex { "/" },	true,	false),
	"do":	("do",	Regex { "do" },	true,	false),
	"prefix":	("prefix",	Regex { "prefix" },	true,	false),
	"enum":	("enum",	Regex { "enum" },	true,	false),
	"nonmutating":	("nonmutating",	Regex { "nonmutating" },	true,	false),
	"green":	("green",	Regex { "green" },	true,	false),
	"setter:":	("setter:",	Regex { "setter:" },	true,	false),
	"macro":	("macro",	Regex { "macro" },	true,	false),
	"repeat":	("repeat",	Regex { "repeat" },	true,	false),
	"extension":	("extension",	Regex { "extension" },	true,	false),
	"dynamic":	("dynamic",	Regex { "dynamic" },	true,	false),
	"#error":	("#error",	Regex { "#error" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"discard":	("discard",	Regex { "discard" },	true,	false),
	">=":	(">=",	Regex { ">=" },	true,	false),
	"any":	("any",	Regex { "any" },	true,	false),
	"nil":	("nil",	Regex { "nil" },	true,	false),
	"get":	("get",	Regex { "get" },	true,	false),
	"iOSApplicationExtension":	("iOSApplicationExtension",	Regex { "iOSApplicationExtension" },	true,	false),
	"copy":	("copy",	Regex { "copy" },	true,	false),
	"arm":	("arm",	Regex { "arm" },	true,	false),
	"||":	("||",	Regex { "||" },	true,	false),
	"simulator":	("simulator",	Regex { "simulator" },	true,	false),
	"is":	("is",	Regex { "is" },	true,	false),
	"#available":	("#available",	Regex { "#available" },	true,	false),
	"targetEnvironment":	("targetEnvironment",	Regex { "targetEnvironment" },	true,	false),
	"consuming":	("consuming",	Regex { "consuming" },	true,	false),
	"where":	("where",	Regex { "where" },	true,	false),
	"swift":	("swift",	Regex { "swift" },	true,	false),
	"rethrows":	("rethrows",	Regex { "rethrows" },	true,	false),
	"set":	("set",	Regex { "set" },	true,	false),
	"subscript":	("subscript",	Regex { "subscript" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"optional":	("optional",	Regex { "optional" },	true,	false),
	"#unavailable":	("#unavailable",	Regex { "#unavailable" },	true,	false),
]
func setterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["set", "mutating", "nonmutating", "@"])
}
func unionStyleEnumMembers() {
	if token.type = .ALT {
		unionStyleEnumMember()
		// OPT
	}
	expect(["let", "infix", "actor", "prefix", "subscript", "convenience", "final", "override", "dynamic", "unowned", "static", "func", "#error", "postfix", "#warning", "fileprivate", "protocol", "indirect", "required", "extension", "private", "#sourceLocation", "nonisolated", "init", "import", "var", "package", "nonmutating", "open", "@", "deinit", "case", "lazy", "public", "optional", "mutating", "precedencegroup", "internal", "weak", "#if", "typealias", "struct", "enum", "class"])
}
func caseLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["case", "@"])
}
func tupleType() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func extensionMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["import", "public", "prefix", "private", "static", "actor", "required", "mutating", "protocol", "let", "indirect", "var", "postfix", "fileprivate", "struct", "optional", "class", "precedencegroup", "nonmutating", "subscript", "package", "dynamic", "weak", "typealias", "@", "lazy", "final", "override", "unowned", "convenience", "open", "func", "deinit", "extension", "enum", "internal", "nonisolated", "init", "infix"])
}
func conditionalSwitchCase() {
	if token.type = .ALT {
		switchIfDirectiveClause()
		// OPT
	}
	expect(["#if"])
}
func Operator() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["plainOperator"])
}
func doStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["do"])
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
func swiftVersion() {
	if token.type = .ALT {
		decimalDigits()
		// OPT
	}
	expect(["decimalNumber"])
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
func willSetDidSetBlock() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func structMembers() {
	if token.type = .ALT {
		structMember()
		// OPT
	}
	expect(["actor", "convenience", "#warning", "#error", "subscript", "precedencegroup", "extension", "package", "indirect", "public", "private", "@", "static", "class", "#sourceLocation", "protocol", "unowned", "init", "fileprivate", "weak", "#if", "internal", "override", "nonmutating", "optional", "let", "required", "postfix", "var", "infix", "lazy", "deinit", "nonisolated", "open", "final", "func", "enum", "dynamic", "typealias", "import", "struct", "prefix", "mutating"])
}
func classBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func extensionMembers() {
	if token.type = .ALT {
		extensionMember()
		// OPT
	}
	expect(["private", "package", "lazy", "extension", "fileprivate", "precedencegroup", "subscript", "var", "enum", "infix", "@", "mutating", "class", "convenience", "actor", "unowned", "public", "final", "import", "#error", "nonisolated", "indirect", "deinit", "optional", "weak", "let", "dynamic", "postfix", "protocol", "typealias", "required", "prefix", "struct", "override", "open", "static", "func", "#warning", "#sourceLocation", "nonmutating", "#if", "init", "internal"])
}
func functionTypeArgumentClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func importPath() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func tupleTypeElementList() {
	if token.type = .ALT {
		tupleTypeElement()
		// END
	} else if token.type = .ALT {
		tupleTypeElement()
		// END
	}
	expect(["implicitParameterName", "some", "plainIdentifier", "(", "Self", "_", "propertyWrapperProjection", "@", "escapedIdentifier", "[", "Any"])
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
func guardStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["guard"])
}
func patternInitializerList() {
	if token.type = .ALT {
		patternInitializer()
		// END
	} else if token.type = .ALT {
		patternInitializer()
		// END
	}
	expect(["plainRegularExpressionLiteral", "propertyWrapperProjection", "plainOperator", "dotOperator", "switch", "plainIdentifier", "_", "hexadecimalLiteral", "is", "self", "octalLiteral", "#fileLiteral", "let", "{", "(", "try", "[", "stringLiteral", "false", "hexadecimalFloatingPointLiteral", "#selector", "#keyPath", "extendedRegularExpressionLiteral", "true", "&", "nil", "macroIdentifier", "\\\\", "await", "binaryLiteral", ".", "var", "#colorLiteral", "if", "super", "#imageLiteral", "implicitParameterName", "decimalFloatingPointLiteral", "escapedIdentifier", "decimalNumber"])
}
func precedenceGroupRelation() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["higherThan"])
}
func repeatWhileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["repeat"])
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
func ifExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
}
func actorName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func caseItemList() {
	if token.type = .ALT {
		pattern()
		// OPT
	} else if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["escapedIdentifier", "nil", "#fileLiteral", "decimalNumber", "[", "#keyPath", "false", "self", "hexadecimalLiteral", "switch", "is", "try", "(", "propertyWrapperProjection", "plainRegularExpressionLiteral", "super", "stringLiteral", "await", "plainOperator", "macroIdentifier", "binaryLiteral", "extendedRegularExpressionLiteral", "octalLiteral", "\\\\", "true", "var", "_", "#selector", "{", "if", ".", "implicitParameterName", "plainIdentifier", "#colorLiteral", "dotOperator", "decimalFloatingPointLiteral", "hexadecimalFloatingPointLiteral", "let", "#imageLiteral", "&"])
}
func elseDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#else"])
}
func sameTypeRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func whereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func subscriptExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["#keyPath", "if", "super", "#fileLiteral", "self", ".", "stringLiteral", "nil", "#imageLiteral", "hexadecimalLiteral", "(", "switch", "escapedIdentifier", "[", "{", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "#colorLiteral", "#selector", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "_", "macroIdentifier", "propertyWrapperProjection", "octalLiteral", "binaryLiteral", "false", "plainIdentifier", "\\\\", "true", "decimalNumber", "implicitParameterName"])
}
func typealiasDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["package", "fileprivate", "public", "private", "@", "open", "typealias", "internal"])
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
func macroExpansionExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["macroIdentifier"])
}
func switchStatement() {
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
	expect(["enum", "package", "public", "indirect", "private", "open", "fileprivate", "internal", "@"])
}
func genericWhereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func importDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["import", "@"])
}
func getterSetterKeywordBlock() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func expression() {
	if token.type = .ALT {
		// OPT
	}
	expect(["(", "\\\\", "self", "binaryLiteral", "decimalFloatingPointLiteral", "false", "true", "#fileLiteral", "implicitParameterName", "_", "if", "#colorLiteral", "extendedRegularExpressionLiteral", "#selector", "{", ".", "super", "hexadecimalFloatingPointLiteral", "stringLiteral", "switch", "octalLiteral", "#imageLiteral", "plainIdentifier", "dotOperator", "escapedIdentifier", "propertyWrapperProjection", "await", "hexadecimalLiteral", "macroIdentifier", "try", "nil", "plainRegularExpressionLiteral", "#keyPath", "decimalNumber", "&", "[", "plainOperator"])
}
func genericParameterList() {
	if token.type = .ALT {
		genericParameter()
		// END
	} else if token.type = .ALT {
		genericParameter()
		// END
	}
	expect(["_", "plainIdentifier", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier"])
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
	expect(["required", "internal", "package", "final", "dynamic", "unowned", "prefix", "mutating", "@", "lazy", "class", "private", "nonmutating", "postfix", "infix", "var", "convenience", "override", "fileprivate", "weak", "nonisolated", "optional", "static", "open", "public"])
}
func breakStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["break"])
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
func getterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["nonmutating", "@", "get", "mutating"])
}
func rawValueAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func protocolMember() {
	if token.type = .ALT {
		protocolMemberDeclaration()
		// END
	} else if token.type = .ALT {
		protocolMemberDeclaration()
		// END
	}
	expect(["required", "static", "typealias", "convenience", "weak", "internal", "class", "override", "prefix", "@", "open", "fileprivate", "lazy", "nonmutating", "associatedtype", "nonisolated", "private", "dynamic", "init", "package", "infix", "unowned", "subscript", "mutating", "func", "optional", "public", "final", "postfix", "var"])
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
	expect(["internal", "nonmutating", "convenience", "open", "private", "static", "override", "postfix", "@", "unowned", "prefix", "weak", "fileprivate", "required", "public", "subscript", "final", "lazy", "class", "infix", "dynamic", "nonisolated", "mutating", "optional", "package"])
}
func attributes() {
	if token.type = .ALT {
		attribute()
		// OPT
	}
	expect(["@"])
}
func arrayType() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
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
func declarationModifiers() {
	if token.type = .ALT {
		declarationModifier()
		// OPT
	}
	expect(["optional", "open", "postfix", "required", "internal", "nonmutating", "lazy", "prefix", "static", "public", "dynamic", "class", "infix", "fileprivate", "nonisolated", "final", "unowned", "convenience", "private", "package", "override", "weak", "mutating"])
}
func returnStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["return"])
}
func lineNumber() {
	if token.type = .ALT {
		decimalDigits()
		// END
	}
	expect(["decimalNumber"])
}
func protocolAssociatedTypeDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["package", "internal", "public", "@", "associatedtype", "fileprivate", "open", "private"])
}
func keyPathComponents() {
	if token.type = .ALT {
		keyPathComponent()
		// END
	} else if token.type = .ALT {
		keyPathComponent()
		// END
	}
	expect(["implicitParameterName", "escapedIdentifier", "_", "!", "self", "plainIdentifier", "?", "[", "propertyWrapperProjection"])
}
func constantDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["internal", "@", "fileprivate", "weak", "optional", "convenience", "public", "required", "postfix", "unowned", "nonmutating", "lazy", "package", "mutating", "private", "static", "final", "override", "infix", "let", "nonisolated", "dynamic", "open", "class", "prefix"])
}
func structDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["internal", "struct", "@", "fileprivate", "open", "private", "package", "public"])
}
func dictionaryLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["["])
}
func switchElseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
}
func parameterTypeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
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
func subscriptResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func ifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#if"])
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
	expect(["optional", "postfix", "unowned", "nonisolated", "@", "required", "nonmutating", "prefix", "final", "public", "private", "fileprivate", "var", "internal", "lazy", "dynamic", "open", "static", "class", "infix", "convenience", "weak", "package", "override", "mutating"])
}
func statementLabel() {
	if token.type = .ALT {
		labelName()
		next()
	}
	expect(["propertyWrapperProjection", "implicitParameterName", "plainIdentifier", "escapedIdentifier", "_"])
}
func continueStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["continue"])
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
	expect(["macOS", "watchOS", "tvOSApplicationExtension", "macCatalystApplicationExtension", "visionOSApplicationExtension", "iOSApplicationExtension", "iOS", "watchOSApplicationExtension", "macCatalyst", "tvOS", "visionOS", "macOSApplicationExtension"])
}
func staticStringLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["stringLiteral"])
}
func didSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "didSet"])
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
func captureList() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
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
func identifierList() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func closureParameter() {
	if token.type = .ALT {
		closureParameterName()
		// OPT
	} else if token.type = .ALT {
		closureParameterName()
		// OPT
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func labelName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
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
func requirement() {
	if token.type = .ALT {
		conformanceRequirement()
		// END
	} else if token.type = .ALT {
		conformanceRequirement()
		// END
	}
	expect(["escapedIdentifier", "_", "implicitParameterName", "propertyWrapperProjection", "plainIdentifier"])
}
func unionStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["case", "indirect", "@"])
}
func optionalPattern() {
	if token.type = .ALT {
		identifierPattern()
		next()
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "_", "implicitParameterName"])
}
func argumentNames() {
	if token.type = .ALT {
		argumentName()
		// OPT
	}
	expect(["plainIdentifier", "_", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection"])
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
func typeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func elseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
}
func labeledTrailingClosure() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func ifExpressionTail() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
}
func unionStyleEnum() {
	if token.type = .ALT {
		// OPT
	}
	expect(["indirect", "enum"])
}
func elseifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#elseif"])
}
func functionTypeArgument() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["escapedIdentifier", "inout", "_", "some", "plainIdentifier", "@", "Self", "Any", "(", "implicitParameterName", "[", "propertyWrapperProjection"])
}
func rawValueStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["implicitParameterName", "escapedIdentifier", "_", "propertyWrapperProjection", "plainIdentifier"])
}
func dictionaryLiteralItem() {
	if token.type = .ALT {
		expression()
		next()
	}
	expect(["#selector", "binaryLiteral", "#fileLiteral", "#colorLiteral", "{", "propertyWrapperProjection", "(", ".", "stringLiteral", "#keyPath", "escapedIdentifier", "plainRegularExpressionLiteral", "#imageLiteral", "dotOperator", "\\\\", "[", "self", "await", "hexadecimalLiteral", "if", "try", "implicitParameterName", "nil", "&", "plainIdentifier", "extendedRegularExpressionLiteral", "false", "hexadecimalFloatingPointLiteral", "true", "decimalNumber", "switch", "octalLiteral", "super", "decimalFloatingPointLiteral", "plainOperator", "_", "macroIdentifier"])
}
func keyPathPostfixes() {
	if token.type = .ALT {
		keyPathPostfix()
		// OPT
	}
	expect(["!", "[", "self", "?"])
}
func whereExpression() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["#selector", "binaryLiteral", "#fileLiteral", "#colorLiteral", "{", "propertyWrapperProjection", "(", ".", "stringLiteral", "#keyPath", "escapedIdentifier", "plainRegularExpressionLiteral", "#imageLiteral", "dotOperator", "\\\\", "[", "self", "await", "hexadecimalLiteral", "if", "try", "implicitParameterName", "nil", "&", "plainIdentifier", "extendedRegularExpressionLiteral", "false", "hexadecimalFloatingPointLiteral", "true", "decimalNumber", "switch", "octalLiteral", "super", "decimalFloatingPointLiteral", "plainOperator", "_", "macroIdentifier"])
}
func parameterList() {
	if token.type = .ALT {
		parameter()
		// END
	} else if token.type = .ALT {
		parameter()
		// END
	}
	expect(["_", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection", "plainIdentifier"])
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
	expect(["#selector", "binaryLiteral", "#fileLiteral", "#colorLiteral", "{", "propertyWrapperProjection", "(", ".", "stringLiteral", "#keyPath", "escapedIdentifier", "plainRegularExpressionLiteral", "#imageLiteral", "dotOperator", "\\\\", "[", "self", "await", "hexadecimalLiteral", "if", "try", "implicitParameterName", "nil", "&", "plainIdentifier", "extendedRegularExpressionLiteral", "false", "hexadecimalFloatingPointLiteral", "true", "decimalNumber", "switch", "octalLiteral", "super", "decimalFloatingPointLiteral", "plainOperator", "_", "macroIdentifier"])
}
func catchClauses() {
	if token.type = .ALT {
		catchClause()
		// OPT
	}
	expect(["catch"])
}
func elementName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func inOutExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["&"])
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
func metatypeType() {
	if token.type = .ALT {
		type()
		next()
	} else if token.type = .ALT {
		type()
		next()
	}
	expect(["plainIdentifier", "[", "(", "@", "escapedIdentifier", "_", "Any", "propertyWrapperProjection", "some", "Self", "implicitParameterName"])
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
func protocolSubscriptDeclaration() {
	if token.type = .ALT {
		subscriptHead()
		subscriptResult()
		// OPT
	}
	expect(["internal", "nonmutating", "convenience", "open", "private", "static", "override", "postfix", "@", "unowned", "prefix", "weak", "fileprivate", "required", "public", "subscript", "final", "lazy", "class", "infix", "dynamic", "nonisolated", "mutating", "optional", "package"])
}
func macroFunctionSignatureResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
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
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func parameterClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func conformanceRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	} else if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func decimalLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["decimalNumber"])
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
func enumCasePattern() {
	if token.type = .ALT {
		// OPT
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "_", ".", "implicitParameterName"])
}
func typeIdentifier() {
	if token.type = .ALT {
		typeName()
		// OPT
	} else if token.type = .ALT {
		typeName()
		// OPT
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "_", "implicitParameterName"])
}
func tuplePatternElement() {
	if token.type = .ALT {
		pattern()
		// END
	} else if token.type = .ALT {
		pattern()
		// END
	}
	expect(["escapedIdentifier", "nil", "#fileLiteral", "decimalNumber", "[", "#keyPath", "false", "self", "hexadecimalLiteral", "switch", "is", "try", "(", "propertyWrapperProjection", "plainRegularExpressionLiteral", "super", "stringLiteral", "await", "plainOperator", "macroIdentifier", "binaryLiteral", "extendedRegularExpressionLiteral", "octalLiteral", "\\\\", "true", "var", "_", "#selector", "{", "if", ".", "implicitParameterName", "plainIdentifier", "#colorLiteral", "dotOperator", "decimalFloatingPointLiteral", "hexadecimalFloatingPointLiteral", "let", "#imageLiteral", "&"])
}
func protocolCompositionContinuation() {
	if token.type = .ALT {
		typeIdentifier()
		// END
	} else if token.type = .ALT {
		typeIdentifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func catchClause() {
	if token.type = .ALT {
		next()
	}
	expect(["catch"])
}
func precedenceGroupName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func externalParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
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
func closureExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func structName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func infixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["dotOperator", "plainOperator"])
}
func throwsClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["throws"])
}
func catchPatternList() {
	if token.type = .ALT {
		catchPattern()
		// END
	} else if token.type = .ALT {
		catchPattern()
		// END
	}
	expect(["try", "macroIdentifier", "stringLiteral", "implicitParameterName", ".", "switch", "escapedIdentifier", "dotOperator", "#keyPath", "true", "#selector", "\\\\", "_", "nil", "self", "#colorLiteral", "{", "super", "false", "hexadecimalLiteral", "decimalFloatingPointLiteral", "&", "is", "var", "plainRegularExpressionLiteral", "plainIdentifier", "octalLiteral", "(", "hexadecimalFloatingPointLiteral", "decimalNumber", "[", "#fileLiteral", "if", "await", "binaryLiteral", "extendedRegularExpressionLiteral", "#imageLiteral", "let", "propertyWrapperProjection", "plainOperator"])
}
func prefixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["dotOperator", "plainOperator"])
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
	expect(["hexadecimalLiteral", "hexadecimalFloatingPointLiteral", "decimalNumber", "octalLiteral", "binaryLiteral", "decimalFloatingPointLiteral"])
}
func nilLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["nil"])
}
func superclassInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func setterName() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
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
	expect(["#keyPath", "if", "super", "#fileLiteral", "self", ".", "stringLiteral", "nil", "#imageLiteral", "hexadecimalLiteral", "(", "switch", "escapedIdentifier", "[", "{", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "#colorLiteral", "#selector", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "_", "macroIdentifier", "propertyWrapperProjection", "octalLiteral", "binaryLiteral", "false", "plainIdentifier", "\\\\", "true", "decimalNumber", "implicitParameterName"])
}
func parameter() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["escapedIdentifier", "implicitParameterName", "plainIdentifier", "_", "propertyWrapperProjection"])
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
func functionCallArgumentClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func infixExpressions() {
	if token.type = .ALT {
		infixExpression()
		// OPT
	}
	expect(["is", "?", "as", "plainOperator", "=", "dotOperator"])
}
func patternInitializer() {
	if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["escapedIdentifier", "nil", "#fileLiteral", "decimalNumber", "[", "#keyPath", "false", "self", "hexadecimalLiteral", "switch", "is", "try", "(", "propertyWrapperProjection", "plainRegularExpressionLiteral", "super", "stringLiteral", "await", "plainOperator", "macroIdentifier", "binaryLiteral", "extendedRegularExpressionLiteral", "octalLiteral", "\\\\", "true", "var", "_", "#selector", "{", "if", ".", "implicitParameterName", "plainIdentifier", "#colorLiteral", "dotOperator", "decimalFloatingPointLiteral", "hexadecimalFloatingPointLiteral", "let", "#imageLiteral", "&"])
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
func selfSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func infixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["infix"])
}
func ifStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
}
func switchExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["switch"])
}
func tupleElement() {
	if token.type = .ALT {
		expression()
		// END
	} else if token.type = .ALT {
		expression()
		// END
	}
	expect(["#selector", "binaryLiteral", "#fileLiteral", "#colorLiteral", "{", "propertyWrapperProjection", "(", ".", "stringLiteral", "#keyPath", "escapedIdentifier", "plainRegularExpressionLiteral", "#imageLiteral", "dotOperator", "\\\\", "[", "self", "await", "hexadecimalLiteral", "if", "try", "implicitParameterName", "nil", "&", "plainIdentifier", "extendedRegularExpressionLiteral", "false", "hexadecimalFloatingPointLiteral", "true", "decimalNumber", "switch", "octalLiteral", "super", "decimalFloatingPointLiteral", "plainOperator", "_", "macroIdentifier"])
}
func diagnosticStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#warning"])
}
func typeInheritanceList() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "@", "_", "implicitParameterName"])
}
func regularExpressionLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["plainRegularExpressionLiteral"])
}
func actorBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func protocolBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
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
func setterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["mutating", "@", "set", "nonmutating"])
}
func classMembers() {
	if token.type = .ALT {
		classMember()
		// OPT
	}
	expect(["precedencegroup", "weak", "postfix", "override", "private", "final", "@", "func", "static", "nonisolated", "#sourceLocation", "fileprivate", "package", "init", "#if", "enum", "open", "unowned", "internal", "protocol", "infix", "actor", "#warning", "subscript", "nonmutating", "class", "convenience", "import", "prefix", "struct", "extension", "mutating", "let", "var", "indirect", "required", "deinit", "typealias", "public", "dynamic", "optional", "lazy", "#error"])
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
	expect(["plainRegularExpressionLiteral", "if", "switch", "#selector", "#imageLiteral", "binaryLiteral", "\\\\", "hexadecimalFloatingPointLiteral", "implicitParameterName", "stringLiteral", "#fileLiteral", "hexadecimalLiteral", "self", ".", "escapedIdentifier", "_", "nil", "propertyWrapperProjection", "(", "{", "decimalFloatingPointLiteral", "false", "macroIdentifier", "[", "#colorLiteral", "extendedRegularExpressionLiteral", "octalLiteral", "#keyPath", "decimalNumber", "plainIdentifier", "super", "true"])
}
func initializerBody() {
	if token.type = .ALT {
		codeBlock()
		// END
	}
	expect(["{"])
}
func caseCondition() {
	if token.type = .ALT {
		next()
	}
	expect(["case"])
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
func keyPathStringExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["#keyPath"])
}
func superclassSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func arrayLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func selfMethodExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
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
func endifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#endif"])
}
func functionType() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "("])
}
func variableDeclarationHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["dynamic", "optional", "required", "var", "mutating", "nonmutating", "fileprivate", "public", "static", "nonisolated", "internal", "package", "prefix", "@", "private", "lazy", "unowned", "convenience", "class", "override", "infix", "weak", "postfix", "final", "open"])
}
func availabilityArguments() {
	if token.type = .ALT {
		availabilityArgument()
		// END
	} else if token.type = .ALT {
		availabilityArgument()
		// END
	}
	expect(["tvOS", "macOS", "macOSApplicationExtension", "macCatalystApplicationExtension", "tvOSApplicationExtension", "macCatalyst", "visionOSApplicationExtension", "iOS", "iOSApplicationExtension", "watchOSApplicationExtension", "visionOS", "watchOS", "*"])
}
func functionBody() {
	if token.type = .ALT {
		codeBlock()
		// END
	}
	expect(["{"])
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
	expect(["propertyWrapperProjection", "escapedIdentifier", "implicitParameterName", "plainIdentifier", "_"])
}
func postfixSelfExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["#keyPath", "if", "super", "#fileLiteral", "self", ".", "stringLiteral", "nil", "#imageLiteral", "hexadecimalLiteral", "(", "switch", "escapedIdentifier", "[", "{", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "#colorLiteral", "#selector", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "_", "macroIdentifier", "propertyWrapperProjection", "octalLiteral", "binaryLiteral", "false", "plainIdentifier", "\\\\", "true", "decimalNumber", "implicitParameterName"])
}
func structMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["import", "public", "prefix", "private", "static", "actor", "required", "mutating", "protocol", "let", "indirect", "var", "postfix", "fileprivate", "struct", "optional", "class", "precedencegroup", "nonmutating", "subscript", "package", "dynamic", "weak", "typealias", "@", "lazy", "final", "override", "unowned", "convenience", "open", "func", "deinit", "extension", "enum", "internal", "nonisolated", "init", "infix"])
}
func protocolInitializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["class", "public", "convenience", "prefix", "postfix", "private", "@", "unowned", "nonisolated", "mutating", "required", "nonmutating", "weak", "fileprivate", "static", "final", "internal", "infix", "override", "dynamic", "open", "init", "package", "lazy", "optional"])
}
func interpolatedStringLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["stringLiteral"])
}
func conditionalOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["?"])
}
func extensionBody() {
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
	expect(["escapedIdentifier", "nil", "#fileLiteral", "decimalNumber", "[", "#keyPath", "false", "self", "hexadecimalLiteral", "switch", "is", "try", "(", "propertyWrapperProjection", "plainRegularExpressionLiteral", "super", "stringLiteral", "await", "plainOperator", "macroIdentifier", "binaryLiteral", "extendedRegularExpressionLiteral", "octalLiteral", "\\\\", "true", "var", "_", "#selector", "{", "if", ".", "implicitParameterName", "plainIdentifier", "#colorLiteral", "dotOperator", "decimalFloatingPointLiteral", "hexadecimalFloatingPointLiteral", "let", "#imageLiteral", "&"])
}
func macroDeclaration() {
	if token.type = .ALT {
		macroHead()
		identifier()
		// OPT
	}
	expect(["open", "postfix", "override", "dynamic", "fileprivate", "final", "public", "prefix", "macro", "static", "unowned", "nonmutating", "internal", "optional", "nonisolated", "class", "private", "convenience", "@", "required", "infix", "lazy", "package", "weak", "mutating"])
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
func precedenceGroupNames() {
	if token.type = .ALT {
		precedenceGroupName()
		// END
	} else if token.type = .ALT {
		precedenceGroupName()
		// END
	}
	expect(["escapedIdentifier", "implicitParameterName", "_", "propertyWrapperProjection", "plainIdentifier"])
}
func attributeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func identifierPattern() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func requirementList() {
	if token.type = .ALT {
		requirement()
		// END
	} else if token.type = .ALT {
		requirement()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "_", "plainIdentifier", "escapedIdentifier"])
}
func wildcardExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["_"])
}
func actorMembers() {
	if token.type = .ALT {
		actorMember()
		// OPT
	}
	expect(["fileprivate", "static", "postfix", "var", "override", "#warning", "prefix", "@", "init", "final", "infix", "deinit", "optional", "extension", "nonmutating", "precedencegroup", "nonisolated", "weak", "private", "unowned", "#error", "mutating", "indirect", "lazy", "#sourceLocation", "typealias", "enum", "struct", "public", "package", "dynamic", "internal", "protocol", "#if", "required", "subscript", "actor", "open", "convenience", "func", "import", "let", "class"])
}
func dictionaryLiteralItems() {
	if token.type = .ALT {
		dictionaryLiteralItem()
		// OPT
	} else if token.type = .ALT {
		dictionaryLiteralItem()
		// OPT
	}
	expect(["await", "{", "extendedRegularExpressionLiteral", "#colorLiteral", "hexadecimalLiteral", "propertyWrapperProjection", "true", "dotOperator", "macroIdentifier", "&", "decimalNumber", "(", ".", "#fileLiteral", "#imageLiteral", "#selector", "stringLiteral", "switch", "\\\\", "implicitParameterName", "octalLiteral", "[", "try", "plainOperator", "if", "#keyPath", "plainIdentifier", "escapedIdentifier", "binaryLiteral", "_", "nil", "self", "super", "false", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "plainRegularExpressionLiteral"])
}
func conditionalCompilationBlock() {
	if token.type = .ALT {
		ifDirectiveClause()
		// OPT
	}
	expect(["#if"])
}
func rawValueStyleEnumCaseList() {
	if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	} else if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	}
	expect(["implicitParameterName", "plainIdentifier", "escapedIdentifier", "_", "propertyWrapperProjection"])
}
func protocolMethodDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["func", "class", "internal", "@", "infix", "weak", "dynamic", "mutating", "fileprivate", "private", "open", "nonmutating", "postfix", "public", "prefix", "static", "required", "unowned", "lazy", "optional", "package", "override", "final", "nonisolated", "convenience"])
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
func floatingPointLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["decimalFloatingPointLiteral"])
}
func functionCallArgumentList() {
	if token.type = .ALT {
		functionCallArgument()
		// END
	} else if token.type = .ALT {
		functionCallArgument()
		// END
	}
	expect(["{", "if", "#selector", "propertyWrapperProjection", "plainOperator", "#fileLiteral", "_", "nil", "#colorLiteral", "\\\\", "hexadecimalFloatingPointLiteral", "&", "true", "false", "plainIdentifier", "macroIdentifier", "octalLiteral", "plainRegularExpressionLiteral", "hexadecimalLiteral", "dotOperator", "decimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "self", "(", "decimalNumber", "super", "implicitParameterName", "#imageLiteral", ".", "binaryLiteral", "switch", "stringLiteral", "try", "await", "#keyPath", "escapedIdentifier", "["])
}
func closureParameterList() {
	if token.type = .ALT {
		closureParameter()
		// END
	} else if token.type = .ALT {
		closureParameter()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func rawValueStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "case"])
}
func macroHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["static", "private", "macro", "lazy", "dynamic", "@", "convenience", "postfix", "infix", "fileprivate", "open", "nonisolated", "package", "final", "prefix", "public", "nonmutating", "unowned", "internal", "optional", "class", "required", "override", "weak", "mutating"])
}
func valueBindingPattern() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["var"])
}
func enumCaseName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func willSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["willSet", "@"])
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
func deinitializerDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "deinit"])
}
func tuplePattern() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func balancedTokens() {
	if token.type = .ALT {
		balancedToken()
		// OPT
	}
	expect(["dynamic", "convenience", "open", "nonisolated", ";", "import", "propertyWrapperProjection", "octalLiteral", "class", "#selector", "final", "nil", "internal", "for", "defer", "false", "rethrows", "plainIdentifier", "#elseif", "binaryLiteral", "didSet", "break", "catch", "lazy", "Self", "extendedRegularExpressionLiteral", "#warning", "yield", "optional", "<", "#sourceLocation", "Any", "nonmutating", "^", "discard", "prefix", "true", "where", "left", "~", "=", "guard", "fileprivate", "isolated", "struct", "try", "unowned", "@", "precedencegroup", "await", "self", "deinit", "#fileLiteral", "#imageLiteral", "get", "borrowing", "higherThan", "each", ",", "dotOperator", "#keyPath", "/", "[", "escapedIdentifier", "var", "?", "&", "return", "willSet", "!", "else", "if", "public", "throws", "extension", "move", "copy", "static", "hexadecimalLiteral", "operator", "#unavailable", "some", "postfix", "package", "fallthrough", "lowerThan", "_unsafeInheritExecutor", "do", "required", "is", "in", "#endif", "#error", "stringLiteral", "actor", "weak", "default", "plainOperator", "init", "implicitParameterName", "hexadecimalFloatingPointLiteral", "+", "#available", "indirect", ">", "override", "mutating", "inout", "enum", "%", "while", "super", "*", "func", "decimalNumber", ".", "subscript", "consuming", "throw", "(", "async", "_", "right", "let", ":", "associatedtype", "typealias", "#else", "switch", "-", "{", "#colorLiteral", "#", "set", "continue", "protocol", "|", "as", "none", "#if", "private", "case", "associativity", "repeat", "plainRegularExpressionLiteral", "decimalFloatingPointLiteral"])
}
func actorIsolationModifier() {
	if token.type = .ALT {
		next()
	}
	expect(["nonisolated"])
}
func precedenceGroupAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["assignment"])
}
func rawValueStyleEnumMembers() {
	if token.type = .ALT {
		rawValueStyleEnumMember()
		// OPT
	}
	expect(["mutating", "actor", "public", "subscript", "nonmutating", "nonisolated", "#error", "static", "#warning", "struct", "precedencegroup", "dynamic", "#sourceLocation", "init", "#if", "open", "weak", "import", "final", "indirect", "postfix", "class", "package", "override", "convenience", "optional", "@", "protocol", "infix", "func", "typealias", "deinit", "case", "private", "enum", "internal", "var", "prefix", "let", "lazy", "unowned", "fileprivate", "required", "extension"])
}
func forcedValueExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["#keyPath", "if", "super", "#fileLiteral", "self", ".", "stringLiteral", "nil", "#imageLiteral", "hexadecimalLiteral", "(", "switch", "escapedIdentifier", "[", "{", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "#colorLiteral", "#selector", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "_", "macroIdentifier", "propertyWrapperProjection", "octalLiteral", "binaryLiteral", "false", "plainIdentifier", "\\\\", "true", "decimalNumber", "implicitParameterName"])
}
func arrayLiteralItems() {
	if token.type = .ALT {
		arrayLiteralItem()
		// OPT
	} else if token.type = .ALT {
		arrayLiteralItem()
		// OPT
	}
	expect(["self", "(", "plainIdentifier", "#colorLiteral", "#selector", "macroIdentifier", "false", "octalLiteral", "plainRegularExpressionLiteral", "binaryLiteral", "\\\\", "{", "hexadecimalLiteral", "implicitParameterName", "[", "#keyPath", "nil", "if", "stringLiteral", "escapedIdentifier", "plainOperator", "extendedRegularExpressionLiteral", "dotOperator", "try", "await", "_", "switch", "true", "&", ".", "super", "#fileLiteral", "propertyWrapperProjection", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "decimalNumber", "#imageLiteral"])
}
func implicitlyUnwrappedOptionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["plainIdentifier", "[", "(", "@", "escapedIdentifier", "_", "Any", "propertyWrapperProjection", "some", "Self", "implicitParameterName"])
}
func argumentLabel() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func argumentName() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func switchCases() {
	if token.type = .ALT {
		switchCase()
		// OPT
	}
	expect(["#if", "case", "@", "default"])
}
func tupleElementList() {
	if token.type = .ALT {
		tupleElement()
		// END
	} else if token.type = .ALT {
		tupleElement()
		// END
	}
	expect(["&", "\\\\", "#fileLiteral", "try", "extendedRegularExpressionLiteral", "binaryLiteral", "switch", ".", "#selector", "hexadecimalLiteral", "dotOperator", "implicitParameterName", "escapedIdentifier", "false", "plainIdentifier", "stringLiteral", "super", "(", "#imageLiteral", "_", "await", "octalLiteral", "decimalNumber", "propertyWrapperProjection", "hexadecimalFloatingPointLiteral", "plainOperator", "self", "true", "[", "macroIdentifier", "#colorLiteral", "decimalFloatingPointLiteral", "{", "#keyPath", "plainRegularExpressionLiteral", "if", "nil"])
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
	expect(["#selector", "binaryLiteral", "#fileLiteral", "#colorLiteral", "{", "propertyWrapperProjection", "(", ".", "stringLiteral", "#keyPath", "escapedIdentifier", "plainRegularExpressionLiteral", "#imageLiteral", "dotOperator", "\\\\", "[", "self", "await", "hexadecimalLiteral", "if", "try", "implicitParameterName", "nil", "&", "plainIdentifier", "extendedRegularExpressionLiteral", "false", "hexadecimalFloatingPointLiteral", "true", "decimalNumber", "switch", "octalLiteral", "super", "decimalFloatingPointLiteral", "plainOperator", "_", "macroIdentifier"])
}
func variableName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func protocolName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func switchElseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
}
func swiftVersionContinuation() {
	if token.type = .ALT {
		next()
	}
	expect(["."])
}
func enumName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func labeledTrailingClosures() {
	if token.type = .ALT {
		labeledTrailingClosure()
		// OPT
	}
	expect(["plainIdentifier", "escapedIdentifier", "_", "implicitParameterName", "propertyWrapperProjection"])
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
	expect(["import", "public", "prefix", "private", "static", "actor", "required", "mutating", "protocol", "let", "indirect", "var", "postfix", "fileprivate", "struct", "optional", "class", "precedencegroup", "nonmutating", "subscript", "package", "dynamic", "weak", "typealias", "@", "lazy", "final", "override", "unowned", "convenience", "open", "func", "deinit", "extension", "enum", "internal", "nonisolated", "init", "infix"])
}
func functionHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["final", "optional", "nonmutating", "convenience", "nonisolated", "class", "weak", "private", "lazy", "postfix", "@", "dynamic", "internal", "override", "infix", "static", "fileprivate", "func", "public", "prefix", "required", "package", "mutating", "unowned", "open"])
}
func className() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func availabilityCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#available"])
}
func closureParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func initializer() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func optionalChainingExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["#keyPath", "if", "super", "#fileLiteral", "self", ".", "stringLiteral", "nil", "#imageLiteral", "hexadecimalLiteral", "(", "switch", "escapedIdentifier", "[", "{", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "#colorLiteral", "#selector", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "_", "macroIdentifier", "propertyWrapperProjection", "octalLiteral", "binaryLiteral", "false", "plainIdentifier", "\\\\", "true", "decimalNumber", "implicitParameterName"])
}
func fallthroughStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["fallthrough"])
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
	expect(["propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "_", "implicitParameterName"])
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
	expect(["#keyPath", "if", "super", "#fileLiteral", "self", ".", "stringLiteral", "nil", "#imageLiteral", "hexadecimalLiteral", "(", "switch", "escapedIdentifier", "[", "{", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "#colorLiteral", "#selector", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "_", "macroIdentifier", "propertyWrapperProjection", "octalLiteral", "binaryLiteral", "false", "plainIdentifier", "\\\\", "true", "decimalNumber", "implicitParameterName"])
}
func captureListItems() {
	if token.type = .ALT {
		captureListItem()
		// END
	} else if token.type = .ALT {
		captureListItem()
		// END
	}
	expect(["_", "self", "plainIdentifier", "unowned(unsafe)", "escapedIdentifier", "weak", "unowned", "unowned(safe)", "implicitParameterName", "propertyWrapperProjection"])
}
func functionName() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
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
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "_"])
}
func protocolDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["internal", "open", "fileprivate", "protocol", "package", "@", "private", "public"])
}
func postfixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["postfix"])
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
	expect(["hexadecimalLiteral", "hexadecimalFloatingPointLiteral", "decimalNumber", "octalLiteral", "binaryLiteral", "decimalFloatingPointLiteral"])
}
func boxedProtocolType() {
	if token.type = .ALT {
		next()
	}
	expect(["any"])
}
func switchIfDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
}
func initializerExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	} else if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["#keyPath", "if", "super", "#fileLiteral", "self", ".", "stringLiteral", "nil", "#imageLiteral", "hexadecimalLiteral", "(", "switch", "escapedIdentifier", "[", "{", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "#colorLiteral", "#selector", "plainRegularExpressionLiteral", "extendedRegularExpressionLiteral", "_", "macroIdentifier", "propertyWrapperProjection", "octalLiteral", "binaryLiteral", "false", "plainIdentifier", "\\\\", "true", "decimalNumber", "implicitParameterName"])
}
func structBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func filePath() {
	if token.type = .ALT {
		staticStringLiteral()
		// END
	}
	expect(["stringLiteral"])
}
func initializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["class", "public", "convenience", "prefix", "postfix", "private", "@", "unowned", "nonisolated", "mutating", "required", "nonmutating", "weak", "fileprivate", "static", "final", "internal", "infix", "override", "dynamic", "open", "init", "package", "lazy", "optional"])
}
func functionResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func initializerHead() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["postfix", "package", "nonisolated", "infix", "mutating", "init", "override", "internal", "final", "nonmutating", "convenience", "private", "fileprivate", "public", "static", "lazy", "@", "unowned", "optional", "dynamic", "class", "open", "required", "weak", "prefix"])
}
func subscriptHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["mutating", "prefix", "weak", "dynamic", "nonisolated", "required", "unowned", "optional", "class", "nonmutating", "open", "lazy", "package", "internal", "subscript", "fileprivate", "static", "override", "convenience", "infix", "@", "final", "postfix", "public", "private"])
}
func forInStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["for"])
}
func ifDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
}
func unionStyleEnumCaseList() {
	if token.type = .ALT {
		unionStyleEnumCase()
		// END
	} else if token.type = .ALT {
		unionStyleEnumCase()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "_", "implicitParameterName", "propertyWrapperProjection"])
}
func tupleExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func parenthesizedExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func topLevelDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["#selector", "@", "[", "static", "switch", "prefix", "await", "func", "weak", "indirect", "dynamic", "fallthrough", "repeat", "internal", "var", "extendedRegularExpressionLiteral", "true", "#imageLiteral", "implicitParameterName", "hexadecimalFloatingPointLiteral", "#fileLiteral", "decimalNumber", "precedencegroup", "", "convenience", "hexadecimalLiteral", ".", "postfix", "lazy", "do", "#colorLiteral", "mutating", "nil", "#warning", "decimalFloatingPointLiteral", "optional", "continue", "init", "infix", "actor", "open", "fileprivate", "struct", "\\\\", "(", "break", "subscript", "plainIdentifier", "for", "while", "dotOperator", "class", "return", "escapedIdentifier", "deinit", "&", "_", "self", "nonmutating", "defer", "#if", "plainRegularExpressionLiteral", "if", "final", "stringLiteral", "public", "super", "#error", "macroIdentifier", "#sourceLocation", "propertyWrapperProjection", "import", "unowned", "protocol", "{", "enum", "plainOperator", "try", "package", "nonisolated", "guard", "typealias", "override", "let", "#keyPath", "private", "octalLiteral", "extension", "false", "binaryLiteral", "throw", "required"])
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
	expect(["#selector", "binaryLiteral", "#fileLiteral", "#colorLiteral", "{", "propertyWrapperProjection", "(", ".", "stringLiteral", "#keyPath", "escapedIdentifier", "plainRegularExpressionLiteral", "#imageLiteral", "dotOperator", "\\\\", "[", "self", "await", "hexadecimalLiteral", "if", "try", "implicitParameterName", "nil", "&", "plainIdentifier", "extendedRegularExpressionLiteral", "false", "hexadecimalFloatingPointLiteral", "true", "decimalNumber", "switch", "octalLiteral", "super", "decimalFloatingPointLiteral", "plainOperator", "_", "macroIdentifier"])
}
func mutationModifier() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["mutating"])
}
func expressionPattern() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["#selector", "binaryLiteral", "#fileLiteral", "#colorLiteral", "{", "propertyWrapperProjection", "(", ".", "stringLiteral", "#keyPath", "escapedIdentifier", "plainRegularExpressionLiteral", "#imageLiteral", "dotOperator", "\\\\", "[", "self", "await", "hexadecimalLiteral", "if", "try", "implicitParameterName", "nil", "&", "plainIdentifier", "extendedRegularExpressionLiteral", "false", "hexadecimalFloatingPointLiteral", "true", "decimalNumber", "switch", "octalLiteral", "super", "decimalFloatingPointLiteral", "plainOperator", "_", "macroIdentifier"])
}
func assignmentOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
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
func macroSignature() {
	if token.type = .ALT {
		parameterClause()
		// OPT
	}
	expect(["("])
}
func booleanLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["true"])
}
func lineControlStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#sourceLocation"])
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
func precedenceGroupDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["precedencegroup"])
}
func keyPathExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["\\\\"])
}
func classMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["import", "public", "prefix", "private", "static", "actor", "required", "mutating", "protocol", "let", "indirect", "var", "postfix", "fileprivate", "struct", "optional", "class", "precedencegroup", "nonmutating", "subscript", "package", "dynamic", "weak", "typealias", "@", "lazy", "final", "override", "unowned", "convenience", "open", "func", "deinit", "extension", "enum", "internal", "nonisolated", "init", "infix"])
}
func environment() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["simulator"])
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
func protocolMembers() {
	if token.type = .ALT {
		protocolMember()
		// OPT
	}
	expect(["open", "static", "final", "internal", "class", "public", "postfix", "weak", "nonisolated", "subscript", "fileprivate", "optional", "#sourceLocation", "lazy", "@", "package", "dynamic", "required", "convenience", "mutating", "#warning", "associatedtype", "infix", "typealias", "init", "#if", "prefix", "private", "func", "nonmutating", "unowned", "#error", "var", "override"])
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
	expect(["lowerThan", "higherThan"])
}
func functionTypeArgumentList() {
	if token.type = .ALT {
		functionTypeArgument()
		// END
	} else if token.type = .ALT {
		functionTypeArgument()
		// END
	}
	expect(["propertyWrapperProjection", "@", "_", "inout", "Any", "plainIdentifier", "(", "some", "Self", "escapedIdentifier", "implicitParameterName", "["])
}
func genericArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
}
func deferStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["defer"])
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
func switchExpressionCases() {
	if token.type = .ALT {
		switchExpressionCase()
		// OPT
	}
	expect(["default", "case", "@"])
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
	expect(["swift", "os", "arch", "canImport", "compiler", "targetEnvironment"])
}
func statements() {
	if token.type = .ALT {
		statement()
		// OPT
	}
	expect(["binaryLiteral", "propertyWrapperProjection", "macroIdentifier", "#imageLiteral", "public", "try", "decimalFloatingPointLiteral", "dynamic", "[", "@", "dotOperator", "hexadecimalFloatingPointLiteral", "open", "do", "_", "deinit", "postfix", "octalLiteral", "switch", "final", "continue", "prefix", "class", "if", "internal", "override", "typealias", "nonmutating", "throw", "static", "optional", "import", "plainOperator", "let", "nil", "#sourceLocation", "for", "enum", "\\\\", "fallthrough", "hexadecimalLiteral", "func", "(", "return", "extension", "escapedIdentifier", "var", "weak", "super", "lazy", "plainIdentifier", "init", "#selector", "false", "subscript", "#colorLiteral", "true", "infix", ".", "#fileLiteral", "required", "while", "mutating", "decimalNumber", "repeat", "indirect", "precedencegroup", "await", "{", "&", "struct", "#warning", "break", "defer", "#keyPath", "guard", "package", "convenience", "self", "#error", "actor", "unowned", "stringLiteral", "plainRegularExpressionLiteral", "private", "implicitParameterName", "#if", "protocol", "fileprivate", "extendedRegularExpressionLiteral", "nonisolated"])
}
func functionDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["func", "class", "internal", "@", "infix", "weak", "dynamic", "mutating", "fileprivate", "private", "open", "nonmutating", "postfix", "public", "prefix", "static", "required", "unowned", "lazy", "optional", "package", "override", "final", "nonisolated", "convenience"])
}
func actorDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["public", "internal", "fileprivate", "private", "@", "actor", "package", "open"])
}
func attribute() {
	if token.type = .ALT {
		next()
	}
	expect(["@"])
}
func genericArgumentList() {
	if token.type = .ALT {
		genericArgument()
		// END
	} else if token.type = .ALT {
		genericArgument()
		// END
	}
	expect(["(", "escapedIdentifier", "_", "implicitParameterName", "Self", "@", "some", "plainIdentifier", "[", "propertyWrapperProjection", "Any"])
}
func genericArgument() {
	if token.type = .ALT {
		type()
		// END
	}
	expect(["plainIdentifier", "[", "(", "@", "escapedIdentifier", "_", "Any", "propertyWrapperProjection", "some", "Self", "implicitParameterName"])
}
func codeBlock() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func keyPathComponent() {
	if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func superclassMethodExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func decimalDigits() {
	if token.type = .ALT {
		next()
	}
	expect(["decimalNumber"])
}
func wildcardPattern() {
	if token.type = .ALT {
		next()
	}
	expect(["_"])
}
func elseifDirectiveClause() {
	if token.type = .ALT {
		elseifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#elseif"])
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
func throwStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["throw"])
}
func typealiasAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func tuplePatternElementList() {
	if token.type = .ALT {
		tuplePatternElement()
		// END
	} else if token.type = .ALT {
		tuplePatternElement()
		// END
	}
	expect(["#fileLiteral", "#selector", "is", "let", "self", "propertyWrapperProjection", "octalLiteral", "macroIdentifier", "decimalNumber", "plainIdentifier", "&", "false", "hexadecimalLiteral", "nil", "#imageLiteral", "super", "plainOperator", "#colorLiteral", "extendedRegularExpressionLiteral", "plainRegularExpressionLiteral", ".", "\\\\", "switch", "stringLiteral", "escapedIdentifier", "binaryLiteral", "try", "if", "(", "{", "[", "await", "decimalFloatingPointLiteral", "dotOperator", "_", "var", "#keyPath", "implicitParameterName", "hexadecimalFloatingPointLiteral", "true"])
}
func protocolCompositionType() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName"])
}
func infixOperatorGroup() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func optionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["plainIdentifier", "[", "(", "@", "escapedIdentifier", "_", "Any", "propertyWrapperProjection", "some", "Self", "implicitParameterName"])
}
func protocolPropertyDeclaration() {
	if token.type = .ALT {
		variableDeclarationHead()
		variableName()
		typeAnnotation()
		getterSetterKeywordBlock()
		// END
	}
	expect(["required", "internal", "package", "final", "dynamic", "unowned", "prefix", "mutating", "@", "lazy", "class", "private", "nonmutating", "postfix", "infix", "var", "convenience", "override", "fileprivate", "weak", "nonisolated", "optional", "static", "open", "public"])
}
func actorMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["import", "public", "prefix", "private", "static", "actor", "required", "mutating", "protocol", "let", "indirect", "var", "postfix", "fileprivate", "struct", "optional", "class", "precedencegroup", "nonmutating", "subscript", "package", "dynamic", "weak", "typealias", "@", "lazy", "final", "override", "unowned", "convenience", "open", "func", "deinit", "extension", "enum", "internal", "nonisolated", "init", "infix"])
}
func typealiasName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func whileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["while"])
}
func rawValueStyleEnum() {
	if token.type = .ALT {
		next()
	}
	expect(["enum"])
}
func precedenceGroupAttributes() {
	if token.type = .ALT {
		precedenceGroupAttribute()
		// OPT
	}
	expect(["assignment", "associativity", "higherThan", "lowerThan"])
}
func conditionList() {
	if token.type = .ALT {
		condition()
		// END
	} else if token.type = .ALT {
		condition()
		// END
	}
	expect(["true", "\\\\", "if", "macroIdentifier", "(", "dotOperator", "#selector", "await", "octalLiteral", "#fileLiteral", "#colorLiteral", "#unavailable", "_", "nil", "switch", "plainIdentifier", "{", "plainOperator", "var", "super", "#imageLiteral", "decimalFloatingPointLiteral", "#available", "case", "plainRegularExpressionLiteral", "self", "stringLiteral", "hexadecimalLiteral", "decimalNumber", "#keyPath", "implicitParameterName", ".", "[", "&", "propertyWrapperProjection", "binaryLiteral", "hexadecimalFloatingPointLiteral", "try", "let", "false", "extendedRegularExpressionLiteral", "escapedIdentifier"])
}
func getterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["get", "mutating", "nonmutating", "@"])
}
func switchElseifDirectiveClause() {
	if token.type = .ALT {
		elseifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#elseif"])
}
func awaitOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["await"])
}
func trailingClosures() {
	if token.type = .ALT {
		closureExpression()
		// OPT
	}
	expect(["{"])
}
func attributeArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func isPattern() {
	if token.type = .ALT {
		next()
	}
	expect(["is"])
}
func asPattern() {
	if token.type = .ALT {
		pattern()
		next()
	}
	expect(["escapedIdentifier", "nil", "#fileLiteral", "decimalNumber", "[", "#keyPath", "false", "self", "hexadecimalLiteral", "switch", "is", "try", "(", "propertyWrapperProjection", "plainRegularExpressionLiteral", "super", "stringLiteral", "await", "plainOperator", "macroIdentifier", "binaryLiteral", "extendedRegularExpressionLiteral", "octalLiteral", "\\\\", "true", "var", "_", "#selector", "{", "if", ".", "implicitParameterName", "plainIdentifier", "#colorLiteral", "dotOperator", "decimalFloatingPointLiteral", "hexadecimalFloatingPointLiteral", "let", "#imageLiteral", "&"])
}
func arrayLiteralItem() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["#selector", "binaryLiteral", "#fileLiteral", "#colorLiteral", "{", "propertyWrapperProjection", "(", ".", "stringLiteral", "#keyPath", "escapedIdentifier", "plainRegularExpressionLiteral", "#imageLiteral", "dotOperator", "\\\\", "[", "self", "await", "hexadecimalLiteral", "if", "try", "implicitParameterName", "nil", "&", "plainIdentifier", "extendedRegularExpressionLiteral", "false", "hexadecimalFloatingPointLiteral", "true", "decimalNumber", "switch", "octalLiteral", "super", "decimalFloatingPointLiteral", "plainOperator", "_", "macroIdentifier"])
}
func typeInheritanceClause() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func genericParameterClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
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
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
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
func selfInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func captureListItem() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["unowned", "unowned(unsafe)", "implicitParameterName", "propertyWrapperProjection", "weak", "escapedIdentifier", "_", "plainIdentifier", "unowned(safe)"])
}
func implicitMemberExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["."])
}
func dictionaryType() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func defaultLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["default", "@"])
}
func closureSignature() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["plainIdentifier", "[", "_", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier", "("])
}
func prefixExpression() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["false", "#keyPath", "#colorLiteral", "_", "true", "octalLiteral", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "implicitParameterName", "escapedIdentifier", "#fileLiteral", "\\\\", "[", "self", ".", "macroIdentifier", "if", "decimalFloatingPointLiteral", "hexadecimalLiteral", "(", "#selector", "nil", "#imageLiteral", "decimalNumber", "plainIdentifier", "stringLiteral", "binaryLiteral", "dotOperator", "plainOperator", "super", "plainRegularExpressionLiteral", "switch", "propertyWrapperProjection", "{"])
}
func localParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func numericLiteral() {
	if token.type = .ALT {
		integerLiteral()
		// END
	} else if token.type = .ALT {
		integerLiteral()
		// END
	}
	expect(["decimalNumber", "binaryLiteral", "octalLiteral", "hexadecimalLiteral"])
}
func elseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
}
func typeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "_", "plainIdentifier"])
}
func elseClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
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
	expect(["false", "hexadecimalFloatingPointLiteral", "binaryLiteral", "decimalNumber", "hexadecimalLiteral", "nil", "extendedRegularExpressionLiteral", "decimalFloatingPointLiteral", "stringLiteral", "true", "octalLiteral", "plainRegularExpressionLiteral"])
}
func unionStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["implicitParameterName", "escapedIdentifier", "_", "propertyWrapperProjection", "plainIdentifier"])
}
func optionalBindingCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["let"])
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
func selfType() {
	if token.type = .ALT {
		next()
	}
	expect(["Self"])
}
func postfixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["dotOperator", "plainOperator"])
}
func defaultArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func classDeclaration() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["fileprivate", "@", "package", "final", "private", "public", "internal", "open", "class"])
}
func extensionDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["package", "fileprivate", "internal", "public", "extension", "open", "private", "@"])
}
func anyType() {
	if token.type = .ALT {
		next()
	}
	expect(["Any"])
}
func macroDefinition() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
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
	expect(["import", "public", "prefix", "private", "static", "actor", "required", "mutating", "protocol", "let", "indirect", "var", "postfix", "fileprivate", "struct", "optional", "class", "precedencegroup", "nonmutating", "subscript", "package", "dynamic", "weak", "typealias", "@", "lazy", "final", "override", "unowned", "convenience", "open", "func", "deinit", "extension", "enum", "internal", "nonisolated", "init", "infix"])
}
