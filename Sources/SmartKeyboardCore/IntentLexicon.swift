import Foundation

enum IntentLexicon {
    static let clearPinyinWords: Set<String> = [
        "nihao", "zhongwen", "xiexie", "shenme", "zenme", "weishenme",
        "zhongguo", "hanyu", "pinyin", "qiehuan", "shuru", "yingwen",
        "zhineng", "ceshi", "kaifa", "xiangmu", "wenjian", "xitong",
        "yonghu", "qingwen", "haode", "duide", "bucuo", "jixu",
        "keyi", "meiyou", "buyao", "xihuan", "suoyi", "yinwei",
        "ruguo", "danshi", "zhege", "nage", "dianji", "women",
        "nimen", "tamen", "zamen", "mama", "baba", "laoshi",
        "pengyou", "tongxue", "gongsi", "xianzai", "jintian",
        "mingtian", "gongzuo", "xuexi", "shijian", "wenti",
        "qingchu", "zhidao", "xiangyao", "kaishi", "jieshu",
        "baocun", "chongxin", "fangfa", "wenben", "buxing"
    ]

    static let commonEnglishWords: Set<String> = [
        "about", "after", "again", "also", "and", "answer", "anything", "app",
        "apple", "application", "are", "automatic", "back", "because", "before",
        "better", "between", "browser", "build", "button", "case", "casual",
        "change", "chinese", "chrome", "class", "click", "close", "code",
        "coffee", "command", "computer", "config", "control", "convert", "copy",
        "create", "cursor", "data", "database", "debug", "default", "delete",
        "design", "dictionary", "different", "docker", "document", "else",
        "email", "english", "example", "false", "feature", "file", "final",
        "for", "from", "func", "function", "github", "google", "hardware",
        "hello", "important", "import", "input", "internet", "java", "javascript",
        "json", "keyboard", "kotlin", "language", "linux", "main", "manager",
        "meeting", "menu", "message", "microsoft", "model", "name", "native",
        "network", "normal", "object", "office", "offline", "online", "open",
        "openai", "option", "page", "paste", "path", "performance", "plugin",
        "possible", "print", "private", "problem", "product", "project", "public",
        "python", "quality", "question", "random", "react", "read", "really",
        "recognize", "return", "review", "rust", "schedule", "screen", "search",
        "sentence", "server", "simple", "software", "solution", "something",
        "source", "string", "struct", "swift", "switch", "system", "terminal",
        "test", "thanks", "the", "this", "today", "tomorrow", "translate", "true",
        "typescript", "typing", "update", "user", "value", "video", "view",
        "wechat", "while", "window", "with", "words", "world", "write"
    ]

    static let ambiguousPinyinEnglishWords: Set<String> = [
        "can", "fan", "lang", "long", "man", "name", "pan", "tan", "wan"
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
