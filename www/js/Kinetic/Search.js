if (typeof Kinetic == 'undefined') Kinetic = {}; // Make sure the base namespace exists
Kinetic.Search = function () {};            // constructor

// class definition

Kinetic.Search.prototype = {
    buildURL: function (data) {
        // data from form
        var class_key  = data.class_key.value;
        var domain     = data.domain.value;
        var path       = data.path.value;
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
        return url;
    },

    _addSearchConstraint: function (name, value) {
        // 'search' is handled somewhat differently
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
