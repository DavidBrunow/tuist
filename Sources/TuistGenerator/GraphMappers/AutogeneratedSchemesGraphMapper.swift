import Foundation
import TuistCore

public class AutogeneratedSchemesGraphMapper: GraphMapping {
    public init() {}

    public func map(graph: Graph) throws -> (Graph, [SideEffectDescriptor]) {
//        let buildConfiguration = defaultDebugBuildConfigurationName(in: project)
//        let userDefinedSchemes = Set(project.schemes.map(\.name))
//        let defaultSchemeTargets = project.targets.filter { !userDefinedSchemes.contains($0.name) }
//        let defaultSchemes: [SchemeDescriptor] = try defaultSchemeTargets.map { target in
//            let scheme = createDefaultScheme(target: target, project: project, buildConfiguration: buildConfiguration, graph: graph)
//            return try generateScheme(scheme: scheme,
//                                      path: project.path,
//                                      graph: graph,
//                                      generatedProjects: [project.path: generatedProject])
//        }

        return (graph, [])
    }

    func createDefaultScheme(target: Target, project: Project, buildConfiguration: String, graph: Graph) -> Scheme {
        let targetReference = TargetReference(projectPath: project.path, name: target.name)

        let testTargets: [TestableTarget]

        if target.product.testsBundle {
            testTargets = [TestableTarget(target: targetReference)]
        } else {
            testTargets = graph.testTargetsDependingOn(path: project.path, name: target.name)
                .map { TargetReference(projectPath: $0.project.path, name: $0.target.name) }
                .map { TestableTarget(target: $0) }
        }

        return Scheme(name: target.name,
                      shared: true,
                      buildAction: BuildAction(targets: [targetReference]),
                      testAction: TestAction(targets: testTargets, configurationName: buildConfiguration),
                      runAction: RunAction(configurationName: buildConfiguration,
                                           executable: targetReference,
                                           arguments: Arguments(environment: target.environment)))
    }
}
