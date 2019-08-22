<?php
$channel = (isset($_GET['channel'])?trim($_GET['channel']):'');
if (!preg_match('/^[a-zA-Z0-9_-]+$/', $channel)) {
    $channel = 'invalid_channel_name'; }
?>
<html>
<head>
    <script src="//cdn.dashjs.org/latest/dash.all.min.js"></script>
</head>

<body>
<video data-dashjs-player width="512" height="288" controls autoplay
   src="/livestream/dash/<?=$channel?>/index.mpd">
</video>

<br/><br/>
<a href="/livestream/hlsplayer/<?=$channel?>">switch to HLS player</a>
</body>
</html>
