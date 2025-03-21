//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"dotOperator":	("/\\.[\\.\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]+/",	/\.[\.\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]+/,	false,	false),
	"extendedSinglelineStringLiteral":	("/#+\".*?\"#+/",	/#+".*?"#+/,	false,	false),
	"multilineStringLiteral":	("/\"\"\"(?:\\\\#*\\([^)]*\\)|\\\\#*[0\\\\tnr\"\']|\\\\#*u\\{[0-9a-fA-F]+\\}|\\\\#*\\s*\\n|[^\\\\])*\"\"\"/",	/"""(?:\\#*\([^)]*\)|\\#*[0\\tnr"']|\\#*u\{[0-9a-fA-F]+\}|\\#*\s*\n|[^\\])*"""/,	false,	false),
	"extendedRegularExpressionLiteral":	("/#+\\/(?:[^\\/\\\\]|\\\\.)+\\/#+/",	/#+\/(?:[^\/\\]|\\.)+\/#+/,	false,	false),
	"implicitParameterName":	("/\\$[0-9]+/",	/\$[0-9]+/,	false,	false),
	"singlelineStringLiteral":	("/\"(?:(?:[^\\\\\"]+)|(?:\\\\\\([^\\\\\\)]+\\))|(?:\\\\u\\{[0-9a-fA-F]+\\})|(?:\\\\[0\\\\tnr\"\']))*\"/",	/"(?:(?:[^\\"]+)|(?:\\\([^\\\)]+\))|(?:\\u\{[0-9a-fA-F]+\})|(?:\\[0\\tnr"']))*"/,	false,	false),
	"decimalFloatingPointLiteral":	("/-?[0-9][0-9_]*(?:\\.[0-9][0-9_]*)(?:[eE][+-]?[0-9][0-9_]*)?/",	/-?[0-9][0-9_]*(?:\.[0-9][0-9_]*)(?:[eE][+-]?[0-9][0-9_]*)?/,	false,	false),
	"extendedMultilineStringLiteral":	("/#+\"\"\"(?s).*?\"\"\"#+/",	/#+"""(?s).*?"""#+/,	false,	false),
	"escapedIdentifier":	("/`\\p{XID_Start}\\p{XID_Continue}*`/",	/`\p{XID_Start}\p{XID_Continue}*`/,	false,	false),
	"plainRegularExpressionLiteral":	("/\\/(?:[^\\/\\\\\\n]|\\\\.)+\\//",	/\/(?:[^\/\\\n]|\\.)+\//,	false,	false),
	"plainIdentifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"decimalNumber":	("/-?[0-9][0-9_]*/",	/-?[0-9][0-9_]*/,	false,	false),
	"multilineComment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"hexadecimalLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*/,	false,	false),
	"propertyWrapperProjection":	("/\\$\\p{XID_Continue}+/",	/\$\p{XID_Continue}+/,	false,	false),
	"octalLiteral":	("/-?0o[0-7][0-7_]*/",	/-?0o[0-7][0-7_]*/,	false,	false),
	"binaryLiteral":	("/-?0b[0-1][0-1_]*/",	/-?0b[0-1][0-1_]*/,	false,	false),
	"comment":	("/\\/\\/.*\\r?\\n?/",	/\/\/.*\r?\n?/,	false,	true),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"hexadecimalFloatingPointLiteral":	("/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/",	/-?0x[0-9a-fA-F][0-9a-fA-F_]*(?:\.[0-9a-fA-F][0-9a-fA-F_]*)?(?:[pP][+-]?[0-9][0-9_]*)/,	false,	false),
	"macroIdentifier":	("/#\\p{XID_Start}\\p{XID_Continue}*/",	/#\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"plainOperator":	("/[\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}][\\/=+\\-*%!&|^~?<>\\p{Sm}\\p{So}\\p{Mn}]*/",	/[\/=+\-*%!&|^~?<>\p{Sm}\p{So}][\/=+\-*%!&|^~?<>\p{Sm}\p{So}\p{Mn}]*/,	false,	false),
	"required":	("required",	Regex { "required" },	true,	false),
	"right":	("right",	Regex { "right" },	true,	false),
	"static":	("static",	Regex { "static" },	true,	false),
	"class":	("class",	Regex { "class" },	true,	false),
	"arm64":	("arm64",	Regex { "arm64" },	true,	false),
	"blue":	("blue",	Regex { "blue" },	true,	false),
	";":	(";",	Regex { ";" },	true,	false),
	"discard":	("discard",	Regex { "discard" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"typealias":	("typealias",	Regex { "typealias" },	true,	false),
	"try":	("try",	Regex { "try" },	true,	false),
	"indirect":	("indirect",	Regex { "indirect" },	true,	false),
	"fileprivate":	("fileprivate",	Regex { "fileprivate" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"inout":	("inout",	Regex { "inout" },	true,	false),
	"import":	("import",	Regex { "import" },	true,	false),
	"#if":	("#if",	Regex { "#if" },	true,	false),
	"arm":	("arm",	Regex { "arm" },	true,	false),
	"throw":	("throw",	Regex { "throw" },	true,	false),
	"visionOS":	("visionOS",	Regex { "visionOS" },	true,	false),
	"move":	("move",	Regex { "move" },	true,	false),
	"-":	("-",	Regex { "-" },	true,	false),
	"macCatalystApplicationExtension":	("macCatalystApplicationExtension",	Regex { "macCatalystApplicationExtension" },	true,	false),
	"optional":	("optional",	Regex { "optional" },	true,	false),
	"super":	("super",	Regex { "super" },	true,	false),
	"unowned":	("unowned",	Regex { "unowned" },	true,	false),
	"nonmutating":	("nonmutating",	Regex { "nonmutating" },	true,	false),
	"is":	("is",	Regex { "is" },	true,	false),
	"didSet":	("didSet",	Regex { "didSet" },	true,	false),
	"arch":	("arch",	Regex { "arch" },	true,	false),
	"tvOSApplicationExtension":	("tvOSApplicationExtension",	Regex { "tvOSApplicationExtension" },	true,	false),
	"in":	("in",	Regex { "in" },	true,	false),
	"simulator":	("simulator",	Regex { "simulator" },	true,	false),
	"^":	("^",	Regex { "^" },	true,	false),
	"actor":	("actor",	Regex { "actor" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"nonisolated":	("nonisolated",	Regex { "nonisolated" },	true,	false),
	"private":	("private",	Regex { "private" },	true,	false),
	"#":	("#",	Regex { "#" },	true,	false),
	"setter:":	("setter:",	Regex { "setter:" },	true,	false),
	"for":	("for",	Regex { "for" },	true,	false),
	"visionOSApplicationExtension":	("visionOSApplicationExtension",	Regex { "visionOSApplicationExtension" },	true,	false),
	"left":	("left",	Regex { "left" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"#elseif":	("#elseif",	Regex { "#elseif" },	true,	false),
	"extension":	("extension",	Regex { "extension" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	"lazy":	("lazy",	Regex { "lazy" },	true,	false),
	"weak":	("weak",	Regex { "weak" },	true,	false),
	"Any":	("Any",	Regex { "Any" },	true,	false),
	"catch":	("catch",	Regex { "catch" },	true,	false),
	"file:":	("file:",	Regex { "file:" },	true,	false),
	"as":	("as",	Regex { "as" },	true,	false),
	"infix":	("infix",	Regex { "infix" },	true,	false),
	"#error":	("#error",	Regex { "#error" },	true,	false),
	"@":	("@",	Regex { "@" },	true,	false),
	"continue":	("continue",	Regex { "continue" },	true,	false),
	"%":	("%",	Regex { "%" },	true,	false),
	"os":	("os",	Regex { "os" },	true,	false),
	"_":	("_",	Regex { "_" },	true,	false),
	"internal":	("internal",	Regex { "internal" },	true,	false),
	"red":	("red",	Regex { "red" },	true,	false),
	"func":	("func",	Regex { "func" },	true,	false),
	"convenience":	("convenience",	Regex { "convenience" },	true,	false),
	"->":	("->",	Regex { "->" },	true,	false),
	"protocol":	("protocol",	Regex { "protocol" },	true,	false),
	"set":	("set",	Regex { "set" },	true,	false),
	"&&":	("&&",	Regex { "&&" },	true,	false),
	"swift":	("swift",	Regex { "swift" },	true,	false),
	"Windows":	("Windows",	Regex { "Windows" },	true,	false),
	"async":	("async",	Regex { "async" },	true,	false),
	"green":	("green",	Regex { "green" },	true,	false),
	"mutating":	("mutating",	Regex { "mutating" },	true,	false),
	"borrowing":	("borrowing",	Regex { "borrowing" },	true,	false),
	"break":	("break",	Regex { "break" },	true,	false),
	"safe":	("safe",	Regex { "safe" },	true,	false),
	"case":	("case",	Regex { "case" },	true,	false),
	"operator":	("operator",	Regex { "operator" },	true,	false),
	"x86_64":	("x86_64",	Regex { "x86_64" },	true,	false),
	"==":	("==",	Regex { "==" },	true,	false),
	"||":	("||",	Regex { "||" },	true,	false),
	"deinit":	("deinit",	Regex { "deinit" },	true,	false),
	"true":	("true",	Regex { "true" },	true,	false),
	"enum":	("enum",	Regex { "enum" },	true,	false),
	"#available":	("#available",	Regex { "#available" },	true,	false),
	"await":	("await",	Regex { "await" },	true,	false),
	"/":	("/",	Regex { "/" },	true,	false),
	"nil":	("nil",	Regex { "nil" },	true,	false),
	"#keyPath":	("#keyPath",	Regex { "#keyPath" },	true,	false),
	"willSet":	("willSet",	Regex { "willSet" },	true,	false),
	"default":	("default",	Regex { "default" },	true,	false),
	"associativity":	("associativity",	Regex { "associativity" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"guard":	("guard",	Regex { "guard" },	true,	false),
	"&":	("&",	Regex { "&" },	true,	false),
	"precedencegroup":	("precedencegroup",	Regex { "precedencegroup" },	true,	false),
	"throws":	("throws",	Regex { "throws" },	true,	false),
	"false":	("false",	Regex { "false" },	true,	false),
	"#imageLiteral":	("#imageLiteral",	Regex { "#imageLiteral" },	true,	false),
	"resourceName":	("resourceName",	Regex { "resourceName" },	true,	false),
	"macOSApplicationExtension":	("macOSApplicationExtension",	Regex { "macOSApplicationExtension" },	true,	false),
	",":	(",",	Regex { "," },	true,	false),
	"unowned(unsafe)":	("unowned(unsafe)",	Regex { "unowned(unsafe)" },	true,	false),
	"unowned(safe)":	("unowned(safe)",	Regex { "unowned(safe)" },	true,	false),
	"Protocol":	("Protocol",	Regex { "Protocol" },	true,	false),
	"associatedtype":	("associatedtype",	Regex { "associatedtype" },	true,	false),
	"#selector":	("#selector",	Regex { "#selector" },	true,	false),
	"getter:":	("getter:",	Regex { "getter:" },	true,	false),
	">=":	(">=",	Regex { ">=" },	true,	false),
	"where":	("where",	Regex { "where" },	true,	false),
	"lowerThan":	("lowerThan",	Regex { "lowerThan" },	true,	false),
	"~":	("~",	Regex { "~" },	true,	false),
	"targetEnvironment":	("targetEnvironment",	Regex { "targetEnvironment" },	true,	false),
	"get":	("get",	Regex { "get" },	true,	false),
	"some":	("some",	Regex { "some" },	true,	false),
	"subscript":	("subscript",	Regex { "subscript" },	true,	false),
	"\\":	("\\",	Regex { "\\" },	true,	false),
	"_unsafeInheritExecutor":	("_unsafeInheritExecutor",	Regex { "_unsafeInheritExecutor" },	true,	false),
	"!":	("!",	Regex { "!" },	true,	false),
	"#warning":	("#warning",	Regex { "#warning" },	true,	false),
	"none":	("none",	Regex { "none" },	true,	false),
	"assignment":	("assignment",	Regex { "assignment" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"unsafe":	("unsafe",	Regex { "unsafe" },	true,	false),
	"rethrows":	("rethrows",	Regex { "rethrows" },	true,	false),
	"#colorLiteral":	("#colorLiteral",	Regex { "#colorLiteral" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"Self":	("Self",	Regex { "Self" },	true,	false),
	"...":	("...",	Regex { "..." },	true,	false),
	"package":	("package",	Regex { "package" },	true,	false),
	"postfix":	("postfix",	Regex { "postfix" },	true,	false),
	"#endif":	("#endif",	Regex { "#endif" },	true,	false),
	"switch":	("switch",	Regex { "switch" },	true,	false),
	"return":	("return",	Regex { "return" },	true,	false),
	"macCatalyst":	("macCatalyst",	Regex { "macCatalyst" },	true,	false),
	"iOSApplicationExtension":	("iOSApplicationExtension",	Regex { "iOSApplicationExtension" },	true,	false),
	"Type":	("Type",	Regex { "Type" },	true,	false),
	"fallthrough":	("fallthrough",	Regex { "fallthrough" },	true,	false),
	"defer":	("defer",	Regex { "defer" },	true,	false),
	"i386":	("i386",	Regex { "i386" },	true,	false),
	"compiler":	("compiler",	Regex { "compiler" },	true,	false),
	"alpha":	("alpha",	Regex { "alpha" },	true,	false),
	"final":	("final",	Regex { "final" },	true,	false),
	"while":	("while",	Regex { "while" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"#else":	("#else",	Regex { "#else" },	true,	false),
	"#fileLiteral":	("#fileLiteral",	Regex { "#fileLiteral" },	true,	false),
	"any":	("any",	Regex { "any" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"var":	("var",	Regex { "var" },	true,	false),
	"canImport":	("canImport",	Regex { "canImport" },	true,	false),
	"self":	("self",	Regex { "self" },	true,	false),
	"public":	("public",	Regex { "public" },	true,	false),
	"if":	("if",	Regex { "if" },	true,	false),
	"repeat":	("repeat",	Regex { "repeat" },	true,	false),
	"Linux":	("Linux",	Regex { "Linux" },	true,	false),
	"macro":	("macro",	Regex { "macro" },	true,	false),
	"higherThan":	("higherThan",	Regex { "higherThan" },	true,	false),
	"yield":	("yield",	Regex { "yield" },	true,	false),
	"struct":	("struct",	Regex { "struct" },	true,	false),
	"watchOS":	("watchOS",	Regex { "watchOS" },	true,	false),
	"consuming":	("consuming",	Regex { "consuming" },	true,	false),
	"override":	("override",	Regex { "override" },	true,	false),
	"each":	("each",	Regex { "each" },	true,	false),
	"line:":	("line:",	Regex { "line:" },	true,	false),
	"#sourceLocation":	("#sourceLocation",	Regex { "#sourceLocation" },	true,	false),
	"let":	("let",	Regex { "let" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"tvOS":	("tvOS",	Regex { "tvOS" },	true,	false),
	"prefix":	("prefix",	Regex { "prefix" },	true,	false),
	"isolated":	("isolated",	Regex { "isolated" },	true,	false),
	"#unavailable":	("#unavailable",	Regex { "#unavailable" },	true,	false),
	"iOS":	("iOS",	Regex { "iOS" },	true,	false),
	"watchOSApplicationExtension":	("watchOSApplicationExtension",	Regex { "watchOSApplicationExtension" },	true,	false),
	"open":	("open",	Regex { "open" },	true,	false),
	"do":	("do",	Regex { "do" },	true,	false),
	"copy":	("copy",	Regex { "copy" },	true,	false),
	"init":	("init",	Regex { "init" },	true,	false),
	"macOS":	("macOS",	Regex { "macOS" },	true,	false),
	"else":	("else",	Regex { "else" },	true,	false),
	"dynamic":	("dynamic",	Regex { "dynamic" },	true,	false),
]
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
func willSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["willSet", "@"])
}
func identifierPattern() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func genericArgument() {
	if token.type = .ALT {
		type()
		// END
	}
	expect(["[", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection", "(", "_", "plainIdentifier", "Self", "@", "Any", "some"])
}
func protocolMember() {
	if token.type = .ALT {
		protocolMemberDeclaration()
		// END
	} else if token.type = .ALT {
		protocolMemberDeclaration()
		// END
	}
	expect(["prefix", "weak", "open", "func", "final", "static", "subscript", "class", "postfix", "optional", "mutating", "dynamic", "unowned", "typealias", "init", "nonmutating", "package", "nonisolated", "private", "infix", "associatedtype", "public", "fileprivate", "@", "var", "required", "internal", "convenience", "lazy", "override"])
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
	expect(["prefix", "public", "postfix", "var", "dynamic", "fileprivate", "lazy", "unowned", "infix", "nonisolated", "final", "weak", "open", "static", "mutating", "optional", "nonmutating", "convenience", "class", "override", "internal", "required", "@", "package", "private"])
}
func enumDeclaration() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["fileprivate", "@", "package", "private", "internal", "enum", "open", "public", "indirect"])
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
func functionCallArgumentList() {
	if token.type = .ALT {
		functionCallArgument()
		// END
	} else if token.type = .ALT {
		functionCallArgument()
		// END
	}
	expect(["extendedRegularExpressionLiteral", "plainOperator", "#fileLiteral", "switch", "octalLiteral", "plainRegularExpressionLiteral", "dotOperator", "[", "#selector", "implicitParameterName", "#keyPath", "_", "extendedSinglelineStringLiteral", "nil", "await", "(", "propertyWrapperProjection", "#colorLiteral", "&", "hexadecimalFloatingPointLiteral", "decimalFloatingPointLiteral", "extendedMultilineStringLiteral", "plainIdentifier", ".", "try", "true", "hexadecimalLiteral", "decimalNumber", "singlelineStringLiteral", "binaryLiteral", "if", "\\\\", "{", "multilineStringLiteral", "self", "macroIdentifier", "#imageLiteral", "false", "super", "escapedIdentifier"])
}
func actorMembers() {
	if token.type = .ALT {
		actorMember()
		// OPT
	}
	expect(["internal", "let", "init", "struct", "unowned", "mutating", "enum", "func", "#sourceLocation", "static", "#warning", "open", "class", "fileprivate", "var", "prefix", "precedencegroup", "required", "private", "#error", "infix", "convenience", "extension", "public", "nonisolated", "weak", "import", "lazy", "final", "dynamic", "typealias", "actor", "postfix", "nonmutating", "optional", "package", "subscript", "@", "protocol", "deinit", "indirect", "override", "#if"])
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
func macroFunctionSignatureResult() {
	if token.type = .ALT {
		next()
	}
	expect(["->"])
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
func typeInheritanceClause() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func arrayType() {
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
func elementName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
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
func postfixSelfExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["hexadecimalLiteral", "switch", "false", "extendedRegularExpressionLiteral", ".", "singlelineStringLiteral", "#colorLiteral", "[", "if", "decimalNumber", "binaryLiteral", "true", "macroIdentifier", "plainIdentifier", "decimalFloatingPointLiteral", "nil", "extendedSinglelineStringLiteral", "plainRegularExpressionLiteral", "{", "octalLiteral", "#keyPath", "\\\\", "(", "propertyWrapperProjection", "self", "#imageLiteral", "#selector", "#fileLiteral", "extendedMultilineStringLiteral", "super", "implicitParameterName", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "_", "escapedIdentifier"])
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
func selfInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
}
func parameterClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func structMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["open", "let", "lazy", "extension", "public", "var", "nonisolated", "precedencegroup", "@", "unowned", "convenience", "dynamic", "class", "weak", "mutating", "typealias", "override", "import", "private", "deinit", "postfix", "protocol", "final", "nonmutating", "prefix", "optional", "enum", "struct", "init", "static", "func", "actor", "subscript", "package", "fileprivate", "internal", "infix", "indirect", "required"])
}
func floatingPointLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["decimalFloatingPointLiteral"])
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
func variableName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func ifDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
}
func conditionalSwitchCase() {
	if token.type = .ALT {
		switchIfDirectiveClause()
		// OPT
	}
	expect(["#if"])
}
func optionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["[", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection", "(", "_", "plainIdentifier", "Self", "@", "Any", "some"])
}
func protocolSubscriptDeclaration() {
	if token.type = .ALT {
		subscriptHead()
		subscriptResult()
		// OPT
	}
	expect(["convenience", "nonmutating", "package", "prefix", "dynamic", "@", "subscript", "optional", "open", "unowned", "mutating", "override", "lazy", "fileprivate", "internal", "public", "infix", "required", "nonisolated", "private", "final", "weak", "class", "static", "postfix"])
}
func extensionDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["package", "private", "internal", "open", "@", "extension", "public", "fileprivate"])
}
func statements() {
	if token.type = .ALT {
		statement()
		// OPT
	}
	expect(["super", "return", "true", "repeat", "[", "open", "#keyPath", "(", "prefix", "macroIdentifier", "let", "guard", "convenience", "optional", "await", ".", "extendedMultilineStringLiteral", "#colorLiteral", "extendedSinglelineStringLiteral", "decimalFloatingPointLiteral", "fallthrough", "#imageLiteral", "singlelineStringLiteral", "precedencegroup", "&", "escapedIdentifier", "continue", "do", "\\\\", "for", "throw", "indirect", "#fileLiteral", "class", "break", "nil", "while", "protocol", "@", "weak", "plainRegularExpressionLiteral", "self", "if", "import", "#if", "final", "postfix", "fileprivate", "extendedRegularExpressionLiteral", "required", "public", "decimalNumber", "var", "#warning", "dotOperator", "propertyWrapperProjection", "func", "plainOperator", "actor", "subscript", "typealias", "struct", "internal", "package", "unowned", "lazy", "dynamic", "try", "infix", "switch", "#error", "mutating", "override", "{", "#selector", "static", "#sourceLocation", "octalLiteral", "extension", "implicitParameterName", "multilineStringLiteral", "binaryLiteral", "hexadecimalLiteral", "nonmutating", "_", "private", "false", "nonisolated", "init", "hexadecimalFloatingPointLiteral", "defer", "plainIdentifier", "enum", "deinit"])
}
func functionTypeArgument() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["[", "escapedIdentifier", "_", "(", "plainIdentifier", "propertyWrapperProjection", "@", "inout", "Self", "Any", "implicitParameterName", "some"])
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
	expect(["hexadecimalFloatingPointLiteral", "decimalNumber", "octalLiteral", "decimalFloatingPointLiteral", "hexadecimalLiteral", "binaryLiteral"])
}
func attribute() {
	if token.type = .ALT {
		next()
	}
	expect(["@"])
}
func getterSetterKeywordBlock() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["{"])
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
func protocolDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["package", "protocol", "@", "public", "private", "fileprivate", "open", "internal"])
}
func precedenceGroupRelation() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["higherThan"])
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
func genericWhereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func sameTypeRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["escapedIdentifier", "_", "implicitParameterName", "plainIdentifier", "propertyWrapperProjection"])
}
func genericArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
}
func genericArgumentList() {
	if token.type = .ALT {
		genericArgument()
		// END
	} else if token.type = .ALT {
		genericArgument()
		// END
	}
	expect(["Any", "propertyWrapperProjection", "some", "_", "(", "plainIdentifier", "escapedIdentifier", "@", "implicitParameterName", "[", "Self"])
}
func selfType() {
	if token.type = .ALT {
		next()
	}
	expect(["Self"])
}
func balancedTokens() {
	if token.type = .ALT {
		balancedToken()
		// OPT
	}
	expect(["indirect", "plainRegularExpressionLiteral", "async", "octalLiteral", "func", "super", "precedencegroup", "nonmutating", "Self", "Any", "hexadecimalFloatingPointLiteral", "catch", "throws", "borrowing", "prefix", "+", "postfix", "rethrows", "subscript", "inout", "repeat", "<", ",", "willSet", ":", "=", "init", "guard", "await", "in", "get", "nonisolated", "multilineStringLiteral", "protocol", "-", "unowned", "false", "fileprivate", "plainIdentifier", "didSet", "while", "required", "return", "package", "self", "isolated", "defer", "associatedtype", "binaryLiteral", "copy", "final", "case", "set", "none", "^", "#elseif", "override", "#", "public", "some", "decimalFloatingPointLiteral", "import", "#keyPath", "#error", "[", "nil", "{", "plainOperator", "?", "#fileLiteral", "else", "typealias", "if", "fallthrough", "lazy", "operator", "where", "var", "each", "#warning", "~", "left", "_unsafeInheritExecutor", "default", ".", "higherThan", "switch", "#available", "weak", "break", "implicitParameterName", "is", "_", "move", "private", "extendedMultilineStringLiteral", "extendedRegularExpressionLiteral", "/", "internal", "struct", "throw", "do", "escapedIdentifier", "%", ">", "extension", "associativity", "(", "static", "|", ";", "yield", "open", "!", "dynamic", "#unavailable", "as", "mutating", "discard", "#endif", "#colorLiteral", "#sourceLocation", "propertyWrapperProjection", "#selector", "@", "true", "#imageLiteral", "actor", "dotOperator", "class", "for", "right", "continue", "#else", "decimalNumber", "extendedSinglelineStringLiteral", "enum", "consuming", "#if", "lowerThan", "hexadecimalLiteral", "*", "&", "convenience", "let", "try", "optional", "deinit", "singlelineStringLiteral"])
}
func selfSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["self"])
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
func whereExpression() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect([".", "escapedIdentifier", "implicitParameterName", "\\\\", "{", "plainRegularExpressionLiteral", "decimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "switch", "_", "octalLiteral", "self", "super", "nil", "(", "false", "try", "extendedSinglelineStringLiteral", "plainOperator", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "&", "extendedMultilineStringLiteral", "true", "binaryLiteral", "#imageLiteral", "#selector", "hexadecimalLiteral", "macroIdentifier", "plainIdentifier", "[", "if", "singlelineStringLiteral", "decimalNumber", "await", "#keyPath", "dotOperator"])
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
	expect(["swift", "targetEnvironment", "compiler", "canImport", "os", "arch"])
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
	expect(["open", "let", "lazy", "extension", "public", "var", "nonisolated", "precedencegroup", "@", "unowned", "convenience", "dynamic", "class", "weak", "mutating", "typealias", "override", "import", "private", "deinit", "postfix", "protocol", "final", "nonmutating", "prefix", "optional", "enum", "struct", "init", "static", "func", "actor", "subscript", "package", "fileprivate", "internal", "infix", "indirect", "required"])
}
func metatypeType() {
	if token.type = .ALT {
		type()
		next()
	} else if token.type = .ALT {
		type()
		next()
	}
	expect(["[", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection", "(", "_", "plainIdentifier", "Self", "@", "Any", "some"])
}
func inOutExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["&"])
}
func expressionPattern() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect([".", "escapedIdentifier", "implicitParameterName", "\\\\", "{", "plainRegularExpressionLiteral", "decimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "switch", "_", "octalLiteral", "self", "super", "nil", "(", "false", "try", "extendedSinglelineStringLiteral", "plainOperator", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "&", "extendedMultilineStringLiteral", "true", "binaryLiteral", "#imageLiteral", "#selector", "hexadecimalLiteral", "macroIdentifier", "plainIdentifier", "[", "if", "singlelineStringLiteral", "decimalNumber", "await", "#keyPath", "dotOperator"])
}
func enumCasePattern() {
	if token.type = .ALT {
		// OPT
	}
	expect(["plainIdentifier", "_", ".", "escapedIdentifier", "propertyWrapperProjection", "implicitParameterName"])
}
func boxedProtocolType() {
	if token.type = .ALT {
		next()
	}
	expect(["any"])
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
func structDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["fileprivate", "package", "open", "internal", "@", "struct", "private", "public"])
}
func parameterList() {
	if token.type = .ALT {
		parameter()
		// END
	} else if token.type = .ALT {
		parameter()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "propertyWrapperProjection", "_", "implicitParameterName"])
}
func tuplePattern() {
	if token.type = .ALT {
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
func macroHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["mutating", "weak", "prefix", "static", "package", "convenience", "dynamic", "nonmutating", "required", "infix", "optional", "unowned", "@", "open", "final", "private", "macro", "postfix", "public", "nonisolated", "class", "lazy", "override", "internal", "fileprivate"])
}
func precedenceGroupAttributes() {
	if token.type = .ALT {
		precedenceGroupAttribute()
		// OPT
	}
	expect(["higherThan", "assignment", "associativity", "lowerThan"])
}
func deinitializerDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["deinit", "@"])
}
func macroExpansionExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["macroIdentifier"])
}
func willSetDidSetBlock() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func functionCallArgumentClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func assignmentOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func extensionMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["open", "let", "lazy", "extension", "public", "var", "nonisolated", "precedencegroup", "@", "unowned", "convenience", "dynamic", "class", "weak", "mutating", "typealias", "override", "import", "private", "deinit", "postfix", "protocol", "final", "nonmutating", "prefix", "optional", "enum", "struct", "init", "static", "func", "actor", "subscript", "package", "fileprivate", "internal", "infix", "indirect", "required"])
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
func elseDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#else"])
}
func whereClause() {
	if token.type = .ALT {
		next()
	}
	expect(["where"])
}
func typealiasName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func nilLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["nil"])
}
func availabilityArguments() {
	if token.type = .ALT {
		availabilityArgument()
		// END
	} else if token.type = .ALT {
		availabilityArgument()
		// END
	}
	expect(["macOS", "macOSApplicationExtension", "visionOS", "macCatalyst", "*", "iOS", "macCatalystApplicationExtension", "iOSApplicationExtension", "watchOSApplicationExtension", "visionOSApplicationExtension", "tvOS", "watchOS", "tvOSApplicationExtension"])
}
func optionalBindingCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["let"])
}
func conditionalCompilationBlock() {
	if token.type = .ALT {
		ifDirectiveClause()
		// OPT
	}
	expect(["#if"])
}
func captureListItem() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["_", "unowned", "plainIdentifier", "escapedIdentifier", "unowned(unsafe)", "unowned(safe)", "propertyWrapperProjection", "implicitParameterName", "weak"])
}
func interpolatedStringLiteral() {
	if token.type = .ALT {
		stringLiteral()
		// END
	}
	expect(["multilineStringLiteral", "singlelineStringLiteral", "extendedMultilineStringLiteral", "extendedSinglelineStringLiteral"])
}
func defaultLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "default"])
}
func switchElseifDirectiveClause() {
	if token.type = .ALT {
		elseifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#elseif"])
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
func tupleTypeElementList() {
	if token.type = .ALT {
		tupleTypeElement()
		// END
	} else if token.type = .ALT {
		tupleTypeElement()
		// END
	}
	expect(["_", "[", "@", "Any", "implicitParameterName", "propertyWrapperProjection", "(", "some", "Self", "plainIdentifier", "escapedIdentifier"])
}
func initializerHead() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["nonmutating", "unowned", "postfix", "package", "optional", "final", "@", "lazy", "private", "dynamic", "override", "static", "nonisolated", "prefix", "open", "mutating", "init", "public", "fileprivate", "weak", "convenience", "class", "infix", "internal", "required"])
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
func throwStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["throw"])
}
func captureListItems() {
	if token.type = .ALT {
		captureListItem()
		// END
	} else if token.type = .ALT {
		captureListItem()
		// END
	}
	expect(["_", "weak", "self", "escapedIdentifier", "propertyWrapperProjection", "unowned(unsafe)", "implicitParameterName", "plainIdentifier", "unowned", "unowned(safe)"])
}
func implicitMemberExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["."])
}
func dictionaryLiteralItems() {
	if token.type = .ALT {
		dictionaryLiteralItem()
		// OPT
	} else if token.type = .ALT {
		dictionaryLiteralItem()
		// OPT
	}
	expect(["multilineStringLiteral", "\\\\", "#imageLiteral", "[", "dotOperator", "implicitParameterName", ".", "hexadecimalLiteral", "(", "switch", "if", "{", "false", "await", "self", "_", "plainRegularExpressionLiteral", "&", "macroIdentifier", "plainOperator", "hexadecimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "decimalNumber", "escapedIdentifier", "singlelineStringLiteral", "super", "extendedSinglelineStringLiteral", "#fileLiteral", "decimalFloatingPointLiteral", "extendedMultilineStringLiteral", "plainIdentifier", "#selector", "nil", "true", "try", "#colorLiteral", "binaryLiteral", "#keyPath", "propertyWrapperProjection", "octalLiteral"])
}
func functionResult() {
	if token.type = .ALT {
		next()
	}
	expect(["->"])
}
func catchPattern() {
	if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["hexadecimalFloatingPointLiteral", "plainRegularExpressionLiteral", "extendedMultilineStringLiteral", "nil", "try", "singlelineStringLiteral", ".", "switch", "_", "self", "plainIdentifier", "dotOperator", "propertyWrapperProjection", "binaryLiteral", "false", "multilineStringLiteral", "hexadecimalLiteral", "decimalNumber", "extendedRegularExpressionLiteral", "&", "{", "plainOperator", "decimalFloatingPointLiteral", "[", "#keyPath", "#selector", "macroIdentifier", "super", "#fileLiteral", "true", "var", "octalLiteral", "\\\\", "#imageLiteral", "let", "if", "#colorLiteral", "extendedSinglelineStringLiteral", "implicitParameterName", "escapedIdentifier", "(", "await", "is"])
}
func argumentNames() {
	if token.type = .ALT {
		argumentName()
		// OPT
	}
	expect(["_", "escapedIdentifier", "plainIdentifier", "propertyWrapperProjection", "implicitParameterName"])
}
func regularExpressionLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["plainRegularExpressionLiteral"])
}
func topLevelDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["lazy", "try", "hexadecimalLiteral", "infix", "extendedMultilineStringLiteral", "implicitParameterName", "override", "subscript", "nil", "typealias", "break", "dynamic", "#error", "&", "plainIdentifier", "do", "return", "@", "public", "open", "extendedSinglelineStringLiteral", "singlelineStringLiteral", "decimalNumber", "{", "while", "nonmutating", "dotOperator", "prefix", "final", "func", "octalLiteral", "\\\\", "nonisolated", "class", "static", "_", "binaryLiteral", "switch", "guard", "unowned", "macroIdentifier", "private", "actor", "throw", "extension", "enum", "continue", "internal", "required", "weak", "import", "fallthrough", ".", "#colorLiteral", "if", "self", "escapedIdentifier", "defer", "(", "postfix", "convenience", "hexadecimalFloatingPointLiteral", "false", "deinit", "indirect", "#fileLiteral", "#imageLiteral", "#keyPath", "extendedRegularExpressionLiteral", "precedencegroup", "fileprivate", "await", "for", "package", "protocol", "repeat", "true", "multilineStringLiteral", "#selector", "struct", "", "#sourceLocation", "plainOperator", "mutating", "#warning", "plainRegularExpressionLiteral", "super", "propertyWrapperProjection", "let", "var", "optional", "#if", "[", "decimalFloatingPointLiteral", "init"])
}
func keyPathPostfixes() {
	if token.type = .ALT {
		keyPathPostfix()
		// OPT
	}
	expect(["[", "?", "!", "self"])
}
func dictionaryLiteralItem() {
	if token.type = .ALT {
		expression()
		next()
	}
	expect([".", "escapedIdentifier", "implicitParameterName", "\\\\", "{", "plainRegularExpressionLiteral", "decimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "switch", "_", "octalLiteral", "self", "super", "nil", "(", "false", "try", "extendedSinglelineStringLiteral", "plainOperator", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "&", "extendedMultilineStringLiteral", "true", "binaryLiteral", "#imageLiteral", "#selector", "hexadecimalLiteral", "macroIdentifier", "plainIdentifier", "[", "if", "singlelineStringLiteral", "decimalNumber", "await", "#keyPath", "dotOperator"])
}
func forInStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["for"])
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
func lineControlStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#sourceLocation"])
}
func functionType() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "("])
}
func functionHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["func", "mutating", "internal", "@", "weak", "public", "fileprivate", "nonisolated", "convenience", "nonmutating", "final", "postfix", "open", "dynamic", "lazy", "class", "static", "infix", "private", "package", "optional", "unowned", "prefix", "required", "override"])
}
func parameter() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["plainIdentifier", "escapedIdentifier", "implicitParameterName", "_", "propertyWrapperProjection"])
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
func structMembers() {
	if token.type = .ALT {
		structMember()
		// OPT
	}
	expect(["optional", "nonisolated", "@", "public", "enum", "indirect", "protocol", "postfix", "actor", "dynamic", "unowned", "var", "init", "#sourceLocation", "class", "private", "import", "static", "internal", "precedencegroup", "nonmutating", "final", "required", "#if", "package", "weak", "lazy", "deinit", "struct", "#warning", "fileprivate", "typealias", "#error", "extension", "convenience", "prefix", "let", "override", "subscript", "infix", "open", "mutating", "func"])
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
func parameterTypeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
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
func precedenceGroupDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["precedencegroup"])
}
func caseCondition() {
	if token.type = .ALT {
		next()
	}
	expect(["case"])
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
func swiftVersionContinuation() {
	if token.type = .ALT {
		next()
	}
	expect(["."])
}
func rawValueStyleEnumCaseList() {
	if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	} else if token.type = .ALT {
		rawValueStyleEnumCase()
		// END
	}
	expect(["escapedIdentifier", "propertyWrapperProjection", "plainIdentifier", "implicitParameterName", "_"])
}
func elseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
}
func extensionBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func catchClauses() {
	if token.type = .ALT {
		catchClause()
		// OPT
	}
	expect(["catch"])
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
	expect(["false", "true", "hexadecimalLiteral", "singlelineStringLiteral", "plainRegularExpressionLiteral", "decimalNumber", "octalLiteral", "decimalFloatingPointLiteral", "binaryLiteral", "extendedMultilineStringLiteral", "nil", "hexadecimalFloatingPointLiteral", "multilineStringLiteral", "extendedRegularExpressionLiteral", "extendedSinglelineStringLiteral"])
}
func closureParameterList() {
	if token.type = .ALT {
		closureParameter()
		// END
	} else if token.type = .ALT {
		closureParameter()
		// END
	}
	expect(["plainIdentifier", "_", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection"])
}
func staticStringLiteral() {
	if token.type = .ALT {
		stringLiteral()
		// END
	}
	expect(["multilineStringLiteral", "singlelineStringLiteral", "extendedMultilineStringLiteral", "extendedSinglelineStringLiteral"])
}
func classMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["open", "let", "lazy", "extension", "public", "var", "nonisolated", "precedencegroup", "@", "unowned", "convenience", "dynamic", "class", "weak", "mutating", "typealias", "override", "import", "private", "deinit", "postfix", "protocol", "final", "nonmutating", "prefix", "optional", "enum", "struct", "init", "static", "func", "actor", "subscript", "package", "fileprivate", "internal", "infix", "indirect", "required"])
}
func classDeclaration() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["private", "class", "package", "internal", "final", "open", "fileprivate", "@", "public"])
}
func initializer() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func argumentName() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func conditionList() {
	if token.type = .ALT {
		condition()
		// END
	} else if token.type = .ALT {
		condition()
		// END
	}
	expect(["(", "decimalNumber", "binaryLiteral", "extendedRegularExpressionLiteral", "plainIdentifier", "plainRegularExpressionLiteral", "false", "multilineStringLiteral", "dotOperator", "case", "if", "singlelineStringLiteral", "escapedIdentifier", "_", ".", "plainOperator", "#unavailable", "{", "let", "#selector", "self", "#available", "try", "\\\\", "extendedSinglelineStringLiteral", "extendedMultilineStringLiteral", "#imageLiteral", "decimalFloatingPointLiteral", "octalLiteral", "macroIdentifier", "true", "implicitParameterName", "#colorLiteral", "var", "nil", "&", "propertyWrapperProjection", "hexadecimalFloatingPointLiteral", "hexadecimalLiteral", "await", "switch", "super", "#fileLiteral", "[", "#keyPath"])
}
func labelName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func actorDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "public", "fileprivate", "private", "package", "internal", "actor", "open"])
}
func variableDeclarationHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["prefix", "nonisolated", "override", "var", "private", "mutating", "final", "unowned", "class", "package", "open", "infix", "required", "convenience", "weak", "fileprivate", "static", "nonmutating", "dynamic", "lazy", "internal", "postfix", "@", "public", "optional"])
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
func dictionaryLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["["])
}
func elseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
}
func elseifDirectiveClause() {
	if token.type = .ALT {
		elseifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#elseif"])
}
func arrayLiteralItems() {
	if token.type = .ALT {
		arrayLiteralItem()
		// OPT
	} else if token.type = .ALT {
		arrayLiteralItem()
		// OPT
	}
	expect(["#imageLiteral", "plainOperator", "hexadecimalLiteral", "extendedSinglelineStringLiteral", "implicitParameterName", "try", "octalLiteral", "if", "false", ".", "escapedIdentifier", "plainIdentifier", "multilineStringLiteral", "#selector", "decimalNumber", "decimalFloatingPointLiteral", "singlelineStringLiteral", "#keyPath", "&", "[", "\\\\", "hexadecimalFloatingPointLiteral", "true", "await", "self", "#colorLiteral", "switch", "_", "super", "plainRegularExpressionLiteral", "propertyWrapperProjection", "binaryLiteral", "#fileLiteral", "{", "extendedRegularExpressionLiteral", "(", "dotOperator", "macroIdentifier", "nil", "extendedMultilineStringLiteral"])
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
	expect(["convenience", "nonmutating", "package", "prefix", "dynamic", "@", "subscript", "optional", "open", "unowned", "mutating", "override", "lazy", "fileprivate", "internal", "public", "infix", "required", "nonisolated", "private", "final", "weak", "class", "static", "postfix"])
}
func attributes() {
	if token.type = .ALT {
		attribute()
		// OPT
	}
	expect(["@"])
}
func wildcardPattern() {
	if token.type = .ALT {
		next()
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
	expect(["plainIdentifier", "_", "escapedIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func unionStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["escapedIdentifier", "plainIdentifier", "propertyWrapperProjection", "implicitParameterName", "_"])
}
func setterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["nonmutating", "set", "mutating", "@"])
}
func macroSignature() {
	if token.type = .ALT {
		parameterClause()
		// OPT
	}
	expect(["("])
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
func elseifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#elseif"])
}
func guardStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["guard"])
}
func switchElseifDirectiveClauses() {
	if token.type = .ALT {
		elseifDirectiveClause()
		// OPT
	}
	expect(["#elseif"])
}
func unionStyleEnum() {
	if token.type = .ALT {
		// OPT
	}
	expect(["enum", "indirect"])
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
func codeBlock() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func actorName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func awaitOperator() {
	if token.type = .ALT {
		next()
	}
	expect(["await"])
}
func switchExpressionCases() {
	if token.type = .ALT {
		switchExpressionCase()
		// OPT
	}
	expect(["@", "default", "case"])
}
func extensionMembers() {
	if token.type = .ALT {
		extensionMember()
		// OPT
	}
	expect(["package", "class", "open", "var", "#warning", "protocol", "typealias", "import", "struct", "final", "nonisolated", "optional", "infix", "precedencegroup", "indirect", "postfix", "#error", "init", "#sourceLocation", "lazy", "unowned", "prefix", "convenience", "weak", "override", "enum", "fileprivate", "subscript", "#if", "dynamic", "nonmutating", "let", "required", "actor", "static", "extension", "func", "@", "mutating", "public", "private", "deinit", "internal"])
}
func argumentLabel() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func unionStyleEnumMembers() {
	if token.type = .ALT {
		unionStyleEnumMember()
		// OPT
	}
	expect(["typealias", "weak", "unowned", "final", "enum", "import", "dynamic", "convenience", "override", "protocol", "open", "package", "let", "private", "prefix", "static", "func", "required", "case", "@", "deinit", "class", "lazy", "struct", "nonmutating", "optional", "var", "internal", "nonisolated", "postfix", "subscript", "infix", "#error", "#if", "actor", "indirect", "precedencegroup", "fileprivate", "#sourceLocation", "extension", "init", "mutating", "public", "#warning"])
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
func initializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["required", "convenience", "package", "public", "optional", "@", "init", "postfix", "internal", "open", "class", "private", "fileprivate", "static", "weak", "mutating", "nonmutating", "lazy", "override", "dynamic", "nonisolated", "final", "infix", "unowned", "prefix"])
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
func Operator() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["plainOperator"])
}
func availabilityCondition() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#available"])
}
func caseItemList() {
	if token.type = .ALT {
		pattern()
		// OPT
	} else if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["hexadecimalFloatingPointLiteral", "plainRegularExpressionLiteral", "extendedMultilineStringLiteral", "nil", "try", "singlelineStringLiteral", ".", "switch", "_", "self", "plainIdentifier", "dotOperator", "propertyWrapperProjection", "binaryLiteral", "false", "multilineStringLiteral", "hexadecimalLiteral", "decimalNumber", "extendedRegularExpressionLiteral", "&", "{", "plainOperator", "decimalFloatingPointLiteral", "[", "#keyPath", "#selector", "macroIdentifier", "super", "#fileLiteral", "true", "var", "octalLiteral", "\\\\", "#imageLiteral", "let", "if", "#colorLiteral", "extendedSinglelineStringLiteral", "implicitParameterName", "escapedIdentifier", "(", "await", "is"])
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
func typeIdentifier() {
	if token.type = .ALT {
		typeName()
		// OPT
	} else if token.type = .ALT {
		typeName()
		// OPT
	}
	expect(["plainIdentifier", "escapedIdentifier", "_", "implicitParameterName", "propertyWrapperProjection"])
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
func throwsClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["throws"])
}
func setterName() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func structName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func macroDeclaration() {
	if token.type = .ALT {
		macroHead()
		identifier()
		// OPT
	}
	expect(["open", "dynamic", "postfix", "@", "final", "private", "unowned", "infix", "convenience", "prefix", "internal", "required", "optional", "public", "nonisolated", "macro", "mutating", "class", "fileprivate", "package", "override", "weak", "nonmutating", "lazy", "static"])
}
func optionalPattern() {
	if token.type = .ALT {
		identifierPattern()
		next()
	}
	expect(["implicitParameterName", "escapedIdentifier", "propertyWrapperProjection", "_", "plainIdentifier"])
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
func actorMember() {
	if token.type = .ALT {
		declaration()
		// END
	} else if token.type = .ALT {
		declaration()
		// END
	}
	expect(["open", "let", "lazy", "extension", "public", "var", "nonisolated", "precedencegroup", "@", "unowned", "convenience", "dynamic", "class", "weak", "mutating", "typealias", "override", "import", "private", "deinit", "postfix", "protocol", "final", "nonmutating", "prefix", "optional", "enum", "struct", "init", "static", "func", "actor", "subscript", "package", "fileprivate", "internal", "infix", "indirect", "required"])
}
func typealiasDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["public", "internal", "private", "@", "fileprivate", "package", "typealias", "open"])
}
func valueBindingPattern() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["var"])
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
func rawValueStyleEnumMembers() {
	if token.type = .ALT {
		rawValueStyleEnumMember()
		// OPT
	}
	expect(["weak", "optional", "enum", "indirect", "postfix", "nonisolated", "override", "protocol", "nonmutating", "open", "precedencegroup", "lazy", "static", "public", "import", "infix", "deinit", "var", "#error", "struct", "subscript", "#sourceLocation", "func", "private", "let", "mutating", "#warning", "final", "internal", "@", "convenience", "required", "unowned", "prefix", "extension", "actor", "dynamic", "#if", "class", "package", "fileprivate", "case", "init", "typealias"])
}
func functionTypeArgumentList() {
	if token.type = .ALT {
		functionTypeArgument()
		// END
	} else if token.type = .ALT {
		functionTypeArgument()
		// END
	}
	expect(["_", "[", "plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "@", "implicitParameterName", "inout", "(", "Any", "Self", "some"])
}
func wildcardExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["_"])
}
func keyPathStringExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["#keyPath"])
}
func initializerExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	} else if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["hexadecimalLiteral", "switch", "false", "extendedRegularExpressionLiteral", ".", "singlelineStringLiteral", "#colorLiteral", "[", "if", "decimalNumber", "binaryLiteral", "true", "macroIdentifier", "plainIdentifier", "decimalFloatingPointLiteral", "nil", "extendedSinglelineStringLiteral", "plainRegularExpressionLiteral", "{", "octalLiteral", "#keyPath", "\\\\", "(", "propertyWrapperProjection", "self", "#imageLiteral", "#selector", "#fileLiteral", "extendedMultilineStringLiteral", "super", "implicitParameterName", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "_", "escapedIdentifier"])
}
func switchCases() {
	if token.type = .ALT {
		switchCase()
		// OPT
	}
	expect(["@", "default", "#if", "case"])
}
func captureList() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func didSetClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "didSet"])
}
func protocolMembers() {
	if token.type = .ALT {
		protocolMember()
		// OPT
	}
	expect(["prefix", "package", "init", "#if", "@", "typealias", "fileprivate", "mutating", "required", "final", "open", "nonmutating", "private", "func", "convenience", "internal", "nonisolated", "override", "var", "static", "#warning", "class", "unowned", "infix", "dynamic", "optional", "associatedtype", "#error", "#sourceLocation", "lazy", "public", "weak", "subscript", "postfix"])
}
func tuplePatternElementList() {
	if token.type = .ALT {
		tuplePatternElement()
		// END
	} else if token.type = .ALT {
		tuplePatternElement()
		// END
	}
	expect(["is", "implicitParameterName", "plainOperator", "&", "await", "super", "plainIdentifier", "propertyWrapperProjection", "#imageLiteral", "self", "if", "#colorLiteral", "extendedSinglelineStringLiteral", "decimalNumber", "switch", "extendedRegularExpressionLiteral", "octalLiteral", "[", "var", "macroIdentifier", "hexadecimalFloatingPointLiteral", ".", "escapedIdentifier", "let", "extendedMultilineStringLiteral", "try", "(", "#fileLiteral", "decimalFloatingPointLiteral", "multilineStringLiteral", "singlelineStringLiteral", "#selector", "\\\\", "#keyPath", "true", "binaryLiteral", "dotOperator", "_", "nil", "{", "plainRegularExpressionLiteral", "false", "hexadecimalLiteral"])
}
func tupleExpression() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func attributeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
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
	expect(["propertyWrapperProjection", "_", "escapedIdentifier", "plainIdentifier", "implicitParameterName"])
}
func switchStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["switch"])
}
func repeatWhileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["repeat"])
}
func subscriptResult() {
	if token.type = .ALT {
		next()
	}
	expect(["->"])
}
func breakStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["break"])
}
func subscriptHead() {
	if token.type = .ALT {
		// OPT
	}
	expect(["open", "postfix", "nonmutating", "fileprivate", "static", "nonisolated", "class", "unowned", "lazy", "optional", "infix", "package", "private", "subscript", "mutating", "public", "dynamic", "final", "@", "required", "override", "prefix", "weak", "convenience", "internal"])
}
func protocolPropertyDeclaration() {
	if token.type = .ALT {
		variableDeclarationHead()
		variableName()
		typeAnnotation()
		getterSetterKeywordBlock()
		// END
	}
	expect(["convenience", "fileprivate", "private", "package", "class", "postfix", "weak", "mutating", "unowned", "open", "optional", "internal", "@", "static", "nonisolated", "override", "nonmutating", "required", "infix", "final", "var", "dynamic", "prefix", "lazy", "public"])
}
func closureExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
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
func ifExpressionTail() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
}
func protocolAssociatedTypeDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["internal", "@", "private", "public", "associatedtype", "open", "package", "fileprivate"])
}
func importDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["import", "@"])
}
func className() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func functionBody() {
	if token.type = .ALT {
		codeBlock()
		// END
	}
	expect(["{"])
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
func switchElseDirectiveClause() {
	if token.type = .ALT {
		elseDirective()
		// OPT
	}
	expect(["#else"])
}
func rawValueAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func mutationModifier() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["mutating"])
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
	expect([".", "decimalFloatingPointLiteral", "extendedSinglelineStringLiteral", "[", "#keyPath", "singlelineStringLiteral", "switch", "hexadecimalFloatingPointLiteral", "plainRegularExpressionLiteral", "{", "self", "_", "macroIdentifier", "#selector", "nil", "extendedMultilineStringLiteral", "hexadecimalLiteral", "(", "#colorLiteral", "implicitParameterName", "escapedIdentifier", "\\\\", "#imageLiteral", "super", "multilineStringLiteral", "false", "#fileLiteral", "if", "propertyWrapperProjection", "decimalNumber", "plainIdentifier", "binaryLiteral", "octalLiteral", "extendedRegularExpressionLiteral", "true"])
}
func attributeArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["("])
}
func precedenceGroupAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["assignment"])
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
func functionTypeArgumentClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func diagnosticStatement() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["#warning"])
}
func getterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "mutating", "nonmutating", "get"])
}
func statementLabel() {
	if token.type = .ALT {
		labelName()
		next()
	}
	expect(["propertyWrapperProjection", "escapedIdentifier", "_", "implicitParameterName", "plainIdentifier"])
}
func booleanLiteral() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["true"])
}
func expression() {
	if token.type = .ALT {
		// OPT
	}
	expect(["escapedIdentifier", "true", "extendedMultilineStringLiteral", "hexadecimalLiteral", "hexadecimalFloatingPointLiteral", "macroIdentifier", "&", "super", "plainIdentifier", "implicitParameterName", "#keyPath", "#selector", ".", "binaryLiteral", "nil", "plainRegularExpressionLiteral", "try", "[", "octalLiteral", "if", "plainOperator", "(", "{", "#imageLiteral", "\\\\", "false", "decimalFloatingPointLiteral", "singlelineStringLiteral", "_", "self", "multilineStringLiteral", "extendedSinglelineStringLiteral", "switch", "dotOperator", "extendedRegularExpressionLiteral", "#colorLiteral", "propertyWrapperProjection", "#fileLiteral", "decimalNumber", "await"])
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
func typeName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func labeledTrailingClosures() {
	if token.type = .ALT {
		labeledTrailingClosure()
		// OPT
	}
	expect(["_", "implicitParameterName", "escapedIdentifier", "plainIdentifier", "propertyWrapperProjection"])
}
func whileStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["while"])
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
func catchPatternList() {
	if token.type = .ALT {
		catchPattern()
		// END
	} else if token.type = .ALT {
		catchPattern()
		// END
	}
	expect(["octalLiteral", "switch", "multilineStringLiteral", "#colorLiteral", "dotOperator", "var", "{", "extendedRegularExpressionLiteral", "macroIdentifier", "(", "self", "\\\\", "try", "propertyWrapperProjection", "decimalNumber", "extendedSinglelineStringLiteral", "_", "plainIdentifier", "implicitParameterName", "#fileLiteral", "#keyPath", "hexadecimalLiteral", "true", "nil", "is", "#imageLiteral", "binaryLiteral", "plainRegularExpressionLiteral", "#selector", "&", "singlelineStringLiteral", "escapedIdentifier", "let", "extendedMultilineStringLiteral", ".", "await", "hexadecimalFloatingPointLiteral", "plainOperator", "if", "false", "[", "super", "decimalFloatingPointLiteral"])
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
	expect(["open", "let", "lazy", "extension", "public", "var", "nonisolated", "precedencegroup", "@", "unowned", "convenience", "dynamic", "class", "weak", "mutating", "typealias", "override", "import", "private", "deinit", "postfix", "protocol", "final", "nonmutating", "prefix", "optional", "enum", "struct", "init", "static", "func", "actor", "subscript", "package", "fileprivate", "internal", "infix", "indirect", "required"])
}
func trailingClosures() {
	if token.type = .ALT {
		closureExpression()
		// OPT
	}
	expect(["{"])
}
func forcedValueExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["hexadecimalLiteral", "switch", "false", "extendedRegularExpressionLiteral", ".", "singlelineStringLiteral", "#colorLiteral", "[", "if", "decimalNumber", "binaryLiteral", "true", "macroIdentifier", "plainIdentifier", "decimalFloatingPointLiteral", "nil", "extendedSinglelineStringLiteral", "plainRegularExpressionLiteral", "{", "octalLiteral", "#keyPath", "\\\\", "(", "propertyWrapperProjection", "self", "#imageLiteral", "#selector", "#fileLiteral", "extendedMultilineStringLiteral", "super", "implicitParameterName", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "_", "escapedIdentifier"])
}
func catchClause() {
	if token.type = .ALT {
		next()
	}
	expect(["catch"])
}
func enumCaseName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func protocolInitializerDeclaration() {
	if token.type = .ALT {
		initializerHead()
		// OPT
	} else if token.type = .ALT {
		initializerHead()
		// OPT
	}
	expect(["required", "convenience", "package", "public", "optional", "@", "init", "postfix", "internal", "open", "class", "private", "fileprivate", "static", "weak", "mutating", "nonmutating", "lazy", "override", "dynamic", "nonisolated", "final", "infix", "unowned", "prefix"])
}
func switchIfDirectiveClause() {
	if token.type = .ALT {
		ifDirective()
		compilationCondition()
		// OPT
	}
	expect(["#if"])
}
func closureParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func unionStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["indirect", "@", "case"])
}
func infixExpressions() {
	if token.type = .ALT {
		infixExpression()
		// OPT
	}
	expect(["plainOperator", "as", "?", "is", "dotOperator", "="])
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
func prefixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["prefix"])
}
func defaultArgumentClause() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func macroDefinition() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func filePath() {
	if token.type = .ALT {
		staticStringLiteral()
		// END
	}
	expect(["multilineStringLiteral", "singlelineStringLiteral", "extendedMultilineStringLiteral", "extendedSinglelineStringLiteral"])
}
func tuplePatternElement() {
	if token.type = .ALT {
		pattern()
		// END
	} else if token.type = .ALT {
		pattern()
		// END
	}
	expect(["hexadecimalFloatingPointLiteral", "plainRegularExpressionLiteral", "extendedMultilineStringLiteral", "nil", "try", "singlelineStringLiteral", ".", "switch", "_", "self", "plainIdentifier", "dotOperator", "propertyWrapperProjection", "binaryLiteral", "false", "multilineStringLiteral", "hexadecimalLiteral", "decimalNumber", "extendedRegularExpressionLiteral", "&", "{", "plainOperator", "decimalFloatingPointLiteral", "[", "#keyPath", "#selector", "macroIdentifier", "super", "#fileLiteral", "true", "var", "octalLiteral", "\\\\", "#imageLiteral", "let", "if", "#colorLiteral", "extendedSinglelineStringLiteral", "implicitParameterName", "escapedIdentifier", "(", "await", "is"])
}
func requirementList() {
	if token.type = .ALT {
		requirement()
		// END
	} else if token.type = .ALT {
		requirement()
		// END
	}
	expect(["propertyWrapperProjection", "plainIdentifier", "escapedIdentifier", "implicitParameterName", "_"])
}
func typeInheritanceList() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["implicitParameterName", "_", "escapedIdentifier", "plainIdentifier", "@", "propertyWrapperProjection"])
}
func ifExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
}
func setterKeywordClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "mutating", "set", "nonmutating"])
}
func dictionaryType() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func switchExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["switch"])
}
func postfixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["plainOperator", "dotOperator"])
}
func returnStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["return"])
}
func swiftVersion() {
	if token.type = .ALT {
		decimalDigits()
		// OPT
	}
	expect(["decimalNumber"])
}
func precedenceGroupNames() {
	if token.type = .ALT {
		precedenceGroupName()
		// END
	} else if token.type = .ALT {
		precedenceGroupName()
		// END
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "_", "implicitParameterName", "escapedIdentifier"])
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
	expect(["hexadecimalLiteral", "switch", "false", "extendedRegularExpressionLiteral", ".", "singlelineStringLiteral", "#colorLiteral", "[", "if", "decimalNumber", "binaryLiteral", "true", "macroIdentifier", "plainIdentifier", "decimalFloatingPointLiteral", "nil", "extendedSinglelineStringLiteral", "plainRegularExpressionLiteral", "{", "octalLiteral", "#keyPath", "\\\\", "(", "propertyWrapperProjection", "self", "#imageLiteral", "#selector", "#fileLiteral", "extendedMultilineStringLiteral", "super", "implicitParameterName", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "_", "escapedIdentifier"])
}
func subscriptExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["hexadecimalLiteral", "switch", "false", "extendedRegularExpressionLiteral", ".", "singlelineStringLiteral", "#colorLiteral", "[", "if", "decimalNumber", "binaryLiteral", "true", "macroIdentifier", "plainIdentifier", "decimalFloatingPointLiteral", "nil", "extendedSinglelineStringLiteral", "plainRegularExpressionLiteral", "{", "octalLiteral", "#keyPath", "\\\\", "(", "propertyWrapperProjection", "self", "#imageLiteral", "#selector", "#fileLiteral", "extendedMultilineStringLiteral", "super", "implicitParameterName", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "_", "escapedIdentifier"])
}
func actorIsolationModifier() {
	if token.type = .ALT {
		next()
	}
	expect(["nonisolated"])
}
func elseClause() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["else"])
}
func protocolName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func prefixExpression() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["#selector", "implicitParameterName", "escapedIdentifier", "#colorLiteral", "extendedRegularExpressionLiteral", "(", ".", "#fileLiteral", "\\\\", "binaryLiteral", "switch", "propertyWrapperProjection", "false", "true", "[", "super", "hexadecimalLiteral", "dotOperator", "_", "macroIdentifier", "extendedMultilineStringLiteral", "decimalFloatingPointLiteral", "singlelineStringLiteral", "plainRegularExpressionLiteral", "multilineStringLiteral", "extendedSinglelineStringLiteral", "self", "decimalNumber", "plainIdentifier", "hexadecimalFloatingPointLiteral", "plainOperator", "#keyPath", "nil", "octalLiteral", "#imageLiteral", "if", "{"])
}
func keyPathComponents() {
	if token.type = .ALT {
		keyPathComponent()
		// END
	} else if token.type = .ALT {
		keyPathComponent()
		// END
	}
	expect(["plainIdentifier", "_", "self", "[", "escapedIdentifier", "?", "propertyWrapperProjection", "implicitParameterName", "!"])
}
func classMembers() {
	if token.type = .ALT {
		classMember()
		// OPT
	}
	expect(["optional", "unowned", "import", "nonmutating", "prefix", "postfix", "actor", "infix", "internal", "public", "#error", "struct", "let", "@", "open", "protocol", "weak", "nonisolated", "override", "init", "subscript", "class", "required", "private", "fileprivate", "enum", "lazy", "dynamic", "#if", "#warning", "deinit", "var", "convenience", "final", "package", "func", "extension", "#sourceLocation", "mutating", "precedencegroup", "typealias", "indirect", "static"])
}
func rawValueStyleEnum() {
	if token.type = .ALT {
		next()
	}
	expect(["enum"])
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
func genericParameterClause() {
	if token.type = .ALT {
		next()
	}
	expect(["<"])
}
func environment() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["simulator"])
}
func numericLiteral() {
	if token.type = .ALT {
		integerLiteral()
		// END
	} else if token.type = .ALT {
		integerLiteral()
		// END
	}
	expect(["decimalNumber", "octalLiteral", "hexadecimalLiteral", "binaryLiteral"])
}
func keyPathExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["\\\\"])
}
func patternInitializerList() {
	if token.type = .ALT {
		patternInitializer()
		// END
	} else if token.type = .ALT {
		patternInitializer()
		// END
	}
	expect(["(", "plainRegularExpressionLiteral", "multilineStringLiteral", "macroIdentifier", "\\\\", "decimalNumber", "decimalFloatingPointLiteral", "extendedMultilineStringLiteral", "singlelineStringLiteral", "true", "binaryLiteral", "try", "plainIdentifier", "&", "dotOperator", "{", "#colorLiteral", "await", "plainOperator", "implicitParameterName", "var", "self", "is", "switch", "hexadecimalLiteral", "false", "extendedRegularExpressionLiteral", "[", "octalLiteral", "#imageLiteral", "#keyPath", ".", "let", "propertyWrapperProjection", "nil", "hexadecimalFloatingPointLiteral", "super", "#fileLiteral", "if", "#selector", "escapedIdentifier", "extendedSinglelineStringLiteral", "_"])
}
func typealiasAssignment() {
	if token.type = .ALT {
		next()
	}
	expect(["="])
}
func superclassMethodExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
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
	expect(["hexadecimalFloatingPointLiteral", "decimalNumber", "octalLiteral", "decimalFloatingPointLiteral", "hexadecimalLiteral", "binaryLiteral"])
}
func prefixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["plainOperator", "dotOperator"])
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
	expect(["hexadecimalLiteral", "switch", "false", "extendedRegularExpressionLiteral", ".", "singlelineStringLiteral", "#colorLiteral", "[", "if", "decimalNumber", "binaryLiteral", "true", "macroIdentifier", "plainIdentifier", "decimalFloatingPointLiteral", "nil", "extendedSinglelineStringLiteral", "plainRegularExpressionLiteral", "{", "octalLiteral", "#keyPath", "\\\\", "(", "propertyWrapperProjection", "self", "#imageLiteral", "#selector", "#fileLiteral", "extendedMultilineStringLiteral", "super", "implicitParameterName", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "_", "escapedIdentifier"])
}
func superclassSubscriptExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
}
func protocolMethodDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["open", "mutating", "unowned", "nonmutating", "class", "dynamic", "func", "prefix", "@", "infix", "public", "convenience", "optional", "fileprivate", "private", "package", "lazy", "override", "internal", "postfix", "weak", "required", "nonisolated", "static", "final"])
}
func infixOperator() {
	if token.type = .ALT {
		Operator()
		// END
	}
	expect(["plainOperator", "dotOperator"])
}
func infixOperatorGroup() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func declarationModifiers() {
	if token.type = .ALT {
		declarationModifier()
		// OPT
	}
	expect(["infix", "convenience", "unowned", "override", "lazy", "static", "internal", "optional", "nonmutating", "prefix", "fileprivate", "private", "nonisolated", "final", "weak", "public", "postfix", "required", "mutating", "package", "open", "dynamic", "class"])
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
func rawValueStyleEnumCaseClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "case"])
}
func conformanceRequirement() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	} else if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["escapedIdentifier", "_", "implicitParameterName", "plainIdentifier", "propertyWrapperProjection"])
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
	expect([".", "escapedIdentifier", "implicitParameterName", "\\\\", "{", "plainRegularExpressionLiteral", "decimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "switch", "_", "octalLiteral", "self", "super", "nil", "(", "false", "try", "extendedSinglelineStringLiteral", "plainOperator", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "&", "extendedMultilineStringLiteral", "true", "binaryLiteral", "#imageLiteral", "#selector", "hexadecimalLiteral", "macroIdentifier", "plainIdentifier", "[", "if", "singlelineStringLiteral", "decimalNumber", "await", "#keyPath", "dotOperator"])
}
func arrayLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["["])
}
func postfixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["postfix"])
}
func fallthroughStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["fallthrough"])
}
func unionStyleEnumCaseList() {
	if token.type = .ALT {
		unionStyleEnumCase()
		// END
	} else if token.type = .ALT {
		unionStyleEnumCase()
		// END
	}
	expect(["_", "escapedIdentifier", "plainIdentifier", "implicitParameterName", "propertyWrapperProjection"])
}
func opaqueType() {
	if token.type = .ALT {
		next()
	}
	expect(["some"])
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
	expect(["visionOSApplicationExtension", "iOSApplicationExtension", "macOS", "macCatalyst", "watchOS", "tvOSApplicationExtension", "visionOS", "tvOS", "macCatalystApplicationExtension", "watchOSApplicationExtension", "macOSApplicationExtension", "iOS"])
}
func closureParameter() {
	if token.type = .ALT {
		closureParameterName()
		// OPT
	} else if token.type = .ALT {
		closureParameterName()
		// OPT
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "implicitParameterName", "propertyWrapperProjection"])
}
func patternInitializer() {
	if token.type = .ALT {
		pattern()
		// OPT
	}
	expect(["hexadecimalFloatingPointLiteral", "plainRegularExpressionLiteral", "extendedMultilineStringLiteral", "nil", "try", "singlelineStringLiteral", ".", "switch", "_", "self", "plainIdentifier", "dotOperator", "propertyWrapperProjection", "binaryLiteral", "false", "multilineStringLiteral", "hexadecimalLiteral", "decimalNumber", "extendedRegularExpressionLiteral", "&", "{", "plainOperator", "decimalFloatingPointLiteral", "[", "#keyPath", "#selector", "macroIdentifier", "super", "#fileLiteral", "true", "var", "octalLiteral", "\\\\", "#imageLiteral", "let", "if", "#colorLiteral", "extendedSinglelineStringLiteral", "implicitParameterName", "escapedIdentifier", "(", "await", "is"])
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
func closureSignature() {
	if token.type = .ALT {
		// OPT
	} else if token.type = .ALT {
		// OPT
	}
	expect(["plainIdentifier", "propertyWrapperProjection", "escapedIdentifier", "[", "(", "_", "implicitParameterName"])
}
func rawValueStyleEnumCase() {
	if token.type = .ALT {
		enumCaseName()
		// OPT
	}
	expect(["escapedIdentifier", "plainIdentifier", "propertyWrapperProjection", "implicitParameterName", "_"])
}
func infixOperatorDeclaration() {
	if token.type = .ALT {
		next()
	}
	expect(["infix"])
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
	expect([".", "escapedIdentifier", "implicitParameterName", "\\\\", "{", "plainRegularExpressionLiteral", "decimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "switch", "_", "octalLiteral", "self", "super", "nil", "(", "false", "try", "extendedSinglelineStringLiteral", "plainOperator", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "&", "extendedMultilineStringLiteral", "true", "binaryLiteral", "#imageLiteral", "#selector", "hexadecimalLiteral", "macroIdentifier", "plainIdentifier", "[", "if", "singlelineStringLiteral", "decimalNumber", "await", "#keyPath", "dotOperator"])
}
func anyType() {
	if token.type = .ALT {
		next()
	}
	expect(["Any"])
}
func superclassInitializerExpression() {
	if token.type = .ALT {
		next()
	}
	expect(["super"])
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
func implicitlyUnwrappedOptionalType() {
	if token.type = .ALT {
		type()
		next()
	}
	expect(["[", "implicitParameterName", "escapedIdentifier", "propertyWrapperProjection", "(", "_", "plainIdentifier", "Self", "@", "Any", "some"])
}
func getterClause() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "mutating", "get", "nonmutating"])
}
func enumName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func endifDirective() {
	if token.type = .ALT {
		next()
	}
	expect(["#endif"])
}
func caseLabel() {
	if token.type = .ALT {
		// OPT
	}
	expect(["@", "case"])
}
func labeledTrailingClosure() {
	if token.type = .ALT {
		identifier()
		next()
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func classBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func isPattern() {
	if token.type = .ALT {
		next()
	}
	expect(["is"])
}
func constantDeclaration() {
	if token.type = .ALT {
		// OPT
	}
	expect(["lazy", "optional", "fileprivate", "let", "class", "required", "public", "infix", "private", "weak", "static", "postfix", "override", "final", "unowned", "convenience", "package", "open", "mutating", "nonmutating", "prefix", "dynamic", "internal", "@", "nonisolated"])
}
func protocolBody() {
	if token.type = .ALT {
		next()
	}
	expect(["{"])
}
func tupleType() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["("])
}
func doStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["do"])
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
	expect(["convenience", "fileprivate", "private", "package", "class", "postfix", "weak", "mutating", "unowned", "open", "optional", "internal", "@", "static", "nonisolated", "override", "nonmutating", "required", "infix", "final", "var", "dynamic", "prefix", "lazy", "public"])
}
func initializerBody() {
	if token.type = .ALT {
		codeBlock()
		// END
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
	expect([".", "escapedIdentifier", "implicitParameterName", "\\\\", "{", "plainRegularExpressionLiteral", "decimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "switch", "_", "octalLiteral", "self", "super", "nil", "(", "false", "try", "extendedSinglelineStringLiteral", "plainOperator", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "&", "extendedMultilineStringLiteral", "true", "binaryLiteral", "#imageLiteral", "#selector", "hexadecimalLiteral", "macroIdentifier", "plainIdentifier", "[", "if", "singlelineStringLiteral", "decimalNumber", "await", "#keyPath", "dotOperator"])
}
func typeAnnotation() {
	if token.type = .ALT {
		next()
	}
	expect([":"])
}
func protocolCompositionContinuation() {
	if token.type = .ALT {
		typeIdentifier()
		// END
	} else if token.type = .ALT {
		typeIdentifier()
		// END
	}
	expect(["escapedIdentifier", "_", "implicitParameterName", "plainIdentifier", "propertyWrapperProjection"])
}
func localParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func decimalDigits() {
	if token.type = .ALT {
		next()
	}
	expect(["decimalNumber"])
}
func tupleElementList() {
	if token.type = .ALT {
		tupleElement()
		// END
	} else if token.type = .ALT {
		tupleElement()
		// END
	}
	expect(["extendedMultilineStringLiteral", "escapedIdentifier", "true", "#fileLiteral", "super", "hexadecimalLiteral", "multilineStringLiteral", "#selector", "hexadecimalFloatingPointLiteral", "binaryLiteral", "decimalNumber", "macroIdentifier", ".", "plainOperator", "await", "[", "if", "false", "(", "try", "self", "&", "dotOperator", "plainRegularExpressionLiteral", "{", "#colorLiteral", "implicitParameterName", "extendedSinglelineStringLiteral", "singlelineStringLiteral", "extendedRegularExpressionLiteral", "#keyPath", "\\\\", "switch", "#imageLiteral", "octalLiteral", "decimalFloatingPointLiteral", "_", "propertyWrapperProjection", "plainIdentifier", "nil"])
}
func genericParameterList() {
	if token.type = .ALT {
		genericParameter()
		// END
	} else if token.type = .ALT {
		genericParameter()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "implicitParameterName", "propertyWrapperProjection", "_"])
}
func deferStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["defer"])
}
func decimalLiteral() {
	if token.type = .ALT {
		next()
	}
	expect(["decimalNumber"])
}
func functionDeclaration() {
	if token.type = .ALT {
		functionHead()
		functionName()
		// OPT
	}
	expect(["open", "mutating", "unowned", "nonmutating", "class", "dynamic", "func", "prefix", "@", "infix", "public", "convenience", "optional", "fileprivate", "private", "package", "lazy", "override", "internal", "postfix", "weak", "required", "nonisolated", "static", "final"])
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
	expect(["escapedIdentifier", "implicitParameterName", "propertyWrapperProjection", "_", "plainIdentifier"])
}
func ifStatement() {
	if token.type = .ALT {
		next()
	}
	expect(["if"])
}
func protocolCompositionType() {
	if token.type = .ALT {
		typeIdentifier()
		next()
	}
	expect(["escapedIdentifier", "_", "implicitParameterName", "plainIdentifier", "propertyWrapperProjection"])
}
func arrayLiteralItem() {
	if token.type = .ALT {
		expression()
		// END
	}
	expect([".", "escapedIdentifier", "implicitParameterName", "\\\\", "{", "plainRegularExpressionLiteral", "decimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "switch", "_", "octalLiteral", "self", "super", "nil", "(", "false", "try", "extendedSinglelineStringLiteral", "plainOperator", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "&", "extendedMultilineStringLiteral", "true", "binaryLiteral", "#imageLiteral", "#selector", "hexadecimalLiteral", "macroIdentifier", "plainIdentifier", "[", "if", "singlelineStringLiteral", "decimalNumber", "await", "#keyPath", "dotOperator"])
}
func externalParameterName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
func asPattern() {
	if token.type = .ALT {
		pattern()
		next()
	}
	expect(["hexadecimalFloatingPointLiteral", "plainRegularExpressionLiteral", "extendedMultilineStringLiteral", "nil", "try", "singlelineStringLiteral", ".", "switch", "_", "self", "plainIdentifier", "dotOperator", "propertyWrapperProjection", "binaryLiteral", "false", "multilineStringLiteral", "hexadecimalLiteral", "decimalNumber", "extendedRegularExpressionLiteral", "&", "{", "plainOperator", "decimalFloatingPointLiteral", "[", "#keyPath", "#selector", "macroIdentifier", "super", "#fileLiteral", "true", "var", "octalLiteral", "\\\\", "#imageLiteral", "let", "if", "#colorLiteral", "extendedSinglelineStringLiteral", "implicitParameterName", "escapedIdentifier", "(", "await", "is"])
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
	expect(["plainIdentifier", "escapedIdentifier", "_", "implicitParameterName", "propertyWrapperProjection"])
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
	expect([".", "escapedIdentifier", "implicitParameterName", "\\\\", "{", "plainRegularExpressionLiteral", "decimalFloatingPointLiteral", "extendedRegularExpressionLiteral", "propertyWrapperProjection", "#fileLiteral", "#colorLiteral", "switch", "_", "octalLiteral", "self", "super", "nil", "(", "false", "try", "extendedSinglelineStringLiteral", "plainOperator", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "&", "extendedMultilineStringLiteral", "true", "binaryLiteral", "#imageLiteral", "#selector", "hexadecimalLiteral", "macroIdentifier", "plainIdentifier", "[", "if", "singlelineStringLiteral", "decimalNumber", "await", "#keyPath", "dotOperator"])
}
func optionalChainingExpression() {
	if token.type = .ALT {
		postfixExpression()
		next()
	}
	expect(["hexadecimalLiteral", "switch", "false", "extendedRegularExpressionLiteral", ".", "singlelineStringLiteral", "#colorLiteral", "[", "if", "decimalNumber", "binaryLiteral", "true", "macroIdentifier", "plainIdentifier", "decimalFloatingPointLiteral", "nil", "extendedSinglelineStringLiteral", "plainRegularExpressionLiteral", "{", "octalLiteral", "#keyPath", "\\\\", "(", "propertyWrapperProjection", "self", "#imageLiteral", "#selector", "#fileLiteral", "extendedMultilineStringLiteral", "super", "implicitParameterName", "multilineStringLiteral", "hexadecimalFloatingPointLiteral", "_", "escapedIdentifier"])
}
func precedenceGroupName() {
	if token.type = .ALT {
		identifier()
		// END
	}
	expect(["escapedIdentifier", "plainIdentifier", "_", "propertyWrapperProjection", "implicitParameterName"])
}
