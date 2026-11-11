import SwiftUI

/// One piece of third-party material the app ships, with its credit and licence.
struct LicenseItem: Identifiable {
    let name: String
    /// Who made it, and what the app uses it for.
    let credit: String
    let licenseName: String
    let source: String
    /// The licence text shown in full (MIT, OFL, Unicode), or a notice with a link (Creative Commons).
    let text: String

    var id: String { return name }
}

/// The app's copyright, and credits and licences for the word data, emoji data and icons (several of these
/// licences require the notice to ship with the app).
struct LicensesView: View {
    var body: some View {
        GlassList {
            Section {
                Text(tr("Iramo. Copyright © 2026 Orsós Emil. All rights reserved.")).glassRows()
            } footer: {
                Text(tr("The third-party material below keeps its own licences."))
            }
            Section {
                ForEach(Licenses.data) { item in row(item) }.glassRows()
            } header: {
                Text(tr("Words and emoji"))
            } footer: {
                Text(tr("The keyboard's dictionaries are adapted from FrequencyWords and are shared under the same licence, CC BY-SA 4.0."))
            }
            Section(tr("Emoji tab icons")) {
                ForEach(Licenses.icons) { item in row(item) }.glassRows()
            }
        }
        .glassScreen()
        .navigationTitle(tr("Licences"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ item: LicenseItem) -> some View {
        NavigationLink {
            LicenseDetailView(item: item)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                    Text(item.licenseName).font(.footnote).foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
                Spacer()
                DisclosureChevron()
            }
            .contentShape(Rectangle())
            .waveSource()
        }
    }
}

private struct LicenseDetailView: View {
    let item: LicenseItem

