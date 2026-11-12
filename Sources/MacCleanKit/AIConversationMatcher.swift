import Foundation

public enum AIConversationMatcher {
    private static let conversationPatterns: [String] = [
        "/.gemini/antigravity/conversations",
        "/.gemini/antigravity/brain",
        "/.gemini/antigravity/conversation_summaries",
        "/.gemini/antigravity/annotations",
        "/.gemini/history",
        "/.codex/sessions",
        "/.codex/archived_sessions",
        "/.codex/thread_history",
        "/.claude/projects",
        "/.claude/file-history",
        "/claude-code-sessions"
    ]

    public static func isConversation(path: String) -> Bool {
        let lower: String = path.lowercased()
        for pattern: String in conversationPatterns {
            if lower.contains(pattern) {
                return true
            }
        }
        return false
    }
}
