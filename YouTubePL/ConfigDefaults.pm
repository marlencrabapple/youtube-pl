package YouTubePL::ConfigDefaults;

use Framework;

add_options({
  global => {
    ffmpeg_path => 'ffmpeg',
    ffprobe_path => 'ffprobe',
    enable_dash => 1
  }
});

add_string('s_sqlerror', 'Database error!');

1;
