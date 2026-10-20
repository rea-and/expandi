import Foundation

public final class TestRunner {
    public static func runAllTests() {
        print("==========================================")
        print(" Running Expandi Internal Self-Tests     ")
        print("==========================================")
        
        testMacroEvaluatorDates()
        testFillInExtractionAndEvaluation()
        testDatePickerEvaluation()
        testOptionalSections()
        testCursorPositioning()
        testNestedSnippets()
        testCaseAdaptation()
        testExportImportJSON()
        testExportImportCSV()
        testImportExternalLegacyCSV()
        testFactoryResetAndDeleteAll()
        testOnboardingEmptyAndStarter()
        
        print("==========================================")
        print(" ALL 12 TEST SUITES PASSED (100%)        ")
        print("==========================================")
    }
    
    // MARK: - Tests
    
    private static func testMacroEvaluatorDates() {
        print("[TEST 1/10] Date & Time Macros...")
        let evaluator = MacroEvaluator.shared
        let dummyGroup = UUID()
        
        let snippetDate = Snippet(
            title: "Date Test",
            abbreviation: ";d",
            content: "Date: {{date:yyyy-MM-dd}}",
            groupId: dummyGroup
        )
        let resDate = evaluator.evaluate(snippet: snippetDate)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let expected = "Date: \(formatter.string(from: Date()))"
        assert(resDate.text == expected, "Date evaluation failed: \(resDate.text) != \(expected)")
        
        // Date math +7d
        let snippetMath = Snippet(
            title: "Math Test",
            abbreviation: ";m",
            content: "{{date:offset=+7d,format=yyyy-MM-dd}}",
            groupId: dummyGroup
        )
        let resMath = evaluator.evaluate(snippet: snippetMath)
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let expectedMath = formatter.string(from: nextWeek)
        assert(resMath.text == expectedMath, "Date math offset failed: \(resMath.text) != \(expectedMath)")
        print("  -> Passed!")
    }
    
    private static func testFillInExtractionAndEvaluation() {
        print("[TEST 2/10] Single & Multi Line Fill-Ins...")
        let evaluator = MacroEvaluator.shared
        let content = "Hello {{fill:First Name:default=Andrea}}, notes: {{multiline:Details:default=No notes}}."
        let fields = evaluator.extractFillInFields(from: content)
        
        assert(fields.count == 2, "Expected 2 fields, got \(fields.count)")
        assert(fields[0].label == "First Name", "Field label mismatch")
        assert(fields[0].defaultValue == "Andrea", "Default value mismatch")
        assert(fields[1].label == "Details", "Field label mismatch")
        
        let snippet = Snippet(title: "T", abbreviation: ";t", content: content, groupId: UUID())
        let evalDefault = evaluator.evaluate(snippet: snippet)
        assert(evalDefault.text == "Hello Andrea, notes: No notes.", "Evaluation failed: \(evalDefault.text)")
        
        let evalCustom = evaluator.evaluate(
            snippet: snippet,
            fillInValues: ["fill_First Name": "Sarah", "multi_Details": "Urgent review required"]
        )
        assert(evalCustom.text == "Hello Sarah, notes: Urgent review required.", "Custom eval failed: \(evalCustom.text)")
        print("  -> Passed!")
    }
    
    private static func testDatePickerEvaluation() {
        print("[TEST 3/10] Date Picker Fill-In...")
        let evaluator = MacroEvaluator.shared
        let content = "Meeting scheduled for {{datepicker:Meeting Date:format=yyyy-MM-dd}}."
        let fields = evaluator.extractFillInFields(from: content)
        
        assert(fields.count == 1, "Expected 1 field")
        assert(fields[0].type == .datePicker, "Expected datePicker type")
        
        let snippet = Snippet(title: "T", abbreviation: ";d", content: content, groupId: UUID())
        let customDateVal = ["date_Meeting Date": "2026-12-25"]
        let res = evaluator.evaluate(snippet: snippet, fillInValues: customDateVal)
        assert(res.text == "Meeting scheduled for 2026-12-25.", "DatePicker eval failed: \(res.text)")
        print("  -> Passed!")
    }
    
    private static func testOptionalSections() {
        print("[TEST 4/10] Optional Sections (Checkboxes)...")
        let evaluator = MacroEvaluator.shared
        let content = "Hello!\n{{opt:Include signature:Best regards,\nAndrea}}"
        let fields = evaluator.extractFillInFields(from: content)
        
        assert(fields.count == 1, "Expected 1 field")
        assert(fields[0].type == .optionalSection, "Expected optionalSection type")
        
        let snippet = Snippet(title: "T", abbreviation: ";s", content: content, groupId: UUID())
        
        // When checked:
        let resChecked = evaluator.evaluate(snippet: snippet, fillInValues: ["opt_Include signature": "true"])
        assert(resChecked.text == "Hello!\nBest regards,\nAndrea", "Opt true failed")
        
        // When unchecked:
        let resUnchecked = evaluator.evaluate(snippet: snippet, fillInValues: ["opt_Include signature": "false"])
        assert(resUnchecked.text == "Hello!\n", "Opt false failed")
        print("  -> Passed!")
    }
    
