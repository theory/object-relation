/*

    Do search is the "public" interface to this class. Unfortunately, do to
    limitations with client-side XSLT processing, this must be pushed here
    rather than be available directly in the browser.

    Also, trying to make this is a class method returns annoying
    'Kinetic.Search.doSearch() is not a function' errors.  This is probably
    just limitations with my understanding of JavaScript.
*/

function doSearch(form) {
    var search    = new Kinetic.Search;    
    location.href = search.buildURL(form);
}

if (typeof Kinetic == 'undefined') Kinetic = {}; // Make sure the base namespace exists
Kinetic.Search = function () {};                 // constructor

// class definition

Kinetic.Search.prototype = {
    buildURL: function (data) {
        // data from form
        var class_key  = data._class_key.value;
        var domain     = data._domain.value;
        var path       = data._path.value;
        var type       = data._type.value;
        var search     = data.search.value;
        var limit      = data.limit.value;
        var order_by   = data.order_by.value;
        var sort_order = data.sort_order.value;

        // base url 
        var url = domain + path + class_key;

        // build path info
        url = url + this._addSearchConstraint('search', search);
        url = url + this._addSearchConstraint('limit', limit);
        url = url + this._addSearchConstraint('order_by', order_by);
        if (order_by) {
            url = url + this._addSearchConstraint('sort_order', sort_order);
        }
        if (type) {
            url = url + '?_type=' + type;
        }
        return url;
    },

    _addSearchConstraint: function (name, value) {
        // 'search' is handled somewhat differently because there may be
        // different search types in the future
        if ('search' == name) {
            if ( ! value ) {
                value = 'null';
            }
            return '/search/STRING/' + escape(value);
        }
        if (! value) {
            return '';
        }
        else {
            return '/' + name + '/' + escape(value);
        }
    }
}
