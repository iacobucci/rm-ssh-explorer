import QtQuick 2.5
import "."

Rectangle {
    id: modalRoot
    anchors.fill: parent
    color: "#80000000" // Semi-transparent overlay

    property string remotePath: ""
    property string fileName: ""
    property string fileSizeStr: ""
    property int fileSize: 0

    property string docTitle: ""
    property string statusText: ""
    property bool isWorking: false
    property bool isSuccess: false
    property bool isError: false
    property string errorMessage: ""

    signal requestImport(string path, string title)
    signal requestClose()
    signal inputFocused(var item)

    function reset() {
        isWorking = false;
        isSuccess = false;
        isError = false;
        statusText = "";
        errorMessage = "";
        docTitle = fileName.replace(/\.[pP][dD][fF]$/, "");
    }

    onFileNameChanged: reset()

    // Block background touches
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (!isWorking) modalRoot.requestClose();
        }
    }

    Rectangle {
        id: dialogBox
        width: Math.min(modalRoot.width - 40, 680)
        height: Math.min(modalRoot.height - 40, 520)
        anchors.centerIn: parent
        color: Style.bg
        border.color: Style.border
        border.width: Style.borderWidth + 1
        radius: Style.cornerRadius + 2

        MouseArea {
            // Prevent clicks inside the dialog from closing it
            anchors.fill: parent
        }

        Column {
            anchors.fill: parent
            anchors.margins: Style.padding * 1.5
            spacing: Style.spacing * 1.2

            // Title Bar
            Row {
                width: parent.width
                spacing: 10

                Text {
                    width: parent.width - 50
                    text: "Import PDF to reMarkable"
                    font.pixelSize: Style.fontSizeTitle
                    font.bold: true
                    color: Style.fg
                }

                Rectangle {
                    width: 40
                    height: 40
                    color: closeBtnMa.pressed ? Style.invertedBg : Style.bg
                    border.color: Style.border
                    border.width: 1
                    radius: 3
                    visible: !isWorking

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 18
                        font.bold: true
                        color: closeBtnMa.pressed ? Style.invertedFg : Style.fg
                    }
                    MouseArea {
                        id: closeBtnMa
                        anchors.fill: parent
                        onClicked: modalRoot.requestClose()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Style.subtleBorder
            }

            // Normal Content View
            Column {
                width: parent.width
                spacing: Style.spacing
                visible: !isWorking && !isSuccess && !isError

                // File Info Card
                Rectangle {
                    width: parent.width
                    height: 90
                    color: Style.subtleBg
                    border.color: Style.subtleBorder
                    border.width: 1
                    radius: Style.cornerRadius

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        Text {
                            width: parent.width
                            text: "Remote File: " + modalRoot.fileName
                            font.pixelSize: Style.fontSizeBody
                            font.bold: true
                            elide: Text.ElideMiddle
                            color: Style.fg
                        }

                        Text {
                            text: "Size: " + (modalRoot.fileSizeStr !== "" ? modalRoot.fileSizeStr : (modalRoot.fileSize + " bytes"))
                            font.pixelSize: Style.fontSizeSmall
                            color: Style.subtleFg
                        }

                        Text {
                            width: parent.width
                            text: "Path: " + modalRoot.remotePath
                            font.pixelSize: Style.fontSizeSmall
                            elide: Text.ElideMiddle
                            color: Style.subtleFg
                        }
                    }
                }

                // Custom Title field
                Column {
                    width: parent.width
                    spacing: 4

                    Text {
                        text: "Document Name in Library:"
                        font.pixelSize: Style.fontSizeBody
                        font.bold: true
                        color: Style.fg
                    }

                    Rectangle {
                        width: parent.width
                        height: Style.inputHeight
                        color: Style.bg
                        border.color: titleInput.activeFocus ? Style.border : Style.subtleBorder
                        border.width: titleInput.activeFocus ? Style.borderWidth : 1
                        radius: Style.cornerRadius

                        TextInput {
                            id: titleInput
                            anchors.fill: parent
                            anchors.margins: 10
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: Style.fontSizeBody
                            text: modalRoot.docTitle
                            color: Style.fg
                            selectByMouse: true
                            onTextChanged: modalRoot.docTitle = text
                            onActiveFocusChanged: {
                                if (activeFocus) modalRoot.inputFocused(titleInput);
                            }
                        }
                    }
                }

                Item { width: 1; height: 10 }

                // Action Buttons
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.spacing * 2

                    Rectangle {
                        width: 180
                        height: Style.buttonHeight
                        color: cancelMa.pressed ? Style.activeHighlight : Style.bg
                        border.color: Style.border
                        border.width: Style.borderWidth
                        radius: Style.cornerRadius

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.pixelSize: Style.fontSizeBody
                            font.bold: true
                            color: Style.fg
                        }
                        MouseArea {
                            id: cancelMa
                            anchors.fill: parent
                            onClicked: modalRoot.requestClose()
                        }
                    }

                    Rectangle {
                        width: 260
                        height: Style.buttonHeight
                        color: importMa.pressed ? Style.bg : Style.invertedBg
                        border.color: Style.border
                        border.width: Style.borderWidth
                        radius: Style.cornerRadius

                        Text {
                            anchors.centerIn: parent
                            text: "Download & Import"
                            font.pixelSize: Style.fontSizeBody
                            font.bold: true
                            color: importMa.pressed ? Style.invertedBg : Style.invertedFg
                        }
                        MouseArea {
                            id: importMa
                            anchors.fill: parent
                            onClicked: {
                                modalRoot.requestImport(modalRoot.remotePath, modalRoot.docTitle);
                            }
                        }
                    }
                }
            }

            // Working / Progress View
            Column {
                width: parent.width
                spacing: 20
                visible: isWorking

                Item { width: 1; height: 30 }

                Rectangle {
                    width: 70
                    height: 70
                    radius: 35
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Style.subtleBg
                    border.color: Style.border
                    border.width: 3

                    Text {
                        anchors.centerIn: parent
                        text: "..."
                        font.pixelSize: 32
                        font.bold: true
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modalRoot.statusText !== "" ? modalRoot.statusText : "Downloading and importing PDF..."
                    font.pixelSize: Style.fontSizeTitle
                    font.bold: true
                    color: Style.fg
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Please wait while the file is transferred over SSH."
                    font.pixelSize: Style.fontSizeBody
                    color: Style.subtleFg
                }
            }

            // Success View
            Column {
                width: parent.width
                spacing: 16
                visible: isSuccess

                Item { width: 1; height: 20 }

                Rectangle {
                    width: 60
                    height: 60
                    radius: 30
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Style.invertedBg

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        font.pixelSize: 36
                        color: Style.invertedFg
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Import Complete!"
                    font.pixelSize: Style.fontSizeHeader
                    font.bold: true
                    color: Style.fg
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Document \"" + modalRoot.docTitle + "\" has been imported into your reMarkable library."
                    font.pixelSize: Style.fontSizeBody
                    wrapMode: Text.WordWrap
                    color: Style.fg
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: modalRoot.statusText
                    font.pixelSize: Style.fontSizeSmall
                    wrapMode: Text.WordWrap
                    color: Style.subtleFg
                }

                Item { width: 1; height: 10 }

                Rectangle {
                    width: 220
                    height: Style.buttonHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: successDoneMa.pressed ? Style.bg : Style.invertedBg
                    border.color: Style.border
                    border.width: Style.borderWidth
                    radius: Style.cornerRadius

                    Text {
                        anchors.centerIn: parent
                        text: "Done"
                        font.pixelSize: Style.fontSizeBody
                        font.bold: true
                        color: successDoneMa.pressed ? Style.invertedBg : Style.invertedFg
                    }
                    MouseArea {
                        id: successDoneMa
                        anchors.fill: parent
                        onClicked: modalRoot.requestClose()
                    }
                }
            }

            // Error View
            Column {
                width: parent.width
                spacing: 16
                visible: isError

                Item { width: 1; height: 20 }

                Rectangle {
                    width: 60
                    height: 60
                    radius: 30
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Style.bg
                    border.color: Style.border
                    border.width: 3

                    Text {
                        anchors.centerIn: parent
                        text: "!"
                        font.pixelSize: 36
                        font.bold: true
                        color: Style.fg
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Import Failed"
                    font.pixelSize: Style.fontSizeTitle
                    font.bold: true
                    color: Style.fg
                }

                Rectangle {
                    width: parent.width
                    height: 100
                    color: Style.subtleBg
                    border.color: Style.subtleBorder
                    border.width: 1
                    radius: Style.cornerRadius

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 10
                        contentWidth: width
                        contentHeight: errText.height
                        clip: true

                        Text {
                            id: errText
                            width: parent.width
                            text: modalRoot.errorMessage
                            font.pixelSize: Style.fontSizeSmall
                            wrapMode: Text.WordWrap
                            color: Style.fg
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.spacing * 2

                    Rectangle {
                        width: 150
                        height: Style.buttonHeight
                        color: errCloseMa.pressed ? Style.activeHighlight : Style.bg
                        border.color: Style.border
                        border.width: Style.borderWidth
                        radius: Style.cornerRadius

                        Text {
                            anchors.centerIn: parent
                            text: "Close"
                            font.pixelSize: Style.fontSizeBody
                            font.bold: true
                            color: Style.fg
                        }
                        MouseArea {
                            id: errCloseMa
                            anchors.fill: parent
                            onClicked: modalRoot.requestClose()
                        }
                    }

                    Rectangle {
                        width: 180
                        height: Style.buttonHeight
                        color: retryMa.pressed ? Style.bg : Style.invertedBg
                        border.color: Style.border
                        border.width: Style.borderWidth
                        radius: Style.cornerRadius

                        Text {
                            anchors.centerIn: parent
                            text: "Retry"
                            font.pixelSize: Style.fontSizeBody
                            font.bold: true
                            color: retryMa.pressed ? Style.invertedBg : Style.invertedFg
                        }
                        MouseArea {
                            id: retryMa
                            anchors.fill: parent
                            onClicked: {
                                modalRoot.isError = false;
                                modalRoot.requestImport(modalRoot.remotePath, modalRoot.docTitle);
                            }
                        }
                    }
                }
            }
        }
    }
}
