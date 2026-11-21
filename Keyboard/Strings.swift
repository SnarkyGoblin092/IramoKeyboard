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
        case .uzbek:
            return LanguageStrings(searchEmoji: "Emoji qidirish", recentlyUsed: "Yaqinda ishlatilgan", loadingEmoji: "Emoji yuklanmoqda…",
                                   emptyRecents: "Siz ishlatgan emojilar shu yerda koʻrinadi.", returnKey: "qaytish", go: "Oʻtish", search: "Qidirish",
                                   send: "Yuborish", done: "Tayyor", next: "Keyingi",
                                   categories: ["Smayllar va odamlar", "Hayvonlar va tabiat", "Taom va ichimliklar", "Faoliyat", "Sayohat va joylar", "Buyumlar", "Belgilar", "Bayroqlar"])
        case .latvian:
            return LanguageStrings(searchEmoji: "Meklēt emocijzīmes", recentlyUsed: "Nesen lietotās", loadingEmoji: "Ielādē emocijzīmes…",
                                   emptyRecents: "Šeit būs redzamas jūsu lietotās emocijzīmes.", returnKey: "atgriezt", go: "Aiziet", search: "Meklēt",
                                   send: "Sūtīt", done: "Gatavs", next: "Tālāk",
                                   categories: ["Smaidiņi un cilvēki", "Dzīvnieki un daba", "Ēdieni un dzērieni", "Aktivitātes", "Ceļojumi un vietas", "Objekti", "Simboli", "Karogi"])
        case .cantonese:
            return LanguageStrings(searchEmoji: "搜尋表情符號", recentlyUsed: "最近使用", loadingEmoji: "正在載入表情符號…",
                                   emptyRecents: "你用過嘅表情符號會喺呢度出現。", returnKey: "換行", go: "前往", search: "搜尋",
                                   send: "傳送", done: "完成", next: "下一個",
                                   categories: ["笑臉同人物", "動物同大自然", "食物同飲品", "活動", "旅遊同地點", "物件", "符號", "旗幟"])
        case .danish:
            return LanguageStrings(searchEmoji: "Søg efter emoji", recentlyUsed: "Senest brugt", loadingEmoji: "Indlæser emoji…",
                                   emptyRecents: "Emoji, du bruger, vises her.", returnKey: "retur", go: "Gå", search: "Søg",
                                   send: "Send", done: "OK", next: "Næste",
                                   categories: ["Smileys og personer", "Dyr og natur", "Mad og drikke", "Aktivitet", "Rejser og steder", "Objekter", "Symboler", "Flag"])
        case .norwegian:
            return LanguageStrings(searchEmoji: "Søk etter emoji", recentlyUsed: "Nylig brukt", loadingEmoji: "Laster inn emoji…",
                                   emptyRecents: "Emojier du bruker, vises her.", returnKey: "retur", go: "Gå", search: "Søk",
                                   send: "Send", done: "Ferdig", next: "Neste",
                                   categories: ["Smilefjes og personer", "Dyr og natur", "Mat og drikke", "Aktivitet", "Reise og steder", "Objekter", "Symboler", "Flagg"])
        case .finnish:
            return LanguageStrings(searchEmoji: "Etsi emojia", recentlyUsed: "Viimeksi käytetyt", loadingEmoji: "Ladataan emojeja…",
                                   emptyRecents: "Käyttämäsi emojit näkyvät tässä.", returnKey: "rivinvaihto", go: "Siirry", search: "Hae",
                                   send: "Lähetä", done: "Valmis", next: "Seuraava",
                                   categories: ["Hymiöt ja ihmiset", "Eläimet ja luonto", "Ruoka ja juoma", "Aktiviteetit", "Matkailu ja paikat", "Esineet", "Symbolit", "Liput"])
        case .greek:
            return LanguageStrings(searchEmoji: "Αναζήτηση emoji", recentlyUsed: "Πρόσφατα", loadingEmoji: "Φόρτωση emoji…",
                                   emptyRecents: "Τα emoji που χρησιμοποιείτε θα εμφανίζονται εδώ.", returnKey: "εισαγωγή", go: "Μετάβαση", search: "Αναζήτηση",
                                   send: "Αποστολή", done: "Τέλος", next: "Επόμενο",
                                   categories: ["Φατσούλες και άνθρωποι", "Ζώα και φύση", "Φαγητό και ποτό", "Δραστηριότητες", "Ταξίδια και μέρη", "Αντικείμενα", "Σύμβολα", "Σημαίες"])
        case .hebrew:
            return LanguageStrings(searchEmoji: "חיפוש אמוג׳י", recentlyUsed: "בשימוש לאחרונה", loadingEmoji: "טוען אמוג׳י…",
                                   emptyRecents: "אמוג׳י שבהם תשתמשו יופיעו כאן.", returnKey: "חזרה", go: "מעבר", search: "חיפוש",
                                   send: "שליחה", done: "סיום", next: "הבא",
                                   categories: ["פרצופים ואנשים", "בעלי חיים וטבע", "אוכל ושתייה", "פעילויות", "נסיעות ומקומות", "חפצים", "סמלים", "דגלים"])
        case .persian:
            return LanguageStrings(searchEmoji: "جستجوی اموجی", recentlyUsed: "اخیراً استفاده‌شده", loadingEmoji: "در حال بارگیری اموجی…",
                                   emptyRecents: "اموجی‌هایی که استفاده می‌کنید اینجا نمایش داده می‌شوند.", returnKey: "ورود", go: "برو", search: "جستجو",
                                   send: "ارسال", done: "تمام", next: "بعدی",
                                   categories: ["شکلک‌ها و افراد", "حیوانات و طبیعت", "غذا و نوشیدنی", "فعالیت‌ها", "سفر و مکان‌ها", "اشیا", "نمادها", "پرچم‌ها"])
        case .indonesian:
            return LanguageStrings(searchEmoji: "Cari Emoji", recentlyUsed: "Baru Digunakan", loadingEmoji: "Memuat emoji…",
                                   emptyRecents: "Emoji yang Anda gunakan akan muncul di sini.", returnKey: "enter", go: "Buka", search: "Cari",
                                   send: "Kirim", done: "Selesai", next: "Berikutnya",
                                   categories: ["Smiley & Orang", "Hewan & Alam", "Makanan & Minuman", "Aktivitas", "Perjalanan & Tempat", "Objek", "Simbol", "Bendera"])
        case .malay:
            return LanguageStrings(searchEmoji: "Cari Emoji", recentlyUsed: "Digunakan Baru-baru Ini", loadingEmoji: "Memuatkan emoji…",
                                   emptyRecents: "Emoji yang anda gunakan akan dipaparkan di sini.", returnKey: "kembali", go: "Pergi", search: "Cari",
                                   send: "Hantar", done: "Selesai", next: "Seterusnya",
                                   categories: ["Smiley & Orang", "Haiwan & Alam Semula Jadi", "Makanan & Minuman", "Aktiviti", "Perjalanan & Tempat", "Objek", "Simbol", "Bendera"])
        case .vietnamese:
            return LanguageStrings(searchEmoji: "Tìm biểu tượng", recentlyUsed: "Dùng gần đây", loadingEmoji: "Đang tải biểu tượng…",
                                   emptyRecents: "Biểu tượng cảm xúc bạn dùng sẽ hiện ở đây.", returnKey: "xuống dòng", go: "Đi", search: "Tìm",
                                   send: "Gửi", done: "Xong", next: "Tiếp",
                                   categories: ["Mặt cười & Con người", "Động vật & Thiên nhiên", "Đồ ăn & Thức uống", "Hoạt động", "Du lịch & Địa điểm", "Đồ vật", "Ký hiệu", "Cờ"])
        case .slovak:
            return LanguageStrings(searchEmoji: "Hľadať emoji", recentlyUsed: "Nedávno použité", loadingEmoji: "Načítavajú sa emoji…",
                                   emptyRecents: "Tu sa zobrazia emoji, ktoré používate.", returnKey: "enter", go: "Prejsť", search: "Hľadať",
                                   send: "Odoslať", done: "Hotovo", next: "Ďalej",
                                   categories: ["Smajlíky a ľudia", "Zvieratá a príroda", "Jedlo a pitie", "Aktivity", "Cestovanie a miesta", "Objekty", "Symboly", "Vlajky"])
        case .croatian:
            return LanguageStrings(searchEmoji: "Traži emoji", recentlyUsed: "Nedavno korišteno", loadingEmoji: "Učitavanje emojija…",
                                   emptyRecents: "Ovdje će se prikazati emojiji koje koristite.", returnKey: "povrat", go: "Idi", search: "Traži",
                                   send: "Pošalji", done: "Gotovo", next: "Dalje",
                                   categories: ["Smajlići i ljudi", "Životinje i priroda", "Hrana i piće", "Aktivnosti", "Putovanja i mjesta", "Predmeti", "Simboli", "Zastave"])
        case .bulgarian:
            return LanguageStrings(searchEmoji: "Търсене на емоджи", recentlyUsed: "Наскоро използвани", loadingEmoji: "Зареждане на емоджи…",
                                   emptyRecents: "Тук ще се показват емоджитата, които използвате.", returnKey: "нов ред", go: "Отиди", search: "Търсене",
                                   send: "Изпрати", done: "Готово", next: "Напред",
                                   categories: ["Емотикони и хора", "Животни и природа", "Храна и напитки", "Дейности", "Пътуване и места", "Предмети", "Символи", "Знамена"])
        case .catalan:
            return LanguageStrings(searchEmoji: "Cerca emojis", recentlyUsed: "Usats recentment", loadingEmoji: "Carregant emojis…",
                                   emptyRecents: "Aquí apareixeran els emojis que facis servir.", returnKey: "retorn", go: "Ves", search: "Cerca",
                                   send: "Envia", done: "Fet", next: "Següent",
                                   categories: ["Cares i persones", "Animals i natura", "Menjar i beure", "Activitats", "Viatges i llocs", "Objectes", "Símbols", "Banderes"])
        case .mandarin:
            return LanguageStrings(searchEmoji: "搜索表情符号", recentlyUsed: "最近使用", loadingEmoji: "正在载入表情符号…",
                                   emptyRecents: "你使用过的表情符号会显示在这里。", returnKey: "换行", go: "前往", search: "搜索",
                                   send: "发送", done: "完成", next: "下一项",
                                   categories: ["笑脸和人物", "动物和自然", "食物和饮料", "活动", "旅行和地点", "物体", "符号", "旗帜"])
        case .japanese:
            return LanguageStrings(searchEmoji: "絵文字を検索", recentlyUsed: "最近使った項目", loadingEmoji: "絵文字を読み込み中…",
                                   emptyRecents: "使った絵文字がここに表示されます。", returnKey: "改行", go: "開く", search: "検索",
                                   send: "送信", done: "完了", next: "次へ",
                                   categories: ["スマイリーと人々", "動物と自然", "食べ物と飲み物", "アクティビティ", "旅行と地域", "物", "記号", "旗"])
        case .korean:
            return LanguageStrings(searchEmoji: "이모티콘 검색", recentlyUsed: "최근 사용", loadingEmoji: "이모티콘 불러오는 중…",
                                   emptyRecents: "사용한 이모티콘이 여기에 표시됩니다.", returnKey: "줄바꿈", go: "이동", search: "검색",
                                   send: "보내기", done: "완료", next: "다음",
                                   categories: ["스마일리 및 사람", "동물 및 자연", "음식 및 음료", "활동", "여행 및 장소", "사물", "기호", "깃발"])
        case .hindi:
            return LanguageStrings(searchEmoji: "इमोजी खोजें", recentlyUsed: "हाल ही में उपयोग किए गए", loadingEmoji: "इमोजी लोड हो रहे हैं…",
                                   emptyRecents: "आपके उपयोग किए गए इमोजी यहाँ दिखेंगे।", returnKey: "एंटर", go: "जाएँ", search: "खोजें",
                                   send: "भेजें", done: "हो गया", next: "अगला",
                                   categories: ["स्माइली और लोग", "जानवर और प्रकृति", "खाना और पेय", "गतिविधि", "यात्रा और स्थान", "वस्तुएँ", "प्रतीक", "झंडे"])
        case .thai:
            return LanguageStrings(searchEmoji: "ค้นหาอีโมจิ", recentlyUsed: "ใช้ล่าสุด", loadingEmoji: "กำลังโหลดอีโมจิ…",
                                   emptyRecents: "อีโมจิที่คุณใช้จะแสดงที่นี่", returnKey: "ขึ้นบรรทัด", go: "ไป", search: "ค้นหา",
                                   send: "ส่ง", done: "เสร็จ", next: "ถัดไป",
                                   categories: ["หน้ายิ้มและผู้คน", "สัตว์และธรรมชาติ", "อาหารและเครื่องดื่ม", "กิจกรรม", "การเดินทางและสถานที่", "วัตถุ", "สัญลักษณ์", "ธง"])
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
        case .latvian: return "Cilvēki"
        case .uzbek: return "Odamlar"
        case .arabic: return "الأشخاص"
        case .cantonese: return "人物"
        case .danish: return "Personer"
        case .norwegian: return "Personer"
        case .finnish: return "Ihmiset"
        case .greek: return "Άνθρωποι"
        case .hebrew: return "אנשים"
        case .persian: return "افراد"
        case .indonesian: return "Orang"
        case .malay: return "Orang"
        case .vietnamese: return "Con người"
        case .slovak: return "Ľudia"
        case .croatian: return "Ljudi"
        case .bulgarian: return "Хора"
        case .catalan: return "Persones"
        case .mandarin: return "人物"
        case .japanese: return "人々"
        case .korean: return "사람"
        case .hindi: return "लोग"
        case .thai: return "ผู้คน"
        }
    }
}
