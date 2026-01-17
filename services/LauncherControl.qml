pragma Singleton

import QtQuick

QtObject {
    id: root

    signal openWithSearch(string searchText)

    property string pendingSearchText: ""

    function openLauncher(visibilities: var, searchText: string): void {
        root.pendingSearchText = searchText;
        visibilities.launcher = true;
        Qt.callLater(function() {
            root.openWithSearch(searchText);
        });
    }
}
