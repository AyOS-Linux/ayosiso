// AyOS Material 26.11 — слайдшоу Calamares (slideshowAPI: 2)
// Одна страница: бренд-обои + название. Load-on-start API.
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    function onActivate() { presentation.currentSlide = 0; }
    function onLeave() { }

    Slide {
        Image {
            source: "wallpaper.png"
            width: parent.width
            fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 60
            text: "AyOS Material 26.11"
            font.pixelSize: 44
            color: "white"
            style: Text.Outline
            styleColor: "#c9741f"
        }
    }
}
