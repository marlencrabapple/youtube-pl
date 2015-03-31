package YouTubePL::ConfigDefaults;

use Framework;

add_options({
  global => {
    ffmpeg_path => '',
    ffprobe_path => '',
    enable_dash => 1,
    sql_source => 'dbi:SQLite:dbname=db.sql',
    js_ver => 6,
    css_ver => 6
  }
});

add_string('s_sqlerror', 'Database error!');

1;
