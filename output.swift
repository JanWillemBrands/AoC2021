//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"octalLiteral":	("/-?0o[0-7][0-7_]*/",	/-?0o[0-7][0-7_]*/,	false,	false),
	"macroIdentifier":	("/#\\p{XID_Start}\\p{XID_Continue}*/",	/#\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"hexadecimalLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*/,	false,	false),
	"hexadecimalFloatingPointLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/,	false,	false),
	"extendedRegularExpressionLiteral":	("/#+\\/(?:[^\\/\\\\]|\\\\.)+\\/#+/",	/#+\/(?:[^\/\\]|\\.)+\/#+/,	false,	false),
	"decimalFloatingPointLiteral":	("/-?[0-9][0-9_]*(?:\\.[0-9][0-9_]*)(?:[eE][+-]?[0-9][0-9_]*)?/",	/-?[0-9][0-9_]*(?:\.[0-9][0-9_]*)(?:[eE][+-]?[0-9][0-9_]*)?/,	false,	false),
	"multilineComment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"comment":	("/\\/\\/.*\\r?\\n?/",	/\/\/.*\r?\n?/,	false,	true),
	"plainRegularExpressionLiteral":	("/\\/[^\\s](?:(?:[^\\/\\\\\\s]|\\\\.)*[^\\s])?\\//",	/\/[^\s](?:(?:[^\/\\\s]|\\.)*[^\s])?\//,	false,	false),
	"plainOperator":	("/[\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}][\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]*/",	/[\/=+\-*%!&|^~?<>\p{Sm}\p{So}][\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]*/,	false,	false),
	"decimalNumber":	("/-?[0-9][0-9_]*/",	/-?[0-9][0-9_]*/,	false,	false),
	"escapedIdentifier":	("/`\\p{XID_Start}\\p{XID_Continue}*`/",	/`\p{XID_Start}\p{XID_Continue}*`/,	false,	false),
	"dotOperator":	("/\\.[\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]+/",	/\.[\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]+/,	false,	false),
	"propertyWrapperProjection":	("/\\$\\p{XID_Continue}+/",	/\$\p{XID_Continue}+/,	false,	false),
	"plainIdentifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"implicitParameterName":	("/\\$[0-9]+/",	/\$[0-9]+/,	false,	false),
	"binaryLiteral":	("/-?0b[0-1][0-1_]*/",	/-?0b[0-1][0-1_]*/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"stringLiteral":	("/#*\"(?:\\\\#*\\([^)]*\\)|\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]{1,8}\\}|[^\"\\\\\\n\\r])*\"#*|#*\"\"\"(?:\\\\#*\\([^)]*\\)|\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]{1,8}\\}|\\\\#*\\s*\\n|[^\\\\])*\"\"\"#*/",	/#*"(?:\\#*\([^)]*\)|\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]{1,8}\}|[^"\\\n\r])*"#*|#*"""(?:\\#*\([^)]*\)|\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]{1,8}\}|\\#*\s*\n|[^\\])*"""#*/,	false,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	",":	(",",	Regex { "," },	true,	false),
	"enum":	("enum",	Regex { "enum" },	true,	false),
	"#imageLiteral":	("#imageLiteral",	Regex { "#imageLiteral" },	true,	false),
	"file:":	("file:",	Regex { "file:" },	true,	false),
	"postfix":	("postfix",	Regex { "postfix" },	true,	false),
	"#available":	("#available",	Regex { "#available" },	true,	false),
	"inout":	("inout",	Regex { "inout" },	true,	false),
	"assignment":	("assignment",	Regex { "assignment" },	true,	false),
	"break":	("break",	Regex { "break" },	true,	false),
	"#filePath":	("#filePath",	Regex { "#filePath" },	true,	false),
	"typealias":	("typealias",	Regex { "typealias" },	true,	false),
	"!":	("!",	Regex { "!" },	true,	false),
	"unsafe":	("unsafe",	Regex { "unsafe" },	true,	false),
	"is":	("is",	Regex { "is" },	true,	false),
	"left":	("left",	Regex { "left" },	true,	false),
	"macOS":	("macOS",	Regex { "macOS" },	true,	false),
	"...":	("...",	Regex { "..." },	true,	false),
	"#line":	("#line",	Regex { "#line" },	true,	false),
	"os":	("os",	Regex { "os" },	true,	false),
	"red":	("red",	Regex { "red" },	true,	false),
	"/":	("/",	Regex { "/" },	true,	false),
	"default":	("default",	Regex { "default" },	true,	false),
	"^":	("^",	Regex { "^" },	true,	false),
	"catch":	("catch",	Regex { "catch" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"if":	("if",	Regex { "if" },	true,	false),
	"green":	("green",	Regex { "green" },	true,	false),
	"any":	("any",	Regex { "any" },	true,	false),
	";":	(";",	Regex { ";" },	true,	false),
	"continue":	("continue",	Regex { "continue" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"defer":	("defer",	Regex { "defer" },	true,	false),
	"#dsohandle":	("#dsohandle",	Regex { "#dsohandle" },	true,	false),
	"async":	("async",	Regex { "async" },	true,	false),
	"#":	("#",	Regex { "#" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	"safe":	("safe",	Regex { "safe" },	true,	false),
	"throw":	("throw",	Regex { "throw" },	true,	false),
	"fileprivate":	("fileprivate",	Regex { "fileprivate" },	true,	false),
	"compiler":	("compiler",	Regex { "compiler" },	true,	false),
	"getter:":	("getter:",	Regex { "getter:" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"none":	("none",	Regex { "none" },	true,	false),
	"unowned(unsafe)":	("unowned(unsafe)",	Regex { "unowned(unsafe)" },	true,	false),
	"lazy":	("lazy",	Regex { "lazy" },	true,	false),
	"public":	("public",	Regex { "public" },	true,	false),
	"class":	("class",	Regex { "class" },	true,	false),
	"protocol":	("protocol",	Regex { "protocol" },	true,	false),
	"each":	("each",	Regex { "each" },	true,	false),
	"try":	("try",	Regex { "try" },	true,	false),
	"#else":	("#else",	Regex { "#else" },	true,	false),
	"iOS":	("iOS",	Regex { "iOS" },	true,	false),
	"await":	("await",	Regex { "await" },	true,	false),
	"return":	("return",	Regex { "return" },	true,	false),
	"func":	("func",	Regex { "func" },	true,	false),
	"while":	("while",	Regex { "while" },	true,	false),
	"optional":	("optional",	Regex { "optional" },	true,	false),
	"==":	("==",	Regex { "==" },	true,	false),
	"operator":	("operator",	Regex { "operator" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"-":	("-",	Regex { "-" },	true,	false),
	"#warning":	("#warning",	Regex { "#warning" },	true,	false),
	"precedencegroup":	("precedencegroup",	Regex { "precedencegroup" },	true,	false),
	"move":	("move",	Regex { "move" },	true,	false),
	"internal":	("internal",	Regex { "internal" },	true,	false),
	"targetEnvironment":	("targetEnvironment",	Regex { "targetEnvironment" },	true,	false),
	"throws":	("throws",	Regex { "throws" },	true,	false),
	"Any":	("Any",	Regex { "Any" },	true,	false),
	"nil":	("nil",	Regex { "nil" },	true,	false),
	"_":	("_",	Regex { "_" },	true,	false),
	"||":	("||",	Regex { "||" },	true,	false),
	"fallthrough":	("fallthrough",	Regex { "fallthrough" },	true,	false),
	"Type":	("Type",	Regex { "Type" },	true,	false),
	"associativity":	("associativity",	Regex { "associativity" },	true,	false),
	"visionOSApplicationExtension":	("visionOSApplicationExtension",	Regex { "visionOSApplicationExtension" },	true,	false),
	"blue":	("blue",	Regex { "blue" },	true,	false),
	"setter:":	("setter:",	Regex { "setter:" },	true,	false),
	"import":	("import",	Regex { "import" },	true,	false),
	"else":	("else",	Regex { "else" },	true,	false),
	">=":	(">=",	Regex { ">=" },	true,	false),
	"arch":	("arch",	Regex { "arch" },	true,	false),
	"alpha":	("alpha",	Regex { "alpha" },	true,	false),
	"#keyPath":	("#keyPath",	Regex { "#keyPath" },	true,	false),
	"init":	("init",	Regex { "init" },	true,	false),
	"self":	("self",	Regex { "self" },	true,	false),
	"do":	("do",	Regex { "do" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"convenience":	("convenience",	Regex { "convenience" },	true,	false),
	"i386":	("i386",	Regex { "i386" },	true,	false),
	"override":	("override",	Regex { "override" },	true,	false),
	"in":	("in",	Regex { "in" },	true,	false),
	"nonmutating":	("nonmutating",	Regex { "nonmutating" },	true,	false),
	"iOSApplicationExtension":	("iOSApplicationExtension",	Regex { "iOSApplicationExtension" },	true,	false),
	"super":	("super",	Regex { "super" },	true,	false),
	"struct":	("struct",	Regex { "struct" },	true,	false),
	"extension":	("extension",	Regex { "extension" },	true,	false),
	"\\":	("\\",	Regex { "\\" },	true,	false),
	"#if":	("#if",	Regex { "#if" },	true,	false),
	"discard":	("discard",	Regex { "discard" },	true,	false),
	"final":	("final",	Regex { "final" },	true,	false),
	"willSet":	("willSet",	Regex { "willSet" },	true,	false),
	"macCatalystApplicationExtension":	("macCatalystApplicationExtension",	Regex { "macCatalystApplicationExtension" },	true,	false),
	"visionOS":	("visionOS",	Regex { "visionOS" },	true,	false),
	"package":	("package",	Regex { "package" },	true,	false),
	"swift":	("swift",	Regex { "swift" },	true,	false),
	"private":	("private",	Regex { "private" },	true,	false),
	"Protocol":	("Protocol",	Regex { "Protocol" },	true,	false),
	"switch":	("switch",	Regex { "switch" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"some":	("some",	Regex { "some" },	true,	false),
	"#endif":	("#endif",	Regex { "#endif" },	true,	false),
	"#elseif":	("#elseif",	Regex { "#elseif" },	true,	false),
	"rethrows":	("rethrows",	Regex { "rethrows" },	true,	false),
	"false":	("false",	Regex { "false" },	true,	false),
	"x86_64":	("x86_64",	Regex { "x86_64" },	true,	false),
	"&&":	("&&",	Regex { "&&" },	true,	false),
	"_unsafeInheritExecutor":	("_unsafeInheritExecutor",	Regex { "_unsafeInheritExecutor" },	true,	false),
	"#file":	("#file",	Regex { "#file" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"lowerThan":	("lowerThan",	Regex { "lowerThan" },	true,	false),
	"open":	("open",	Regex { "open" },	true,	false),
	"deinit":	("deinit",	Regex { "deinit" },	true,	false),
	"#error":	("#error",	Regex { "#error" },	true,	false),
	"&":	("&",	Regex { "&" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"get":	("get",	Regex { "get" },	true,	false),
	"dynamic":	("dynamic",	Regex { "dynamic" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"#selector":	("#selector",	Regex { "#selector" },	true,	false),
	"Linux":	("Linux",	Regex { "Linux" },	true,	false),
	"borrowing":	("borrowing",	Regex { "borrowing" },	true,	false),
	"#unavailable":	("#unavailable",	Regex { "#unavailable" },	true,	false),
	"simulator":	("simulator",	Regex { "simulator" },	true,	false),
	"required":	("required",	Regex { "required" },	true,	false),
	"consuming":	("consuming",	Regex { "consuming" },	true,	false),
	"macro":	("macro",	Regex { "macro" },	true,	false),
	"prefix":	("prefix",	Regex { "prefix" },	true,	false),
	"tvOS":	("tvOS",	Regex { "tvOS" },	true,	false),
	"var":	("var",	Regex { "var" },	true,	false),
	"resourceName":	("resourceName",	Regex { "resourceName" },	true,	false),
	"macCatalyst":	("macCatalyst",	Regex { "macCatalyst" },	true,	false),
	"#function":	("#function",	Regex { "#function" },	true,	false),
	"higherThan":	("higherThan",	Regex { "higherThan" },	true,	false),
	"arm":	("arm",	Regex { "arm" },	true,	false),
	"tvOSApplicationExtension":	("tvOSApplicationExtension",	Regex { "tvOSApplicationExtension" },	true,	false),
	"@":	("@",	Regex { "@" },	true,	false),
	"line:":	("line:",	Regex { "line:" },	true,	false),
	"static":	("static",	Regex { "static" },	true,	false),
	"unowned":	("unowned",	Regex { "unowned" },	true,	false),
	"watchOSApplicationExtension":	("watchOSApplicationExtension",	Regex { "watchOSApplicationExtension" },	true,	false),
	"case":	("case",	Regex { "case" },	true,	false),
	"indirect":	("indirect",	Regex { "indirect" },	true,	false),
	"guard":	("guard",	Regex { "guard" },	true,	false),
	"Windows":	("Windows",	Regex { "Windows" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	"associatedtype":	("associatedtype",	Regex { "associatedtype" },	true,	false),
	"subscript":	("subscript",	Regex { "subscript" },	true,	false),
	"macOSApplicationExtension":	("macOSApplicationExtension",	Regex { "macOSApplicationExtension" },	true,	false),
	"#fileID":	("#fileID",	Regex { "#fileID" },	true,	false),
	"#colorLiteral":	("#colorLiteral",	Regex { "#colorLiteral" },	true,	false),
	"%":	("%",	Regex { "%" },	true,	false),
	"let":	("let",	Regex { "let" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"arm64":	("arm64",	Regex { "arm64" },	true,	false),
	"didSet":	("didSet",	Regex { "didSet" },	true,	false),
	"as":	("as",	Regex { "as" },	true,	false),
	"nonisolated":	("nonisolated",	Regex { "nonisolated" },	true,	false),
	"watchOS":	("watchOS",	Regex { "watchOS" },	true,	false),
	"right":	("right",	Regex { "right" },	true,	false),
	"unowned(safe)":	("unowned(safe)",	Regex { "unowned(safe)" },	true,	false),
	"for":	("for",	Regex { "for" },	true,	false),
	"actor":	("actor",	Regex { "actor" },	true,	false),
	"mutating":	("mutating",	Regex { "mutating" },	true,	false),
	"where":	("where",	Regex { "where" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"#fileLiteral":	("#fileLiteral",	Regex { "#fileLiteral" },	true,	false),
	"true":	("true",	Regex { "true" },	true,	false),
	"#sourceLocation":	("#sourceLocation",	Regex { "#sourceLocation" },	true,	false),
	"infix":	("infix",	Regex { "infix" },	true,	false),
	"repeat":	("repeat",	Regex { "repeat" },	true,	false),
	"canImport":	("canImport",	Regex { "canImport" },	true,	false),
	"~":	("~",	Regex { "~" },	true,	false),
	"weak":	("weak",	Regex { "weak" },	true,	false),
	"#column":	("#column",	Regex { "#column" },	true,	false),
	"set":	("set",	Regex { "set" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	"copy":	("copy",	Regex { "copy" },	true,	false),
	"Self":	("Self",	Regex { "Self" },	true,	false),
]
func functionCallArgumentList() {
	if token.type = .ALT {
		functionCallArgument()
		// END
	} else if token.type = .ALT {
		functionCallArgument()
		// END
	}
	expect(["implicitParameterName", "dotOperator", "propertyWrapperProjection", "", "escapedIdentifier", "plainIdentifier", "plainOperator", "try"])
}
func getterSetterKeywordBlock() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func protocolMembers() {
	if token.type = .ALT {
		protocolMember()
		// OPT
	}
	expect(["#warning", "#error", "#sourceLocation", "@", "", "#if"])
}
func macroHead() {
	if token.type = .ALT {
		// OPT
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
func getterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func argumentLabel() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func infixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["infix"])
}
func defaultArgumentClause() {
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
	expect(["propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "implicitParameterName"])
}
func sameTypeRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier"])
}
func genericArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
}
func trailingClosures() {
	if token.type = .ALT {
		closureExpression()
		// OPT
	}
	expect(["{"])
}
func statementLabel() {
	if token.type = .ALT {
		labelName()
		next()
	}
	expect(["plainIdentifier", "implicitParameterName", "propertyWrapperProjection", "escapedIdentifier"])
}
func setterName() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func implicitMemberExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["."])
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
	expect(["postfix", "", "precedencegroup", "infix", "prefix", "@"])
}
func doStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["do"])
}
func initializerExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	} else if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["plainIdentifier", "switch", "(", "hexadecimalLiteral", "#keyPath", "decimalFloatingPointLiteral", "implicitParameterName", "self", "{", "#colorLiteral", "if", "binaryLiteral", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "#selector", "decimalNumber", "plainRegularExpressionLiteral", "stringLiteral", "#fileLiteral", "#imageLiteral", "false", "escapedIdentifier", "\\\\", ".", "super", "true", "[", "macroIdentifier", "_", "hexadecimalFloatingPointLiteral", "octalLiteral", "nil"])
}
func keyPathComponents() {
	if token.type = .ALT {
		keyPathComponent()
		// END
	} else if token.type = .ALT {
		keyPathComponent()
		// END
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "!", "?", "self", "[", "implicitParameterName", "escapedIdentifier"])
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
func identifierPattern() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func setterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func initializerHead() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func structMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["postfix", "", "precedencegroup", "infix", "prefix", "@"])
}
func protocolName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func rawValueStyleEnumMembers() {
	if token.type = .ALT {
		rawValueStyleEnumMember()
		// OPT
	}
	expect(["", "precedencegroup", "prefix", "#warning", "#error", "#sourceLocation", "@", "#if", "postfix", "infix"])
}
func classMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["postfix", "", "precedencegroup", "infix", "prefix", "@"])
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
	expect(["compiler", "arch", "swift", "canImport", "targetEnvironment", "os"])
}
func elseClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
}
func didSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func functionTypeArgumentClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
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
func wildcardExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["_"])
}
func labelName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func throwsClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["throws"])
}
func identifierList() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func tupleTypeElementList() {
	if token.type = .ALT {
		tupleTypeElement()
		// END
	} else if token.type = .ALT {
		tupleTypeElement()
		// END
	}
	expect(["propertyWrapperProjection", "(", "Self", "implicitParameterName", "Any", "plainIdentifier", "some", "@", "[", "", "escapedIdentifier"])
}
func rawValueStyleEnumCaseList() {
	if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	} else if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	}
	expect(["propertyWrapperProjection", "escapedIdentifier", "plainIdentifier", "implicitParameterName"])
}
func isPattern() {
	if token.type = .ALT {
		next()
	}
	expect(["is"])
}
func prefixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["prefix"])
}
func floatingPointLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["decimalFloatingPointLiteral"])
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
	expect(["postfix", "", "precedencegroup", "infix", "prefix", "@"])
}
func subscriptHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func tupleElementList() {
	if token.type = .ALT {
		tupleElement()
		// END
	} else if token.type = .ALT {
		tupleElement()
		// END
	}
	expect(["", "implicitParameterName", "try", "propertyWrapperProjection", "plainIdentifier", "escapedIdentifier"])
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
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func getterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func deinitializerDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func genericArgument() {
	if token.type = .ALT {
		type()
		// END
	}
	expect(["[", "escapedIdentifier", "Self", "", "Any", "some", "(", "@", "implicitParameterName", "plainIdentifier", "propertyWrapperProjection"])
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
func captureListItem() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["", "unowned", "unowned(safe)", "unowned(unsafe)", "weak"])
}
func expression() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "try"])
}
func dictionaryLiteralItem() {
	if token.type = .ALT {
		expression()
		next()
	}
	expect(["", "try"])
}
func switchExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["switch"])
}
func caseItemList() {
	if token.type = .ALT {
		pattern()
		// OPT
	} else if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["implicitParameterName", "escapedIdentifier", "try", "is", "(", "var", "propertyWrapperProjection", "let", "", "_", "plainIdentifier"])
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
func tuplePatternElement() {
	if token.type = .ALT {
		pattern()
		// END
	} else if token.type = .ALT {
		pattern()
		// END
	}
	expect(["implicitParameterName", "escapedIdentifier", "try", "is", "(", "var", "propertyWrapperProjection", "let", "", "_", "plainIdentifier"])
}
func prefixExpression() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["dotOperator", "", "plainOperator"])
}
func postfixSelfExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["plainIdentifier", "switch", "(", "hexadecimalLiteral", "#keyPath", "decimalFloatingPointLiteral", "implicitParameterName", "self", "{", "#colorLiteral", "if", "binaryLiteral", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "#selector", "decimalNumber", "plainRegularExpressionLiteral", "stringLiteral", "#fileLiteral", "#imageLiteral", "false", "escapedIdentifier", "\\\\", ".", "super", "true", "[", "macroIdentifier", "_", "hexadecimalFloatingPointLiteral", "octalLiteral", "nil"])
}
func throwStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["throw"])
}
func dictionaryLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["["])
}
func closureSignature() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["", "["])
}
func decimalLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["decimalNumber"])
}
func unionStyleEnumMembers() {
	if token.type = .ALT {
		unionStyleEnumMember()
		// OPT
	}
	expect(["#error", "", "prefix", "precedencegroup", "#sourceLocation", "#if", "infix", "#warning", "@", "postfix"])
}
func catchPatternList() {
	if token.type = .ALT {
		catchPattern()
		// END
	} else if token.type = .ALT {
		catchPattern()
		// END
	}
	expect(["var", "try", "escapedIdentifier", "(", "is", "_", "implicitParameterName", "propertyWrapperProjection", "plainIdentifier", "", "let"])
}
func tupleElement() {
	if token.type = .ALT {
		expression()
		// END
	} else if token.type = .ALT {
		expression()
		// END
	}
	expect(["", "try"])
}
func rawValueStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
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
func functionType() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
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
	expect(["iOS", "macOSApplicationExtension", "macCatalystApplicationExtension", "watchOS", "tvOS", "tvOSApplicationExtension", "macCatalyst", "visionOS", "visionOSApplicationExtension", "macOS", "iOSApplicationExtension", "watchOSApplicationExtension"])
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
func selfType() {
	if token.type = .ALT {
		next()
	}
	expect(["Self"])
}
func switchStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["switch"])
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
	expect(["plainIdentifier", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier"])
}
func opaqueType() {
	if token.type = .ALT {
		next()
	}
	expect(["some"])
}
func parameter() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["", "propertyWrapperProjection", "escapedIdentifier", "implicitParameterName", "plainIdentifier"])
}
func rawValueAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func structName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func switchIfDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
}
func filePath() {
	if token.type = .ALT {
		staticStringLiteral()
		// END
	}
	expect(["stringLiteral"])
}
func elseDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#else"])
}
func Operator() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["plainOperator"])
}
func actorDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
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
func macroDeclaration() {
	if token.type = .ALT {
		macroHead()
		identifier()
		// OPT
	}
	expect(["", "@"])
}
func mutationModifier() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["mutating"])
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
func genericParameterClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
}
func conformanceRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	} else if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier"])
}
func declarationModifiers() {
	if token.type = .ALT {
		declarationModifier()
		// OPT
	}
	expect(["package", "fileprivate", "infix", "internal", "class", "open", "private", "override", "prefix", "final", "lazy", "weak", "nonmutating", "convenience", "unowned", "mutating", "nonisolated", "dynamic", "postfix", "public", "static", "optional", "required"])
}
func parameterList() {
	if token.type = .ALT {
		parameter()
		// END
	} else if token.type = .ALT {
		parameter()
		// END
	}
	expect(["", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection", "plainIdentifier"])
}
func setterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func swiftVersion() {
	if token.type = .ALT {
		decimalDigits()
		// OPT
	}
	expect(["decimalNumber"])
}
func functionName() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func infixOperatorGroup() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
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
func closureParameter() {
	if token.type = .ALT {
		closureParameterName()
		// OPT
	} else if token.type = .ALT {
		closureParameterName()
		// OPT
	}
	expect(["escapedIdentifier", "plainIdentifier", "propertyWrapperProjection", "implicitParameterName"])
}
func argumentNames() {
	if token.type = .ALT {
		argumentName()
		// OPT
	}
	expect(["propertyWrapperProjection", "escapedIdentifier", "implicitParameterName", "plainIdentifier"])
}
func labeledTrailingClosure() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func functionCallArgumentClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func dictionaryType() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func functionHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func actorMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["postfix", "", "precedencegroup", "infix", "prefix", "@"])
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
	expect(["", "try"])
}
func forInStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["for"])
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
func guardStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["guard"])
}
func argumentName() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func functionTypeArgumentList() {
	if token.type = .ALT {
		functionTypeArgument()
		// END
	} else if token.type = .ALT {
		functionTypeArgument()
		// END
	}
	expect(["@", "escapedIdentifier", "propertyWrapperProjection", "implicitParameterName", "", "plainIdentifier"])
}
func switchElseifDirectiveClause() {
	if token.type = .ALT {
		elseifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#elseif"])
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
func balancedTokens() {
	if token.type = .ALT {
		balancedToken()
		// OPT
	}
	expect(["override", "is", "higherThan", "protocol", "for", "associatedtype", "+", "#", "throws", "private", "&", "#function", ",", "Any", "nonmutating", "<", "fallthrough", "#available", "true", "right", "#colorLiteral", "#fileID", "{", "Self", "return", "unowned", "@", "open", "while", "decimalNumber", "escapedIdentifier", "as", "#if", "set", "case", "#filePath", "precedencegroup", "prefix", "(", "#elseif", "switch", "internal", "break", "typealias", "didSet", "operator", "indirect", "plainOperator", "subscript", "#endif", "#keyPath", "actor", "do", "self", "#selector", "each", ":", "nil", "^", "-", "repeat", "%", "_unsafeInheritExecutor", "#file", "left", ";", "?", "*", "false", "_", "rethrows", "in", "public", "|", "if", "class", "decimalFloatingPointLiteral", "#fileLiteral", "enum", "fileprivate", "init", "func", "propertyWrapperProjection", "willSet", "try", "default", "binaryLiteral", "/", "where", "#imageLiteral", "!", "weak", "let", "extension", "implicitParameterName", "#else", "#line", "dynamic", "super", "#dsohandle", "hexadecimalLiteral", "#error", "struct", "discard", "associativity", "#column", "inout", "optional", "none", "continue", "borrowing", ">", "guard", "deinit", "stringLiteral", "octalLiteral", "static", "plainIdentifier", "extendedRegularExpressionLiteral", "mutating", "[", "import", "lazy", "=", "some", "lowerThan", "get", "#sourceLocation", "var", "convenience", "postfix", "consuming", "defer", "required", "#warning", "dotOperator", "hexadecimalFloatingPointLiteral", "else", "copy", "move", ".", "final", "catch", "~", "throw", "plainRegularExpressionLiteral"])
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
func swiftVersionContinuation() {
	if token.type = .ALT {
		next()
	}
	expect(["."])
}
func rawValueStyleEnum() {
	if token.type = .ALT {
		next()
	}
	expect(["enum"])
}
func willSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
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
func ifExpressionTail() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
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
	expect(["", "try"])
}
func ifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#if"])
}
func lineNumber() {
	if token.type = .ALT {
		decimalDigits()
		// END
	}
	expect(["decimalNumber"])
}
func keyPathComponent() {
	if token.type = .ALT {
		identifier()
		// OPT
	} else if token.type = .ALT {
		identifier()
		// OPT
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func elseifDirectiveClause() {
	if token.type = .ALT {
		elseifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#elseif"])
}
func typeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
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
func parameterClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func returnStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["return"])
}
func enumDeclaration() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func classMembers() {
	if token.type = .ALT {
		classMember()
		// OPT
	}
	expect(["#warning", "precedencegroup", "postfix", "infix", "#error", "#sourceLocation", "@", "#if", "", "prefix"])
}
func extensionMembers() {
	if token.type = .ALT {
		extensionMember()
		// OPT
	}
	expect(["#warning", "", "#sourceLocation", "prefix", "#if", "#error", "infix", "@", "precedencegroup", "postfix"])
}
func statements() {
	if token.type = .ALT {
		statement()
		// OPT
	}
	expect(["fallthrough", "plainIdentifier", "guard", "continue", "postfix", "#warning", "#sourceLocation", "break", "if", "do", "propertyWrapperProjection", "#if", "defer", "switch", "for", "infix", "precedencegroup", "throw", "while", "repeat", "#error", "", "@", "implicitParameterName", "return", "prefix", "escapedIdentifier", "try"])
}
func genericArgumentList() {
	if token.type = .ALT {
		genericArgument()
		// END
	} else if token.type = .ALT {
		genericArgument()
		// END
	}
	expect(["implicitParameterName", "escapedIdentifier", "@", "Self", "some", "", "[", "Any", "plainIdentifier", "(", "propertyWrapperProjection"])
}
func switchElseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
}
func constantDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func elseifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#elseif"])
}
func typeInheritanceClause() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func staticStringLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["stringLiteral"])
}
func catchClause() {
	if token.type = .ALT {
		next()
	}
	expect(["catch"])
}
func caseCondition() {
	if token.type = .ALT {
		next()
	}
	expect(["case"])
}
func unionStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
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
	expect(["var", "_", "implicitParameterName", "", "let", "try", "escapedIdentifier", "(", "plainIdentifier", "propertyWrapperProjection", "is"])
}
func valueBindingPattern() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["var"])
}
func conditionList() {
	if token.type = .ALT {
		condition()
		// END
	} else if token.type = .ALT {
		condition()
		// END
	}
	expect(["let", "#available", "var", "", "#unavailable", "case", "try"])
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
func diagnosticStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#warning"])
}
func importDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func selfMethodExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func macroSignature() {
	if token.type = .ALT {
		parameterClause()
		// OPT
	}
	expect(["("])
}
func caseLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func elementName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func ifDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
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
	expect(["plainIdentifier", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier"])
}
func expressionPattern() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["", "try"])
}
func nilLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["nil"])
}
func macroDefinition() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func availabilityArguments() {
	if token.type = .ALT {
		availabilityArgument()
		// END
	} else if token.type = .ALT {
		availabilityArgument()
		// END
	}
	expect(["iOS", "*", "macOS", "watchOS", "macOSApplicationExtension", "visionOSApplicationExtension", "watchOSApplicationExtension", "macCatalystApplicationExtension", "tvOS", "iOSApplicationExtension", "macCatalyst", "tvOSApplicationExtension", "visionOS"])
}
func regularExpressionLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["plainRegularExpressionLiteral"])
}
func metatypeType() {
	if token.type = .ALT {
		type()
		next()
	} else if token.type = .ALT {
		type()
		next()
	}
	expect(["[", "escapedIdentifier", "Self", "", "Any", "some", "(", "@", "implicitParameterName", "plainIdentifier", "propertyWrapperProjection"])
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
func fallthroughStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["fallthrough"])
}
func interpolatedStringLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["stringLiteral"])
}
func closureParameterList() {
	if token.type = .ALT {
		closureParameter()
		// END
	} else if token.type = .ALT {
		closureParameter()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "implicitParameterName"])
}
func typealiasAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
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
	expect(["decimalNumber", "decimalFloatingPointLiteral", "hexadecimalFloatingPointLiteral", "binaryLiteral", "octalLiteral", "plainRegularExpressionLiteral", "nil", "true", "hexadecimalLiteral", "stringLiteral", "extendedRegularExpressionLiteral", "false"])
}
func ifExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
}
func conditionalSwitchCase() {
	if token.type = .ALT {
		switchIfDirectiveClause()
		// OPT
	}
	expect(["#if"])
}
func environment() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["simulator"])
}
func structBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func enumCaseName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func wildcardPattern() {
	if token.type = .ALT {
		next()
	}
	expect(["_"])
}
func superclassMethodExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func optionalChainingExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["plainIdentifier", "switch", "(", "hexadecimalLiteral", "#keyPath", "decimalFloatingPointLiteral", "implicitParameterName", "self", "{", "#colorLiteral", "if", "binaryLiteral", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "#selector", "decimalNumber", "plainRegularExpressionLiteral", "stringLiteral", "#fileLiteral", "#imageLiteral", "false", "escapedIdentifier", "\\\\", ".", "super", "true", "[", "macroIdentifier", "_", "hexadecimalFloatingPointLiteral", "octalLiteral", "nil"])
}
func extensionDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func attributeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func protocolInitializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["", "@"])
}
func forcedValueExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["plainIdentifier", "switch", "(", "hexadecimalLiteral", "#keyPath", "decimalFloatingPointLiteral", "implicitParameterName", "self", "{", "#colorLiteral", "if", "binaryLiteral", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "#selector", "decimalNumber", "plainRegularExpressionLiteral", "stringLiteral", "#fileLiteral", "#imageLiteral", "false", "escapedIdentifier", "\\\\", ".", "super", "true", "[", "macroIdentifier", "_", "hexadecimalFloatingPointLiteral", "octalLiteral", "nil"])
}
func actorBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func infixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["plainOperator", "dotOperator"])
}
func parameterTypeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func actorMembers() {
	if token.type = .ALT {
		actorMember()
		// OPT
	}
	expect(["#sourceLocation", "prefix", "infix", "#error", "#warning", "", "precedencegroup", "#if", "postfix", "@"])
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
func className() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func functionBody() {
	if token.type = .ALT {
		codeBlock()
		// END
	}
	expect(["{"])
}
func actorIsolationModifier() {
	if token.type = .ALT {
		next()
	}
	expect(["nonisolated"])
}
func switchElseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
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
func variableDeclarationHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func superclassInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func availabilityCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#available"])
}
func optionalPattern() {
	if token.type = .ALT {
		identifierPattern()
		next()
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "plainIdentifier", "escapedIdentifier"])
}
func whereExpression() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["", "try"])
}
func functionResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func variableName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func rawValueStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "implicitParameterName"])
}
func continueStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["continue"])
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
func decimalDigits() {
	if token.type = .ALT {
		next()
	}
	expect(["decimalNumber"])
}
func functionTypeArgument() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func inOutExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["&"])
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
func typeIdentifier() {
	if token.type = .ALT {
		typeName()
		// OPT
	} else if token.type = .ALT {
		typeName()
		// OPT
	}
	expect(["escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "plainIdentifier"])
}
func breakStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["break"])
}
func booleanLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["true"])
}
func anyType() {
	if token.type = .ALT {
		next()
	}
	expect(["Any"])
}
func typealiasName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func actorName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func macroFunctionSignatureResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
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
func classBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func codeBlock() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
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
	expect(["", "@"])
}
func requirement() {
	if token.type = .ALT {
		conformanceRequirement()
		// END
	} else if token.type = .ALT {
		conformanceRequirement()
		// END
	}
	expect(["plainIdentifier", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection"])
}
func protocolCompositionType() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier"])
}
func lineControlStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#sourceLocation"])
}
func classDeclaration() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func deferStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["defer"])
}
func tupleExpression() {
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
func initializerBody() {
	if token.type = .ALT {
		codeBlock()
		// END
	}
	expect(["{"])
}
func precedenceGroupName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func selfInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func keyPathExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["\\\\"])
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
	expect(["decimalNumber", "macroIdentifier", "(", "#colorLiteral", "#imageLiteral", "self", "{", "false", "nil", "binaryLiteral", "if", "[", "true", "plainRegularExpressionLiteral", "hexadecimalLiteral", "switch", "#keyPath", ".", "hexadecimalFloatingPointLiteral", "propertyWrapperProjection", "plainIdentifier", "\\\\", "#fileLiteral", "_", "decimalFloatingPointLiteral", "implicitParameterName", "octalLiteral", "escapedIdentifier", "extendedRegularExpressionLiteral", "super", "stringLiteral", "#selector"])
}
func typeInheritanceList() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func whileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["while"])
}
func macroExpansionExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["macroIdentifier"])
}
func parenthesizedExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func optionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["[", "escapedIdentifier", "Self", "", "Any", "some", "(", "@", "implicitParameterName", "plainIdentifier", "propertyWrapperProjection"])
}
func structMembers() {
	if token.type = .ALT {
		structMember()
		// OPT
	}
	expect(["infix", "#warning", "prefix", "", "#if", "#sourceLocation", "#error", "precedencegroup", "postfix", "@"])
}
func implicitlyUnwrappedOptionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["[", "escapedIdentifier", "Self", "", "Any", "some", "(", "@", "implicitParameterName", "plainIdentifier", "propertyWrapperProjection"])
}
func typeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
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
	expect(["plainIdentifier", "switch", "(", "hexadecimalLiteral", "#keyPath", "decimalFloatingPointLiteral", "implicitParameterName", "self", "{", "#colorLiteral", "if", "binaryLiteral", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "#selector", "decimalNumber", "plainRegularExpressionLiteral", "stringLiteral", "#fileLiteral", "#imageLiteral", "false", "escapedIdentifier", "\\\\", ".", "super", "true", "[", "macroIdentifier", "_", "hexadecimalFloatingPointLiteral", "octalLiteral", "nil"])
}
func unionStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "implicitParameterName"])
}
func protocolBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func extensionBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func whereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func conditionalCompilationBlock() {
	if token.type = .ALT {
		ifDirectiveClause()
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
	expect(["_", "escapedIdentifier", "plainIdentifier", "implicitParameterName", "let", "try", "", "var", "propertyWrapperProjection", "is", "("])
}
func precedenceGroupAttributes() {
	if token.type = .ALT {
		precedenceGroupAttribute()
		// OPT
	}
	expect(["associativity", "lowerThan", "assignment", "higherThan"])
}
func attribute() {
	if token.type = .ALT {
		next()
	}
	expect(["@"])
}
func infixExpressions() {
	if token.type = .ALT {
		infixExpression()
		// OPT
	}
	expect(["as", "plainOperator", "=", "?", "is", "dotOperator"])
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
	expect(["", "try"])
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
func closureExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func arrayType() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func unionStyleEnum() {
	if token.type = .ALT {
		// OPT
	}
	expect(["indirect", ""])
}
func attributeArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
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
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func keyPathStringExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["#keyPath"])
}
func closureParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
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
func repeatWhileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["repeat"])
}
func catchClauses() {
	if token.type = .ALT {
		catchClause()
		// OPT
	}
	expect(["catch"])
}
func prefixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["plainOperator", "dotOperator"])
}
func elseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
}
func defaultLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func requirementList() {
	if token.type = .ALT {
		requirement()
		// END
	} else if token.type = .ALT {
		requirement()
		// END
	}
	expect(["plainIdentifier", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection"])
}
func initializer() {
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
	expect(["implicitParameterName", "escapedIdentifier", "try", "is", "(", "var", "propertyWrapperProjection", "let", "", "_", "plainIdentifier"])
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
	expect(["escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "plainIdentifier"])
}
func superclassSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func precedenceGroupRelation() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["higherThan"])
}
func protocolMethodDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["@", ""])
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
	expect(["", "@"])
}
func importPath() {
	if token.type = .ALT {
		identifier()
		// END
	} else if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
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
func protocolCompositionContinuation() {
	if token.type = .ALT {
		typeIdentifier()
		// END
	} else if token.type = .ALT {
		typeIdentifier()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "implicitParameterName", "escapedIdentifier"])
}
func optionalBindingCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["let"])
}
func postfixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["plainOperator", "dotOperator"])
}
func switchExpressionCases() {
	if token.type = .ALT {
		switchExpressionCase()
		// OPT
	}
	expect(["", "@"])
}
func boxedProtocolType() {
	if token.type = .ALT {
		next()
	}
	expect(["any"])
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
func arrayLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
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
	expect(["", "@"])
}
func protocolSubscriptDeclaration() {
	if token.type = .ALT {
		subscriptHead()
		subscriptResult()
		// OPT
	}
	expect(["@", ""])
}
func labeledTrailingClosures() {
	if token.type = .ALT {
		labeledTrailingClosure()
		// OPT
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func initializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["", "@"])
}
func subscriptResult() {
	if token.type = .ALT {
		next()
	}
	expect([">"])
}
func endifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#endif"])
}
func awaitOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["await"])
}
func keyPathPostfixes() {
	if token.type = .ALT {
		keyPathPostfix()
		// OPT
	}
	expect(["[", "self", "?", "!"])
}
func subscriptExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["plainIdentifier", "switch", "(", "hexadecimalLiteral", "#keyPath", "decimalFloatingPointLiteral", "implicitParameterName", "self", "{", "#colorLiteral", "if", "binaryLiteral", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "#selector", "decimalNumber", "plainRegularExpressionLiteral", "stringLiteral", "#fileLiteral", "#imageLiteral", "false", "escapedIdentifier", "\\\\", ".", "super", "true", "[", "macroIdentifier", "_", "hexadecimalFloatingPointLiteral", "octalLiteral", "nil"])
}
func topLevelDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["for", "implicitParameterName", "guard", "while", "do", "", "try", "switch", "throw", "#if", "break", "escapedIdentifier", "infix", "postfix", "#warning", "repeat", "@", "prefix", "propertyWrapperProjection", "defer", "return", "continue", "plainIdentifier", "if", "precedencegroup", "fallthrough", "#error", "#sourceLocation"])
}
func enumName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func protocolDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "@"])
}
func precedenceGroupDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["precedencegroup"])
}
func enumCasePattern() {
	if token.type = .ALT {
		// OPT
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "implicitParameterName", "", "escapedIdentifier"])
}
func assignmentOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
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
func conditionalOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["?"])
}
func captureList() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func typealiasDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
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
func attributes() {
	if token.type = .ALT {
		attribute()
		// OPT
	}
	expect(["@"])
}
func protocolAssociatedTypeDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func patternInitializer() {
	if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["implicitParameterName", "escapedIdentifier", "try", "is", "(", "var", "propertyWrapperProjection", "let", "", "_", "plainIdentifier"])
}
func extensionMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["postfix", "", "precedencegroup", "infix", "prefix", "@"])
}
func precedenceGroupNames() {
	if token.type = .ALT {
		precedenceGroupName()
		// END
	} else if token.type = .ALT {
		precedenceGroupName()
		// END
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func willSetDidSetBlock() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["{"])
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
func selfSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func externalParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func tuplePattern() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
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
func genericParameterList() {
	if token.type = .ALT {
		genericParameter()
		// END
	} else if token.type = .ALT {
		genericParameter()
		// END
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "implicitParameterName"])
}
func arrayLiteralItem() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect(["", "try"])
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
func captureListItems() {
	if token.type = .ALT {
		captureListItem()
		// END
	} else if token.type = .ALT {
		captureListItem()
		// END
	}
	expect(["unowned", "", "weak", "unowned(safe)", "unowned(unsafe)"])
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
	expect(["plainIdentifier", "switch", "(", "hexadecimalLiteral", "#keyPath", "decimalFloatingPointLiteral", "implicitParameterName", "self", "{", "#colorLiteral", "if", "binaryLiteral", "propertyWrapperProjection", "extendedRegularExpressionLiteral", "#selector", "decimalNumber", "plainRegularExpressionLiteral", "stringLiteral", "#fileLiteral", "#imageLiteral", "false", "escapedIdentifier", "\\\\", ".", "super", "true", "[", "macroIdentifier", "_", "hexadecimalFloatingPointLiteral", "octalLiteral", "nil"])
}
func catchPattern() {
	if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["implicitParameterName", "escapedIdentifier", "try", "is", "(", "var", "propertyWrapperProjection", "let", "", "_", "plainIdentifier"])
}
func precedenceGroupAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["assignment"])
}
func ifStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
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
	expect(["@", ""])
}
func elseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
}
func localParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["implicitParameterName", "propertyWrapperProjection", "escapedIdentifier", "plainIdentifier"])
}
func structDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", ""])
}
func switchCases() {
	if token.type = .ALT {
		switchCase()
		// OPT
	}
	expect(["#if", "@", ""])
}
func genericWhereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func functionDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["@", ""])
}
