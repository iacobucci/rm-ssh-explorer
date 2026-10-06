#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickView>
#include <QQuickItem>
#include "CommandExecutor.h"


int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_CONTROLS_STYLE", "Default");
    QGuiApplication app(argc, argv);

    qmlRegisterType<CommandExecutor>("net.asivery.CommandExecutor", 1, 0, "CommandExecutor");

    QQuickView view;
    view.setSource(QUrl::fromLocalFile("ui/main.qml"));
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    view.setTitle("SSH Explorer - reMarkable 2 Preview");
    view.resize(702, 936);

    // If --test flag is given, exit cleanly after loading
    bool isTest = false;
    for (int i = 1; i < argc; ++i) {
        if (QString(argv[i]) == "--test") {
            isTest = true;
            break;
        }
    }

    // If --screenshot flag is given, grab window and save to file
    QString screenshotPath = "";
    for (int i = 1; i < argc; ++i) {
        if (QString(argv[i]) == "--screenshot" && i + 1 < argc) {
            screenshotPath = QString(argv[i + 1]);
            break;
        }
    }

    if (isTest) {
        if (view.status() == QQuickView::Error) {
            return 1;
        }
        return 0;
    }

    if (!screenshotPath.isEmpty()) {
        view.show();

        // Check for specific test screen state
        for (int i = 1; i < argc; ++i) {
            if (QString(argv[i]) == "--screen" && i + 1 < argc) {
                QString screenName = QString(argv[i + 1]);
                QObject *rootObj = view.rootObject();
                if (rootObj) {
                    if (screenName == "keyboard") {
                        QMetaObject::invokeMethod(rootObj, "setProperty", Q_ARG(const char*, "currentMode"), Q_ARG(QVariant, "connection"));
                        QObject *vk = rootObj->findChild<QObject*>("virtualKeyboard");
                        if (vk) vk->setProperty("visible", true);
                    } else if (screenName == "explorer" || screenName == "search") {
                        rootObj->setProperty("currentMode", "explorer");
                        rootObj->setProperty("activeHost", "192.168.1.50");
                        rootObj->setProperty("activeUser", "valerio");
                        QObject *ev = rootObj->findChild<QObject*>("explorerView");
                        if (ev) {
                            ev->setProperty("currentPath", "/home/valerio/documents");
                            ev->setProperty("parentPath", "/home/valerio");
                            QVariantList list;
                            QVariantMap d1; d1["name"] = "Ebooks"; d1["type"] = "dir"; d1["is_pdf"] = false; d1["size"] = 0; d1["size_str"] = ""; list.append(d1);
                            QVariantMap d2; d2["name"] = "Papers"; d2["type"] = "dir"; d2["is_pdf"] = false; d2["size"] = 0; d2["size_str"] = ""; list.append(d2);
                            QVariantMap f1; f1["name"] = "Remarkable_Manual.pdf"; f1["type"] = "file"; f1["is_pdf"] = true; f1["size"] = 5242880; f1["size_str"] = "5.0 MB"; list.append(f1);
                            QVariantMap f2; f2["name"] = "Research_Paper.pdf"; f2["type"] = "file"; f2["is_pdf"] = true; f2["size"] = 1258291; f2["size_str"] = "1.2 MB"; list.append(f2);
                            QVariantMap f3; f3["name"] = "notes.txt"; f3["type"] = "file"; f3["is_pdf"] = false; f3["size"] = 1024; f3["size_str"] = "1.0 KB"; list.append(f3);
                            QVariantMap h1; h1["name"] = ".config"; h1["type"] = "dir"; h1["is_pdf"] = false; h1["size"] = 0; h1["size_str"] = ""; list.append(h1);
                            QVariantMap h2; h2["name"] = ".bashrc"; h2["type"] = "file"; h2["is_pdf"] = false; h2["size"] = 256; h2["size_str"] = "256 B"; list.append(h2);
                            ev->setProperty("rawEntries", list);
                            if (screenName == "search") {
                                ev->setProperty("searchQuery", "manual");
                                ev->setProperty("isSearchActive", true);
                                QVariantList sList;
                                QVariantMap sf1;
                                sf1["name"] = "Remarkable_Manual.pdf";
                                sf1["path"] = "/home/valerio/documents/Remarkable_Manual.pdf";
                                sf1["rel_path"] = "Remarkable_Manual.pdf";
                                sf1["sub_dir"] = "";
                                sf1["type"] = "file";
                                sf1["is_pdf"] = true;
                                sf1["size"] = 5242880;
                                sf1["size_str"] = "5.0 MB";
                                sList.append(sf1);

                                QVariantMap sf2;
                                sf2["name"] = "Quick_Start_Manual.pdf";
                                sf2["path"] = "/home/valerio/documents/Ebooks/Hardware/Quick_Start_Manual.pdf";
                                sf2["rel_path"] = "Ebooks/Hardware/Quick_Start_Manual.pdf";
                                sf2["sub_dir"] = "Ebooks/Hardware";
                                sf2["type"] = "file";
                                sf2["is_pdf"] = true;
                                sf2["size"] = 2097152;
                                sf2["size_str"] = "2.0 MB";
                                sList.append(sf2);

                                ev->setProperty("searchEntries", sList);
                            }
                        }
                    }
                }
                break;
            }
        }

        for (int i = 0; i < 20; ++i) {
            app.processEvents();
        }
        QImage img = view.grabWindow();
        img.save(screenshotPath);
        return 0;
    }

    view.show();
    return app.exec();

}
