<?php
$channel = (isset($_GET['channel'])?trim($_GET['channel']):'');
if (!preg_match('/^[a-zA-Z0-9_-]+$/', $channel)) {
    $channel = 'invalid_channel_name'; }
?>
<html>
<head>
    <link href="https://unpkg.com/video.js/dist/video-js.min.css" rel="stylesheet">
    <script src="https://unpkg.com/video.js/dist/video.min.js"></script>
</head>

<body>
<video id=videojs autoplay width=512 height=288 class="video-js vjs-default-skin" controls>
  <source src="/livestream/hls/<?=$channel?>/index.m3u8" type="application/x-mpegURL">
</video>

<br/><br/>
<a href="/livestream/dashplayer/<?=$channel?>">switch to DASH player</a>

<script>
    var player = videojs('videojs');
</script>

</body>
</html>
