import Foundation
import TuistSupport
import TuistLoader
import SPMUtility
import Basic

// swiftlint:disable:next type_body_length
class ScaffoldCommand: NSObject, Command {
    // MARK: - Attributes

    static let command = "scaffold"
    static let overview = "Generates new project based on template."
    let listArgument: OptionArgument<Bool>
    
    private let templateLoader: TemplateLoading

    // MARK: - Init

    public required convenience init(parser: ArgumentParser) {
        self.init(parser: parser,
                  templateLoader: TemplateLoader())
    }
    
    init(parser: ArgumentParser,
         templateLoader: TemplateLoading) {
        let subParser = parser.add(subparser: ScaffoldCommand.command, overview: ScaffoldCommand.overview)
        listArgument = subParser.add(option: "--list",
                                     shortName: "-l",
                                     kind: Bool.self,
                                     usage: "Lists available scaffold templates",
                                     completion: nil)
        self.templateLoader = templateLoader
    }

    func run(with arguments: ArgumentParser.Result) throws {
        let templatesDirectory = Environment.shared.versionsDirectory.appending(components: Constants.version, Constants.templatesDirectoryName)
        let directories = try FileHandler.shared.contentsOfDirectory(templatesDirectory)
        
        let shouldList = arguments.get(listArgument) ?? false
        if shouldList {
            try directories.forEach {
                let template = try templateLoader.load(at: $0)
                Printer.shared.print("\($0.basename): \(template.description)")
            }
            return
        }
    }
}