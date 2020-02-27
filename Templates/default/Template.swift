import TemplateDescription

let nameArgument: Template.Attribute = .required("name")
let platformArgument: Template.Attribute = .optional("platform", default: "iOS")

let setupContent = """
import ProjectDescription

let setup = Setup([
    // .homebrew(packages: ["swiftlint", "carthage"]),
    // .carthage()
])
"""

let projectDescriptionHelpersContent = """
import ProjectDescription

extension Project {

    public static func app(name: String, platform: Platform, dependencies: [TargetDependency] = []) -> Project {
        return self.project(name: name, product: .app, platform: platform, dependencies: dependencies, infoPlist: [
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1"
        ])
    }

    public static func framework(name: String, platform: Platform, dependencies: [TargetDependency] = []) -> Project {
        return self.project(name: name, product: .framework, platform: platform, dependencies: dependencies)
    }

    public static func project(name: String,
                               product: Product,
                               platform: Platform,
                               dependencies: [TargetDependency] = [],
                               infoPlist: [String: InfoPlist.Value] = [:]) -> Project {
        return Project(name: name,
                       targets: [
                        Target(name: name,
                                platform: platform,
                                product: product,
                                bundleId: "io.tuist.\\(name)",
                                infoPlist: .extendingDefault(with: infoPlist),
                                sources: ["Sources/**"],
                                resources: [],
                                dependencies: dependencies),
                        Target(name: "\\(name)Tests",
                                platform: platform,
                                product: .unitTests,
                                bundleId: "io.tuist.\\(name)Tests",
                                infoPlist: .default,
                                sources: "Tests/**",
                                dependencies: [
                                    .target(name: "\\(name)")
                                ])
                      ])
    }

}
"""

let projectsPath = "Projects"
let appPath = projectsPath + "/\(nameArgument)"
let kitFrameworkPath = projectsPath + "/\(nameArgument)Kit"
let supportFrameworkPath = projectsPath + "/\(nameArgument)Support"

func directories(for projectPath: String) -> [String] {
    [
        projectPath,
        projectPath + "/Sources",
        projectPath + "/Tests",
        projectPath + "/Playgrounds",
    ]
}

let workspaceContent = """
import ProjectDescription
import ProjectDescriptionHelpers

let workspace = Workspace(name: "\(nameArgument)", projects: [
    "Projects/\(nameArgument)",
    "Projects/\(nameArgument)Kit",
    "Projects/\(nameArgument)Support"
])
"""

func testsContent(_ name: String) -> String {
    """
    import Foundation
    import XCTest
    
    @testable import \(name)

    final class \(name)Tests: XCTestCase {
    
    }
    """
}

let kitSourceContent = """
import Foundation
import \(nameArgument)Support

public final class \(nameArgument)Kit {}
"""

let supportSourceContent = """
import Foundation

public final class \(nameArgument)Support {}
"""

let playgroundContent = """
//: Playground - noun: a place where people can play

import Foundation

"""

let tuistConfigContent =  """
import ProjectDescription

let config = TuistConfig(generationOptions: [
])
"""

let gitignoreContent = """
### macOS ###
# General
.DS_Store
.AppleDouble
.LSOverride

# Icon must end with two \r
Icon

# Thumbnails
._*

# Files that might appear in the root of a volume
.DocumentRevisions-V100
.fseventsd
.Spotlight-V100
.TemporaryItems
.Trashes
.VolumeIcon.icns
.com.apple.timemachine.donotpresent

# Directories potentially created on remote AFP share
.AppleDB
.AppleDesktop
Network Trash Folder
Temporary Items
.apdisk

### Xcode ###
# Xcode
#
# gitignore contributors: remember to update Global/Xcode.gitignore, Objective-C.gitignore & Swift.gitignore

## User settings
xcuserdata/

## compatibility with Xcode 8 and earlier (ignoring not required starting Xcode 9)
*.xcscmblueprint
*.xccheckout

## compatibility with Xcode 3 and earlier (ignoring not required starting Xcode 4)
build/
DerivedData/
*.moved-aside
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3

### Xcode Patch ###
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcodeproj/xcshareddata/
!*.xcworkspace/contents.xcworkspacedata
/*.gcno

### Projects ###
*.xcodeproj
*.xcworkspace

### Tuist derived files ###
graph.dot
"""

let template = Template(
    description: "Custom \(nameArgument)",
    arguments: [
        nameArgument,
        platformArgument,
    ],
    files: [
        .static(path: "Setup.swift",
                contents: setupContent),
        .static(path: "Workspace.swift",
                contents: workspaceContent),
        .static(path: "Tuist/ProjectDescriptionHelpers/Project+Templates.swift",
                contents: projectDescriptionHelpersContent),
        .generated(path: appPath + "/Project.swift",
                   generateFilePath: "AppProject.swift"),
        .generated(path: kitFrameworkPath + "/Project.swift",
                   generateFilePath: "KitFrameworkProject.swift"),
        .generated(path: supportFrameworkPath + "/Project.swift",
                   generateFilePath: "SupportFrameworkProject.swift"),
        .generated(path: appPath + "/Sources/AppDelegate.swift",
                   generateFilePath: "AppDelegate.swift"),
        .static(path: appPath + "/Tests/\(nameArgument)Tests.swift",
                contents: testsContent("\(nameArgument)")),
        .static(path: kitFrameworkPath + "/Sources/\(nameArgument)Kit.swift",
                contents: kitSourceContent),
        .static(path: kitFrameworkPath + "/Tests/\(nameArgument)KitTests.swift",
                contents: testsContent("\(nameArgument)Kit")),
        .static(path: supportFrameworkPath + "/Sources/\(nameArgument)Support.swift",
                contents: supportSourceContent),
        .static(path: supportFrameworkPath + "/Tests/\(nameArgument)SupportTests.swift",
                contents: testsContent("\(nameArgument)Support")),
        .static(path: kitFrameworkPath + "/Playgrounds/\(nameArgument)Kit/Playgrounds/Contents.swift",
                contents: playgroundContent),
        .generated(path: kitFrameworkPath + "/Playgrounds/\(nameArgument)Kit/Playgrounds/contents.xcplayground",
                   generateFilePath: "Playground.swift"),
        .static(path: supportFrameworkPath + "/Playgrounds/\(nameArgument)Support/Playgrounds/Contents.swift",
                contents: playgroundContent),
        .generated(path: kitFrameworkPath + "/Playgrounds/\(nameArgument)Support/Playgrounds/contents.xcplayground",
                   generateFilePath: "Playground.swift"),
        .static(path: "TuistConfig.swift",
                contents: tuistConfigContent),
        .static(path: ".gitignore",
                contents: gitignoreContent),
    ],
    directories: [
        "Tuist/ProjectDescriptionHelpers",
    ]
        + directories(for: appPath)
        + directories(for: kitFrameworkPath)
        + directories(for: supportFrameworkPath)
)