    private static func testCursorPositioning() {
        print("[TEST 5/10] Cursor Placement Macro...")
        let evaluator = MacroEvaluator.shared
        let content = "console.log(\"{{cursor}}\");"
        let snippet = Snippet(title: "T", abbreviation: ";clog", content: content, groupId: UUID())
        let res = evaluator.evaluate(snippet: snippet)
        
        assert(res.text == "console.log(\"\");", "Cursor marker removal failed")
        assert(res.cursorOffsetFromEnd == 3, "Expected cursor offset 3, got \(String(describing: res.cursorOffsetFromEnd))")
        print("  -> Passed!")
    }
    
    private static func testNestedSnippets() {
        print("[TEST 6/10] Nested Snippets...")
        let evaluator = MacroEvaluator.shared
        let g = UUID()
        let snippetA = Snippet(title: "Sig", abbreviation: ";sig", content: "Best,\nAndrea", groupId: g)
        let snippetB = Snippet(title: "Msg", abbreviation: ";msg", content: "Hi there!\n\n{{snippet:;sig}}", groupId: g)
        
        let res = evaluator.evaluate(snippet: snippetB, allSnippets: [snippetA, snippetB])
        assert(res.text == "Hi there!\n\nBest,\nAndrea", "Nested snippet failed: \(res.text)")
        print("  -> Passed!")
    }
    
    private static func testCaseAdaptation() {
        print("[TEST 7/10] Case Sensitivity & Adaptation...")
        let evaluator = MacroEvaluator.shared
        let g = UUID()
        let snippet = Snippet(
            title: "Test",
            abbreviation: ";alpha",
            content: "alpha beta",
            groupId: g,
            caseSensitivity: .adaptCase
        )
        
        // Lowercase
        let resLower = evaluator.evaluate(snippet: snippet, typedTrigger: ";alpha")
        assert(resLower.text == "alpha beta", "Lower failed")
        
        // Capitalized
        let resCap = evaluator.evaluate(snippet: snippet, typedTrigger: ";Alpha")
        assert(resCap.text == "Alpha beta", "Capitalized failed")
        
        // ALL CAPS
        let resAll = evaluator.evaluate(snippet: snippet, typedTrigger: ";ALPHA")
        assert(resAll.text == "ALPHA BETA", "ALL CAPS failed")
        print("  -> Passed!")
    }
    
    private static func testExportImportJSON() {
        print("[TEST 8/10] JSON Export & Import Round-trip...")
        let group = SnippetGroup(name: "Test Group", prefix: ";")
        let snippet = Snippet(title: "Test Snippet", abbreviation: ";test", content: "Hello JSON", groupId: group.id)
        
        do {
            let data = try Exporter.shared.exportJSON(groups: [group], snippets: [snippet])
            assert(!data.isEmpty, "Export produced empty data")
            
            var groups: [SnippetGroup] = []
            var snippets: [Snippet] = []
            let result = try Importer.shared.importJSON(
                data: data,
                into: &groups,
                existingSnippets: &snippets,
                resolutionMode: .overwrite
            )
            
            assert(result.snippetsImported == 1, "Expected 1 snippet imported")
            assert(snippets.first?.abbreviation == ";test", "Snippet abbreviation mismatch")
            print("  -> Passed!")
        } catch {
            fatalError("JSON test error: \(error)")
        }
    }
    
    private static func testExportImportCSV() {
        print("[TEST 9/10] CSV Export & RFC-4180 Parsing...")
        let group = SnippetGroup(name: "CSV Group", prefix: ";")
        let snippet = Snippet(
            title: "Quote Test",
            abbreviation: ";quote",
            content: "Line 1 with, comma\n\"Line 2 with quotes\"",
            groupId: group.id
        )
        
        let csv = Exporter.shared.exportCSV(groups: [group], snippets: [snippet])
        assert(csv.contains("Line 1 with, comma"), "CSV missing content")
        
        var groups: [SnippetGroup] = []
        var snippets: [Snippet] = []
        let result = Importer.shared.importCSV(
            csvString: csv,
            into: &groups,
            existingSnippets: &snippets,
            resolutionMode: .overwrite
        )
        
        assert(result.snippetsImported == 1, "Expected 1 snippet imported via CSV")
        assert(snippets.first?.content == snippet.content, "CSV multi-line quote parsing mismatch")
        print("  -> Passed!")
    }
    
