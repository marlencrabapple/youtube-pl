(function($) {
  $('.dl-link').on('click', function(e) {
    e.preventDefault();
    $.get(this.href, function(data) {
      $('.dl-button').attr('disabled', true);
      $('.inprogress').show();

      var statusloop = setInterval(function() {
        $.get('/status/' + data.fn, function(data2) {
          if(data2.finished == 1) {
            var a = document.createElement("a");
            document.body.appendChild(a);
            a.href = data.url;
            a.download = data.fn;
            a.click();

            $('.dl-button').attr('disabled', false);
            $('.inprogress').hide();
            clearInterval(statusloop)
          }
          else {
            console.log(data2)
          }
        })
      }, 1000);
    })
  })
})(jQuery);
