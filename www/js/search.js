function do_search(data) {
  var class_key = data.class_key.value;
  var domain    = data.domain.value;
  var path      = data.path.value;
  var search    = data.search.value;
  if ( ! search ) {
    search = 'null';
  }
  var limit = data.limit.value;
  var order_by = data.order_by.value;
  var sort_order = data.sort_order.value;

  var url = domain + path + class_key + '/search/STRING/' + escape(search);
  url = url + add_search_constraint('limit', limit);
  url = url + add_search_constraint('order_by', order_by);
  if (order_by) {
    url = url + add_search_constraint('sort_order', sort_order);
  }
  //alert(url);
  location.href = url;
  return false;
}

function add_search_constraint(name, value) {
  if (! value) {
    return '';
  }
  else {
    return '/' + name + '/' + escape(value);
  }
}
