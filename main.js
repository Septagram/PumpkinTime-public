/*
 *  Copyright (c) 2013, Igor Novikov
 *  All rights reserved.
 *  
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *  
 *  * Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *  
 *  * Redistributions in binary form must reproduce the above copyright notice, this
 *    list of conditions and the following disclaimer in the documentation and/or
 *    other materials provided with the distribution.
 *  
 *  * Neither the name of the Pumpkin Time nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *  
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 *  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 *  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 *  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 *  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

(function() {

var h = {};
window.PumpkinTime = h;

_.mixin ({
    numberIn: function (number, min, max) {
        return  _.isUndefined (max) || number < max ?
                !_.isUndefined (min) && number < min ?
            min : number : max;
    },

    vmap: function (obj, f_val) { 
        return _.object (_.keys(obj), _.map (obj, f_val));
    },

    grammarNazi: function (string) {
        return string.slice (0, 1).toUpperCase() + string.slice (1) + (string.match (/[.?!]$/) ? '' : '.');
    },
});

h.debug = function (f, name) {
    name = typeof name === 'undefined' ? f.name : name;
    name = name === '' ? name : name + ' ';
    return function() {
        var res, args = Array.prototype.slice.call (arguments),
            callstring = 'function ' + name + '(' + _.map (args, JSON.stringify).join (', ') + ')';
        try {
            res = f.apply (this, args);
        } catch (e) {
            console.log (callstring + ' -X ' + JSON.stringify (e));
            throw e;
        };
        console.log (callstring + ' -> ' + JSON.stringify (res));
        return res;
    };
};

h.scope = function() {
    var args = Array.prototype.slice.call (arguments);
    return args.pop().apply (this, args);
};

h.stack = function() {
    return new Error().stack;
};

h.delta = function (a, b) {
    var keys = _.union (_.keys (a), _.keys (b));
    return _.object (keys, _.map (keys, function (key) {
        return a [key] - b [key];
    }));
};

h.sign = function (n) {
    n = Number (n);
    return n ? n < 0 ? -1 : 1 : 0;
};

h.deepCopy = function deepCopy (source) {
    return typeof source !== 'object' ? source : _.extend (source instanceof Array ? [] : {}, _.vmap (source, h.deepCopy));
};

// Kind thanks to @Ian for this solution (http://stackoverflow.com/a/16135889/521032)
h.ieVersion = (function () {
    var jscriptVersion = new Function("/*@cc_on return @_jscript_version; @*/")();
    return _.isUndefined (jscriptVersion) ? false : {
        "5.5":  5,
        "5.6":  6,
        "5.7":  7,
        "5.8":  8,
        "9":    9,
        "10":   10,
        "11":   11,
    } [jscriptVersion];
}());

