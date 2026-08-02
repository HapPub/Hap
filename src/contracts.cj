package hapcli

import std.collection.ArrayList

public class HapDependencyRef {
    public let name: String
    public let path: String
    public let git: String
    public let branch: String
    public let tag: String

    public init(name: String, path: String, git: String, branch: String, tag: String) {
        this.name = name
        this.path = path
        this.git = git
        this.branch = branch
        this.tag = tag
    }

    public func isPathDependency(): Bool {
        path.size > 0
    }

    public func isGitDependency(): Bool {
        git.size > 0
    }
}
public class HapCjpmProfileInspectResult {
    public let schema: String
    public let ok: Bool
    public let fixtureId: String
    public let input: String
    public let inferredProfile: String
    public let pathDependencies: ArrayList<HapDependencyRef>
    public let gitDependencies: ArrayList<HapDependencyRef>
    public let mixedProfile: Bool
    public let warnings: ArrayList<String>
    public let nextAllowed: ArrayList<String>

    public init(
        schema: String,
        ok: Bool,
        fixtureId: String,
        input: String,
        inferredProfile: String,
        pathDependencies: ArrayList<HapDependencyRef>,
        gitDependencies: ArrayList<HapDependencyRef>,
        mixedProfile: Bool,
        warnings: ArrayList<String>,
        nextAllowed: ArrayList<String>
    ) {
        this.schema = schema
        this.ok = ok
        this.fixtureId = fixtureId
        this.input = input
        this.inferredProfile = inferredProfile
        this.pathDependencies = pathDependencies
        this.gitDependencies = gitDependencies
        this.mixedProfile = mixedProfile
        this.warnings = warnings
        this.nextAllowed = nextAllowed
    }
}
