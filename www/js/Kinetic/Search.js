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

function checkForMultiValues(selectList, name) {
    var between     = document.getElementById(name + "_between");
    var not_between = document.getElementById(name + "_not_between");

    if ('BETWEEN' == selectList.options[selectList.selectedIndex].value) {
        between.style.display = "block";
        not_between.style.display = "none";
    }
    else {
        between.style.display = "none";
        not_between.style.display = "block";
    }
}

function toggleDiv(divName) {
    thisDiv = document.getElementById(divName);
    if (thisDiv) {
        if (thisDiv.style.display == "none") {
            thisDiv.style.display = "block";
        }
        else {
            thisDiv.style.display = "none";
        }
    }
    else {
        alert("Error: Could not locate div with id: " + divName);
    }
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

        var search     = this._getSearchString(data);

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

    _getSearchString: function (data) {
        var logical_for    = new Array();
        var comparison_for = new Array();

        var search_string  = '';
        for ( var index in data.elements ) {
            var elem  = data.elements[index];
            var name  = elem.name;

            if ( this._isEmpty(name) ) continue;
            if ( "_" == name.substring(0, 1) ) {
                // cache comparison metadata.  Note that this currently is dependent on
                // the order of these elements in the HTML.  This should be changed.
                var result_for = this._getComparison(elem, 'logical');
                logical_for[ result_for["name"] ] = result_for[ "value" ];

                result_for = this._getComparison(elem, 'comp');
                comparison_for[ result_for["name"] ] = result_for[ "value" ];
                continue;
            }
            var value = elem.value;
            if ( this._isEmpty(value) ) continue;
            if ( search_string ) {
                search_string = search_string + ", ";
            }
            var logical    = logical_for[name]    ? " " + logical_for[name]    : "";
            var comparison = comparison_for[name] ? " " + comparison_for[name] : "";
            // do not escape the value.  It's already been escaped
            search_string = search_string 
                          + name 
                          + logical 
                          + comparison 
                          + ' "' + value + '"';
        }
        return search_string;
    },

    _getComparison: function (elem, type) {
        var name  = elem.name;
        var regex = new RegExp("^_([^_]*)_" + type);
        name      = name.replace(regex, "$1");

        if (! name) return;
        var value = "";
        if (elem.options) { 
            value = elem.options[elem.selectedIndex].value;
            value = value ? value : "";
        }
        return {
            "name"  : name,
            "value" : value
        };
    },

    _isEmpty: function (value) {
        if (null == value || value.match(/^\s*$/)) {
            return true;
        }
        else {
            return false;
        }
    },

    _addToURL: function (name, value) {
        // 'search' is handled somewhat differently because there may be
        // different search types in the future
        if (param_for['search'] == name) {
            if ( ! value ) {
                value = 'null';
            }
            return '/search/STRING/' + escape(value);
        }
        if (param_for['limit'] == name) {
            if (0 == value) {
                return '';
            }
        }
        if (! value) {
            return '';
        }
        else {
            return '/' + name + '/' + escape(value);
        }
    }
}
