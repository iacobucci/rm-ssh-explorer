import QtQuick 2.5
import "."

Item {
    id: connectionViewRoot

    property var profiles: []
    property string activeProfileName: "Default"

    property string host: ""
    property int port: 22
    property string user: "root"
    property string keyPath: "/home/root/.ssh/id_dropbear"
    property string remotePath: "~"

    property string statusMessage: ""
    property bool isTesting: false
    property bool testSuccess: false

    property bool isCurrentProfileSaved: {
        if (!profiles) return false;
        for (var i = 0; i < profiles.length; i++) {
            if (profiles[i].name === activeProfileName) {
                return true;
            }
        }
        return false;
    }

    signal requestConnect(string host, int port, string user, string key, string path)
    signal requestTest(string host, int port, string user, string key)
    signal requestSaveProfile(string name, string host, int port, string user, string key, string path)
    signal requestDeleteProfile(string name)
    signal inputFocused(var item)

    function loadProfile(p) {
        if (!p) return;
        activeProfileName = p.name || "Default";
        host = p.host || "";
        port = p.port || 22;
        user = p.user || "root";
        keyPath = p.key !== undefined ? p.key : "/home/root/.ssh/id_dropbear";
        remotePath = p.remotePath || "~";
        statusMessage = "";
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.height + 40
        clip: true

        Column {
            id: contentCol
            width: Math.min(parent.width - 40, 720)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: Style.spacing * 1.2

            // Section Header
            Row {
                width: parent.width
                spacing: 12
                Text {
                    text: "SSH Connection Setup"
                    font.pixelSize: Style.fontSizeHeader
                    font.bold: true
                    color: Style.fg
                }
            }

            Rectangle {
                width: parent.width
                height: 2
                color: Style.border
            }

            // Saved Profiles Row
            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: "Saved Profiles:"
                    font.pixelSize: Style.fontSizeSmall
                    font.bold: true
                    color: Style.subtleFg
                }

                Flow {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: connectionViewRoot.profiles
                        delegate: Rectangle {
                            height: 38
                            width: profText.width + 24
                            color: (connectionViewRoot.activeProfileName === modelData.name) ? Style.invertedBg : (pMa.pressed ? Style.activeHighlight : Style.bg)
                            border.color: Style.border
                            border.width: 1
                            radius: Style.cornerRadius

                            Text {
                                id: profText
                                anchors.centerIn: parent
                                text: modelData.name
                                font.pixelSize: Style.fontSizeSmall
                                font.bold: true
                                color: (connectionViewRoot.activeProfileName === modelData.name) ? Style.invertedFg : Style.fg
                            }

                            MouseArea {
                                id: pMa
                                anchors.fill: parent
                                onClicked: connectionViewRoot.loadProfile(modelData)
                            }
                        }
                    }

                    // "+ New Profile" button
                    Rectangle {
                        height: 38
                        width: newProfText.width + 20
                        color: newMa.pressed ? Style.activeHighlight : Style.subtleBg
                        border.color: Style.subtleBorder
                        border.width: 1
                        radius: Style.cornerRadius

                        Text {
                            id: newProfText
                            anchors.centerIn: parent
                            text: "+ New"
                            font.pixelSize: Style.fontSizeSmall
                            color: Style.fg
                        }
                        MouseArea {
                            id: newMa
                            anchors.fill: parent
                            onClicked: {
                                connectionViewRoot.activeProfileName = "Server " + (connectionViewRoot.profiles.length + 1);
                                connectionViewRoot.host = "";
                                connectionViewRoot.port = 22;
                                connectionViewRoot.user = "root";
                                connectionViewRoot.keyPath = "/home/root/.ssh/id_dropbear";
                                connectionViewRoot.remotePath = "~";
                                connectionViewRoot.statusMessage = "";
                            }
                        }
                    }
                }
            }

            // Input Fields Card
            Rectangle {
                width: parent.width
                height: formCol.height + 24
                color: Style.bg
                border.color: Style.subtleBorder
                border.width: 1
                radius: Style.cornerRadius

                Column {
                    id: formCol
                    width: parent.width - 24
                    anchors.centerIn: parent
                    spacing: 10

                    // Profile Name
                    Row {
                        width: parent.width
                        spacing: 12
                        Text {
                            width: 130
                            text: "Profile Name:"
                            font.pixelSize: Style.fontSizeBody
                            anchors.verticalCenter: parent.verticalCenter
                            color: Style.fg
                        }
                        Rectangle {
                            width: parent.width - 142
                            height: Style.inputHeight
                            color: Style.bg
                            border.color: pNameInp.activeFocus ? Style.border : Style.subtleBorder
                            border.width: pNameInp.activeFocus ? Style.borderWidth : 1
                            radius: 3
                            TextInput {
                                id: pNameInp
                                anchors.fill: parent
                                anchors.margins: 10
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: Style.fontSizeBody
                                text: connectionViewRoot.activeProfileName
                                color: Style.fg
                                selectByMouse: true
                                onTextChanged: connectionViewRoot.activeProfileName = text
                                onActiveFocusChanged: if (activeFocus) connectionViewRoot.inputFocused(pNameInp)
                            }
                        }
                    }

                    // Host & Port
                    Row {
                        width: parent.width
                        spacing: 12
                        Text {
                            width: 130
                            text: "Host / IP:"
                            font.pixelSize: Style.fontSizeBody
                            anchors.verticalCenter: parent.verticalCenter
                            color: Style.fg
                        }
                        Rectangle {
                            width: parent.width - 142 - 130
                            height: Style.inputHeight
                            color: Style.bg
                            border.color: hostInp.activeFocus ? Style.border : Style.subtleBorder
                            border.width: hostInp.activeFocus ? Style.borderWidth : 1
                            radius: 3
                            TextInput {
                                id: hostInp
                                anchors.fill: parent
                                anchors.margins: 10
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: Style.fontSizeBody
                                text: connectionViewRoot.host
                                color: Style.fg
                                selectByMouse: true
                                onTextChanged: connectionViewRoot.host = text
                                onActiveFocusChanged: if (activeFocus) connectionViewRoot.inputFocused(hostInp)
                            }
                        }
                        Text {
                            text: "Port:"
                            font.pixelSize: Style.fontSizeBody
                            anchors.verticalCenter: parent.verticalCenter
                            color: Style.fg
                        }
                        Rectangle {
                            width: 70
                            height: Style.inputHeight
                            color: Style.bg
                            border.color: portInp.activeFocus ? Style.border : Style.subtleBorder
                            border.width: portInp.activeFocus ? Style.borderWidth : 1
                            radius: 3
                            TextInput {
                                id: portInp
                                anchors.fill: parent
                                anchors.margins: 10
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: Style.fontSizeBody
                                text: connectionViewRoot.port.toString()
                                color: Style.fg
                                selectByMouse: true
                                onTextChanged: {
                                    var val = parseInt(text);
                                    if (!isNaN(val)) connectionViewRoot.port = val;
                                }
                                onActiveFocusChanged: if (activeFocus) connectionViewRoot.inputFocused(portInp)
                            }
                        }
                    }

                    // User
                    Row {
                        width: parent.width
                        spacing: 12
                        Text {
                            width: 130
                            text: "User:"
                            font.pixelSize: Style.fontSizeBody
                            anchors.verticalCenter: parent.verticalCenter
                            color: Style.fg
                        }
                        Rectangle {
                            width: parent.width - 142
                            height: Style.inputHeight
                            color: Style.bg
                            border.color: userInp.activeFocus ? Style.border : Style.subtleBorder
                            border.width: userInp.activeFocus ? Style.borderWidth : 1
                            radius: 3
                            TextInput {
                                id: userInp
                                anchors.fill: parent
                                anchors.margins: 10
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: Style.fontSizeBody
                                text: connectionViewRoot.user
                                color: Style.fg
                                selectByMouse: true
                                onTextChanged: connectionViewRoot.user = text
                                onActiveFocusChanged: if (activeFocus) connectionViewRoot.inputFocused(userInp)
                            }
                        }
                    }

                    // Key Path
                    Row {
                        width: parent.width
                        spacing: 12
                        Text {
                            width: 130
                            text: "SSH Key Path:"
                            font.pixelSize: Style.fontSizeBody
                            anchors.verticalCenter: parent.verticalCenter
                            color: Style.fg
                        }
                        Rectangle {
                            width: parent.width - 142
                            height: Style.inputHeight
                            color: Style.bg
                            border.color: keyInp.activeFocus ? Style.border : Style.subtleBorder
                            border.width: keyInp.activeFocus ? Style.borderWidth : 1
                            radius: 3
                            TextInput {
                                id: keyInp
                                anchors.fill: parent
                                anchors.margins: 10
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: Style.fontSizeSmall
                                text: connectionViewRoot.keyPath
                                color: Style.fg
                                selectByMouse: true
                                onTextChanged: connectionViewRoot.keyPath = text
                                onActiveFocusChanged: if (activeFocus) connectionViewRoot.inputFocused(keyInp)
                            }
                        }
                    }

                    // Remote Path
                    Row {
                        width: parent.width
                        spacing: 12
                        Text {
                            width: 130
                            text: "Initial Path:"
                            font.pixelSize: Style.fontSizeBody
                            anchors.verticalCenter: parent.verticalCenter
                            color: Style.fg
                        }
                        Rectangle {
                            width: parent.width - 142
                            height: Style.inputHeight
                            color: Style.bg
                            border.color: pathInp.activeFocus ? Style.border : Style.subtleBorder
                            border.width: pathInp.activeFocus ? Style.borderWidth : 1
                            radius: 3
                            TextInput {
                                id: pathInp
                                anchors.fill: parent
                                anchors.margins: 10
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: Style.fontSizeBody
                                text: connectionViewRoot.remotePath
                                color: Style.fg
                                selectByMouse: true
                                onTextChanged: connectionViewRoot.remotePath = text
                                onActiveFocusChanged: if (activeFocus) connectionViewRoot.inputFocused(pathInp)
                            }
                        }
                    }
                }
            }

            // Status feedback banner
            Rectangle {
                width: parent.width
                height: statusTextItem.height + 18
                color: connectionViewRoot.testSuccess ? Style.subtleBg : "#FAFAFA"
                border.color: connectionViewRoot.testSuccess ? Style.border : (connectionViewRoot.statusMessage !== "" ? Style.subtleBorder : "transparent")
                border.width: 1
                radius: Style.cornerRadius
                visible: connectionViewRoot.statusMessage !== "" || connectionViewRoot.isTesting

                Text {
                    id: statusTextItem
                    anchors.centerIn: parent
                    width: parent.width - 24
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Style.fontSizeSmall
                    font.bold: connectionViewRoot.testSuccess
                    text: connectionViewRoot.isTesting ? "Testing SSH connection to " + connectionViewRoot.host + "..." : connectionViewRoot.statusMessage
                    color: Style.fg
                }
            }

            // Action Buttons
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    // Test Button
                    Rectangle {
                        width: 170
                        height: Style.buttonHeight
                        color: testMa.pressed ? Style.activeHighlight : Style.bg
                        border.color: Style.border
                        border.width: Style.borderWidth
                        radius: Style.cornerRadius

                        Text {
                            anchors.centerIn: parent
                            text: connectionViewRoot.isTesting ? "Testing..." : "Test Connection"
                            font.pixelSize: Style.fontSizeBody
                            font.bold: true
                            color: Style.fg
                        }
                        MouseArea {
                            id: testMa
                            anchors.fill: parent
                            enabled: !connectionViewRoot.isTesting && connectionViewRoot.host !== ""
                            onClicked: {
                                connectionViewRoot.requestTest(connectionViewRoot.host, connectionViewRoot.port, connectionViewRoot.user, connectionViewRoot.keyPath);
                            }
                        }
                    }

                    // Delete Profile Button
                    Rectangle {
                        width: 150
                        height: Style.buttonHeight
                        color: !connectionViewRoot.isCurrentProfileSaved ? Style.subtleBg : (delMa.pressed ? Style.activeHighlight : Style.bg)
                        border.color: !connectionViewRoot.isCurrentProfileSaved ? Style.subtleBorder : Style.border
                        border.width: Style.borderWidth
                        radius: Style.cornerRadius
                        opacity: connectionViewRoot.isCurrentProfileSaved ? 1.0 : 0.4

                        Text {
                            anchors.centerIn: parent
                            text: "Delete Profile"
                            font.pixelSize: Style.fontSizeBody
                            font.bold: true
                            color: !connectionViewRoot.isCurrentProfileSaved ? Style.subtleFg : Style.fg
                        }
                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            enabled: connectionViewRoot.isCurrentProfileSaved
                            onClicked: {
                                deleteModal.visible = true;
                            }
                        }
                    }

                    // Save Profile Button
                    Rectangle {
                        width: 150
                        height: Style.buttonHeight
                        color: saveMa.pressed ? Style.activeHighlight : Style.bg
                        border.color: Style.border
                        border.width: Style.borderWidth
                        radius: Style.cornerRadius

                        Text {
                            anchors.centerIn: parent
                            text: "Save Profile"
                            font.pixelSize: Style.fontSizeBody
                            font.bold: true
                            color: Style.fg
                        }
                        MouseArea {
                            id: saveMa
                            anchors.fill: parent
                            onClicked: {
                                connectionViewRoot.requestSaveProfile(
                                    connectionViewRoot.activeProfileName,
                                    connectionViewRoot.host,
                                    connectionViewRoot.port,
                                    connectionViewRoot.user,
                                    connectionViewRoot.keyPath,
                                    connectionViewRoot.remotePath
                                );
                            }
                        }
                    }
                }

                // Connect & Explore Button
                Rectangle {
                    width: 340
                    height: Style.buttonHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: connMa.pressed ? Style.bg : Style.invertedBg
                    border.color: Style.border
                    border.width: Style.borderWidth
                    radius: Style.cornerRadius

                    Text {
                        anchors.centerIn: parent
                        text: "Connect & Explore"
                        font.pixelSize: Style.fontSizeBody
                        font.bold: true
                        color: connMa.pressed ? Style.invertedBg : Style.invertedFg
                    }
                    MouseArea {
                        id: connMa
                        anchors.fill: parent
                        enabled: connectionViewRoot.host !== ""
                        onClicked: {
                            connectionViewRoot.requestConnect(
                                connectionViewRoot.host,
                                connectionViewRoot.port,
                                connectionViewRoot.user,
                                connectionViewRoot.keyPath,
                                connectionViewRoot.remotePath
                            );
                        }
                    }
                }
            }

            Item { width: 1; height: 20 }
        }
    }

    // Delete Confirmation Modal
    Rectangle {
        id: deleteModal
        anchors.fill: parent
        color: "#80000000"
        visible: false
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: deleteModal.visible = false
        }

        Rectangle {
            width: Math.min(parent.width - 40, 500)
            height: 220
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
                anchors.margins: 22
                spacing: 14

                Text {
                    text: "Delete Profile"
                    font.pixelSize: Style.fontSizeTitle
                    font.bold: true
                    color: Style.fg
                }

                Text {
                    width: parent.width
                    text: "Are you sure you want to delete profile \"" + connectionViewRoot.activeProfileName + "\"?"
                    font.pixelSize: Style.fontSizeBody
                    wrapMode: Text.WordWrap
                    color: Style.fg
                }

                Item { width: 1; height: 6 }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    Rectangle {
                        width: 140
                        height: Style.buttonHeight
                        color: cancelDelMa.pressed ? Style.activeHighlight : Style.bg
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
                            id: cancelDelMa
                            anchors.fill: parent
                            onClicked: deleteModal.visible = false
                        }
                    }

                    Rectangle {
                        width: 140
                        height: Style.buttonHeight
                        color: confirmDelMa.pressed ? Style.bg : Style.invertedBg
                        border.color: Style.border
                        border.width: Style.borderWidth
                        radius: Style.cornerRadius

                        Text {
                            anchors.centerIn: parent
                            text: "Delete"
                            font.pixelSize: Style.fontSizeBody
                            font.bold: true
                            color: confirmDelMa.pressed ? Style.invertedBg : Style.invertedFg
                        }
                        MouseArea {
                            id: confirmDelMa
                            anchors.fill: parent
                            onClicked: {
                                deleteModal.visible = false;
                                connectionViewRoot.requestDeleteProfile(connectionViewRoot.activeProfileName);
                            }
                        }
                    }
                }
            }
        }
    }
}