    var body: some View {
        GlassList {
            Section {
                Text(item.credit).glassRows()
                if let url = URL(string: item.source) {
                    Link(item.source, destination: url).font(.footnote).glassRows()
                }
            }
            Section(item.licenseName) {
                Text(item.text)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .glassRows()
            }
        }
        .glassScreen()
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum Licenses {
    static let data: [LicenseItem] = [
        LicenseItem(
            name: "FrequencyWords",
            credit: "Word frequency lists by Hermit Dave, made from the OpenSubtitles 2018 corpus. The keyboard's "
                + "dictionaries are built from them.",
            licenseName: "CC BY-SA 4.0",
            source: "https://github.com/hermitdave/FrequencyWords",
            text: creativeCommons("Attribution-ShareAlike 4.0 International", "https://creativecommons.org/licenses/by-sa/4.0/")),
        LicenseItem(
            name: "Tatoeba",
            credit: "Example sentences by the Tatoeba contributors, used for word pairs and next-word suggestions.",
            licenseName: "CC BY 2.0 FR",
            source: "https://tatoeba.org",
            text: creativeCommons("Attribution 2.0 France", "https://creativecommons.org/licenses/by/2.0/fr/")),
        LicenseItem(
            name: "OpenSubtitles corpus",
            credit: "Word sequence statistics for next-word suggestions are counted from the OpenSubtitles 2018 "
                + "corpus of OPUS (P. Lison and J. Tiedemann, 2016, \"OpenSubtitles2016: Extracting Large Parallel "
                + "Corpora from Movie and TV Subtitles\", LREC 2016), compiled from opensubtitles.org.",
            licenseName: "Corpus credit",
            source: "https://opus.nlpl.eu/",
            text: "No subtitle text is included in the app; only counts of which words follow which."),
        LicenseItem(
            name: "CC-CEDICT",
            credit: "Chinese words in simplified characters with their Pinyin, from the community-maintained "
                + "CC-CEDICT dictionary published by MDBG (based on CEDICT by Paul Andrew Denisowski). The "
                + "Mandarin dictionary is built from it, ranked by the FrequencyWords Chinese word counts, and is "
                + "shared under the same licence.",
            licenseName: "CC BY-SA 4.0",
            source: "https://www.mdbg.net/chinese/dictionary?page=cc-cedict",
            text: creativeCommons("Attribution-ShareAlike 4.0 International", "https://creativecommons.org/licenses/by-sa/4.0/")),
        LicenseItem(
            name: "JMdict",
            credit: "Japanese words with their readings, from the JMdict dictionary files, the property of the "
                + "Electronic Dictionary Research and Development Group (EDRDG), used in conformance with the "
                + "Group's licence. The Japanese dictionary is built from them and is shared under the same licence.",
            licenseName: "CC BY-SA 4.0",
            source: "https://www.edrdg.org/edrdg/licence.html",
            text: creativeCommons("Attribution-ShareAlike 4.0 International", "https://creativecommons.org/licenses/by-sa/4.0/")),
        LicenseItem(
            name: "rime-cantonese",
            credit: "Cantonese characters and words with their Jyutping, and how often they are used, by the "
                + "Cantonese Computational Linguistics Infrastructure Development Workgroup (CanCLID). The "
                + "Cantonese dictionary is built from them.",
            licenseName: "CC BY 4.0",
            source: "https://github.com/rime/rime-cantonese",
            text: creativeCommons("Attribution 4.0 International", "https://creativecommons.org/licenses/by/4.0/")),
        LicenseItem(
            name: "Unicode emoji data and CLDR",
            credit: "The emoji list (emoji-test.txt) and the emoji names and keywords used for search and "
                + "suggestions (CLDR annotations), by Unicode, Inc.",
            licenseName: "Unicode License V3",
            source: "https://www.unicode.org/license.txt",
            text: unicodeLicense),
    ]

    static let icons: [LicenseItem] = [
        LicenseItem(name: "Codicons", credit: "Smiley icon (emoji key), by Microsoft Corporation.",
                    licenseName: "CC BY 4.0", source: "https://github.com/microsoft/vscode-codicons",
                    text: creativeCommons("Attribution 4.0 International", "https://creativecommons.org/licenses/by/4.0/")),
    ]

    private static func creativeCommons(_ title: String, _ url: String) -> String {
        return "Licensed under the Creative Commons \(title) licence. The full licence text is at \(url)\n\n"
            + "The material is shown here as converted for the keyboard (resized, reformatted or counted); "
            + "the original is available from the source above."
    }

    private static let unicodeLicense = """
    UNICODE LICENSE V3

    COPYRIGHT AND PERMISSION NOTICE

    Copyright © 1991-2026 Unicode, Inc.

    NOTICE TO USER: Carefully read the following legal agreement. BY DOWNLOADING, INSTALLING, COPYING OR \
    OTHERWISE USING DATA FILES, AND/OR SOFTWARE, YOU UNEQUIVOCALLY ACCEPT, AND AGREE TO BE BOUND BY, ALL OF THE \
    TERMS AND CONDITIONS OF THIS AGREEMENT. IF YOU DO NOT AGREE, DO NOT DOWNLOAD, INSTALL, COPY, DISTRIBUTE OR \
    USE THE DATA FILES OR SOFTWARE.

    Permission is hereby granted, free of charge, to any person obtaining a copy of data files and any \
    associated documentation (the "Data Files") or software and any associated documentation (the "Software") \
    to deal in the Data Files or Software without restriction, including without limitation the rights to use, \
    copy, modify, merge, publish, distribute, and/or sell copies of the Data Files or Software, and to permit \
    persons to whom the Data Files or Software are furnished to do so, provided that either (a) this copyright \
    and permission notice appear with all copies of the Data Files or Software, or (b) this copyright and \
    permission notice appear in associated Documentation.

    THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, \
    INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND \
    NONINFRINGEMENT OF THIRD PARTY RIGHTS.

    IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY \
    SPECIAL INDIRECT OR CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR \
    PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN \
    CONNECTION WITH THE USE OR PERFORMANCE OF THE DATA FILES OR SOFTWARE.

    Except as contained in this notice, the name of a copyright holder shall not be used in advertising or \
    otherwise to promote the sale, use or other dealings in these Data Files or Software without prior written \
    authorization of the copyright holder.
    """
}
