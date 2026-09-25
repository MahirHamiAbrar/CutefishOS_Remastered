import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Image {
            anchors.centerIn: parent
            height: parent.height * 0.95
            width: parent.width * 0.95
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: "one.png"
        }
    }

    Slide {
        Image {
            anchors.centerIn: parent
            height: parent.height * 0.95
            width: parent.width * 0.95
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: "two.png"
        }
    }

    Slide {
        Image {
            anchors.centerIn: parent
            height: parent.height * 0.95
            width: parent.width * 0.95
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: "three.png"
        }
    }

    Slide {
        Image {
            anchors.centerIn: parent
            height: parent.height * 0.95
            width: parent.width * 0.95
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: "four.png"
        }
    }
}