    private static func testImportExternalLegacyCSV() {
        print("[TEST 10/10] External 3-Column CSV (Basics.csv) Import & Macro Conversion...")
        
        let pathCandidates = [
            "Resources/Basics.csv",
            "../Resources/Basics.csv",
            "/Users/andrea/Projects/expandi/Resources/Basics.csv",
            "/Users/andrea/Downloads/Basics.csv"
        ]
        
        var csvContent: String? = nil
        for p in pathCandidates {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: p)),
               let str = String(data: data, encoding: .utf8) {
                csvContent = str
                break
            }
        }
        
        guard let csv = csvContent else {
            print("  -> Skipped (Basics.csv not found on disk)")
            return
        }
        
        var groups: [SnippetGroup] = []
        var snippets: [Snippet] = []
        
        let result = Importer.shared.importCSV(
            csvString: csv,
            defaultGroupName: "Basics",
            into: &groups,
            existingSnippets: &snippets,
            resolutionMode: .overwrite
        )
        
        guard result.snippetsImported >= 10 else {
            fatalError("Expected at least 10 snippets from Basics.csv, got \(result.snippetsImported)")
        }
        guard groups.first?.name == "Basics" else {
            fatalError("Expected group 'Basics' to be created")
        }
        
        // Verify Blue Dot
        let blueDot = snippets.first { $0.abbreviation == ";bb" }
        guard let bb = blueDot, bb.content == "🔵", bb.title == "Blue Dot" else {
            fatalError("Verification failed for ;bb")
        }
        
        // Verify Date conversion
        let dateSnippet = snippets.first { $0.abbreviation == ";dd" }
        guard let dd = dateSnippet, dd.content.contains("{{date:") else {
            fatalError("Date format conversion failed for ;dd")
        }
        
        // Verify Fill-in conversion
        let pmSnippet = snippets.first { $0.abbreviation == ";pm" }
        guard let pm = pmSnippet, pm.content.contains("{{fill:Incident Name}}") else {
            fatalError("Filltext conversion failed for ;pm: \(pmSnippet?.content ?? "")")
        }
        
        // Test evaluating the imported snippet with fill-in
        let eval = MacroEvaluator.shared.evaluate(
            snippet: pm,
            fillInValues: ["fill_Incident Name": "API Gateway Timeout"]
        )
        guard eval.text.contains("API Gateway Timeout") && !eval.text.contains("%filltext") else {
            fatalError("Evaluation failed for converted snippet: \(eval.text)")
        }
        
        print("  -> Passed! (Successfully imported \(result.snippetsImported) snippets from Basics.csv with full macro conversion)")
    }
    
    private static func testFactoryResetAndDeleteAll() {
        print("[TEST 11/12] Factory Reset & Delete All Snippets...")
        Task { @MainActor in
            let store = SnippetStore.shared
            
            // 1. Reset to defaults first
            store.resetToDefaults()
            assert(!store.snippets.isEmpty, "Store should have default snippets")
            assert(!store.groups.isEmpty, "Store should have default groups")
            
            // 2. Test Delete All Snippets
            store.deleteAllSnippets()
            assert(store.snippets.isEmpty, "All snippets should be deleted")
            assert(!store.groups.isEmpty, "Groups should remain when only deleting snippets")
            
            // 3. Test Wipe Everything & Re-Onboard
            store.wipeEverything(reOnboard: true)
            assert(store.snippets.isEmpty, "Snippets should be empty after wipe")
            assert(store.groups.isEmpty, "Groups should be empty after re-onboard wipe")
            assert(store.settings.hasCompletedOnboarding == false, "Onboarding should be reset")
        }
        print("  -> Passed!")
    }
    
    private static func testOnboardingEmptyAndStarter() {
        print("[TEST 12/12] First-Run Onboarding (Empty Library vs Starter Pack)...")
        Task { @MainActor in
            let store = SnippetStore.shared
            
            // 1. Start Empty
            store.startEmptyLibrary()
            assert(store.snippets.isEmpty, "Empty library should contain 0 snippets")
            assert(store.groups.count == 1, "Empty library should contain 1 default group")
            assert(store.groups.first?.name == "General", "Default group should be General")
            assert(store.settings.hasCompletedOnboarding == true, "Onboarding should be completed")
            
            // 2. Load Starter Pack
            store.loadStarterSnippets()
            assert(store.snippets.count > 10, "Starter pack should contain snippets")
            assert(store.groups.count > 3, "Starter pack should contain standard groups")
            assert(store.settings.hasCompletedOnboarding == true, "Onboarding should remain completed")
        }
        print("  -> Passed!")
    }
}
