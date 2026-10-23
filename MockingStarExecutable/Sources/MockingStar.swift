import MockingstarEngine
#if os(Linux)
import Glibc
#else
import Darwin
#endif

@main
enum MockingStarCLI {
    static func main() async {
        var arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.first == MockingstarEngine.runtimeArgument { arguments.removeFirst() }
        exit(await MockingstarEngine.runCLI(arguments))
    }
}
