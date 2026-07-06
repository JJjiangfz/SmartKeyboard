import Foundation

enum IntentLexicon {
    static let clearPinyinWords: Set<String> = [
        "nihao", "zhongwen", "xiexie", "shenme", "zenme", "weishenme",
        "zhongguo", "hanyu", "pinyin", "qiehuan", "shuru", "yingwen",
        "zhineng", "ceshi", "kaifa", "xiangmu", "wenjian", "xitong",
        "yonghu", "qingwen", "haode", "duide", "bucuo", "jixu",
        "keyi", "meiyou", "buyao", "xihuan", "suoyi", "yinwei",
        "ruguo", "danshi", "zhege", "nage", "dianji", "women",
        "nimen", "tamen", "zamen"
    ]

    static let commonEnglishWords: Set<String> = [
        "about", "after", "again", "also", "and", "app", "apple", "are", "back",
        "build", "button", "case", "change", "chinese", "class", "click", "code",
        "close", "coffee", "command", "config", "control", "copy", "data", "debug",
        "default", "design", "dictionary", "docker", "else", "email", "english",
        "false", "file", "for", "from", "func", "function", "github", "google",
        "hello", "import", "input", "java", "javascript", "json", "keyboard",
        "kotlin", "linux", "main", "manager", "meeting", "menu", "message",
        "microsoft", "model", "name", "object", "offline", "online", "open",
        "openai", "option", "page", "paste", "path", "print", "private",
        "product", "project", "public", "python", "react", "read", "return",
        "review", "rust", "schedule", "screen", "server", "source", "string",
        "struct", "swift", "switch", "terminal", "test", "thanks", "the",
        "this", "today", "tomorrow", "true", "typescript", "update", "user",
        "value", "video", "view", "while", "window", "with", "world", "write"
    ]

    static let ambiguousPinyinEnglishWords: Set<String> = [
        "name"
    ]

    static let englishFragments = [
        "the", "ing", "tion", "ment", "ness", "able", "ough", "ight", "ck",
        "wh", "wr", "th", "qu", "ed", "ly", "er"
    ]

    static let englishStartingClusters = [
        "bl", "br", "cl", "cr", "dr", "fl", "fr", "gl", "gr", "pl",
        "pr", "sk", "sl", "sm", "sn", "sp", "st", "sw", "tr", "tw",
        "wh", "wr"
    ]

    static let englishEndingClusters = [
        "ct", "ft", "ld", "lk", "lm", "lp", "lt", "mp", "nd", "nk",
        "nt", "pt", "rd", "rk", "rn", "rp", "rt", "sk", "sp", "st"
    ]
}
