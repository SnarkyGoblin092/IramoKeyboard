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
        List {
            Section {
                Text("Iramo. Copyright © 2026 Orsós Emil. All rights reserved.")
            } footer: {
                Text("The third-party material below keeps its own licences.")
            }
            Section {
                ForEach(Licenses.data) { item in row(item) }
            } header: {
                Text("Words and emoji")
            } footer: {
                Text("The keyboard's dictionaries are adapted from FrequencyWords and are shared under the same "
                     + "licence, CC BY-SA 4.0.")
            }
            Section("Emoji tab icons") {
                ForEach(Licenses.icons) { item in row(item) }
            }
        }
        .navigationTitle("Licences")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ item: LicenseItem) -> some View {
        NavigationLink {
            LicenseDetailView(item: item)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                Text(item.licenseName).font(.footnote).foregroundColor(.secondary)
            }
        }
    }
}

private struct LicenseDetailView: View {
    let item: LicenseItem

    var body: some View {
        List {
            Section {
                Text(item.credit)
                if let url = URL(string: item.source) {
                    Link(item.source, destination: url).font(.footnote)
                }
            }
            Section(item.licenseName) {
                Text(item.text)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }
        }
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
            name: "Unicode emoji data and CLDR",
            credit: "The emoji list (emoji-test.txt) and the emoji names and keywords used for search and "
                + "suggestions (CLDR annotations), by Unicode, Inc.",
            licenseName: "Unicode License V3",
            source: "https://www.unicode.org/license.txt",
            text: unicodeLicense),
    ]

    static let icons: [LicenseItem] = [
        LicenseItem(name: "Codicons", credit: "Smiley icon (emoji tab and emoji key), by Microsoft Corporation.",
                    licenseName: "CC BY 4.0", source: "https://github.com/microsoft/vscode-codicons",
                    text: creativeCommons("Attribution 4.0 International", "https://creativecommons.org/licenses/by/4.0/")),
        LicenseItem(name: "Basil", credit: "Light bulb icon (objects tab), by Craftwork.",
                    licenseName: "CC BY 4.0", source: "https://www.figma.com/community/file/931906394678748246",
                    text: creativeCommons("Attribution 4.0 International", "https://creativecommons.org/licenses/by/4.0/")),
        LicenseItem(name: "Font Awesome 4", credit: "Football icon (activities tab), by Dave Gandy.",
                    licenseName: "SIL Open Font License 1.1", source: "https://github.com/FortAwesome/Font-Awesome/tree/v4.7.0",
                    text: "Copyright (c) 2012-2016 Dave Gandy (http://fontawesome.io)\n\n" + ofl),
        LicenseItem(name: "Akar Icons", credit: "Clock (recents tab) and heart (symbols tab) icons.",
                    licenseName: "MIT", source: "https://github.com/artcoholic/akar-icons",
                    text: mit("Copyright (c) 2020 Arturo Wibawa")),
        LicenseItem(name: "Famicons", credit: "Paw icon (animals & nature tab).",
                    licenseName: "MIT", source: "https://github.com/familyjs/famicons",
                    text: mit("Copyright (c) 2022-present Family")),
        LicenseItem(name: "Flowbite Icons", credit: "Apple icon (food & drink tab).",
                    licenseName: "MIT", source: "https://github.com/themesberg/flowbite-icons",
                    text: mit("Copyright (c) 2024 Themesberg")),
        LicenseItem(name: "Fluent UI System Icons", credit: "Car icon (travel & places tab).",
                    licenseName: "MIT", source: "https://github.com/microsoft/fluentui-system-icons",
                    text: mit("Copyright (c) 2020 Microsoft Corporation")),
        LicenseItem(name: "Boxicons", credit: "Flag icon (flags tab).",
                    licenseName: "MIT", source: "https://github.com/box-icons/boxicons-core",
                    text: mit("Copyright (c) 2026 Boxicons")),
    ]

    private static func creativeCommons(_ title: String, _ url: String) -> String {
        return "Licensed under the Creative Commons \(title) licence. The full licence text is at \(url)\n\n"
            + "The material is shown here as converted for the keyboard (resized, reformatted or counted); "
            + "the original is available from the source above."
    }

    private static func mit(_ copyright: String) -> String {
        return copyright + """


        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and \
        associated documentation files (the "Software"), to deal in the Software without restriction, including \
        without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
        copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the \
        following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial \
        portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT \
        LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO \
        EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER \
        IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR \
        THE USE OR OTHER DEALINGS IN THE SOFTWARE.
        """
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

    private static let ofl = """
    This Font Software is licensed under the SIL Open Font License, Version 1.1.

    SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007

    PREAMBLE
    The goals of the Open Font License (OFL) are to stimulate worldwide development of collaborative font \
    projects, to support the font creation efforts of academic and linguistic communities, and to provide a \
    free and open framework in which fonts may be shared and improved in partnership with others.

    The OFL allows the licensed fonts to be used, studied, modified and redistributed freely as long as they \
    are not sold by themselves. The fonts, including any derivative works, can be bundled, embedded, \
    redistributed and/or sold with any software provided that any reserved names are not used by derivative \
    works. The fonts and derivatives, however, cannot be released under any other type of license. The \
    requirement for fonts to remain under this license does not apply to any document created using the fonts \
    or their derivatives.

    DEFINITIONS
    "Font Software" refers to the set of files released by the Copyright Holder(s) under this license and \
    clearly marked as such. This may include source files, build scripts and documentation.

    "Reserved Font Name" refers to any names specified as such after the copyright statement(s).

    "Original Version" refers to the collection of Font Software components as distributed by the Copyright \
    Holder(s).

    "Modified Version" refers to any derivative made by adding to, deleting, or substituting -- in part or in \
    whole -- any of the components of the Original Version, by changing formats or by porting the Font \
    Software to a new environment.

    "Author" refers to any designer, engineer, programmer, technical writer or other person who contributed to \
    the Font Software.

    PERMISSION & CONDITIONS
    Permission is hereby granted, free of charge, to any person obtaining a copy of the Font Software, to use, \
    study, copy, merge, embed, modify, redistribute, and sell modified and unmodified copies of the Font \
    Software, subject to the following conditions:

    1) Neither the Font Software nor any of its individual components, in Original or Modified Versions, may be \
    sold by itself.

    2) Original or Modified Versions of the Font Software may be bundled, redistributed and/or sold with any \
    software, provided that each copy contains the above copyright notice and this license. These can be \
    included either as stand-alone text files, human-readable headers or in the appropriate machine-readable \
    metadata fields within text or binary files as long as those fields can be easily viewed by the user.

    3) No Modified Version of the Font Software may use the Reserved Font Name(s) unless explicit written \
    permission is granted by the corresponding Copyright Holder. This restriction only applies to the primary \
    font name as presented to the users.

    4) The name(s) of the Copyright Holder(s) and the Author(s) of the Font Software shall not be used to \
    promote, endorse or advertise any Modified Version, except to acknowledge the contribution(s) of the \
    Copyright Holder(s) and the Author(s) or with their explicit written permission.

    5) The Font Software, modified or unmodified, in part or in whole, must be distributed entirely under this \
    license, and must not be distributed under any other license. The requirement for fonts to remain under \
    this license does not apply to any document created using the Font Software.

    TERMINATION
    This license becomes null and void if any of the above conditions are not met.

    DISCLAIMER
    THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT \
    LIMITED TO ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF \
    COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY \
    CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL \
    DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF THE USE OR INABILITY TO \
    USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN THE FONT SOFTWARE.
    """
}
