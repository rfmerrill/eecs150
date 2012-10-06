#!/usr/bin/env perl

use strict;

if ($#ARGV < 1) {
  print "Usage: instantiate.pl <modulename> <instancename> [indentdepth]\n";
  exit(2);
}

my $modulename = shift(@ARGV);
my $modulefilename = $modulename . ".v";
my $instancename = shift(@ARGV);
my $indentdepth = shift(@ARGV) || 0;


open (my $modfile, "<", $modulefilename) || die "Can't open $modulefilename: $!";

my @lines = <$modfile>;

map { s{//.*}{}g } @lines;
map { s{`.*}{}g } @lines;

my $filestring = join " ", @lines;


my $stripped = "";

my $i = 0;
my $j = 0;

while (($i = index($filestring, "/*")) != -1) {
  $stripped = $stripped . substr($filestring, 0, $i);

  $filestring = substr($filestring, $i);

  $j = index ($filestring, "*/");

  if ($j == -1) { 
    die "Comment not closed!";
  }

  $filestring = substr($filestring, $j + 2);
}

$stripped = $stripped . $filestring;
     
$stripped =~ s/;/ ; /g;
$stripped =~ s/,/ , /g;
$stripped =~ s/\(/ ( /g;
$stripped =~ s/\)/ ) /g;
$stripped =~ s/\s+/ /g;

my @words = split(' ', $stripped);

# print join("\n", @words);

while (lc(shift(@words)) ne "module") {

}

my $foo = shift(@words);

if (lc($foo) ne lc($modulename)) { die "$foo != $modulename"; }

$foo = shift (@words);

if ($foo ne "(")  { die "$foo is not an open paren"; }

my @wires = ();

while (($foo = shift (@words)) ne ")") {
  next if (lc($foo) eq "wire");
  next if (lc($foo) eq "reg");
  next if (lc($foo) eq "input");
  next if (lc($foo) eq "output");
  next if ($foo eq ",");
  next if ($foo eq ";");
  next if ($foo =~ /^[^A-Za-z].*/);

  push (@wires, $foo)

}

print "Wires: " . join(" ", @wires) . "\n";


print ' ' x $indentdepth;
print $modulename . " " . $instancename . "(\n";

my $wire = shift(@wires);
print ' ' x $indentdepth;
print "  ." . $wire . "()";

while ($wire = shift(@wires)) {
  print ",\n";
  print ' ' x $indentdepth;
  print "  .". $wire . "()";
}

print "\n";
print ' ' x $indentdepth;
print ");\n";

 
