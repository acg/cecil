;(function($) {

$(document).ready( function() {
  $('table').tablesorter();
  $('.filter').change( function() { $('form').submit(); } );
} );

})(jQuery);
