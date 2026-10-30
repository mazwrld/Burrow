import Foundation

/// The only commands Burrow hands to Terminal. Built from this fixed list,
/// never from free text.
public enum TerminalCommand: Equatable, Sendable {
    case clean
    case cleanWhitelist
    case uninstall(name: String)

    public var arguments: [String] {
        switch self {
        case .clean: ["clean"]
        case .cleanWhitelist: ["clean", "--whitelist"]
        case .uninstall(let name): ["uninstall", name]
        }
    }

    /// What the user sees and copies: `mo clean --whitelist`.
    public var display: String { (["mo"] + arguments.map(Shell.quote)).joined(separator: " ") }

    /// The script a `.command` file runs: the real `mo` path, then the arguments.
    public func script(moPath: String) -> String {
        "#!/bin/zsh\n" + ([moPath] + arguments).map(Shell.quote).joined(separator: " ") + "\n"
    }
}

public enum Shell {
    /// Leaves plain words alone and single-quotes everything else.
    public static func quote(_ word: String) -> String {
        let plain = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./=:@+")
        if !word.isEmpty, word.unicodeScalars.allSatisfy(plain.contains) { return word }
        return "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
