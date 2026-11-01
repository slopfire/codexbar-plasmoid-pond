import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: harness

    Layout.minimumWidth: 900
    Layout.minimumHeight: 640
    width: 900
    height: 640

    property int attempts: 0
    property bool resultRecorded: false

    Plasma5Support.DataSource {
        id: resultMarker
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName) { disconnectSource(sourceName); }
    }

    Loader {
        id: providersLoader
        anchors.fill: parent
        source: "../../../../plasmoid/contents/ui/configProviders.qml"

        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("CONFIG_SMOKE_FAIL loader error");
                Qt.quit();
            }
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: !harness.resultRecorded
        onTriggered: {
            harness.attempts += 1;
            const page = providersLoader.item;
            if (!page || page.accountDiscoveryBusy) {
                if (harness.attempts < 150) {
                    return;
                }
                console.error("CONFIG_SMOKE_FAIL account discovery timeout");
                Qt.quit();
                return;
            }

            const detected = page.discoveredAccounts.codex || [];
            if (detected.indexOf("mock-codex@example.com") >= 0) {
                page.setAccountSelection(0, "selected", ["home@example.com", "work@example.com"]);
                let saved = JSON.parse(page.cfg_providerConfigs)[0];
                if (saved.accounts.length !== 2 || saved.accountMode !== "selected" || saved.account || saved.allAccounts) {
                    console.error("CONFIG_SMOKE_FAIL selected accounts did not round-trip");
                    Qt.quit(); return;
                }
                page.toggleAccount(0, "home@example.com", false);
                saved = JSON.parse(page.cfg_providerConfigs)[0];
                if (saved.accounts.length !== 1 || saved.accounts[0] !== "work@example.com") {
                    console.error("CONFIG_SMOKE_FAIL account removal did not round-trip");
                    Qt.quit(); return;
                }
                page.setProviderProperty(0, "apiKey", "synthetic-private-key");
                if (JSON.stringify(page.accountDiscoveryConfigs(0)).indexOf("synthetic-private-key") >= 0) {
                    console.error("CONFIG_SMOKE_FAIL discovery exposed a key");
                    Qt.quit(); return;
                }
                page.addAccountProfile(0);
                const profiles = JSON.parse(page.cfg_providerConfigs);
                if (profiles[1].apiKey || profiles[1].accountMode !== "active" || profiles[1].accounts.length) {
                    console.error("CONFIG_SMOKE_FAIL new profile reused credentials or account selection");
                    Qt.quit(); return;
                }
                // The "Sync all from server" toggle must round-trip through the
                // page property so KConfigXT persists it on Apply.
                page.cfg_syncAllFromServer = true;
                if (page.cfg_syncAllFromServer !== true) {
                    console.error("CONFIG_SMOKE_FAIL sync-all toggle did not round-trip");
                    Qt.quit();
                    return;
                }
                page.cfg_syncAllFromServer = false;
                harness.resultRecorded = true;
                resultMarker.connectSource("/usr/bin/touch /tmp/codexbar-config-smoke.pass");
                return;
            }
            if (harness.attempts >= 150) {
                console.error(
                    "CONFIG_SMOKE_FAIL detected=" + JSON.stringify(detected)
                    + " status=" + String(page.accountDiscoveryStatus)
                );
                Qt.quit();
            }
        }
    }
}
