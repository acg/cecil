;(function($) {

$(document).ready( function() {
  $('table').tablesorter();

  $('.filter').change( function() {
    var form = $('form.mainform');
    /* Remove empty fields to avoid cluttering the query string */
    form.find('.filter:input[value=""]').attr('disabled',true);
    form.submit();
  } );

} );

})(jQuery);
