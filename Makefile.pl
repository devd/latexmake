#!/usr/bin/perl

use warnings;
use strict;
use List::Util qw{max};

my $basefile='paper';
my ($input,$output)=($basefile.".tex",$basefile.".pdf");
my @files=<*tex>;
my @bibfiles=<*bib>;
# print "date output last modified: ",(stat($output))[9],"\n";
# print "max modification time of tex files: ",(max(map {(stat($_))[9]} @files)),"\n";
if( -e $output){
if(!( ((stat($output))[9]) < max(map {(stat($_))[9]} (@files,@bibfiles)))){
  print "$output newer than all input files, exiting...\n" ; exit ;
  }
}

#Need to recreate output.pdf
system("echo 'X' | pdflatex $input > /dev/null 2>/dev/null");
my $log_file = readLog();

if($log_file =~ qr{^Type X to quit or <RETURN> to proceed,$}m){
  print "There was an error, please check $basefile.log\n";
  exit;
}





sub readLog{
  open LOG,"$basefile.log";
  local $/;
  return <LOG>;
}