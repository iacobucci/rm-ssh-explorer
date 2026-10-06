import QtQuick 2.5
import "."

Item {
    id: explorerRoot

    property string currentPath: "/"
    property string parentPath: "/"
    property var rawEntries: []
    property bool filterOnlyPdfs: true
    property bool showHiddenFiles: false
    property bool isFilterMenuOpen: false
    property bool isLoading: false
    property string errorMessage: ""

    property string searchQuery: ""

    function clearSearch() {
        searchQuery = "";
        if (searchInput) {
            searchInput.text = "";
        }
    }

    onCurrentPathChanged: {
        isFilterMenuOpen = false;
        clearSearch();
    }

    onSearchQueryChanged: {
        fileListView.contentY = 0;
    }

    // Computed filtered model
    property var displayEntries: {
        var res = [];
        var query = searchQuery.trim().toLowerCase();
        var queryWords = query.length > 0 ? query.split(/\s+/) : [];
        for (var i = 0; i < rawEntries.length; i++) {
            var item = rawEntries[i];
            var isHidden = item.name.length > 0 && item.name.charAt(0) === ".";
            if (!showHiddenFiles && isHidden) {
                continue;
            }
            if (filterOnlyPdfs && item.type !== "dir" && !item.is_pdf) {
                continue;
            }
            if (queryWords.length > 0) {
                var nameLower = item.name.toLowerCase();
                var allMatch = true;
                for (var w = 0; w < queryWords.length; w++) {
                    if (nameLower.indexOf(queryWords[w]) === -1) {
                        allMatch = false;
                        break;
                    }
                }
                if (!allMatch) {
                    continue;
                }
            }
            res.push(item);
        }
        return res;
    }

    signal navigateTo(string path)
    signal refreshRequested()
    signal pdfSelected(string path, string name, string sizeStr, int size)
    signal inputFocused(var item)

    Column {
        anchors.fill: parent
        spacing: 0

        // Location & Tool Bar
        Rectangle {
            id: locationBar
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
                    width: 100
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
                        onClicked: {
                            explorerRoot.isFilterMenuOpen = false;
                            explorerRoot.navigateTo(explorerRoot.parentPath);
                        }
                    }
                }

                // Current Path Label Box
                Rectangle {
                    width: parent.width - 100 - 90 - 120 - 40
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
                        onClicked: {
                            explorerRoot.isFilterMenuOpen = false;
                            explorerRoot.refreshRequested();
                        }
                    }
                }

                // Filters Menu Button
                Rectangle {
                    width: 120
                    height: 48
                    color: (explorerRoot.isFilterMenuOpen || filtMa.pressed) ? Style.invertedBg : ((explorerRoot.filterOnlyPdfs || explorerRoot.showHiddenFiles) ? Style.activeHighlight : Style.bg)
                    border.color: Style.border
                    border.width: 1
                    radius: Style.cornerRadius

                    Text {
                        anchors.centerIn: parent
                        text: (explorerRoot.filterOnlyPdfs || explorerRoot.showHiddenFiles) ? "Filters [on]" : "Filters"
                        font.pixelSize: Style.fontSizeSmall
                        font.bold: true
                        color: (explorerRoot.isFilterMenuOpen || filtMa.pressed) ? Style.invertedFg : Style.fg
                    }
                    MouseArea {
                        id: filtMa
                        anchors.fill: parent
                        onClicked: {
                            explorerRoot.isFilterMenuOpen = !explorerRoot.isFilterMenuOpen;
                        }
                    }
                }
            }
        }

        // Search Bar
        Rectangle {
            id: searchBarContainer
            width: parent.width
            height: 52
            color: Style.subtleBg
            border.color: Style.subtleBorder
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                spacing: 8

                // Search Input Field Box
                Rectangle {
                    id: searchInputBox
                    width: parent.width - (clearSearchBtn.visible ? (clearSearchBtn.width + 8) : 0)
                    height: 44
                    anchors.verticalCenter: parent.verticalCenter
                    color: Style.bg
                    border.color: searchInput.activeFocus ? Style.border : Style.subtleBorder
                    border.width: searchInput.activeFocus ? Style.borderWidth : 1
                    radius: Style.cornerRadius

                    Text {
                        id: searchIconText
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search:"
                        font.pixelSize: Style.fontSizeSmall
                        font.bold: true
                        color: searchInput.activeFocus ? Style.fg : Style.subtleFg

                        MouseArea {
                            anchors.fill: parent
                            onClicked: searchInput.forceActiveFocus()
                        }
                    }

                    TextInput {
                        id: searchInput
                        anchors.left: searchIconText.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: Style.fontSizeBody
                        color: Style.fg
                        selectByMouse: true
                        clip: true

                        Text {
                            id: placeholderText
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Filter files by name..."
                            font.pixelSize: Style.fontSizeBody
                            color: Style.subtleBorder
                            visible: searchInput.text.length === 0
                        }

                        onTextChanged: {
                            explorerRoot.searchQuery = text;
                        }

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                explorerRoot.isFilterMenuOpen = false;
                                explorerRoot.inputFocused(searchInput);
                            }
                        }

                        onAccepted: {
                            searchInput.focus = false;
                        }
                    }
                }

                // Clear Search Button
                Rectangle {
                    id: clearSearchBtn
                    width: 80
                    height: 44
                    anchors.verticalCenter: parent.verticalCenter
                    visible: explorerRoot.searchQuery.length > 0
                    color: clearSearchMa.pressed ? Style.invertedBg : Style.bg
                    border.color: Style.border
                    border.width: 1
                    radius: Style.cornerRadius

                    Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        font.pixelSize: Style.fontSizeSmall
                        font.bold: true
                        color: clearSearchMa.pressed ? Style.invertedFg : Style.fg
                    }

                    MouseArea {
                        id: clearSearchMa
                        anchors.fill: parent
                        onClicked: {
                            explorerRoot.clearSearch();
                        }
                    }
                }
            }
        }

        // File List Area
        Item {
            id: fileListContainer
            width: parent.width
            height: parent.height - locationBar.height - searchBarContainer.height - footerBar.height

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
                    text: explorerRoot.searchQuery.trim().length > 0
                          ? "No files match \"" + explorerRoot.searchQuery.trim() + "\""
                          : ((explorerRoot.rawEntries.length > 0) ? "No files match active filters." : "Folder is empty.")
                    font.pixelSize: Style.fontSizeTitle
                    color: Style.subtleFg
                }

                Rectangle {
                    width: 180
                    height: 42
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: emptyClearMa.pressed ? Style.activeHighlight : Style.bg
                    border.color: Style.border
                    border.width: 1
                    radius: Style.cornerRadius
                    visible: explorerRoot.searchQuery.trim().length > 0

                    Text {
                        anchors.centerIn: parent
                        text: "Clear Search"
                        font.pixelSize: Style.fontSizeSmall
                        font.bold: true
                        color: Style.fg
                    }
                    MouseArea {
                        id: emptyClearMa
                        anchors.fill: parent
                        onClicked: {
                            explorerRoot.clearSearch();
                        }
                    }
                }

                Rectangle {
                    width: 180
                    height: 42
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: emptyToggleMa.pressed ? Style.activeHighlight : Style.bg
                    border.color: Style.border
                    border.width: 1
                    radius: Style.cornerRadius
                    visible: explorerRoot.searchQuery.trim().length === 0 && explorerRoot.rawEntries.length > 0 && (explorerRoot.filterOnlyPdfs || !explorerRoot.showHiddenFiles)

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
                        onClicked: {
                            explorerRoot.filterOnlyPdfs = false;
                            explorerRoot.showHiddenFiles = true;
                        }
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
                            explorerRoot.isFilterMenuOpen = false;
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
            id: footerBar
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
                    text: {
                        if (explorerRoot.searchQuery.trim().length > 0) {
                            return explorerRoot.displayEntries.length + " of " + explorerRoot.rawEntries.length + " items";
                        }
                        return explorerRoot.displayEntries.length + " items";
                    }
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

    // Dismiss overlay for filter menu
    MouseArea {
        anchors.fill: parent
        visible: explorerRoot.isFilterMenuOpen
        z: 40
        onClicked: {
            explorerRoot.isFilterMenuOpen = false;
        }
    }

    // Filter Menu Dropdown Card
    Rectangle {
        id: filterMenuCard
        visible: explorerRoot.isFilterMenuOpen
        z: 50
        width: 280
        anchors.top: parent.top
        anchors.topMargin: 64
        anchors.right: parent.right
        anchors.rightMargin: 8
        color: Style.bg
        border.color: Style.border
        border.width: Style.borderWidth
        radius: Style.cornerRadius

        Column {
            width: parent.width
            spacing: 0

            // Menu Header
            Rectangle {
                width: parent.width
                height: 44
                color: Style.subtleBg
                radius: Style.cornerRadius

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Filter Options"
                    font.pixelSize: Style.fontSizeSmall
                    font.bold: true
                    color: Style.fg
                }

                Rectangle {
                    width: 32
                    height: 32
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "X"
                        font.pixelSize: 14
                        font.bold: true
                        color: Style.subtleFg
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: explorerRoot.isFilterMenuOpen = false
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Style.border
            }

            // Option 1: PDFs Only
            Rectangle {
                width: parent.width
                height: 60
                color: pdfOptMa.pressed ? Style.activeHighlight : Style.bg

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Rectangle {
                        width: 26
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        border.color: Style.border
                        border.width: 2
                        radius: 3
                        color: explorerRoot.filterOnlyPdfs ? Style.invertedBg : Style.bg

                        Text {
                            anchors.centerIn: parent
                            text: "X"
                            font.pixelSize: 14
                            font.bold: true
                            color: Style.invertedFg
                            visible: explorerRoot.filterOnlyPdfs
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "PDFs Only"
                            font.pixelSize: Style.fontSizeBody
                            font.bold: true
                            color: Style.fg
                        }

                        Text {
                            text: "Show only PDF files"
                            font.pixelSize: 12
                            color: Style.subtleFg
                        }
                    }
                }

                MouseArea {
                    id: pdfOptMa
                    anchors.fill: parent
                    onClicked: {
                        explorerRoot.filterOnlyPdfs = !explorerRoot.filterOnlyPdfs;
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Style.subtleBorder
            }

            // Option 2: Show Hidden Files
            Rectangle {
                width: parent.width
                height: 60
                color: hiddenOptMa.pressed ? Style.activeHighlight : Style.bg

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Rectangle {
                        width: 26
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        border.color: Style.border
                        border.width: 2
                        radius: 3
                        color: explorerRoot.showHiddenFiles ? Style.invertedBg : Style.bg

                        Text {
                            anchors.centerIn: parent
                            text: "X"
                            font.pixelSize: 14
                            font.bold: true
                            color: Style.invertedFg
                            visible: explorerRoot.showHiddenFiles
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Hidden Files"
                            font.pixelSize: Style.fontSizeBody
                            font.bold: true
                            color: Style.fg
                        }

                        Text {
                            text: "Show dotfiles (.*)"
                            font.pixelSize: 12
                            color: Style.subtleFg
                        }
                    }
                }

                MouseArea {
                    id: hiddenOptMa
                    anchors.fill: parent
                    onClicked: {
                        explorerRoot.showHiddenFiles = !explorerRoot.showHiddenFiles;
                    }
                }
            }
        }
    }
}
