import Foundation

/// The few pieces of text the keyboard itself shows, per language.
struct LanguageStrings {
    let returnKey: String
    let go: String
    let search: String
    let send: String
    let done: String
    let next: String
}

extension Language {
    var strings: LanguageStrings {
        switch self {
        case .english:
            return LanguageStrings(returnKey: "return", go: "Go", search: "Search",
                                   send: "Send", done: "Done", next: "Next")
        case .hungarian:
            return LanguageStrings(returnKey: "Enter", go: "Mehet", search: "Keresés",
                                   send: "Küldés", done: "Kész", next: "Tovább")
        case .spanish:
            return LanguageStrings(returnKey: "intro", go: "Ir", search: "Buscar",
                                   send: "Enviar", done: "Listo", next: "Siguiente")
        case .french:
            return LanguageStrings(returnKey: "retour", go: "OK", search: "Rechercher",
                                   send: "Envoyer", done: "OK", next: "Suivant")
        case .german:
            return LanguageStrings(returnKey: "Return", go: "Los", search: "Suchen",
                                   send: "Senden", done: "Fertig", next: "Weiter")
        case .italian:
            return LanguageStrings(returnKey: "invio", go: "Vai", search: "Cerca",
                                   send: "Invia", done: "Fine", next: "Avanti")
        case .portuguese:
            return LanguageStrings(returnKey: "retorno", go: "Ir", search: "Buscar",
                                   send: "Enviar", done: "OK", next: "Seguinte")
        case .dutch:
            return LanguageStrings(returnKey: "return", go: "Ga", search: "Zoek",
                                   send: "Stuur", done: "Gereed", next: "Volgende")
        case .polish:
            return LanguageStrings(returnKey: "return", go: "Idź", search: "Szukaj",
                                   send: "Wyślij", done: "Gotowe", next: "Dalej")
        case .czech:
            return LanguageStrings(returnKey: "return", go: "Přejít", search: "Hledat",
                                   send: "Odeslat", done: "Hotovo", next: "Další")
        case .romanian:
            return LanguageStrings(returnKey: "return", go: "Mergi", search: "Caută",
                                   send: "Trimite", done: "Gata", next: "Următorul")
        case .turkish:
            return LanguageStrings(returnKey: "return", go: "Git", search: "Ara",
                                   send: "Gönder", done: "Bitti", next: "İleri")
        case .russian:
            return LanguageStrings(returnKey: "ввод", go: "Перейти", search: "Найти",
                                   send: "Отправить", done: "Готово", next: "Далее")
        case .ukrainian:
            return LanguageStrings(returnKey: "ввід", go: "Перейти", search: "Шукати",
                                   send: "Надіслати", done: "Готово", next: "Далі")
        case .swedish:
            return LanguageStrings(returnKey: "retur", go: "Gå", search: "Sök",
                                   send: "Skicka", done: "Klar", next: "Nästa")
        case .lithuanian:
            return LanguageStrings(returnKey: "grįžti", go: "Eiti", search: "Ieškoti",
                                   send: "Siųsti", done: "Atlikta", next: "Kitas")
        case .uzbek:
            return LanguageStrings(returnKey: "qaytish", go: "Oʻtish", search: "Qidirish",
                                   send: "Yuborish", done: "Tayyor", next: "Keyingi")
        case .latvian:
            return LanguageStrings(returnKey: "atgriezt", go: "Aiziet", search: "Meklēt",
                                   send: "Sūtīt", done: "Gatavs", next: "Tālāk")
        case .cantonese:
            return LanguageStrings(returnKey: "換行", go: "前往", search: "搜尋",
                                   send: "傳送", done: "完成", next: "下一個")
        case .danish:
            return LanguageStrings(returnKey: "retur", go: "Gå", search: "Søg",
                                   send: "Send", done: "OK", next: "Næste")
        case .norwegian:
            return LanguageStrings(returnKey: "retur", go: "Gå", search: "Søk",
                                   send: "Send", done: "Ferdig", next: "Neste")
        case .finnish:
            return LanguageStrings(returnKey: "rivinvaihto", go: "Siirry", search: "Hae",
                                   send: "Lähetä", done: "Valmis", next: "Seuraava")
        case .greek:
            return LanguageStrings(returnKey: "εισαγωγή", go: "Μετάβαση", search: "Αναζήτηση",
                                   send: "Αποστολή", done: "Τέλος", next: "Επόμενο")
        case .hebrew:
            return LanguageStrings(returnKey: "חזרה", go: "מעבר", search: "חיפוש",
                                   send: "שליחה", done: "סיום", next: "הבא")
        case .persian:
            return LanguageStrings(returnKey: "ورود", go: "برو", search: "جستجو",
                                   send: "ارسال", done: "تمام", next: "بعدی")
        case .indonesian:
            return LanguageStrings(returnKey: "enter", go: "Buka", search: "Cari",
                                   send: "Kirim", done: "Selesai", next: "Berikutnya")
        case .malay:
            return LanguageStrings(returnKey: "kembali", go: "Pergi", search: "Cari",
                                   send: "Hantar", done: "Selesai", next: "Seterusnya")
        case .vietnamese:
            return LanguageStrings(returnKey: "xuống dòng", go: "Đi", search: "Tìm",
                                   send: "Gửi", done: "Xong", next: "Tiếp")
        case .slovak:
            return LanguageStrings(returnKey: "enter", go: "Prejsť", search: "Hľadať",
                                   send: "Odoslať", done: "Hotovo", next: "Ďalej")
        case .croatian:
            return LanguageStrings(returnKey: "povrat", go: "Idi", search: "Traži",
                                   send: "Pošalji", done: "Gotovo", next: "Dalje")
        case .bulgarian:
            return LanguageStrings(returnKey: "нов ред", go: "Отиди", search: "Търсене",
                                   send: "Изпрати", done: "Готово", next: "Напред")
        case .catalan:
            return LanguageStrings(returnKey: "retorn", go: "Ves", search: "Cerca",
                                   send: "Envia", done: "Fet", next: "Següent")
        case .mandarin:
            return LanguageStrings(returnKey: "换行", go: "前往", search: "搜索",
                                   send: "发送", done: "完成", next: "下一项")
        case .japanese:
            return LanguageStrings(returnKey: "改行", go: "開く", search: "検索",
                                   send: "送信", done: "完了", next: "次へ")
        case .korean:
            return LanguageStrings(returnKey: "줄바꿈", go: "이동", search: "검색",
                                   send: "보내기", done: "완료", next: "다음")
        case .hindi:
            return LanguageStrings(returnKey: "एंटर", go: "जाएँ", search: "खोजें",
                                   send: "भेजें", done: "हो गया", next: "अगला")
        case .thai:
            return LanguageStrings(returnKey: "ขึ้นบรรทัด", go: "ไป", search: "ค้นหา",
                                   send: "ส่ง", done: "เสร็จ", next: "ถัดไป")
        case .arabic:
            return LanguageStrings(returnKey: "إدخال", go: "انتقال", search: "بحث",
                                   send: "إرسال", done: "تم", next: "التالي")
        }
    }
}
