import QtQuick
import QtQuick.Layouts
import Quickshell
import "Theme.js" as Theme

// phi: one solid bar, no boxes. the bottom edge is the installer's rule,
// bronze running into gold, with a tick at 1/φ of the width
Item {
    anchors.fill: parent

    readonly property real phi: 0.6180339887

    component Divider: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: 14
        color: Theme.accent
        opacity: 0.55
    }

    Rectangle {
        id: rule
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.bgAlt }
            GradientStop { position: 0.35; color: Theme.accent }
            GradientStop { position: 1.0; color: Theme.yellow }
        }
    }

    Rectangle {
        anchors.bottom: rule.bottom
        x: parent.width * parent.phi - width / 2
        width: 1
        height: 5
        color: Theme.yellow
    }

    RowLayout {
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 14

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "φ"
            color: launcher.containsMouse ? Theme.fg : Theme.yellow
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSize + 7
            font.weight: Font.DemiBold

            MouseArea {
                id: launcher
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["rofi", "-show", "drun"])
            }
        }

        Divider {}

        Workspaces {
            Layout.alignment: Qt.AlignVCenter
            activeColor: Theme.yellow
            // the theme's faint colour is the gold accent here, too loud for empty desks
            idleColor: Qt.darker(Theme.accent, 2.6)
        }
    }

    Clock {
        anchors.centerIn: parent
    }

    RowLayout {
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 12

        Stats { Layout.alignment: Qt.AlignVCenter }
        BatteryWidget { Layout.alignment: Qt.AlignVCenter }
        Divider {}
        VolumeWidget { Layout.alignment: Qt.AlignVCenter }
        Indicators {
            Layout.alignment: Qt.AlignVCenter
            dnd: bar.dnd
            notifCount: bar.notifCount
            notifOpen: bar.notifOpen
        }
        PowerButton { Layout.alignment: Qt.AlignVCenter }
    }
}
