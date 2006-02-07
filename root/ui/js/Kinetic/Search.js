/*

    Do search is the "public" interface to this class. Unfortunately, do to
    limitations with client-side XSLT processing, this must be pushed here
    rather than be available directly in the browser.

    Also, trying to make this is a class method returns annoying
    'Kinetic.Search.doSearch() is not a function' errors.  This is probably
    just limitations with my understanding of JavaScript.
*/

var TESTING = 0;

function doSearch(form) {
    var search    = new Kinetic.Search;    
    
    var url = search.buildURL(form);
    if (TESTING) {
        alert(url);
        return false;
    }
    else {
        location.href = url;
    }
}

var lastSelectedOption;

function checkForMultiValues(selectList) {
    var name = selectList.name.replace(/^_(.*)_comp$/, "$1");
    if ( ! name ) {
        // XXX this should never happen.  This is coupled with the XSLT 
        // generation for the comparison functions.  Should I alert?
        return;
    }
    var between    = document.getElementById(name + "_between");
    var notBetween = document.getElementById(name + "_not_between");

    var option = selectList.options[ selectList.selectedIndex ].value;
    if ( 'BETWEEN' == option ) {
        var betweenInput    = between.getElementsByTagName('input');
        var notBetweenInput = notBetween.getElementsByTagName('input');
        betweenInput[0].value = notBetweenInput[0].value; 
        between.style.display    = "block";
        notBetween.style.display = "none";
    }
    else {
        if ('BETWEEN' == lastSelectedOption) {
            var betweenInput    = between.getElementsByTagName('input');
            var notBetweenInput = notBetween.getElementsByTagName('input');
            notBetweenInput[0].value = betweenInput[0].value;
        }
        between.style.display    = "none";
        notBetween.style.display = "block";
    }
    lastSelectedOption = option;
}

if (typeof Kinetic == 'undefined') Kinetic = {}; // Make sure the base namespace exists
Kinetic.Search = function () {};                 // constructor

// class definition

Kinetic.Search.prototype = {
    paramFor: {
        'classKey'    : '_class_key',
        'domain'      : '_domain',
        'path'        : '_path',
        'outputType'  : '_type',    
        'limit'       : '_limit',
        'order'       : '_order_by',
        'sort'        : '_sort_order',
        'search'      : 'search'
    },
    logicalFor:    new Array(),
    comparisonFor: new Array(),

    buildURL: function (data) {
        // data from form
        var classKey   = data[ this.paramFor['classKey']    ].value;
        var domain     = data[ this.paramFor['domain']      ].value;
        var path       = data[ this.paramFor['path']        ].value;
        var type       = data[ this.paramFor['outputType']  ].value;
        var limit      = data[ this.paramFor['limit']       ].value;
        var orderBy    = data[ this.paramFor['order']       ].value;
        var sortOrder  = data[ this.paramFor['sort']        ].value;

        var search     = this._getSearchString(data);

        // base url 
        var url = domain + path + 'search/' + classKey;

        // build path info
        url = url + this._addToURL( this.paramFor['search'], search );
        url = url + this._addToURL( this.paramFor['limit'],  limit );
        url = url + this._addToURL( this.paramFor['order'],  orderBy );
        if (orderBy) {
            url = url + this._addToURL( this.paramFor['sort'], sortOrder );
        }
        if (type) {
            url = url + '?' + this.paramFor['outputType'] + '=' + type;
        }
        return url;
    },

    _getSearchString: function (data) {

        var searchString  = '';
        var foundElem =  new Array();
        
        for ( var i = 0; i < data.elements.length; i++ ) {
            var elem  = data.elements[i];
            var name  = elem.name;

            if ( this._isEmpty(name) ) continue;
            if ( "_" == name.substring(0, 1) ) {
                // cache comparison metadata.  Note that this currently is dependent on
                // the order of these elements in the HTML.  This should be changed.
                var resultFor = this._getComparison(elem, 'logical');
                this.logicalFor[ resultFor["name"] ] = resultFor[ "value" ];

                resultFor = this._getComparison(elem, 'comp');
                this.comparisonFor[ resultFor["name"] ] = resultFor[ "value" ];
                continue;
            }
            if (foundElem[elem.name]) { // only process first array value
                continue;
            }
            foundElem[name] = 1;
            var value = this._getElemValue(data.elements[elem.name]);

            if ( this._isEmpty(value) ) continue;
            if ( searchString ) {
                searchString = searchString + ", ";
            }
            var logical    = this.logicalFor[name]    ? " " + this.logicalFor[name]    : "";
            var comparison = this.comparisonFor[name] ? " " + this.comparisonFor[name] : "";
            // do not escape the value.  It's already been escaped
            searchString = searchString 
                          + name 
                          + logical 
                          + comparison 
                          + value;
        }
        return searchString;
    },

    _getElemValue: function(elem) {
        return this._isEmpty(elem.value) 
            ? '' 
            : ' "' + this._quote(elem.value) + '"';
    },

    _quote: function(value) {
        // Naive?  What if they've already tried to escape it?
        return value.replace(/"/g, '\\"');
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

    _elemIsArray: function(elem) {
        var string = Object.prototype.toString.apply(elem);
        var name = string.substring(8, string.length - 1);
        return (name.match(/nodelist/i) != null);
    },

    _addToURL: function (name, value) {
        // 'search' is handled somewhat differently because there may be
        // different search types in the future
        if (this.paramFor['search'] == name) {
            if ( ! value ) {
                value = 'null';
            }
            return '/squery/' + escape(value);
        }
        if (this.paramFor['limit'] == name) {
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
