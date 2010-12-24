#!/usr/bin/perl

use warnings;
use strict;
use List::Util qw{max};
use Getopt::Long;

my $basefile='paper';
my $bibtex_db_check=1;
my $use_pdflatex=0;
my $force=0;
my $clean=0;
GetOptions(
    'basefile=s'=>\$basefile,
    'bibtex-check!'=>\$bibtex_db_check,
    'pdflatex'=>\$use_pdflatex,
    'force!'=>\$force,
    'clean!'=>\$clean
);

if($clean or ($ARGV[0] and ($ARGV[0] eq 'clean'))){
  my @delfiles= map {$basefile.'.'.$_} ('aux','bbl','blg','log','pdf','dvi','ps');
  print "deleting ..\t",join ("  ",@delfiles),"\n";
  unlink(@delfiles);
  exit 0;
}

my $progname=$use_pdflatex ? "pdflatex" : "latex";
 

my ($error_color,$def_color)=("\e[1;31m","\e[0m");
my ($input,$output)=($basefile.".tex",$basefile.".pdf");
my @files=glob("*tex");
my @bibfiles=glob("*bib");

if( (not $force) and (-e $output)){
  my $inputfile_mtime =  max(map {(stat($_))[9]} @files,@bibfiles);
  my $outputfile_mtime = (stat($output))[9];
  if($outputfile_mtime  > $inputfile_mtime){
    print "$output newer than all input files, exiting...\n" ; 
    exit ;
  }
}

#Need to recreate output.pdf
run('');
my $log_file = readLog();

if($log_file =~ qr{^! LaTeX Error:(.*$)}m){
  my $error = $1 || '';
  print "There was an error:$error_color";
  print $error,"$def_color\n";
  print "please check $basefile.log for details\n";
  cleanup();
}

if($log_file =~ qr{^LaTeX Warning: Citation.*undefined on input line \d*\.$}m){
  print "Found some citations undefined, running bibtex...\n";
  system("bibtex $basefile > /dev/null 2>/dev/null");
  my $biblog=readLog('blg');
  if($biblog =~ m/\(There were \d* error messages\)\Z/){
    my $errormsg = '';
    $errormsg = $error_color.'can\'t find '.$1.$def_color if $biblog =~ m/^\QI couldn't open database file \E(.*bib)$/m;
    print "BibTex ran into errors: $errormsg \t  check $basefile.blg\n";
    cleanup();
  }
  
  my @missing=();
  push @missing,$1 while($biblog =~ m{^Warning--I didn't find a database entry for ("[^"]+")$}mg);
  if(@missing){
      print "BiBTeX couldn't find entries for the following cites: ",join("  ",@missing),"\n";
      if ($bibtex_db_check){
      print "Exiting ... change \$bibtex_db_check if you want to continue inspite of these errors\n" ;
      cleanup();
      }
  }
  run("Again");
  $log_file = readLog();
}

while(index($log_file,'Rerun to get cross-references right.' ) >= 0){
  run("Fixing crossrefs by again");
  $log_file = readLog();
}

if($log_file =~ m/Warning/){
  print "I have ran pdflatex a few times, but it still warns,.. you should check $basefile.log\n";
}


unless($use_pdflatex){
  print "Converting ps to pdf...\n";
  system("dvips $basefile.dvi > /dev/null 2>/dev/null");
  system("ps2pdf $basefile.ps > /dev/null 2>/dev/null");
  unlink("$basefile.dvi","$basefile.ps");
}

print "done!\n";


sub readLog{
  open my $fh,'<',($basefile.'.'.($_[0] || "log") ) 
	or die "couldn't open log file";
  local $/=undef;
  my $str=<$fh>;
  close($fh);
  return $str;
  
}

sub cleanup{
  unlink($basefile.'.dvi', $basefile.'.pdf', $basefile.'.ps');
  exit 1;
}

sub run{
  print $_[0], " running $progname...\n";
  system("$progname -interaction=batchmode $input > /dev/null 2>/dev/null");
  return $? == -1 ? 0 : $?>>8;
}