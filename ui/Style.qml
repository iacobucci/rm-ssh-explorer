pragma Singleton
import QtQuick 2.5

QtObject {
    // E-Ink Colors
    readonly property color bg: "#FFFFFF"
    readonly property color fg: "#000000"
    readonly property color border: "#000000"
    readonly property color subtleBg: "#F0F0F0"
    readonly property color subtleBorder: "#888888"
    readonly property color subtleFg: "#555555"
    readonly property color invertedBg: "#000000"
    readonly property color invertedFg: "#FFFFFF"
    readonly property color activeHighlight: "#E2E2E2"

    // Typography
    readonly property int fontSizeHeader: 26
    readonly property int fontSizeTitle: 21
    readonly property int fontSizeBody: 17
    readonly property int fontSizeSmall: 14
    readonly property int fontSizeKey: 19
    readonly property string fontFamily: "sans-serif"
    readonly property string monoFontFamily: "monospace"

    // Metrics
    readonly property int buttonHeight: 52
    readonly property int inputHeight: 48
    readonly property int rowHeight: 64
    readonly property int borderWidth: 2
    readonly property int cornerRadius: 4
    readonly property int spacing: 12
    readonly property int padding: 16
}
