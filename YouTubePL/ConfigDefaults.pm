package YouTubePL::ConfigDefaults;

use Framework;

add_options({
  global => {
    ffmpeg_path => '',
    ffprobe_path => '',
    enable_dash => 1,
    preferred_video => ['135', '244', '22', '137'],
    preferred_audio => [], # who cares
    sql_source => 'dbi:SQLite:dbname=db.sql',
    js_ver => 8,
    css_ver => 6
  }
});

add_string('s_sqlerror', 'Database error!');

1;
