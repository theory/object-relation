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

var param_for = {
    'class_key'   : '_class_key',
    'domain'      : '_domain',
    'path'        : '_path',
    'output_type' : '_type',    
    'limit'       : '_limit',
    'order'       : '_order_by',
    'sort'        : '_sort_order',
    'search'      : 'search'
};

Kinetic.Search.prototype = {
    buildURL: function (data) {
        // data from form
        var class_key  = data[ param_for['class_key']   ].value;
        var domain     = data[ param_for['domain']      ].value;
        var path       = data[ param_for['path']        ].value;
        var type       = data[ param_for['output_type'] ].value;
        var limit      = data[ param_for['limit']       ].value;
        var order_by   = data[ param_for['order']       ].value;
        var sort_order = data[ param_for['sort']        ].value;
        var search     = data[ param_for['search']      ].value;

        // base url 
        var url = domain + path + class_key;

        // build path info
        url = url + this._addToURL( param_for['search'], search );
        url = url + this._addToURL( param_for['limit'],  limit );
        url = url + this._addToURL( param_for['order'],  order_by );
        if (order_by) {
            url = url + this._addToURL( param_for['sort'], sort_order );
        }
        if (type) {
            url = url + '?' + param_for['output_type'] + '=' + type;
        }
        return url;
    },

    _isEmpty: function (value) {
        if (null == value || value.match(/^\s*$/)) {
            return true;
        }
        else {
            return false;
        }
    },


    _getSearchString: function (data) {
        var search_string = '';
        for ( var index in data.elements ) {
            var name  = data.elements[index].name;
            if ( this._isEmpty(name) ) continue;
            if ( "_" == name.substring(0, 1) ) {
                continue;
            }
            var value = data.elements[index].value;
            if ( this._isEmpty(value) ) continue;
            if ( search_string ) {
                search_string = search_string + ", ";
            }
            search_string = search_string + name + " " + value;
        }
        alert('"'+search_string+'"');
        return search_string;
    },

    _addToURL: function (name, value) {
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
