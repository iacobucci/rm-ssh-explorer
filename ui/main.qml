import QtQuick 2.5
import QtQuick.Controls 2.5
import net.asivery.CommandExecutor 1.0
import "."

Rectangle {
    id: appRoot
    anchors.fill: parent
    color: Style.bg

    // AppLoad signals & lifecycle
    signal close
    function unloading() {
        console.log("[SSH Explorer] Unloading application");
    }

    // App State
    property string currentMode: "connection" // "connection" or "explorer"
    property var configData: ({ "profiles": [], "activeProfile": "Default" })
    property string activeHost: ""
    property int activePort: 22
    property string activeUser: "root"
    property string activeKey: "/home/root/.ssh/id_dropbear"
    property string activeRemotePath: "~"

    // CommandExecutor instance from XOVI
    CommandExecutor {
        id: cmdExecutor
    }

    // Helper runner executing /bin/sh ssh-helper.sh <subcommand> <args...>
    function runHelper(subcommand, args) {
        var paths = [
            "/home/root/xovi/exthome/appload/ssh-explorer/ssh-helper.sh",
            "./ssh-helper.sh",
            "ssh-helper.sh"
        ];
        
        var resStr = "";
        for (var i = 0; i < paths.length; i++) {
            var fullArgs = [paths[i], subcommand].concat(args);
            resStr = cmdExecutor.executeCommand("/bin/sh", fullArgs);
            if (resStr && resStr.indexOf("No such file") === -1) {
                break;
            }
        }

        try {
            var procOut = JSON.parse(resStr);
            var stdoutStr = procOut.stdout ? procOut.stdout.trim() : "";
            if (stdoutStr.length > 0) {
                var firstBrace = stdoutStr.indexOf("{");
                var lastBrace = stdoutStr.lastIndexOf("}");
                if (firstBrace !== -1 && lastBrace !== -1 && lastBrace >= firstBrace) {
                    var jsonStr = stdoutStr.substring(firstBrace, lastBrace + 1);
                    return JSON.parse(jsonStr);
                }
                return { success: false, error: stdoutStr };
            } else if (procOut.stderr && procOut.stderr.trim().length > 0) {
                return { success: false, error: procOut.stderr.trim() };
            }
            return { success: false, error: "Empty response from helper" };
        } catch (e) {
            return { success: false, error: "Failed to parse helper output: " + resStr };
        }
    }

    // Config Management
    function loadConfig() {
        var res = runHelper("load-config", []);
        if (res && res.profiles) {
            configData = res;
            connectionView.profiles = res.profiles;
            var profToLoad = null;
            for (var i = 0; i < res.profiles.length; i++) {
                if (res.profiles[i].name === res.activeProfile) {
                    profToLoad = res.profiles[i];
                    break;
                }
            }
            if (!profToLoad && res.profiles.length > 0) {
                profToLoad = res.profiles[0];
            }
            if (profToLoad) {
                connectionView.loadProfile(profToLoad);
            }
        }
    }

    function saveProfile(name, host, port, user, key, path) {
        var profiles = configData.profiles || [];
        var updated = false;
        for (var i = 0; i < profiles.length; i++) {
            if (profiles[i].name === name) {
                profiles[i].host = host;
                profiles[i].port = port;
                profiles[i].user = user;
                profiles[i].key = key;
                profiles[i].remotePath = path;
                updated = true;
                break;
            }
        }
        if (!updated) {
            profiles.push({
                name: name,
                host: host,
                port: port,
                user: user,
                key: key,
                remotePath: path
            });
        }
        configData.profiles = profiles;
        configData.activeProfile = name;
        connectionView.profiles = profiles;

        var jsonStr = JSON.stringify(configData);
        var res = runHelper("save-config", [jsonStr]);
        if (res && res.success) {
            connectionView.statusMessage = "Profile '" + name + "' saved successfully";
            connectionView.testSuccess = true;
        } else {
            connectionView.statusMessage = "Failed to save profile: " + (res ? res.error : "Unknown error");
            connectionView.testSuccess = false;
        }
    }

    function deleteProfile(name) {
        var profiles = configData.profiles || [];
        var newProfiles = [];
        for (var i = 0; i < profiles.length; i++) {
            if (profiles[i].name !== name) {
                newProfiles.push(profiles[i]);
            }
        }
        if (newProfiles.length === 0) {
            newProfiles.push({
                name: "Default",
                host: "",
                port: 22,
                user: "root",
                key: "/home/root/.ssh/id_dropbear",
                remotePath: "~"
            });
        }
        configData.profiles = newProfiles;
        configData.activeProfile = newProfiles[0].name;
        connectionView.profiles = newProfiles;
        connectionView.loadProfile(newProfiles[0]);

        var jsonStr = JSON.stringify(configData);
        var res = runHelper("save-config", [jsonStr]);
        if (res && res.success) {
            connectionView.statusMessage = "Profile '" + name + "' deleted successfully";
            connectionView.testSuccess = true;
        } else {
            connectionView.statusMessage = "Failed to delete profile: " + (res ? res.error : "Unknown error");
            connectionView.testSuccess = false;
        }
    }

    // Connection & Navigation
    function startBrowse(host, port, user, key, initialPath) {
        activeHost = host;
        activePort = port;
        activeUser = user;
        activeKey = key;
        activeRemotePath = initialPath;

        virtualKeyboard.visible = false;
        currentMode = "explorer";
        fetchDirectory(initialPath);
    }

    function fetchDirectory(path) {
        explorerView.isLoading = true;
        explorerView.errorMessage = "";

        // Small timer to let UI render the loading spinner on e-ink
        fetchTimer.targetPath = path;
        fetchTimer.restart();
    }

    Timer {
        id: fetchTimer
        property string targetPath: ""
        interval: 50
        repeat: false
        onTriggered: {
            var res = appRoot.runHelper("list-dir", [
                appRoot.activeHost,
                appRoot.activePort.toString(),
                appRoot.activeUser,
                appRoot.activeKey,
                fetchTimer.targetPath
            ]);

            explorerView.isLoading = false;
            if (res && res.success) {
                explorerView.currentPath = res.path;
                explorerView.parentPath = res.parent;
                explorerView.rawEntries = res.entries || [];
            } else {
                explorerView.errorMessage = res ? res.error : "Failed to communicate with remote host";
            }
        }
    }

    function searchDirectory(path, query) {
        explorerView.isSearching = true;
        explorerView.isLoading = true;
        explorerView.errorMessage = "";

        searchTimer.targetPath = path;
        searchTimer.searchQuery = query;
        searchTimer.restart();
    }

    Timer {
        id: searchTimer
        property string targetPath: ""
        property string searchQuery: ""
        interval: 50
        repeat: false
        onTriggered: {
            var res = appRoot.runHelper("search-dir", [
                appRoot.activeHost,
                appRoot.activePort.toString(),
                appRoot.activeUser,
                appRoot.activeKey,
                searchTimer.targetPath,
                searchTimer.searchQuery
            ]);

            explorerView.isLoading = false;
            explorerView.isSearching = false;
            if (res && res.success) {
                explorerView.setSearchResults(res.entries || [], searchTimer.searchQuery);
            } else {
                explorerView.errorMessage = res ? res.error : "Failed to search remote directory";
            }
        }
    }

    // PDF Import Execution
    function executeImport(remoteFilePath, title) {
        importModal.isWorking = true;
        importModal.statusText = "Downloading and importing PDF...";

        importTimer.remotePath = remoteFilePath;
        importTimer.docTitle = title;
        importTimer.restart();
    }

    function restartXochitl() {
        runHelper("restart-xochitl", []);
        appRoot.close();
    }

    Timer {
        id: importTimer
        property string remotePath: ""
        property string docTitle: ""
        interval: 50
        repeat: false
        onTriggered: {
            var res = appRoot.runHelper("import-pdf", [
                appRoot.activeHost,
                appRoot.activePort.toString(),
                appRoot.activeUser,
                appRoot.activeKey,
                importTimer.remotePath,
                importTimer.docTitle
            ]);

            importModal.isWorking = false;
            if (res && res.success) {
                importModal.isSuccess = true;
                importModal.importMethod = res.method || "";
                importModal.statusText = res.message || "Import completed successfully.";
            } else {
                importModal.isError = true;
                importModal.errorMessage = res ? res.error : "Import failed.";
            }
        }
    }

    Component.onCompleted: {
        loadConfig();
    }

    // Top Navigation Header
    Rectangle {
        id: topNav
        width: parent.width
        height: 70
        color: Style.invertedBg
        z: 10

        // Left Branding & Status
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "SSH Explorer"
                font.pixelSize: Style.fontSizeHeader
                font.bold: true
                color: Style.invertedFg
            }

            Rectangle {
                height: 36
                width: hostStatusText.width + 20
                radius: 4
                color: appRoot.currentMode === "explorer" ? Style.bg : "#333333"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: hostStatusText
                    anchors.centerIn: parent
                    text: appRoot.currentMode === "explorer" ? (appRoot.activeUser + "@" + appRoot.activeHost) : "Not Connected"
                    font.pixelSize: Style.fontSizeSmall
                    font.bold: true
                    color: appRoot.currentMode === "explorer" ? Style.fg : "#AAAAAA"
                }
            }
        }

        // Right Navigation Action Buttons
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // Profiles / Setup Button
            Rectangle {
                width: 120
                height: 44
                color: pNavMa.pressed ? Style.subtleBg : Style.bg
                radius: Style.cornerRadius
                visible: appRoot.currentMode === "explorer"

                Text {
                    anchors.centerIn: parent
                    text: "Profiles"
                    font.pixelSize: Style.fontSizeSmall
                    font.bold: true
                    color: Style.fg
                }
                MouseArea {
                    id: pNavMa
                    anchors.fill: parent
                    onClicked: {
                        virtualKeyboard.visible = false;
                        appRoot.currentMode = "connection";
                    }
                }
            }

            // Quick Reload Library (Restart xochitl)
            Rectangle {
                width: 150
                height: 44
                color: rstNavMa.pressed ? Style.subtleBg : Style.bg
                radius: Style.cornerRadius

                Text {
                    anchors.centerIn: parent
                    text: "Restart xochitl"
                    font.pixelSize: Style.fontSizeSmall
                    font.bold: true
                    color: Style.fg
                }
                MouseArea {
                    id: rstNavMa
                    anchors.fill: parent
                    onClicked: {
                        appRoot.restartXochitl();
                    }
                }
            }

            // Close Application Button
            Rectangle {
                width: 80
                height: 44
                color: closeMa.pressed ? Style.activeHighlight : Style.bg
                radius: Style.cornerRadius

                Text {
                    anchors.centerIn: parent
                    text: "Exit"
                    font.pixelSize: Style.fontSizeSmall
                    font.bold: true
                    color: Style.fg
                }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    onClicked: {
                        appRoot.close();
                    }
                }
            }
        }
    }

    // Main Content Views
    Item {
        id: viewContainer
        width: parent.width
        anchors.top: topNav.bottom
        anchors.bottom: virtualKeyboard.visible ? virtualKeyboard.top : parent.bottom

        // Connection View
        ConnectionView {
            id: connectionView
            anchors.fill: parent
            visible: appRoot.currentMode === "connection"

            onRequestConnect: (h, p, u, k, path) => {
                appRoot.startBrowse(h, p, u, k, path);
            }

            onRequestTest: (h, p, u, k) => {
                connectionView.isTesting = true;
                connectionView.statusMessage = "";
                testTimer.testHost = h;
                testTimer.testPort = p;
                testTimer.testUser = u;
                testTimer.testKey = k;
                testTimer.restart();
            }

            onRequestSaveProfile: (name, h, p, u, k, path) => {
                appRoot.saveProfile(name, h, p, u, k, path);
            }

            onRequestDeleteProfile: (name) => {
                virtualKeyboard.visible = false;
                appRoot.deleteProfile(name);
            }

            onInputFocused: (item) => {
                virtualKeyboard.targetInput = item;
                virtualKeyboard.visible = true;
            }
        }

        Timer {
            id: testTimer
            property string testHost: ""
            property int testPort: 22
            property string testUser: "root"
            property string testKey: ""
            interval: 50
            repeat: false
            onTriggered: {
                var res = appRoot.runHelper("test-connection", [
                    testTimer.testHost,
                    testTimer.testPort.toString(),
                    testTimer.testUser,
                    testTimer.testKey
                ]);

                connectionView.isTesting = false;
                if (res && res.success) {
                    connectionView.testSuccess = true;
                    connectionView.statusMessage = "Connection test succeeded!";
                } else {
                    connectionView.testSuccess = false;
                    connectionView.statusMessage = "Connection failed: " + (res ? res.error : "Unknown error");
                }
            }
        }

        // Explorer View
        ExplorerView {
            id: explorerView
            objectName: "explorerView"
            anchors.fill: parent
            visible: appRoot.currentMode === "explorer"

            onNavigateTo: (path) => {
                virtualKeyboard.visible = false;
                appRoot.fetchDirectory(path);
            }

            onRefreshRequested: {
                if (explorerView.isSearchActive && explorerView.searchQuery.length > 0) {
                    appRoot.searchDirectory(explorerView.currentPath, explorerView.searchQuery);
                } else {
                    appRoot.fetchDirectory(explorerView.currentPath);
                }
            }

            onSearchRequested: (query) => {
                virtualKeyboard.visible = false;
                appRoot.searchDirectory(explorerView.currentPath, query);
            }

            onPdfSelected: (path, name, sizeStr, size) => {
                virtualKeyboard.visible = false;
                importModal.remotePath = path;
                importModal.fileName = name;
                importModal.fileSizeStr = sizeStr;
                importModal.fileSize = size;
                importModal.reset();
                importModal.visible = true;
            }

            onInputFocused: (item) => {
                virtualKeyboard.targetInput = item;
                virtualKeyboard.visible = true;
            }
        }
    }

    // Virtual On-Screen Keyboard
    VirtualKeyboard {
        id: virtualKeyboard
        objectName: "virtualKeyboard"
        anchors.bottom: parent.bottom
        visible: false
        z: 30
    }

    // Import Dialog Modal
    ImportModal {
        id: importModal
        visible: false
        z: 40

        onRequestImport: (path, title) => {
            appRoot.executeImport(path, title);
        }

        onRequestRestartXochitl: {
            appRoot.restartXochitl();
        }

        onRequestClose: {
            importModal.visible = false;
        }

        onInputFocused: (item) => {
            virtualKeyboard.targetInput = item;
            virtualKeyboard.visible = true;
        }
    }
}
