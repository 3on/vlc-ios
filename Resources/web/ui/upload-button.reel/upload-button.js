/**
 * @module ui/upload-button.reel
 * @requires digit/ui/button.reel
 */
var Button = require("digit/ui/button.reel").Button;

/**
 * @class UploadButton
 * @extends Button
 */
exports.UploadButton = Button.specialize(/** @lends UploadButton# */ {
    constructor: {
        value: function UploadButton() {
            this.super();
        }
    }
});