h.AdaptivePanels = machina.Fsm.extend ({
    initialize: function (element) {
        this.$ = $(element).first();
        this.$panels = this.$.children ('.panel').data ('scroll', 0);
        this.panelCount = this.$panels.length;

        this.$
            .on ('movestart', _.bind (this.handle, this, 'touchstart'))
            .on ('move', _.bind (this.handle, this, 'dragging'))
            .on ('moveend', _.bind (this.handle, this, 'drag'));

        $(window).resize (_.bind (this.handle, this, 'windowResize'));
        setTimeout (_.bind (this.handle, this, 'windowResize'), 0);
        this.$portraitMeta = $('<meta>').attr ({
            name:       'viewport',
            content:    'width=device-width, initial-scale=1, minimum-scale=1.0, maximum-scale=1.0, user-scalable=0',
        });
    },

    initialState: 'large',

    states: (function() {
        var res = {
            large: {
                _onEnter: function() {
                    this.$portraitMeta.detach();
                    $('#wrapper').removeClass ('portrait').addClass ('landscape');
                    $('#mobile-scroll').css ('height',  '');

                    this.$.animate ({ 'left': '' }, this.animationSettings);
                    this.$panels.animate ({
                        'width': $(window).width() / (this.panelCount - 1) + 'px',
                        'scroll-top': 0,
                    }, _.extend ({ complete: _.bind (this.handle, this, 'contentChange') }, this.animationSettings));
                    this.$panels.eq (1).animate ({
                        width: 0,
                    }, this.animationSettings);
                },

                _onExit: function() {
                    $('head').append (this.$portraitMeta);
                    $('#wrapper').removeClass ('landscape').addClass ('portrait');
                    $('#mobile-scroll').css ('height', $(window).height() - $('#portrait-header').height());

                    this.$panels.animate ({
                        'width': '100%',
                        'height': $(window).height() - $('#portrait-header').height() + 'px',
                        'scroll-top': function() {
                            return $(this).data ('scroll');
                        },
                    }, this.animationSettings);
                },

                windowResize: function() {
                    if ($(window).width() / $(window).height() < 1) {
                        this.transition ('small-1');
                    } else {
                        this.handle ('contentChange');
                    };
                },

                contentChange: function() {
                    var max_height = _.chain (this.$panels.get())
                        .map (function (el, panel_index)
                    {
                        el.style.height = '';
                        return panel_index === 1 ? 0 : el.scrollHeight;
                        // A hack so that the central (invisible) panel does not affect height
                    }).max().value();

                    this.$panels.animate ({ height: max_height }, this.animationSettings);
                },

                touchstart: function (e) {
                    e.preventDefault();
                },
            },
        };

        for (var i = 0; i < 3; i ++) {
            res ['small-' + i] = h.scope (i, function (i) {
                return {
                    _onEnter: function() {
                        this.$.animate ({ 'left': -i + '00%' }, this.animationSettings);
                    },

                    drag: function (e) {
                        var $panel = this.$panels.eq (i);
                        $panel.data ('scroll', _.numberIn (
                            $panel.data ('scroll') - e.distY, 0, $panel [0].scrollHeight - $panel.height())
                        );
                        var target_panel = Math.abs (e.distX) > $(window).width() / 3 ?
                                _.numberIn (i - h.sign (e.distX), 0, this.panelCount - 1) : i;
                        if (i === target_panel) {
                            this.currentState()._onEnter.call (this);
                        } else {
                            e.preventDefault();
                            this.transition ('small-' + target_panel);
                        };
                    },

                    dragging: function (e) {
                        e.preventDefault();
                        var $panel = this.$panels.eq (i);
                        $panel.scrollTop ($panel.data ('scroll') - e.distY);
                        this.$.css ('left', 100 * (-i + e.distX / this.$panels.eq (i).width()) + '%');
                    },
                    
                    tap: function (e) {
                        if (typeof globalevent === 'undefined') {
                            window.globalevent = null;
                        };
                        globalevent = e;
                        setTimeout (_.bind (this.transition, this, 'large'), 0);
                    },

                    windowResize: (function() {
                        var last_width = $(window).width();
                        return function() {
                            if (last_width !== $(window).width() && $(window).width() / $(window).height() > 1) {
                                this.transition ('large');
                            } else {
                                $('#mobile-scroll').add (this.$panels).height ($(window).height() - $('#portrait-header').height());
                            };
                            last_width = $(window).width();
                        };
                    })(),
                };
            });
        };

        return res;
    })(),

    currentState: function() {
        return this.states [this.state];
    },

    animationSettings: {
        duration: 'slow',
        queue: false,
    },

    $portraitMeta: null,
});

app.Model = Backbone.RelationalModel.extend ({
    computed: {},
    get: function (name) {
        return typeof this.computed [name] === 'undefined' ?
            Backbone.RelationalModel.prototype.get.apply (this, arguments) :
            this.computed [name].apply (this, Array.prototype.slice.call (arguments, 1));
    },

    getAttributes: function() {
        var that = this;
        return _.extend ({}, _.clone (this.attributes), _.vmap (this.computed, function (f) {
            return typeof f === 'function' ? f.call (that) : f;
        }));
    },
});

app.View = Backbone.View.extend ({
    initialize: function (options) {
        _.extend (this, options, { model: undefined });
        this.setModel (options.model);
    },

    setModel: function (model) {
        if (typeof this.model !== 'undefined') {
            this.stopListening (this.model);
            this.model.stopListening (this);
        };
        this.model = model;
        if (typeof this.model !== 'undefined') {
            this.listenTo (this.model, 'change', _.chain (this.render).bind (this).debounce (0).value());
            this.render();
            // Note the debouncing. In case server and client time are not yet in sync, this forces to process the
            // Pumpkin-Time header (the one with the current syncing time) to be processed first, thus syncing them
            // before any possible rendering is done.
        };
        this.trigger ('modelChanged', model);
    },

    render: function() {
        this.$el.html (app.templates [this.template] (this.model));
        this.delegateEvents();
        this.trigger ('change');
    },
});

$(function() {
    h.templates = _.chain ($('script[type="text/template-underscore"]').toArray()).map (function (element) {
        element = $(element);
        return [
            element.data ('name'),

            _.chain (_.template (element.html())).compose (function (values) {
                return _.extend ({
                    template: function (name, inner_values) {
                        return app.templates [name] (_.isUndefined (inner_values) ? values : inner_values);
                    },

                    each: function (name, values, separator) {
                        return (values instanceof Backbone.Collection ? values.models() : values)
                            .map (app.templates [name])
                            .join (_.isUndefined (separator) ? '' : separator);
                    },
                }, values instanceof app.Model ? values.getAttributes() : values);
            }).extend ({
                source: element.html()
            }).value()
        ];
        // oh fuck, brevity vs clarity
    }).object().value();
});

})();
