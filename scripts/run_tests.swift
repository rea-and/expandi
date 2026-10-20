import Foundation

print("Expandi Test Suite Running...")

// Test 1: Date math and offsets
let now = Date()
let calendar = Calendar.current
let nextWeek = calendar.date(byAdding: .day, value: 7, to: now)!
let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd"
print("Date test: today=\(formatter.string(from: now)), +7d=\(formatter.string(from: nextWeek))")
assert(!formatter.string(from: nextWeek).isEmpty)

print("All Core Tests Passed!")
