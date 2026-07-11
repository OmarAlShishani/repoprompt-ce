import Foundation
import XCTest
@_spi(TestSupport) @testable import RepoPrompt

final class ModelPickerStringOrderingTests: XCTestCase {
    func testScalarOrderingUsesAsciiFoldThenRawScalarTieBreak() {
        XCTAssertEqual(
            ModelPickerStringOrdering.compare("GPT-5", "gpt-5", caseInsensitiveASCII: true),
            .orderedAscending
        )
        XCTAssertEqual(
            ["ı", "i", "I"].sorted { ModelPickerStringOrdering.precedes($0, $1) },
            ["I", "i", "ı"]
        )
        XCTAssertTrue(ModelPickerStringOrdering.precedes("gpt-5.5-Low", "gpt-5.5-low"))
    }

    func testAIModelSemanticPickerOrderingCoversGptVersionsServiceTierReasoningAndRawTieBreaks() {
        let models: [AIModel] = [
            .codexCustom(name: "gpt-5.2-high"),
            .codexCustom(name: "gpt-5.4-fast-high"),
            .codexCustom(name: "gpt-5.5-high"),
            .codexCustom(name: "gpt-5.4-low"),
            .codexCustom(name: "gpt-5.5-low"),
            .codexCustom(name: "gpt-5.4-fast-low"),
            .codexCustom(name: "gpt-5.5-Low")
        ]

        let sorted = AIModel.sortedForPicker(models).map(\.modelName)

        XCTAssertEqual(sorted, [
            "gpt-5.5-Low",
            "gpt-5.5-low",
            "gpt-5.5-high",
            "gpt-5.4-low",
            "gpt-5.4-fast-low",
            "gpt-5.4-fast-high",
            "gpt-5.2-high"
        ])
    }

    func testSemanticOrderingUsesFamilyBeforeDisplayNameAcrossFamilies() {
        let sorted = AIModel.sortedForPicker([
            .customProvider(name: "Aardvark", provider: "custom", model: "zzz-1"),
            .customProvider(name: "Zed", provider: "custom", model: "aaa-1")
        ])

        XCTAssertEqual(sorted.map(\.modelName), ["aaa-1", "zzz-1"])
    }

    func testStaleGeminiCLIPrefixedModelsAreRejectedForFallback() {
        XCTAssertNil(AIModel.fromModelName("gemini_cli_flash-2.5"))
        XCTAssertNil(AIModel.fromModelName(" gemini_cli_pro-3.1-preview "))
        XCTAssertEqual(AIModel.fromModelName("gemini-3-pro-preview"), .gemini3p1ProPreview)
    }

    func testClaudeCodePickerExposesFable5WithEffortVariantsFirst() throws {
        let models = AIModel.modelsForProvider(.claudeCode)
        XCTAssertTrue(models.contains(.claudeCodeModel(specifier: "claude-fable-5")))
        XCTAssertTrue(models.contains(.claudeCodeModel(specifier: "claude-fable-5:xhigh")))
        XCTAssertEqual(
            AIModel.fromModelName("\(ClaudeCodeAIModelCatalog.rawPrefix)claude-fable-5:xhigh"),
            .claudeCodeModel(specifier: "claude-fable-5:xhigh")
        )

        let menu = AIModel.claudeCodeMenu(for: models)
        XCTAssertEqual(menu.groups.first?.baseModelRaw, "claude-fable-5")
        let fableGroup = try XCTUnwrap(menu.groups.first { $0.baseModelRaw == "claude-fable-5" })
        XCTAssertEqual(fableGroup.displayName, "Fable 5")
        XCTAssertTrue(fableGroup.options.contains { $0.displayName == "XHigh" })
    }

    func testAIModelCodexMenuGroupsUseStableSemanticOrdering() {
        let groups = AIModel.codexMenuGroups(for: [
            .codexCustom(name: "gpt-5.2-high"),
            .codexCustom(name: "gpt-5.4-fast-high"),
            .codexCustom(name: "gpt-5.5-high"),
            .codexCustom(name: "gpt-5.4-low"),
            .codexCustom(name: "gpt-5.5-low"),
            .codexCustom(name: "gpt-5.4-fast-low"),
            .codexCustom(name: "gpt-5.5-Low")
        ])

        XCTAssertEqual(groups.map(\.baseModelID), [
            "gpt-5.5",
            "gpt-5.4",
            "gpt-5.4-fast",
            "gpt-5.2"
        ])
        XCTAssertEqual(
            groups.first { $0.baseModelID == "gpt-5.5" }?.models.map(\.modelName),
            ["gpt-5.5-Low", "gpt-5.5-low", "gpt-5.5-high"]
        )
    }

