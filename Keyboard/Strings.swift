import Foundation

/// The few pieces of text the keyboard itself shows, per language.
struct LanguageStrings {
    let searchEmoji: String
    let recentlyUsed: String
    let loadingEmoji: String
    let emptyRecents: String
    let returnKey: String
    let go: String
    let search: String
    let send: String
    let done: String
    let next: String
    /// smileys, animals, food, activity, travel, objects, symbols, flags
    let categories: [String]

    func categoryTitle(_ key: String) -> String? {
        let keys = ["smileys", "animals", "food", "activity", "travel", "objects", "symbols", "flags"]
        guard let index = keys.firstIndex(of: key), index < categories.count else { return nil }
        return categories[index]
    }
}

extension Language {
    var strings: LanguageStrings {
        switch self {
        case .english:
            return LanguageStrings(searchEmoji: "Search Emoji", recentlyUsed: "Recently Used", loadingEmoji: "Loading emoji…",
                                   emptyRecents: "Emoji you use will show up here.", returnKey: "return", go: "Go", search: "Search",
                                   send: "Send", done: "Done", next: "Next",
                                   categories: ["Smileys & People", "Animals & Nature", "Food & Drink", "Activity", "Travel & Places", "Objects", "Symbols", "Flags"])
        case .hungarian:
            return LanguageStrings(searchEmoji: "Emoji keresése", recentlyUsed: "Legutóbb használt", loadingEmoji: "Emoji betöltése…",
                                   emptyRecents: "A legutóbb használt emojik itt jelennek meg.", returnKey: "Enter", go: "Mehet", search: "Keresés",
                                   send: "Küldés", done: "Kész", next: "Tovább",
                                   categories: ["Mosolygók és emberek", "Állatok és természet", "Étel és ital", "Tevékenység", "Utazás és helyek", "Tárgyak", "Szimbólumok", "Zászlók"])
        case .spanish:
            return LanguageStrings(searchEmoji: "Buscar emoji", recentlyUsed: "Usados recientemente", loadingEmoji: "Cargando emojis…",
                                   emptyRecents: "Los emojis que uses aparecerán aquí.", returnKey: "intro", go: "Ir", search: "Buscar",
                                   send: "Enviar", done: "Listo", next: "Siguiente",
                                   categories: ["Emojis y personas", "Animales y naturaleza", "Comida y bebida", "Actividades", "Viajes y lugares", "Objetos", "Símbolos", "Banderas"])
        case .french:
            return LanguageStrings(searchEmoji: "Rechercher un emoji", recentlyUsed: "Récents", loadingEmoji: "Chargement des emojis…",
                                   emptyRecents: "Vos emojis récents apparaîtront ici.", returnKey: "retour", go: "OK", search: "Rechercher",
                                   send: "Envoyer", done: "OK", next: "Suivant",
                                   categories: ["Smileys et personnes", "Animaux et nature", "Nourriture et boissons", "Activités", "Voyages et lieux", "Objets", "Symboles", "Drapeaux"])
        case .german:
            return LanguageStrings(searchEmoji: "Emoji suchen", recentlyUsed: "Häufig verwendet", loadingEmoji: "Emojis werden geladen…",
                                   emptyRecents: "Verwendete Emojis erscheinen hier.", returnKey: "Return", go: "Los", search: "Suchen",
                                   send: "Senden", done: "Fertig", next: "Weiter",
                                   categories: ["Smileys & Personen", "Tiere & Natur", "Essen & Trinken", "Aktivitäten", "Reisen & Orte", "Objekte", "Symbole", "Flaggen"])
        case .italian:
            return LanguageStrings(searchEmoji: "Cerca emoji", recentlyUsed: "Usate di recente", loadingEmoji: "Caricamento emoji…",
                                   emptyRecents: "Le emoji che usi appariranno qui.", returnKey: "invio", go: "Vai", search: "Cerca",
                                   send: "Invia", done: "Fine", next: "Avanti",
                                   categories: ["Faccine e persone", "Animali e natura", "Cibo e bevande", "Attività", "Viaggi e luoghi", "Oggetti", "Simboli", "Bandiere"])
        case .portuguese:
            return LanguageStrings(searchEmoji: "Buscar emoji", recentlyUsed: "Usados recentemente", loadingEmoji: "Carregando emojis…",
                                   emptyRecents: "Os emojis que você usar aparecerão aqui.", returnKey: "retorno", go: "Ir", search: "Buscar",
                                   send: "Enviar", done: "OK", next: "Seguinte",
                                   categories: ["Carinhas e pessoas", "Animais e natureza", "Comidas e bebidas", "Atividades", "Viagens e lugares", "Objetos", "Símbolos", "Bandeiras"])
        case .dutch:
            return LanguageStrings(searchEmoji: "Zoek emoji", recentlyUsed: "Veelgebruikt", loadingEmoji: "Emoji laden…",
                                   emptyRecents: "Emoji die je gebruikt verschijnen hier.", returnKey: "return", go: "Ga", search: "Zoek",
                                   send: "Stuur", done: "Gereed", next: "Volgende",
                                   categories: ["Smileys en personen", "Dieren en natuur", "Eten en drinken", "Activiteiten", "Reizen en plaatsen", "Objecten", "Symbolen", "Vlaggen"])
        case .polish:
            return LanguageStrings(searchEmoji: "Szukaj emoji", recentlyUsed: "Ostatnio używane", loadingEmoji: "Wczytywanie emoji…",
                                   emptyRecents: "Używane emoji pojawią się tutaj.", returnKey: "return", go: "Idź", search: "Szukaj",
                                   send: "Wyślij", done: "Gotowe", next: "Dalej",
                                   categories: ["Buźki i ludzie", "Zwierzęta i natura", "Jedzenie i picie", "Aktywności", "Podróże i miejsca", "Obiekty", "Symbole", "Flagi"])
        case .czech:
            return LanguageStrings(searchEmoji: "Hledat emoji", recentlyUsed: "Nedávno použité", loadingEmoji: "Načítání emoji…",
                                   emptyRecents: "Použitá emoji se zobrazí zde.", returnKey: "return", go: "Přejít", search: "Hledat",
                                   send: "Odeslat", done: "Hotovo", next: "Další",
                                   categories: ["Smajlíci a lidé", "Zvířata a příroda", "Jídlo a pití", "Aktivity", "Cestování a místa", "Předměty", "Symboly", "Vlajky"])
        case .romanian:
            return LanguageStrings(searchEmoji: "Caută emoji", recentlyUsed: "Folosite recent", loadingEmoji: "Se încarcă emoji…",
                                   emptyRecents: "Emoji-urile folosite vor apărea aici.", returnKey: "return", go: "Mergi", search: "Caută",
                                   send: "Trimite", done: "Gata", next: "Următorul",
                                   categories: ["Fețe și persoane", "Animale și natură", "Mâncare și băutură", "Activități", "Călătorii și locuri", "Obiecte", "Simboluri", "Steaguri"])
        case .turkish:
            return LanguageStrings(searchEmoji: "Emoji Ara", recentlyUsed: "Son Kullanılanlar", loadingEmoji: "Emoji yükleniyor…",
                                   emptyRecents: "Kullandığınız emojiler burada görünür.", returnKey: "return", go: "Git", search: "Ara",
                                   send: "Gönder", done: "Bitti", next: "İleri",
                                   categories: ["Suratlar ve insanlar", "Hayvanlar ve doğa", "Yiyecek ve içecek", "Aktivite", "Seyahat ve yerler", "Nesneler", "Semboller", "Bayraklar"])
        case .russian:
            return LanguageStrings(searchEmoji: "Поиск эмодзи", recentlyUsed: "Недавние", loadingEmoji: "Загрузка эмодзи…",
                                   emptyRecents: "Здесь появятся использованные эмодзи.", returnKey: "ввод", go: "Перейти", search: "Найти",
                                   send: "Отправить", done: "Готово", next: "Далее",
                                   categories: ["Смайлики и люди", "Животные и природа", "Еда и напитки", "Активность", "Путешествия и места", "Предметы", "Символы", "Флаги"])
        case .ukrainian:
            return LanguageStrings(searchEmoji: "Пошук емодзі", recentlyUsed: "Нещодавні", loadingEmoji: "Завантаження емодзі…",
                                   emptyRecents: "Тут з’являться використані емодзі.", returnKey: "ввід", go: "Перейти", search: "Шукати",
                                   send: "Надіслати", done: "Готово", next: "Далі",
                                   categories: ["Смайли та люди", "Тварини та природа", "Їжа та напої", "Активність", "Подорожі та місця", "Об’єкти", "Символи", "Прапори"])
        case .swedish:
            return LanguageStrings(searchEmoji: "Sök emoji", recentlyUsed: "Senast använda", loadingEmoji: "Läser in emoji…",
                                   emptyRecents: "Emojis du använder visas här.", returnKey: "retur", go: "Gå", search: "Sök",
                                   send: "Skicka", done: "Klar", next: "Nästa",
                                   categories: ["Smileys och personer", "Djur och natur", "Mat och dryck", "Aktiviteter", "Resor och platser", "Objekt", "Symboler", "Flaggor"])
        case .lithuanian:
            return LanguageStrings(searchEmoji: "Ieškoti jaustukų", recentlyUsed: "Neseniai naudoti", loadingEmoji: "Įkeliami jaustukai…",
                                   emptyRecents: "Čia bus rodomi jūsų naudoti jaustukai.", returnKey: "grįžti", go: "Eiti", search: "Ieškoti",
                                   send: "Siųsti", done: "Atlikta", next: "Kitas",
                                   categories: ["Šypsenėlės ir žmonės", "Gyvūnai ir gamta", "Maistas ir gėrimai", "Veikla", "Kelionės ir vietos", "Objektai", "Simboliai", "Vėliavos"])
        case .arabic:
            return LanguageStrings(searchEmoji: "البحث عن رموز تعبيرية", recentlyUsed: "المستخدمة مؤخرًا", loadingEmoji: "جارٍ تحميل الرموز…",
                                   emptyRecents: "ستظهر هنا الرموز التعبيرية التي تستخدمها.", returnKey: "إدخال", go: "انتقال", search: "بحث",
                                   send: "إرسال", done: "تم", next: "التالي",
                                   categories: ["الوجوه والأشخاص", "الحيوانات والطبيعة", "الطعام والشراب", "الأنشطة", "السفر والأماكن", "الأشياء", "الرموز", "الأعلام"])
        }
    }
}

extension Language {
    /// Name of the separate "People" tab (the other category names come from `LanguageStrings.categories`).
    var peopleCategoryTitle: String {
        switch self {
        case .english: return "People"
        case .hungarian: return "Emberek"
        case .spanish: return "Personas"
        case .french: return "Personnes"
        case .german: return "Personen"
        case .italian: return "Persone"
        case .portuguese: return "Pessoas"
        case .dutch: return "Mensen"
        case .polish: return "Ludzie"
        case .czech: return "Lidé"
        case .romanian: return "Oameni"
        case .turkish: return "İnsanlar"
        case .russian: return "Люди"
        case .ukrainian: return "Люди"
        case .swedish: return "Personer"
        case .lithuanian: return "Žmonės"
        case .arabic: return "الأشخاص"
        }
    }
}
