;(function($) {


$(document).ready( function() {

  $('table').tablesorter();

  $('.filter').change( function() {
    var form = $('form.mainform');
    /* Remove empty fields to avoid cluttering the query string */
    form.find('.filter:input[value=""]').attr('disabled',true);
    form.submit();
  } );

  $('.field-Progress').percentageBar();

} );


$.fn.percentageBar = function() {
  $(this).each( function(i,elem) {

    var parts = $(elem).text().split(' ');
    var x = parseFloat(parts[0]);
    var y = parseFloat(parts[2]);

    var percent = 0;
    var color;

    if (y > 0.0)
      percent = Math.round( 100 * x / y );

    if (percent <= 100)
    {
      var color1 = [ 0x00, 0x40, 0x80 ];
      var color2 = [ 0x30, 0xb0, 0x40 ];
      color = '';

      for (i=0; i<3; i++) {
        var c = Math.round( color1[i] + percent * (color2[i] - color1[i]) / 100 );
        var hex = c.toString(16);
        while (hex.length < 2) hex = "0"+hex;
        color += hex;
      }
    }

    var bar = $('<div class="percentage"><div class="text">'+percent+' %</div><div class="pos">&nbsp;</div><div class="mask">&nbsp;</div></div>');
    var pos = $('.pos', bar);
    var issue = $(elem).parent('tr');

    pos.css({ width: percent+'%' });
    pos.css({ 'background-color': '#'+color });

    if (percent > 100) $(bar).addClass("over");
    if (y == 0) $(bar).addClass("unknown");
    $(elem).prepend(bar);

  } );
};


})(jQuery);