    func testAgentModelCatalogCodexMenuUsesStableSemanticOrdering() {
        var options = [
            option(raw: AgentModel.defaultModel.rawValue, displayName: AgentModel.defaultModel.displayName, placeholderDefault: true),
            option(raw: "gpt-5.2-high", displayName: "GPT-5.2 High"),
            option(raw: "gpt-5.4-fast-high", displayName: "GPT-5.4 Fast High"),
            option(raw: "gpt-5.5-high", displayName: "GPT-5.5 High"),
            option(raw: "gpt-5.4-low", displayName: "GPT-5.4 Low"),
            option(raw: "gpt-5.5-low", displayName: "GPT-5.5 Low"),
            option(raw: "gpt-5.4-fast-low", displayName: "GPT-5.4 Fast Low"),
            option(raw: "gpt-5.5-Low", displayName: "GPT-5.5 Low")
        ]
        let commonGPT56Efforts: [CodexDynamicReasoningRecord] = [
            .init(reasoningEffort: "low", description: "Fast responses with lighter reasoning"),
            .init(reasoningEffort: "medium", description: "Balanced speed and reasoning depth"),
            .init(reasoningEffort: "high", description: "Greater reasoning depth"),
            .init(reasoningEffort: "xhigh", description: "Extra high reasoning depth"),
            .init(reasoningEffort: "max", description: "Maximum reasoning depth")
        ]
        let dynamicModels = [
            CodexDynamicModelRecord(
                id: "gpt-5.6-sol",
                model: "gpt-5.6-sol",
                displayName: "GPT-5.6-Sol",
                description: "Latest frontier agentic coding model.",
                isDefault: true,
                supportedReasoningEfforts: commonGPT56Efforts + [
                    .init(reasoningEffort: "ultra", description: "Maximum reasoning with automatic task delegation")
                ],
                defaultReasoningEffort: "medium"
            ),
            CodexDynamicModelRecord(
                id: "gpt-5.6-terra",
                model: "gpt-5.6-terra",
                displayName: "GPT-5.6-Terra",
                description: "Balanced agentic coding model for everyday work.",
                isDefault: false,
                supportedReasoningEfforts: commonGPT56Efforts + [
                    .init(reasoningEffort: "ultra", description: "Maximum reasoning with automatic task delegation")
                ],
                defaultReasoningEffort: "medium"
            ),
            CodexDynamicModelRecord(
                id: "gpt-5.6-luna",
                model: "gpt-5.6-luna",
                displayName: "GPT-5.6-Luna",
                description: "Fast and affordable agentic coding model.",
                isDefault: false,
                supportedReasoningEfforts: commonGPT56Efforts,
                defaultReasoningEffort: "medium"
            )
        ]
        let mappedDynamicOptions = CodexDynamicModelMapper.options(from: dynamicModels)
        XCTAssertEqual(
            mappedDynamicOptions.filter { $0.baseID == "gpt-5.6-sol" }.map(\.id),
            [
                "gpt-5.6-sol-low", "gpt-5.6-sol-medium", "gpt-5.6-sol-high",
                "gpt-5.6-sol-xhigh", "gpt-5.6-sol-max", "gpt-5.6-sol-ultra"
            ]
        )
        XCTAssertEqual(
            mappedDynamicOptions.filter { $0.baseID == "gpt-5.6-terra" }.map(\.id),
            [
                "gpt-5.6-terra-low", "gpt-5.6-terra-medium", "gpt-5.6-terra-high",
                "gpt-5.6-terra-xhigh", "gpt-5.6-terra-max", "gpt-5.6-terra-ultra"
            ]
        )
        XCTAssertEqual(
            mappedDynamicOptions.filter { $0.baseID == "gpt-5.6-luna" }.map(\.id),
            [
                "gpt-5.6-luna-low", "gpt-5.6-luna-medium", "gpt-5.6-luna-high",
                "gpt-5.6-luna-xhigh", "gpt-5.6-luna-max"
            ]
        )
        XCTAssertEqual(mappedDynamicOptions.first(where: \.isDefault)?.id, "gpt-5.6-sol-medium")

        options.append(contentsOf: mappedDynamicOptions.map {
            option(raw: $0.id, displayName: $0.displayName, providerDefault: $0.isDefault)
        })
        let menu = AgentModelCatalog.codexMenu(for: options)

        XCTAssertEqual(menu.defaultOption?.rawValue, AgentModel.defaultModel.rawValue)
        XCTAssertEqual(menu.groups.map(\.baseModelID), [
            "gpt-5.6-sol",
            "gpt-5.6-terra",
            "gpt-5.6-luna",
            "gpt-5.5",
            "gpt-5.4",
            "gpt-5.4-fast",
            "gpt-5.2"
        ])
        XCTAssertEqual(
            menu.groups.first { $0.baseModelID == "gpt-5.5" }?.options.map(\.rawValue),
            ["gpt-5.5-Low", "gpt-5.5-low", "gpt-5.5-high"]
        )
        XCTAssertEqual(
            menu.groups.first { $0.baseModelID == "gpt-5.6-sol" }?.options.map(\.rawValue),
            [
                "gpt-5.6-sol-low", "gpt-5.6-sol-medium", "gpt-5.6-sol-high",
                "gpt-5.6-sol-xhigh", "gpt-5.6-sol-max", "gpt-5.6-sol-ultra"
            ]
        )

        let maxSpecifier = CodexModelSpecifier(raw: "gpt-5.6-sol-max")
        XCTAssertEqual(maxSpecifier.baseModel, "gpt-5.6-sol")
        XCTAssertEqual(maxSpecifier.reasoningEffort, .max)
        let ultraSpecifier = CodexModelSpecifier(raw: "gpt-5.6-sol-ultra")
        XCTAssertEqual(ultraSpecifier.baseModel, "gpt-5.6-sol")
        XCTAssertEqual(ultraSpecifier.reasoningEffort, .ultra)
        let legacyMaxModel = CodexModelSpecifier(raw: "gpt-5.1-codex-max")
        XCTAssertEqual(legacyMaxModel.baseModel, "gpt-5.1-codex-max")
        XCTAssertNil(legacyMaxModel.reasoningEffort)
        let legacyModelAtMaxEffort = CodexModelSpecifier(raw: "gpt-5.1-codex-max-max")
        XCTAssertEqual(legacyModelAtMaxEffort.baseModel, "gpt-5.1-codex-max")
        XCTAssertEqual(legacyModelAtMaxEffort.reasoningEffort, .max)
        XCTAssertEqual(AIModel.stripCodexReasoningSuffix(from: "GPT-5.1 Codex Max"), "GPT-5.1 Codex Max")
    }

