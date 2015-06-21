(function($) {
  "use strict";
  var env = findBootstrapEnvironment();
  
  if((env == 'sm') || (env == 'xs')) {
    $($('.dropdown-menu')[0]).addClass('dropdown-menu-right');
  }
  else {
    // might not be enough vertical space on mobile
    $($('.dropdown-menu')[1]).parents('.btn-group').addClass('dropup');
  }
  
  $('.dl-link').on('click', function(e) {
    e.preventDefault();
    var link = this;

    $.get(link.href, function(data) {
      $('.dl-button').attr('disabled', true);
      $('.inprogress').show();

      if(videoinfo.duration > 300) {
        $('.bepatient').show()
      }

      var statusloop = setInterval(function(data) {
        $.get('/status/' + data.fn, function(data2) {
          if(data2.finished == 1) {
            var a = document.createElement("a");
            document.body.appendChild(a);
            a.href = data.url;
            a.download = $(link).attr('download');
            a.click();

            $('.dl-button').attr('disabled', false);
            $('.inprogress').hide();
            $('.bepatient').hide();

            clearInterval(statusloop)
          }
        })
      }, 1000, data);
    })
  })

  function findBootstrapEnvironment() {
    var envs = ['xs', 'sm', 'md', 'lg'];
    var el = $('<div>');
    $(el).appendTo($('body'));

    for(var i = envs.length - 1; i >= 0; i--) {
      var env = envs[i];
      $(el).addClass('hidden-' + env);

      if($(el).is(':hidden')) {
        $(el).remove();
        return env
      }
    };
  }
})(jQuery);
