import Foundation

public enum MacroFieldType: Equatable, Sendable {
    case date(format: String?, offsetDays: Int, offsetMonths: Int, offsetYears: Int)
    case time(format: String?)
    case fillIn(id: String, label: String, defaultValue: String)
    case multiline(id: String, label: String, defaultValue: String)
    case datePicker(id: String, label: String, format: String, defaultDate: Date)
    case choice(id: String, label: String, options: [String], defaultValue: String)
    case optional(id: String, label: String, content: String, isDefaultChecked: Bool)
    case clipboard
    case cursor
    case key(name: String)
    case nestedSnippet(abbreviation: String)
    case shell(command: String)
    case appleScript(script: String)
}

public struct FillInField: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var type: FieldType
    public var defaultValue: String
    public var options: [String]
    public var optionalContent: String
    public var dateFormat: String
    
    public enum FieldType: String, Sendable {
        case singleLine
        case multiLine
        case datePicker
        case choice
        case optionalSection
    }
    
    public init(
        id: String,
        label: String,
        type: FieldType,
        defaultValue: String = "",
        options: [String] = [],
        optionalContent: String = "",
        dateFormat: String = "yyyy-MM-dd"
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.defaultValue = defaultValue
        self.options = options
        self.optionalContent = optionalContent
        self.dateFormat = dateFormat
    }
}

public struct MacroParseToken: Sendable {
    public enum TokenType: Sendable {
        case literal(String)
        case macro(MacroFieldType)
    }
    public let type: TokenType
    public let originalString: String
}
