import QtQuick 2.5
import "."

Rectangle {
    id: keyboardRoot
    property var targetInput: null
    property bool shiftActive: false

    width: parent.width
    height: 290
    color: Style.subtleBg
    border.color: Style.border
    border.width: Style.borderWidth

    function typeChar(ch) {
        if (!targetInput) return;
        var cursor = targetInput.cursorPosition;
        var text = targetInput.text;
        var prefix = text.substring(0, cursor);
        var suffix = text.substring(cursor);
        targetInput.text = prefix + ch + suffix;
        targetInput.cursorPosition = cursor + 1;
    }

    function backspace() {
        if (!targetInput) return;
        var cursor = targetInput.cursorPosition;
        if (cursor <= 0) return;
        var text = targetInput.text;
        var prefix = text.substring(0, cursor - 1);
        var suffix = text.substring(cursor);
        targetInput.text = prefix + suffix;
        targetInput.cursorPosition = cursor - 1;
    }

    function clearText() {
        if (!targetInput) return;
        targetInput.text = "";
        targetInput.cursorPosition = 0;
    }

    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 5

        // Row 1: Numbers
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
                delegate: Rectangle {
                    width: (keyboardRoot.width - 60) / 10
                    height: 50
                    color: keyMa.pressed ? Style.invertedBg : Style.bg
                    border.color: Style.border
                    border.width: 1
                    radius: 3

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: Style.fontSizeKey
                        font.bold: true
                        color: keyMa.pressed ? Style.invertedFg : Style.fg
                    }
                    MouseArea {
                        id: keyMa
                        anchors.fill: parent
                        onClicked: keyboardRoot.typeChar(modelData)
                    }
                }
            }
        }

        // Row 2: QWERTY
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
                delegate: Rectangle {
                    width: (keyboardRoot.width - 60) / 10
                    height: 50
                    color: keyMa2.pressed ? Style.invertedBg : Style.bg
                    border.color: Style.border
                    border.width: 1
                    radius: 3

                    Text {
                        anchors.centerIn: parent
                        text: keyboardRoot.shiftActive ? modelData.toUpperCase() : modelData
                        font.pixelSize: Style.fontSizeKey
                        color: keyMa2.pressed ? Style.invertedFg : Style.fg
                    }
                    MouseArea {
                        id: keyMa2
                        anchors.fill: parent
                        onClicked: keyboardRoot.typeChar(keyboardRoot.shiftActive ? modelData.toUpperCase() : modelData)
                    }
                }
            }
        }

        // Row 3: ASDFGHJKL
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
                delegate: Rectangle {
                    width: (keyboardRoot.width - 70) / 9.5
                    height: 50
                    color: keyMa3.pressed ? Style.invertedBg : Style.bg
                    border.color: Style.border
                    border.width: 1
                    radius: 3

                    Text {
                        anchors.centerIn: parent
                        text: keyboardRoot.shiftActive ? modelData.toUpperCase() : modelData
                        font.pixelSize: Style.fontSizeKey
                        color: keyMa3.pressed ? Style.invertedFg : Style.fg
                    }
                    MouseArea {
                        id: keyMa3
                        anchors.fill: parent
                        onClicked: keyboardRoot.typeChar(keyboardRoot.shiftActive ? modelData.toUpperCase() : modelData)
                    }
                }
            }
        }

        // Row 4: Shift, ZXCVBNM, Backspace
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            // Shift Key
            Rectangle {
                width: 70
                height: 50
                color: keyboardRoot.shiftActive ? Style.invertedBg : (shiftMa.pressed ? Style.activeHighlight : Style.bg)
                border.color: Style.border
                border.width: 1
                radius: 3

                Text {
                    anchors.centerIn: parent
                    text: "SHIFT"
                    font.pixelSize: Style.fontSizeSmall
                    font.bold: true
                    color: keyboardRoot.shiftActive ? Style.invertedFg : Style.fg
                }
                MouseArea {
                    id: shiftMa
                    anchors.fill: parent
                    onClicked: keyboardRoot.shiftActive = !keyboardRoot.shiftActive
                }
            }

            Repeater {
                model: ["z", "x", "c", "v", "b", "n", "m"]
                delegate: Rectangle {
                    width: (keyboardRoot.width - 190) / 7
                    height: 50
                    color: keyMa4.pressed ? Style.invertedBg : Style.bg
                    border.color: Style.border
                    border.width: 1
                    radius: 3

                    Text {
                        anchors.centerIn: parent
                        text: keyboardRoot.shiftActive ? modelData.toUpperCase() : modelData
                        font.pixelSize: Style.fontSizeKey
                        color: keyMa4.pressed ? Style.invertedFg : Style.fg
                    }
                    MouseArea {
                        id: keyMa4
                        anchors.fill: parent
                        onClicked: keyboardRoot.typeChar(keyboardRoot.shiftActive ? modelData.toUpperCase() : modelData)
                    }
                }
            }

            // Backspace Key
            Rectangle {
                width: 80
                height: 50
                color: bsMa.pressed ? Style.invertedBg : Style.bg
                border.color: Style.border
                border.width: 1
                radius: 3

                Text {
                    anchors.centerIn: parent
                    text: "BACK"
                    font.pixelSize: Style.fontSizeSmall
                    font.bold: true
                    color: bsMa.pressed ? Style.invertedFg : Style.fg
                }
                MouseArea {
                    id: bsMa
                    anchors.fill: parent
                    onClicked: keyboardRoot.backspace()
                }
            }
        }

        // Row 5: Symbols, Space, Clear, Done
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            Repeater {
                model: [".", "-", "_", "/", "~", "@", ":"]
                delegate: Rectangle {
                    width: 44
                    height: 50
                    color: symMa.pressed ? Style.invertedBg : Style.bg
                    border.color: Style.border
                    border.width: 1
                    radius: 3

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: Style.fontSizeKey
                        font.bold: true
                        color: symMa.pressed ? Style.invertedFg : Style.fg
                    }
                    MouseArea {
                        id: symMa
                        anchors.fill: parent
                        onClicked: keyboardRoot.typeChar(modelData)
                    }
                }
            }

            // Spacebar
            Rectangle {
                width: keyboardRoot.width - 530
                height: 50
                color: spaceMa.pressed ? Style.invertedBg : Style.bg
                border.color: Style.border
                border.width: 1
                radius: 3

                Text {
                    anchors.centerIn: parent
                    text: "SPACE"
                    font.pixelSize: Style.fontSizeSmall
                    color: spaceMa.pressed ? Style.invertedFg : Style.subtleFg
                }
                MouseArea {
                    id: spaceMa
                    anchors.fill: parent
                    onClicked: keyboardRoot.typeChar(" ")
                }
            }

            // Clear
            Rectangle {
                width: 70
                height: 50
                color: clearMa.pressed ? Style.invertedBg : Style.bg
                border.color: Style.border
                border.width: 1
                radius: 3

                Text {
                    anchors.centerIn: parent
                    text: "CLEAR"
                    font.pixelSize: Style.fontSizeSmall
                    font.bold: true
                    color: clearMa.pressed ? Style.invertedFg : Style.fg
                }
                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    onClicked: keyboardRoot.clearText()
                }
            }

            // Done / Close keyboard
            Rectangle {
                width: 90
                height: 50
                color: doneMa.pressed ? Style.bg : Style.invertedBg
                border.color: Style.border
                border.width: 1
                radius: 3

                Text {
                    anchors.centerIn: parent
                    text: "DONE"
                    font.pixelSize: Style.fontSizeSmall
                    font.bold: true
                    color: doneMa.pressed ? Style.invertedBg : Style.invertedFg
                }
                MouseArea {
                    id: doneMa
                    anchors.fill: parent
                    onClicked: {
                        keyboardRoot.visible = false;
                        if (targetInput) targetInput.focus = false;
                    }
                }
            }
        }
    }
}
