import Foundation

public struct DefaultSnippets {
    public static func generateDefaultData() -> (groups: [SnippetGroup], snippets: [Snippet]) {
        let groups = SnippetGroup.defaultGroups
        
        let dateGroup = groups.first { $0.name == "Dates & Times" }!
        let personalGroup = groups.first { $0.name == "Personal & Contact" }!
        let emailGroup = groups.first { $0.name == "Email & Communication" }!
        let codeGroup = groups.first { $0.name == "Code & Development" }!
        let supportGroup = groups.first { $0.name == "Customer Support" }!
        let symbolGroup = groups.first { $0.name == "Symbols & Emojis" }!
        
        var snippets: [Snippet] = []
        
        // Dates & Times
        snippets.append(Snippet(
            title: "Current Date (YYYY-MM-DD)",
            abbreviation: ";date",
            content: "{{date:YYYY-MM-dd}}",
            notes: "Inserts ISO 8601 formatted date",
            groupId: dateGroup.id,
            tags: ["date", "time"]
        ))
        snippets.append(Snippet(
            title: "Current Date (Long Format)",
            abbreviation: ";today",
            content: "{{date:MMMM d, YYYY}}",
            notes: "Inserts full human-readable date",
            groupId: dateGroup.id,
            tags: ["date"]
        ))
        snippets.append(Snippet(
            title: "Current Time",
            abbreviation: ";time",
            content: "{{time:h:mm a}}",
            notes: "Inserts 12-hour formatted time with AM/PM",
            groupId: dateGroup.id,
            tags: ["time"]
        ))
        snippets.append(Snippet(
            title: "Date & Time Timestamp",
            abbreviation: ";now",
            content: "{{date:YYYY-MM-dd}} {{time:HH:mm}}",
            notes: "Quick timestamp for logs or notes",
            groupId: dateGroup.id,
            tags: ["timestamp"]
        ))
        snippets.append(Snippet(
            title: "Tomorrow's Date",
            abbreviation: ";tomorrow",
            content: "{{date:offset=+1d,format=YYYY-MM-dd}}",
            notes: "Calculates tomorrow's date",
            groupId: dateGroup.id,
            tags: ["date", "math"]
        ))
        snippets.append(Snippet(
            title: "One Week From Now",
            abbreviation: ";nextweek",
            content: "{{date:offset=+7d,format=MMMM d, YYYY}}",
            notes: "Calculates the date 7 days ahead",
            groupId: dateGroup.id,
            tags: ["date", "math"]
        ))
        
        // Personal & Contact
        snippets.append(Snippet(
            title: "Email Address",
            abbreviation: ";email",
            content: "andrea@example.com",
            notes: "Primary email address",
            groupId: personalGroup.id,
            tags: ["contact", "personal"],
            isFavorite: true
        ))
        snippets.append(Snippet(
            title: "Phone Number",
            abbreviation: ";phone",
            content: "+1 (555) 234-5678",
            notes: "Work direct phone number",
            groupId: personalGroup.id,
            tags: ["contact"]
        ))
        snippets.append(Snippet(
            title: "Mailing Address",
            abbreviation: ";addr",
            content: "123 Innovation Way, Suite 400\nSan Francisco, CA 94107",
            notes: "Office shipping address",
            groupId: personalGroup.id,
            tags: ["contact"]
        ))
        snippets.append(Snippet(
            title: "Email Signature with Optional Title",
            abbreviation: ";sig",
            content: "Best regards,\nAndrea\n{{opt:Include Title:Senior Software Engineer\n}}Expandi Labs",
            notes: "Standard email signature with configurable title toggle",
            groupId: personalGroup.id,
            tags: ["email", "signature"],
            isFavorite: true
        ))
        
        // Email & Communication
        snippets.append(Snippet(
            title: "Appointment Confirmation (with Date Picker)",
            abbreviation: ";appt",
            content: "Hi {{fill:Client Name}},\n\nYour appointment has been scheduled for {{datepicker:Appointment Date:format=EEEE, MMMM d, yyyy}} at {{choice:Time Slot:9:00 AM,11:30 AM,2:00 PM,4:30 PM:default=2:00 PM}}.\n\n{{opt:Include Location:Location: 123 Innovation Way, Suite 400\n}}Please let us know 24 hours in advance if you need to reschedule.\n\nBest regards,\nExpandi Team",
            notes: "Appointment confirmation with interactive graphical Date Picker, time slot choice, and optional location",
            groupId: emailGroup.id,
            tags: ["email", "appointment", "datepicker"],
            isFavorite: true
        ))
        snippets.append(Snippet(
            title: "Personalized Outreach Email",
            abbreviation: ";intro",
            content: "Hi {{fill:First Name:default=there}},\n\nI hope you're having a productive week! I wanted to follow up regarding {{fill:Subject:default=our project}}.\n\n{{multiline:Notes / Context}}\n\n{{cursor}}\n\nBest regards,\nAndrea",
            notes: "Interactive email template with dynamic fill-in fields",
            groupId: emailGroup.id,
            tags: ["email", "template"],
            isFavorite: true
        ))
        snippets.append(Snippet(
            title: "Meeting Request with Duration Choice",
            abbreviation: ";meeting",
            content: "Hi {{fill:Recipient Name}},\n\nWould you have time for a quick {{choice:Duration:15-minute,30-minute,45-minute:default=30-minute}} call?\n\n- Tomorrow at 2:00 PM\n- {{date:offset=+2d,format=EEEE}} at 10:00 AM\n\nLooking forward to speaking!\n\nBest,\nAndrea",
            notes: "Meeting invitation with dynamic duration picker and date math",
            groupId: emailGroup.id,
            tags: ["meeting", "scheduling"]
        ))
        snippets.append(Snippet(
            title: "Quick Thank You",
            abbreviation: ";thanks",
            content: "Thank you so much for your help with this! Really appreciate your fast turnaround.",
            notes: "Polite gratitude message",
            groupId: emailGroup.id,
            tags: ["email", "quick"]
        ))
        snippets.append(Snippet(
            title: "Follow-up Check-in",
            abbreviation: ";followup",
            content: "Hi {{fill:First Name}},\n\nJust checking in to see if you had a chance to review {{fill:Topic:default=my previous note}}.\n\nLet me know if there's anything else needed from my end!\n\nThanks,\nAndrea",
            notes: "Gentle follow-up message",
            groupId: emailGroup.id,
            tags: ["email"]
        ))
        
        // Customer Support
        snippets.append(Snippet(
            title: "Support Ticket Response",
            abbreviation: ";ticket",
            content: "Hello {{fill:Customer Name}},\n\nThank you for reaching out regarding ticket #{{fill:Ticket Number}}.\n\nI have investigated the issue and {{multiline:Resolution Details}}\n\n{{cursor}}\n\nPlease let us know if you have any questions!\n\nWarm regards,\nExpandi Support Team",
            notes: "Customer support ticket reply with multiline resolution",
            groupId: supportGroup.id,
            tags: ["support", "customer"]
        ))
        snippets.append(Snippet(
            title: "Documentation Link Picker",
            abbreviation: ";docs",
            content: "You can find our guide on {{choice:Topic:Getting Started,Account Setup,Snippets & Shortcuts,Keyboard Navigation,Security & Privacy:default=Snippets & Shortcuts}} in our knowledge base: https://docs.expandi.app",
            notes: "Interactive guide link chooser",
            groupId: supportGroup.id,
            tags: ["support", "docs"]
        ))
        
        // Code & Development
        snippets.append(Snippet(
            title: "Lorem Ipsum Paragraph",
            abbreviation: ";lorem",
            content: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            notes: "Placeholder text",
            groupId: codeGroup.id,
            tags: ["placeholder", "code"]
        ))
        snippets.append(Snippet(
            title: "Markdown Table Template",
            abbreviation: ";table",
            content: "| Column 1 | Column 2 | Column 3 |\n| :--- | :--- | :--- |\n| {{cursor}} |  |  |\n|  |  |  |",
            notes: "3-column Markdown table with cursor ready in first cell",
            groupId: codeGroup.id,
            tags: ["markdown", "table"]
        ))
        snippets.append(Snippet(
            title: "TODO Code Comment",
            abbreviation: ";todo",
            content: "// TODO({{fill:Assignee:default=Andrea}}): {{cursor}}",
            notes: "Standardized code TODO with assignee",
            groupId: codeGroup.id,
            tags: ["code", "comments"]
        ))
        snippets.append(Snippet(
            title: "Paste with Clipboard Wrapper",
            abbreviation: ";clip",
            content: "```\n{{clipboard}}\n```\n{{cursor}}",
            notes: "Wraps current clipboard in Markdown code block",
            groupId: codeGroup.id,
            tags: ["code", "clipboard"]
        ))
        
        // Symbols & Emojis
        snippets.append(Snippet(
            title: "Checkmark",
            abbreviation: ";check",
            content: "✓",
            groupId: symbolGroup.id,
            tags: ["symbol"]
        ))
        snippets.append(Snippet(
            title: "Cross Mark",
            abbreviation: ";cross",
            content: "✗",
            groupId: symbolGroup.id,
            tags: ["symbol"]
        ))
        snippets.append(Snippet(
            title: "Right Arrow",
            abbreviation: ";arrow",
            content: "→",
            groupId: symbolGroup.id,
            tags: ["symbol"]
        ))
        snippets.append(Snippet(
            title: "Bullet Point",
            abbreviation: ";bullet",
            content: "•",
            groupId: symbolGroup.id,
            tags: ["symbol"]
        ))
        snippets.append(Snippet(
            title: "Shrug Emoji",
            abbreviation: ";shrug",
            content: "¯\\_(ツ)_/¯",
            groupId: symbolGroup.id,
            tags: ["emoji"]
        ))
        snippets.append(Snippet(
            title: "Rocket",
            abbreviation: ";rocket",
            content: "🚀",
            groupId: symbolGroup.id,
            tags: ["emoji"]
        ))
        snippets.append(Snippet(
            title: "Fire",
            abbreviation: ";fire",
            content: "🔥",
            groupId: symbolGroup.id,
            tags: ["emoji"]
        ))
        snippets.append(Snippet(
            title: "Red Heart",
            abbreviation: ";heart",
            content: "❤️",
            groupId: symbolGroup.id,
            tags: ["emoji"]
        ))
        
        return (groups, snippets)
    }
}
