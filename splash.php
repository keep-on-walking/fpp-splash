<?php
$cfgFile = "/home/fpp/media/config/plugin.fpp-splash.json";
$defaults = array(
    "idle_display" => "",      // "" = text, else image path
    "paused_display" => "",    // "" = text, "idle" = same as idle, else image path
    "idle_delay" => "0",
    "text" => "Welcome",
    "paused_text" => "PAUSED",
    "pointsize" => "100",
    "fg" => "white",
    "bg" => "black",
    "font" => "Nimbus-Sans-Bold-Italic"
);

$cfg = $defaults;
if (file_exists($cfgFile)) {
    $j = json_decode(file_get_contents($cfgFile), true);
    if (is_array($j)) $cfg = array_merge($defaults, $j);
}

$saved = false;
if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    foreach ($defaults as $k => $v) {
        if (isset($_POST[$k])) $cfg[$k] = trim($_POST[$k]);
    }
    // retire v1.0 keys so old mode/image can't override the new selection
    unset($cfg['mode']);
    unset($cfg['image']);
    file_put_contents($cfgFile, json_encode($cfg, JSON_PRETTY_PRINT) . "\n");
    $saved = true;
}

$images = array();
foreach (glob("/home/fpp/media/images/*.{png,jpg,jpeg,gif,webp,PNG,JPG,JPEG,GIF,WEBP}", GLOB_BRACE) as $f) {
    $images[] = $f;
}

$playlists = array();
foreach (glob("/home/fpp/media/playlists/*.json") as $f) {
    $playlists[] = basename($f, ".json");
}

function displayOptions($selected, $images, $extra = array(), $playlists = array()) {
    echo "<option value=''" . ($selected == '' ? ' selected' : '') . ">Centered text</option>\n";
    foreach ($extra as $val => $label) {
        echo "<option value='" . htmlspecialchars($val) . "'" . ($selected == $val ? ' selected' : '') . ">" . htmlspecialchars($label) . "</option>\n";
    }
    foreach ($images as $img) {
        echo "<option value='" . htmlspecialchars($img) . "'" . ($selected == $img ? ' selected' : '') . ">Image: " . htmlspecialchars(basename($img)) . "</option>\n";
    }
    foreach ($playlists as $pl) {
        $val = "playlist:" . $pl;
        echo "<option value='" . htmlspecialchars($val) . "'" . ($selected == $val ? ' selected' : '') . ">Playlist: " . htmlspecialchars($pl) . "</option>\n";
    }
}
?>

<div id="global" class="settings">
<fieldset>
<legend>Idle / Paused Splash</legend>

<?php if ($saved) { ?>
<div class="alert alert-success">Saved. The splash re-renders automatically within a couple of seconds
(visible immediately if nothing is playing).</div>
<?php } ?>

<p>Shown on the HDMI output whenever no media is playing. Upload images via
<b>Content Setup &rarr; File Manager &rarr; Images</b>, then pick them below &mdash;
one dropdown per state, no separate mode switch.</p>

<form method="post">
<table class="table" style="max-width: 720px;">
  <tr>
    <td style="width: 180px;"><b>Idle display</b></td>
    <td>
      <select name="idle_display">
        <?php displayOptions($cfg['idle_display'], $images, array(), $playlists); ?>
      </select>
      <br><small>Playlist option: starts that playlist (repeating) whenever nothing is
      playing &mdash; a video screensaver. The idle text is shown briefly while it starts.</small>
    </td>
  </tr>
  <tr>
    <td>Idle delay (seconds)</td>
    <td><input type="number" name="idle_delay" min="0" max="3600" value="<?php echo htmlspecialchars($cfg['idle_delay']); ?>">
        <br><small>0 = idle display appears immediately when playback stops.
        Above 0: when playback stops, the <b>paused</b> display is shown for this many
        seconds first, then the idle display activates. This also makes pausing
        reveal the paused display with no visible switch at all. Does not delay
        the splash at boot.</small></td>
  </tr>
  <tr>
    <td>Idle text</td>
    <td><input type="text" name="text" size="40" value="<?php echo htmlspecialchars($cfg['text']); ?>">
        <small>(used when Idle display is "Centered text")</small></td>
  </tr>
  <tr>
    <td><b>Paused display</b></td>
    <td>
      <select name="paused_display">
        <?php displayOptions($cfg['paused_display'], $images, array("idle" => "Same as idle")); ?>
      </select>
    </td>
  </tr>
  <tr>
    <td>Paused text</td>
    <td><input type="text" name="paused_text" size="40" value="<?php echo htmlspecialchars($cfg['paused_text']); ?>">
        <small>(used when Paused display is "Centered text")</small></td>
  </tr>
  <tr>
    <td>Text size</td>
    <td><input type="number" name="pointsize" min="10" max="500" value="<?php echo htmlspecialchars($cfg['pointsize']); ?>"></td>
  </tr>
  <tr>
    <td>Text color</td>
    <td><input type="text" name="fg" size="16" value="<?php echo htmlspecialchars($cfg['fg']); ?>">
        <small>(named color or #rrggbb)</small></td>
  </tr>
  <tr>
    <td>Background color</td>
    <td><input type="text" name="bg" size="16" value="<?php echo htmlspecialchars($cfg['bg']); ?>">
        <small>(also the letterbox color for images)</small></td>
  </tr>
  <tr>
    <td>Font</td>
    <td><input type="text" name="font" size="30" value="<?php echo htmlspecialchars($cfg['font']); ?>">
        <small>(ImageMagick font name; falls back to default if missing)</small></td>
  </tr>
  <tr>
    <td></td>
    <td><input type="submit" class="buttons" value="Save"></td>
  </tr>
</table>
</form>

</fieldset>
</div>
