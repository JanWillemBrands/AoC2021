/// Trace macro that prints debug output in DEBUG builds only.
///
/// In release builds, this macro expands to a call to `_traceImpl` which has
/// an empty body, and the optimizer eliminates everything including argument evaluation.
///
/// The `_traceImpl` function must be defined in the consuming module (e.g. in OutputTools.swift).
///
/// Usage:
///   #Trace("message")
///   #Trace("label:", value)
///   #Trace("text", terminator: "\n")
///   #Trace()
@freestanding(expression)
public macro Trace(_ items: Any..., terminator: String = "") = #externalMacro(module: "AdventMacrosImpl", type: "TraceMacro")
