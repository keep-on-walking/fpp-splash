<?php
$cfgFile = "/home/fpp/media/config/plugin.fpp-splash.json";
$defaults = array(
    "mode" => "text",
    "text" => "Welcome",
    "paused_text" => "PAUSED",
    "pointsize" => "100",
    "fg" => "white",
    "bg" => "black",
    "font" => "Nimbus-Sans-Bold-Italic",
    "image" => ""
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
    file_put_contents($cfgFile, json_encode($cfg, JSON_PRETTY_PRINT) . "\n");
    $saved = true;
}

$images = array();
foreach (glob("/home/fpp/media/images/*.{png,jpg,jpeg,PNG,JPG,JPEG}", GLOB_BRACE) as $f) {
    $images[] = $f;
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
<b>Content Setup &rarr; File Manager &rarr; Images</b> to use image mode.</p>

<form method="post">
<table class="table" style="max-width: 720px;">
  <tr>
    <td><b>Idle display</b></td>
    <td>
      <select name="mode">
        <option value="text"  <?php if ($cfg['mode'] != 'image') echo 'selected'; ?>>Centered text</option>
        <option value="image" <?php if ($cfg['mode'] == 'image') echo 'selected'; ?>>Fullscreen image</option>
      </select>
    </td>
  </tr>
  <tr>
    <td>Idle text</td>
    <td><input type="text" name="text" size="40" value="<?php echo htmlspecialchars($cfg['text']); ?>"></td>
  </tr>
  <tr>
    <td>Idle image</td>
    <td>
      <select name="image">
        <option value="">-- none selected --</option>
        <?php foreach ($images as $img) { ?>
        <option value="<?php echo htmlspecialchars($img); ?>" <?php if ($cfg['image'] == $img) echo 'selected'; ?>>
          <?php echo htmlspecialchars(basename($img)); ?>
        </option>
        <?php } ?>
      </select>
      <small>(scaled to fit, centered, letterboxed)</small>
    </td>
  </tr>
  <tr>
    <td>Paused text</td>
    <td><input type="text" name="paused_text" size="40" value="<?php echo htmlspecialchars($cfg['paused_text']); ?>">
        <small>(leave empty to show the idle display while paused)</small></td>
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
    <td><input type="text" name="bg" size="16" value="<?php echo htmlspecialchars($cfg['bg']); ?>"></td>
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
