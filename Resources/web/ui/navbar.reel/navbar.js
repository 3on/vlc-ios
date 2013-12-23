/**
 * @module ui/navbar.reel
 * @requires montage/ui/component
 */
var Component = require("montage/ui/component").Component;

/**
 * @class Navbar
 * @extends Component
 */
exports.Navbar = Component.specialize(/** @lends Navbar# */ {
    title: {
        value: ""
    },

    constructor: {
        value: function Navbar() {
            this.super();
        }
    },

    handleAddButtonAction: {
        value: function (evt) {
            this.dispatchEventNamed("addFile", true, true);
        }
    },

    handlehomeButtonAction: {
        value: function (evt) {
        }
    }
});