    @MainActor
    func testCollapsedCodexOptionsUseStableSemanticOrderingAndPreserveDefaults() throws {
        let collapsed: [AgentModelOption] = CodexAgentModeCoordinator.test_collapseCodexModelOptions([
            option(raw: AgentModel.defaultModel.rawValue, displayName: AgentModel.defaultModel.displayName, placeholderDefault: true),
            option(raw: "gpt-5.2-high", displayName: "GPT-5.2 High"),
            option(raw: "gpt-5.4-fast-high", displayName: "GPT-5.4 Fast High"),
            option(raw: "gpt-5.5-high", displayName: "GPT-5.5 High", providerDefault: true),
            option(raw: "gpt-5.4-low", displayName: "GPT-5.4 Low"),
            option(raw: "gpt-5.5-low", displayName: "GPT-5.5 Low"),
            option(raw: "gpt-5.4-fast-low", displayName: "GPT-5.4 Fast Low")
        ])

        XCTAssertEqual(collapsed.map(\.rawValue), [
            AgentModel.defaultModel.rawValue,
            "gpt-5.5",
            "gpt-5.4",
            "gpt-5.4-fast",
            "gpt-5.2"
        ])

        let gpt55 = try XCTUnwrap(collapsed.first { $0.rawValue == "gpt-5.5" })
        XCTAssertEqual(gpt55.supportedReasoningEfforts, [CodexReasoningEffort.low, .high])
        XCTAssertEqual(gpt55.defaultReasoningEffort, .high)
        XCTAssertEqual(gpt55.isProviderDefault, true)
    }

    private func option(
        raw: String,
        displayName: String,
        placeholderDefault: Bool = false,
        providerDefault: Bool = false,
        supportedReasoningEfforts: [CodexReasoningEffort] = [],
        defaultReasoningEffort: CodexReasoningEffort? = nil
    ) -> AgentModelOption {
        AgentModelOption(
            rawValue: raw,
            displayName: displayName,
            description: nil,
            isPlaceholderDefault: placeholderDefault,
            isProviderDefault: providerDefault,
            supportedReasoningEfforts: supportedReasoningEfforts,
            defaultReasoningEffort: defaultReasoningEffort
        )
    }
}
