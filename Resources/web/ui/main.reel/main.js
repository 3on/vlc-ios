/**
 * @module ui/main.reel
 * @requires montage/ui/component
 */
var Component = require("montage/ui/component").Component;

/**
 * @class Main
 * @extends Component
 */
exports.Main = Component.specialize(/** @lends Main# */ {
    constructor: {
        value: function Main() {
            this.super();
        }
    },

    files : {
        value: [
            {
                name: "toto.mkv"
            },
            {
                name: "film de boules.mkv"
            },
        ]
    }
});
