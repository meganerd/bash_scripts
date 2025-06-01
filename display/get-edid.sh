#!/bin/bash
xrandr --verbose | perl -ne '
if ((/EDID(_DATA)?:/.../:/) && !/:/) {
  s/^\s+//;
  chomp;
  $hex .= $_;
} elsif ($hex) {
  # Use "|strings" if you dont have read-edid package installed 
  # and just want to see (or grep) the human-readable parts.
  open FH, "|parse-edid"; 
  print FH pack("H*", $hex); 
  $hex = "";
}'
