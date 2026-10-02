#ifndef COMMANDEXECUTOR_H
#define COMMANDEXECUTOR_H

#include <QObject>
#include <QProcess>
#include <QProcessEnvironment>
#include <QString>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>

class CommandExecutor : public QObject
{
    Q_OBJECT
public:
    explicit CommandExecutor(QObject *parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE QString executeCommand(const QString &command, const QStringList &arguments)
    {
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.remove("LD_PRELOAD");
        QProcess process;
        process.setProcessEnvironment(env);
        process.start(command, arguments);
        process.waitForFinished();

        QString stdoutStr = QString::fromUtf8(process.readAllStandardOutput());
        QString stderrStr = QString::fromUtf8(process.readAllStandardError());

        QJsonObject outputJson;
        outputJson.insert("stdout", stdoutStr);
        outputJson.insert("stderr", stderrStr);

        QJsonDocument outputDoc(outputJson);
        return QString::fromUtf8(outputDoc.toJson(QJsonDocument::Compact));
    }
};

#endif // COMMANDEXECUTOR_H
