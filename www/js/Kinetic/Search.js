/*

    Do search is the "public" interface to this class. Unfortunately, do to
    limitations with client-side XSLT processing, this must be pushed here
    rather than be available directly in the browser.

    Also, trying to make this is a class method returns annoying
    'Kinetic.Search.doSearch() is not a function' errors.  This is probably
    just limitations with my understanding of JavaScript.
*/

var TESTING = 1;

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

function checkForMultiValues(selectList) {
    var name = selectList.name.replace(/^_(.*)_comp$/, "$1");
    if ( ! name ) {
        // this should never happen.  This is coupled with the XSLT generation 
        // for the comparison functions
        return;
    }
    var between    = document.getElementById(name + "_between");
    var notBetween = document.getElementById(name + "_not_between");

    if ('BETWEEN' == selectList.options[selectList.selectedIndex].value) {
        between.style.display = "block";
        notBetween.style.display = "none";
    }
    else {
        between.style.display = "none";
        notBetween.style.display = "block";
    }
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
        var url = domain + path + classKey;

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
            var value = this._getElemValue(elem);

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
                          + ' "' + value + '"';
        }
        return searchString;
    },

    _getElemValue: function(elem) {
        if ('BETWEEN' == this.comparisonFor[elem.name]) {
            alert(Dumper(this.comparisonFor));
            // XXX does not yet handle quotes?
            return '[ "' + elem[1].value + '", "' + elem[2].value + '" ]';
        }
        else {
            return elem.value;
        }
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
            return '/search/STRING/' + escape(value);
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

// ===================================================================
// Author: Matt Kruse <matt@mattkruse.com>
// WWW: http://www.mattkruse.com/
//
// NOTICE: You may use this code for any purpose, commercial or
// private, without any further permission from the author. You may
// remove this notice from your final code if you wish, however it is
// appreciated by the author if at least my web site address is kept.
//
// You may *NOT* re-distribute this code in any way except through its
// use. That means, you can include it in your product, or your web
// site, or any other form where the code is actually being used. You
// may not put the plain javascript up on your site for download or
// include it in your javascript libraries for download. 
// If you wish to share this code with others, please just point them
// to the URL instead.
// Please DO NOT link directly to my .js files from your site. Copy
// the files to your server and use them there. Thank you.
// ===================================================================

// HISTORY
// ------------------------------------------------------------------
// March 18, 2004: Updated to include max depth limit, ignoring standard
//    objects, ignoring references to itself, and following only
//    certain object properties.
// March 17, 2004: Created
/* 
DESCRIPTION: These functions let you easily and quickly view the data
structure of javascript objects and variables

COMPATABILITY: Will work in any javascript-enabled browser

USAGE:

// Return the output as a string, and you can do with it whatever you want
var out = Dumper(obj);

// When starting to traverse through the object, only follow certain top-
// level properties. Ignore the others
var out = Dumper(obj,'value','text');

// Sometimes the object you are dumping has a huge number of properties, like
// form fields. If you are only interested in certain properties of certain 
// types of tags, you can restrict that like Below. Then if DataDumper finds
// an object that is a tag of type "OPTION" it will only examine the properties
// of that object that are specified.
DumperTagProperties["OPTION"] = [ 'text','value','defaultSelected' ]

// View the structure of an object in a window alert
DumperAlert(obj);

// Popup a new window and write the Dumper output to that window
DumperPopup(obj);

// Write the Dumper output to a document using document.write()
DumperWrite(obj);
// Optionall, give it a different document to write to
DumperWrite(obj,documentObject);

NOTES: Be Careful! Some objects hold references to their parent nodes, other
objects, etc. Data Dumper will keep traversing these nodes as well, until you
have a really, really huge tree built up. If the object you are passing in has
references to other document objects, you should either:
    1) Set the maximum depth that Data Dumper will search (set DumperMaxDepth)
or
    2) Pass in only certain object properties to traverse
or
    3) Set the object properties to traverse for each type of tag
    
*/ 
var DumperIndent = 1;
var DumperIndentText = " ";
var DumperNewline = "\n";
var DumperObject = null; // Keeps track of the root object passed in
var DumperMaxDepth = 5; // Max depth that Dumper will traverse in object
//var DumperMaxDepth = -1; // Max depth that Dumper will traverse in object
var DumperIgnoreStandardObjects = true; // Ignore top-level objects like window, document
var DumperProperties = null; // Holds properties of top-level object to traverse - others are igonred
var DumperTagProperties = new Object(); // Holds properties to traverse for certain HTML tags
function DumperGetArgs(a,index) {
    var args = new Array();
    // This is kind of ugly, but I don't want to use js1.2 functions, just in case...
    for (var i=index; i<a.length; i++) {
        args[args.length] = a[i];
    }
    return args;
}
function DumperPopup(o) {
    var w = window.open("about:blank");
    w.document.open();
    w.document.writeln("<HTML><BODY><PRE>");
    w.document.writeln(Dumper(o,DumperGetArgs(arguments,1)));
    w.document.writeln("</PRE></BODY></HTML>");
    w.document.close();
}
function DumperAlert(o) {
    alert(Dumper(o,DumperGetArgs(arguments,1)));
}
function DumperWrite(o) {
    var argumentsIndex = 1;
    var d = document;
    if (arguments.length>1 && arguments[1]==window.document) {
        d = arguments[1];
        argumentsIndex = 2;
    }
    var temp = DumperIndentText;
    var args = DumperGetArgs(arguments,argumentsIndex)
    DumperIndentText = "&nbsp;";
    d.write(Dumper(o,args));
    DumperIndentText = temp;
}
function DumperPad(len) {
    var ret = "";
    for (var i=0; i<len; i++) {
        ret += DumperIndentText;
    }
    return ret;
}
function Dumper(o) {
    var level = 1;
    var indentLevel = DumperIndent;
    var ret = "";
    if (arguments.length>1 && typeof(arguments[1])=="number") {
        level = arguments[1];
        indentLevel = arguments[2];
        if (o == DumperObject) {
            return "[original object]";
        }
    }
    else {
        DumperObject = o;
        // If a list of properties are passed in
        if (arguments.length>1) {
            var list = arguments;
            var listIndex = 1;
            if (typeof(arguments[1])=="object") {
                list = arguments[1];
                listIndex = 0;
            }
            for (var i=listIndex; i<list.length; i++) {
                if (DumperProperties == null) { DumperProperties = new Object(); }
                DumperProperties[list[i]]=1;
            }
        }
    }
    if (DumperMaxDepth != -1 && level > DumperMaxDepth) {
        return "...";
    }
    if (DumperIgnoreStandardObjects) {
        if (o==window || o==window.document) {
            return "[Ignored Object]";
        }
    }
    // NULL
    if (o==null) {
        ret = "[null]";
        return ret;
    }
    // FUNCTION
    if (typeof(o)=="function") {
        ret = "[function]";
        return ret;
    } 
    // BOOLEAN
    if (typeof(o)=="boolean") {
        ret = (o)?"true":"false";
        return ret;
    } 
    // STRING
    if (typeof(o)=="string") {
        ret = "'" + o + "'";
        return ret;
    } 
    // NUMBER   
    if (typeof(o)=="number") {
        ret = o;
        return ret;
    }
    if (typeof(o)=="object") {
        if (typeof(o.length)=="number" ) {
            // ARRAY
            ret = "[";
            for (var i=0; i<o.length;i++) {
                if (i>0) {
                    ret += "," + DumperNewline + DumperPad(indentLevel);
                }
                else {
                    ret += DumperNewline + DumperPad(indentLevel);
                }
                ret += Dumper(o[i],level+1,indentLevel-0+DumperIndent);
            }
            if (i > 0) {
                ret += DumperNewline + DumperPad(indentLevel-DumperIndent);
            }
            ret += "]";
            return ret;
        }
        else {
            // OBJECT
            ret = "{";
            var count = 0;
            for (i in o) {
                if (o==DumperObject && DumperProperties!=null && DumperProperties[i]!=1) {
                    // do nothing with this node
                }
                else {
                    if (typeof(o[i]) != "unknown") {
                        var processAttribute = true;
                        // Check if this is a tag object, and if so, if we have to limit properties to look at
                        if (typeof(o.tagName)!="undefined") {
                            if (typeof(DumperTagProperties[o.tagName])!="undefined") {
                                processAttribute = false;
                                for (var p=0; p<DumperTagProperties[o.tagName].length; p++) {
                                    if (DumperTagProperties[o.tagName][p]==i) {
                                        processAttribute = true;
                                        break;
                                    }
                                }
                            }
                        }
                        if (processAttribute) {
                            if (count++>0) {
                                ret += "," + DumperNewline + DumperPad(indentLevel);
                            }
                            else {
                                ret += DumperNewline + DumperPad(indentLevel);
                            }
                            ret += "'" + i + "' => " + Dumper(o[i],level+1,indentLevel-0+i.length+6+DumperIndent);
                        }
                    }
                }
            }
            if (count > 0) {
                ret += DumperNewline + DumperPad(indentLevel-DumperIndent);
            }
            ret += "}";
            return ret;
        }
    }
}



