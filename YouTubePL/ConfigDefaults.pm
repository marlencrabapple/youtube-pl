package YouTubePL::ConfigDefaults;

use Framework;

add_options({
  global => {
    ffmpeg_path => 'ffmpeg',
    ffprobe_path => 'ffprobe',
    enable_dash => 1,
    sql_source => 'dbi:SQLite:dbname=db.sql',
    js_ver => 2,
    css_ver => 2
  }
});

add_string('s_sqlerror', 'Database error!');

1;
