pragma Singleton

import ".."
import qs.config
import qs.utils
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

Searcher {
    id: root

    function transformSearch(search: string): string {
        return search.slice(`${Config.launcher.actionPrefix}vpn `.length);
    }

    function selector(item: var): string {
        return item.name;
    }

    function reload(): void {
        getServers.running = true;
    }

    list: servers.instances
    useFuzzy: Config.launcher.useFuzzy.vpn
    keys: ["name"]
    weights: [1]

    Variants {
        id: servers

        Server {}
    }

    Process {
        id: getServers

        running: true
        command: ["find", `${Paths.home}/.vpn`, "-maxdepth", "1", "-name", "*.ovpn", "-type", "f"]
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("[VpnServers] Raw output:", text);
                const lines = text.trim().split('\n').filter(l => l && l.length > 0);
                console.log("[VpnServers] Filtered lines:", lines.length);

                const list = lines.map(line => {
                    const filename = line.split('/').pop().replace('.ovpn', '');
                    // Parse format: NCVPN-CC-City-PROTOCOL or NCVPN-CC-City - Virtual-PROTOCOL
                    const parts = filename.split('-');
                    let country = parts[1] || '';
                    let city = '';
                    let protocol = '';
                    let isVirtual = false;

                    if (parts.length >= 3) {
                        // Find protocol (TCP or UDP)
                        const lastPart = parts[parts.length - 1];
                        if (lastPart === 'TCP' || lastPart === 'UDP') {
                            protocol = lastPart;
                            // Check if Virtual
                            if (parts[parts.length - 2] === 'Virtual') {
                                isVirtual = true;
                                city = parts.slice(2, parts.length - 2).join('-');
                            } else {
                                city = parts.slice(2, parts.length - 1).join('-');
                            }
                        } else {
                            city = parts.slice(2).join('-');
                        }
                    }

                    return {
                        name: filename,
                        path: line,
                        country: country,
                        city: city,
                        protocol: protocol,
                        isVirtual: isVirtual
                    };
                });

                console.log("[VpnServers] Parsed servers:", list.length);
                // Sort by country, then city, then protocol (UDP first)
                servers.model = list.sort((a, b) => {
                    if (a.country !== b.country) return a.country.localeCompare(b.country);
                    if (a.city !== b.city) return a.city.localeCompare(b.city);
                    if (a.protocol !== b.protocol) return b.protocol.localeCompare(a.protocol); // UDP before TCP
                    return 0;
                });
                console.log("[VpnServers] VPN servers loaded:", servers.model.length);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.warn("[VpnServers] Error:", text);
                }
            }
        }
    }

    component Server: QtObject {
        required property var modelData
        readonly property string name: modelData.name
        readonly property string path: modelData.path
        readonly property string country: modelData.country || ''
        readonly property string city: modelData.city || ''
        readonly property string protocol: modelData.protocol || ''
        readonly property bool isVirtual: modelData.isVirtual || false

        function onClicked(list: AppList): void {
            list.visibilities.launcher = false;
            // Run the connect command similar to CLI
            Quickshell.execDetached(["sh", "-c", `pkexec openvpn --config '${path}' --auth-user-pass '${Paths.home}/.vpn/pass.txt' --daemon < /dev/null`]);
        }
    }
}
