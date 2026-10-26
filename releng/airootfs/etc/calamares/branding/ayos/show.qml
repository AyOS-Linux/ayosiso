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
            source: "slide3.png"
            width: parent.width
            fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent
        }
    }
}
