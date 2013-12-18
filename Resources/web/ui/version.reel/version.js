/**
 * @module ui/version.reel
 * @requires montage/ui/component
 */
var Component = require("montage/ui/component").Component;

/**
 * @class Version
 * @extends Component
 */
exports.Version = Component.specialize(/** @lends Version# */ {
    constructor: {
        value: function Version() {
            this.super();
        }
    },

    montageDescription: {
        get: function() {
            return montageRequire.packageDescription;
        }
    }
});
