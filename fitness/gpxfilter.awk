BEGIN { skipping=0; cur = ""; }
{
  if ($0 ~ /trkpt lat/) {
      if (cur == $0) {
	  skipping = 1;
      } else {
	  skipping = 0;
      }
      cur = $0;
  }
  if (skipping) {
  } else {
      print $0;
  }
}
END   { }
