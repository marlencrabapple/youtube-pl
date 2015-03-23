(function($) {
  var saveData = (function() {
    console.log("This is where its all going wrong");

    return function(data, filename) {
      var xhr = new XMLHttpRequest();
      xhr.open("GET", data, true);
      xhr.responseType = "arraybuffer";

      console.log(data, filename);
      console.log(xhr);

      xhr.addEventListener("progress", function(e) {
        if(e.lengthComputable) {
          console.log(e.loaded / e.total)
        }
        else {
          console.log("Can't get content size.")
        }
      }, false);

      xhr.addEventListener("error", function(e) {
        alert("Something went wrong :(")
      }, false);

      xhr.addEventListener("load", function(e) {
        if(xhr.status === 200) {
          var blob = new Blob([xhr.response], { type: "octet/stream" }),
            url = window.URL.createObjectURL(blob),
            a = document.createElement("a");

          document.body.appendChild(a);
          $(a).css('display', 'none');

          a.href = url;
          a.download = filename;
          a.click();

          console.log(a);

          window.URL.revokeObjectURL(url);
        }
        else {
          alert("Something went wrong :(")
        }
      }, false);

      console.log(xhr);

      xhr.send();
    };
  }());

  $('.dl-link').each(function(i, v) {
    $(v).attr('download', $(v).attr('data-download'))
  });

  $('.dl-link').on('click', function(e) {
    //e.preventDefault();

    // Can't use any of this for various reasons
    //saveData(this.href, $(this).attr('download'));
  });
})(jQuery);
