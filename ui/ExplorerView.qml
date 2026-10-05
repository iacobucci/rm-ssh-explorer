import QtQuick 2.5
import "."

Item {
    id: explorerRoot

    property string currentPath: "/"
    property string parentPath: "/"
    property var rawEntries: []
    property bool filterOnlyPdfs: true
    property bool isLoading: false
    property string errorMessage: ""

    // Computed filtered model
    property var displayEntries: {
        var res = [];
        for (var i = 0; i < rawEntries.length; i++) {
            var item = rawEntries[i];
            if (filterOnlyPdfs) {
                if (item.type === "dir" || item.is_pdf) {
                    res.push(item);
                }
            } else {
                res.push(item);
            }
        }
        return res;
    }

    signal navigateTo(string path)
    signal refreshRequested()
    signal pdfSelected(string path, string name, string sizeStr, int size)

    Column {
        anchors.fill: parent
        spacing: 0

        // Location & Tool Bar
        Rectangle {
            width: parent.width
            height: 64
            color: Style.subtleBg
            border.color: Style.border
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // Up / Parent Directory Button
                Rectangle {
                    width: 110
                    height: 48
                    color: (currentPath === "/" || currentPath === parentPath) ? Style.subtleBg : (upMa.pressed ? Style.invertedBg : Style.bg)
                    border.color: (currentPath === "/" || currentPath === parentPath) ? Style.subtleBorder : Style.border
                    border.width: 1
                    radius: Style.cornerRadius
                    enabled: currentPath !== "/" && currentPath !== parentPath && !explorerRoot.isLoading

                    Text {
                        anchors.centerIn: parent
                        text: "Up"
                        font.pixelSize: Style.fontSizeBody
                        font.bold: true
                        color: (currentPath === "/" || currentPath === parentPath) ? Style.subtleFg : (upMa.pressed ? Style.invertedFg : Style.fg)
                    }
                    MouseArea {
                        id: upMa
                        anchors.fill: parent
                        onClicked: explorerRoot.navigateTo(explorerRoot.parentPath)
                    }
                }

                // Current Path Label Box
                Rectangle {
                    width: parent.width - 110 - 100 - 150 - 32
                    height: 48
                    color: Style.bg
                    border.color: Style.subtleBorder
                    border.width: 1
                    radius: Style.cornerRadius
                    clip: true

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: explorerRoot.currentPath
                        font.pixelSize: Style.fontSizeSmall
                        font.family: Style.monoFontFamily
                        font.bold: true
                        elide: Text.ElideMiddle
                        color: Style.fg
                    }
                }

                // Refresh Button
                Rectangle {
                    width: 90
                    height: 48
                    color: refMa.pressed ? Style.invertedBg : Style.bg
                    border.color: Style.border
                    border.width: 1
                    radius: Style.cornerRadius
                    enabled: !explorerRoot.isLoading

                    Text {
                        anchors.centerIn: parent
                        text: "Refresh"
                        font.pixelSize: Style.fontSizeSmall
                        font.bold: true
                        color: refMa.pressed ? Style.invertedFg : Style.fg
                    }
                    MouseArea {
                        id: refMa
                        anchors.fill: parent
                        onClicked: explorerRoot.refreshRequested()
                    }
                }

                // Filter Toggle Button
                Rectangle {
                    width: 140
                    height: 48
                    color: explorerRoot.filterOnlyPdfs ? Style.invertedBg : (filtMa.pressed ? Style.activeHighlight : Style.bg)
                    border.color: Style.border
                    border.width: 1
                    radius: Style.cornerRadius

                    Text {
                        anchors.centerIn: parent
                        text: explorerRoot.filterOnlyPdfs ? "PDFs Only" : "Show All Files"
                        font.pixelSize: Style.fontSizeSmall
                        font.bold: true
                        color: explorerRoot.filterOnlyPdfs ? Style.invertedFg : Style.fg
                    }
                    MouseArea {
                        id: filtMa
                        anchors.fill: parent
                        onClicked: explorerRoot.filterOnlyPdfs = !explorerRoot.filterOnlyPdfs
                    }
                }
            }
        }

        // File List Area
        Item {
            width: parent.width
            height: parent.height - 64 - 56 // account for top bar and footer paging bar

            // Loading View
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: explorerRoot.isLoading

                Rectangle {
                    width: 60
                    height: 60
                    radius: 30
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Style.subtleBg
                    border.color: Style.border
                    border.width: 2
                    Text {
                        anchors.centerIn: parent
                        text: "..."
                        font.pixelSize: 28
                        font.bold: true
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Listing remote directory..."
                    font.pixelSize: Style.fontSizeBody
                    font.bold: true
                    color: Style.fg
                }
            }

            // Error View
            Column {
                anchors.centerIn: parent
                width: parent.width - 60
                spacing: 14
                visible: !explorerRoot.isLoading && explorerRoot.errorMessage !== ""

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Error Accessing Remote Folder"
                    font.pixelSize: Style.fontSizeTitle
                    font.bold: true
                    color: Style.fg
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: explorerRoot.errorMessage
                    font.pixelSize: Style.fontSizeBody
                    wrapMode: Text.WordWrap
                    color: Style.subtleFg
                }

                Rectangle {
                    width: 140
                    height: Style.buttonHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: errRetryMa.pressed ? Style.bg : Style.invertedBg
                    border.color: Style.border
                    border.width: Style.borderWidth
                    radius: Style.cornerRadius

                    Text {
                        anchors.centerIn: parent
                        text: "Retry"
                        font.pixelSize: Style.fontSizeBody
                        font.bold: true
                        color: errRetryMa.pressed ? Style.invertedBg : Style.invertedFg
                    }
                    MouseArea {
                        id: errRetryMa
                        anchors.fill: parent
                        onClicked: explorerRoot.refreshRequested()
                    }
                }
            }

            // Empty View
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: !explorerRoot.isLoading && explorerRoot.errorMessage === "" && explorerRoot.displayEntries.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: explorerRoot.filterOnlyPdfs ? "No PDF files found in this folder." : "Folder is empty."
                    font.pixelSize: Style.fontSizeTitle
                    color: Style.subtleFg
                }

                Rectangle {
                    width: 180
                    height: 42
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: emptyToggleMa.pressed ? Style.activeHighlight : Style.bg
                    border.color: Style.border
                    border.width: 1
                    radius: Style.cornerRadius
                    visible: explorerRoot.filterOnlyPdfs

                    Text {
                        anchors.centerIn: parent
                        text: "Show All Files"
                        font.pixelSize: Style.fontSizeSmall
                        font.bold: true
                        color: Style.fg
                    }
                    MouseArea {
                        id: emptyToggleMa
                        anchors.fill: parent
                        onClicked: explorerRoot.filterOnlyPdfs = false
                    }
                }
            }

            // ListView
            ListView {
                id: fileListView
                anchors.fill: parent
                model: explorerRoot.displayEntries
                clip: true
                visible: !explorerRoot.isLoading && explorerRoot.errorMessage === "" && explorerRoot.displayEntries.length > 0

                delegate: Rectangle {
                    id: rowDelegate
                    width: fileListView.width
                    height: Style.rowHeight
                    color: rowMa.pressed ? Style.activeHighlight : ((index % 2 === 0) ? Style.bg : Style.subtleBg)

                    Rectangle {
                        width: parent.width
                        height: 1
                        anchors.bottom: parent.bottom
                        color: Style.subtleBorder
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 14

                        // Icon badge
                        Rectangle {
                            width: 44
                            height: 44
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.is_pdf ? Style.invertedBg : Style.bg
                            border.color: Style.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.type === "dir" ? "DIR" : (modelData.is_pdf ? "PDF" : "FILE")
                                font.pixelSize: 13
                                font.bold: true
                                color: modelData.is_pdf ? Style.invertedFg : Style.fg
                            }
                        }

                        // File name and details
                        Column {
                            width: parent.width - 44 - 14 - 130
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                width: parent.width
                                text: modelData.name
                                font.pixelSize: Style.fontSizeBody
                                font.bold: modelData.type === "dir" || modelData.is_pdf
                                elide: Text.ElideRight
                                color: Style.fg
                            }

                            Text {
                                text: modelData.type === "dir" ? "Folder" : (modelData.size_str !== "" ? modelData.size_str : (modelData.size + " B"))
                                font.pixelSize: Style.fontSizeSmall
                                color: Style.subtleFg
                            }
                        }

                        // Action / indicator on right
                        Rectangle {
                            width: 110
                            height: 40
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.is_pdf ? (rowMa.pressed ? Style.invertedBg : Style.bg) : "transparent"
                            border.color: modelData.is_pdf ? Style.border : "transparent"
                            border.width: 1
                            radius: 3
                            visible: modelData.is_pdf || modelData.type === "dir"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.is_pdf ? "Import" : "Open"
                                font.pixelSize: Style.fontSizeSmall
                                font.bold: true
                                color: Style.fg
                            }
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        onClicked: {
                            if (modelData.type === "dir") {
                                var target = explorerRoot.currentPath;
                                if (target === "/") {
                                    target = "/" + modelData.name;
                                } else {
                                    target = target + "/" + modelData.name;
                                }
                                explorerRoot.navigateTo(target);
                            } else if (modelData.is_pdf) {
                                var fullPath = explorerRoot.currentPath;
                                if (fullPath === "/") {
                                    fullPath = "/" + modelData.name;
                                } else {
                                    fullPath = fullPath + "/" + modelData.name;
                                }
                                explorerRoot.pdfSelected(fullPath, modelData.name, modelData.size_str, modelData.size);
                            }
                        }
                    }
                }
            }
        }

        // Footer Bar: E-Ink Paging Controls & Item Count
        Rectangle {
            width: parent.width
            height: 56
            color: Style.subtleBg
            border.color: Style.border
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: explorerRoot.displayEntries.length + " items"
                    font.pixelSize: Style.fontSizeSmall
                    font.bold: true
                    color: Style.subtleFg
                }

                Item { width: 20; height: 1 }

                // Page Up Button
                Rectangle {
                    width: 140
                    height: 40
                    color: pgUpMa.pressed ? Style.invertedBg : Style.bg
                    border.color: Style.border
                    border.width: 1
                    radius: Style.cornerRadius
                    enabled: fileListView.contentY > 0

                    Text {
                        anchors.centerIn: parent
                        text: "Page Up"
                        font.pixelSize: Style.fontSizeSmall
                        font.bold: true
                        color: pgUpMa.pressed ? Style.invertedFg : Style.fg
                    }
                    MouseArea {
                        id: pgUpMa
                        anchors.fill: parent
                        onClicked: {
                            var newY = Math.max(0, fileListView.contentY - fileListView.height + 60);
                            fileListView.contentY = newY;
                        }
                    }
                }

                // Page Down Button
                Rectangle {
                    width: 140
                    height: 40
                    color: pgDnMa.pressed ? Style.invertedBg : Style.bg
                    border.color: Style.border
                    border.width: 1
                    radius: Style.cornerRadius
                    enabled: fileListView.contentY < (fileListView.contentHeight - fileListView.height)

                    Text {
                        anchors.centerIn: parent
                        text: "Page Down"
                        font.pixelSize: Style.fontSizeSmall
                        font.bold: true
                        color: pgDnMa.pressed ? Style.invertedFg : Style.fg
                    }
                    MouseArea {
                        id: pgDnMa
                        anchors.fill: parent
                        onClicked: {
                            var maxY = fileListView.contentHeight - fileListView.height;
                            if (maxY > 0) {
                                var newY = Math.min(maxY, fileListView.contentY + fileListView.height - 60);
                                fileListView.contentY = newY;
                            }
                        }
                    }
                }
            }
        }
    }
}
