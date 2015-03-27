(function($) {
  $('.dl-link').on('click', function(e) {
    e.preventDefault();
    var link = this;

    $.get(link.href, function(data) {
      $('.dl-button').attr('disabled', true);
      $('.inprogress').show();

      if(videoinfo.duration > 300) {
        $('.bepatient').show();
      }

      var statusloop = setInterval(function() {
        $.get('/status/' + data.fn, function(data2) {
          if(data2.finished == 1) {
            var a = document.createElement("a");
            document.body.appendChild(a);
            a.href = data.url;
            a.download = $(link).attr('data-download');
            a.click();

            $('.dl-button').attr('disabled', false);
            $('.inprogress').hide();
            $('.bepatient').hide();
            clearInterval(statusloop)
          }
        })
      }, 1000);
    })
  })
})(jQuery);
