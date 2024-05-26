// import { fetchNui } from './fetchNui.js';


function copyTextToClipboard(text) {
    console.log(text)
    var copyFrom = $('<textarea/>');
    copyFrom.text(text);
    $('body').append(copyFrom);
    copyFrom.select();
    document.execCommand('copy');
    copyFrom.remove();
}

window.addEventListener('DOMContentLoaded', function () {
    window.addEventListener('message', function (event) {
        switch (event.data.type) {
            case "copy":
                copyTextToClipboard(event.data.text)
                break;
            default:
                break;
        }
    })
})