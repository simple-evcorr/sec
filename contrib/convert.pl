#!/usr/bin/perl -w
#
# program for converting SEC 1.1 configuration files to SEC 2.0 format
# (contributed by Risto Vaarandi)

use Getopt::Long;

# read options given in commandline

GetOptions( "conf=s" => \$conffile,
            "separator=s" => \$separator );


if (!defined($conffile)) {

print STDERR << "USAGE";

Usage: $0 -conf=<conffile> [-separator=<separator>]

USAGE

exit(1);

}


# Default regular expression that is used to detect field boundaries 
# in configuration file

if (!defined($separator))  { $separator = '\s+\|\s+'; }


##############################
# Functions
##############################

sub log_msg {

  my($msg) = $_[0];

  print STDERR "$msg\n";

}



sub convert_actionlist {

  my($actionlist) = $_[0];
  my(@parts, $action, $result);
  my($context, $lifetime);

  @parts = split(/\s*;\s*/, $actionlist);
  $result = "";
  
  foreach $action (@parts) {

    if ($action =~ /^create\s*(\d*)\s*(.*)/i) {
 
      $lifetime = $1;
      $context = $2;

      if (!length($context)) { $context = "%s"; }

      $result .= "create " . $context . " " . $lifetime . "; ";
 
    } else {

      $result .= $action . "; ";

    }

  }

  return $result;

}



sub convert_config {

  my($line, $i, $cont, @comp, $type);


  log_msg("Reading configuration from $conffile...");

  if (open(CONFFILE, "$conffile")) {

    $i = 0;
    $cont = 0;

    while (<CONFFILE>) {

      # check if current line belongs to previous line;
      # if it does, form a single line from them
 
      if ($cont)  { $line .= $_; }  else { $line = $_; }

      # remove whitespaces from line beginnings and ends;
      # if line is empty or all-whitespace, print empty line,
      # take next line, and set $cont to 0

      if ($line =~ /^\s*(.*\S)/) { $line = $1; }  
        else { print "\n"; $cont = 0; next; }

      # check if line ends with '\'; if it does, remove '\', set $cont
      # to 1 and jump at the start of loop to read next line, otherwise 
      # set $cont to 0

      if (rindex($line, '\\') == length($line) - 1) { 

        chop($line);
        $cont = 1;
        next;

      } else { $cont = 0; }

      # preserve comment lines

      if (index($line, '#') == 0) { 

        print $line, "\n";
        next; 

      }

      # split line into fields

      @comp = split(/$separator/, $line);

      # find the rule type

      $type = uc($comp[0]);

      # ------------------------------------------------------------
      # SINGLE rule
      # ------------------------------------------------------------

      if ($type eq "SINGLE") {

        if (scalar(@comp) < 6  ||  scalar(@comp) > 7) { 

          log_msg("Wrong number of parameters specified at line $.");
          next; 

        }

        $comp[5] = convert_actionlist($comp[5]);

        print "type=Single\n";
        print "continue=$comp[1]\n";
        print "ptype=$comp[2]\n";
        print "pattern=$comp[3]\n";
 
        if (defined($comp[6])) { print "context=$comp[6]\n"; }

        print "desc=$comp[4]\n";
        print "action=$comp[5]\n";

        ++$i;

      }


      # ------------------------------------------------------------
      # SINGLE_W_SCRIPT rule
      # ------------------------------------------------------------

      elsif ($type eq "SINGLEWITHSCRIPT") {

        if (scalar(@comp) < 7  ||  scalar(@comp) > 8) { 

          log_msg("Wrong number of parameters specified at line $.");
          next; 

        }

        $comp[6] = convert_actionlist($comp[6]);

        print "type=SingleWithScript\n";
        print "continue=$comp[1]\n";
        print "ptype=$comp[2]\n";
        print "pattern=$comp[3]\n";

        if (defined($comp[7])) { print "context=$comp[7]\n"; }

        print "script=$comp[4]\n";
        print "desc=$comp[5]\n";
        print "action=$comp[6]\n";

        ++$i;

      }


      # ------------------------------------------------------------
      # SINGLE_W_SUPPRESS rule
      # ------------------------------------------------------------

      elsif ($type eq "SINGLEWITHSUPPRESS") {

        if (scalar(@comp) < 7  ||  scalar(@comp) > 8) { 

          log_msg("Wrong number of parameters specified at line $.");
          next; 

        }

        $comp[5] = convert_actionlist($comp[5]);

        print "type=SingleWithSuppress\n";
        print "continue=$comp[1]\n";
        print "ptype=$comp[2]\n";
        print "pattern=$comp[3]\n";

        if (defined($comp[7])) { print "context=$comp[7]\n"; }

        print "desc=$comp[4]\n";
        print "action=$comp[5]\n";
        print "window=$comp[6]\n";

	++$i;

      }


      # ------------------------------------------------------------
      # PAIR rule
      # ------------------------------------------------------------

      elsif ($type eq "PAIR") {

        if (scalar(@comp) < 11  ||  scalar(@comp) > 12) { 

          log_msg("Wrong number of parameters specified at line $.");
          next; 

        }

        $comp[5] = convert_actionlist($comp[5]);
        $comp[9] = convert_actionlist($comp[9]);

        print "type=Pair\n";
        print "continue=$comp[1]\n";
        print "ptype=$comp[2]\n";
        print "pattern=$comp[3]\n";

        if (defined($comp[11])) {
 
          print "context=$comp[11]\n";
 
        }

        print "desc=$comp[4]\n";
        print "action=$comp[5]\n";

        print "continue2=$comp[1]\n";
        print "ptype2=$comp[6]\n";
        print "pattern2=$comp[7]\n";

        if (defined($comp[11])) {
 
          $comp[11] =~ s/\$(\d+)/%$1/g;
          print "context2=$comp[11]\n";
 
        }

        print "desc2=$comp[8]\n";
        print "action2=$comp[9]\n";
        print "window=$comp[10]\n";

	++$i;

      }
  

      # ------------------------------------------------------------
      # PAIR_W_WINDOW rule
      # ------------------------------------------------------------

      elsif ($type eq "PAIRWITHWINDOW") {

        if (scalar(@comp) < 11  ||  scalar(@comp) > 12) { 

          log_msg("Wrong number of parameters specified at line $.");
          next; 

        }

        $comp[5] = convert_actionlist($comp[5]);
        $comp[9] = convert_actionlist($comp[9]);

        print "type=PairWithWindow\n";
        print "continue=$comp[1]\n";
        print "ptype=$comp[2]\n";
        print "pattern=$comp[3]\n";

        if (defined($comp[11])) {
 
          print "context=$comp[11]\n";
 
        }

        print "desc=$comp[4]\n";
        print "action=$comp[5]\n";

        print "continue2=$comp[1]\n";
        print "ptype2=$comp[6]\n";
        print "pattern2=$comp[7]\n";

        if (defined($comp[11])) {
 
          $comp[11] =~ s/\$(\d+)/%$1/g;
          print "context2=$comp[11]\n";
 
        }

        print "desc2=$comp[8]\n";
        print "action2=$comp[9]\n";
        print "window=$comp[10]\n";

	++$i;

      }
 

      # ------------------------------------------------------------
      # SINGLE_W_THRESHOLD rule
      # ------------------------------------------------------------

      elsif ($type eq "SINGLEWITHTHRESHOLD") {

        if (scalar(@comp) < 8  ||  scalar(@comp) > 9) { 

          log_msg("Wrong number of parameters specified at line $.");
          next; 

        }

        $comp[5] = convert_actionlist($comp[5]);

        print "type=SingleWithThreshold\n";
        print "continue=$comp[1]\n";
        print "ptype=$comp[2]\n";
        print "pattern=$comp[3]\n";

        if (defined($comp[8])) { print "context=$comp[8]\n"; }

        print "desc=$comp[4]\n";
        print "action=$comp[5]\n";
        print "window=$comp[6]\n";
        print "thresh=$comp[7]\n";

	++$i;

      }


      # ------------------------------------------------------------
      # SINGLE_W_2_THRESHOLDS rule
      # ------------------------------------------------------------

      elsif ($type eq "SINGLEWITH2THRESHOLDS") {

        if (scalar(@comp) < 12  ||  scalar(@comp) > 13) { 

          log_msg("Wrong number of parameters specified at line $.");
          next; 

        }

        $comp[5] = convert_actionlist($comp[5]);
        $comp[9] = convert_actionlist($comp[9]);

        print "type=SingleWith2Thresholds\n";
        print "continue=$comp[1]\n";
        print "ptype=$comp[2]\n";
        print "pattern=$comp[3]\n";

        if (defined($comp[12])) { print "context=$comp[12]\n"; }

        print "desc=$comp[4]\n";
        print "action=$comp[5]\n";
        print "window=$comp[6]\n";
        print "thresh=$comp[7]\n";
        print "desc2=$comp[8]\n";
        print "action2=$comp[9]\n";
        print "window2=$comp[10]\n";
        print "thresh2=$comp[11]\n";

	++$i;

      }


      # ------------------------------------------------------------
      # SUPPRESS rule
      # ------------------------------------------------------------

      elsif ($type eq "SUPPRESS") {

        if (scalar(@comp) < 3  ||  scalar(@comp) > 4) { 

          log_msg("Wrong number of parameters specified at line $.");
          next; 

        }

        print "type=Suppress\n";
        print "ptype=$comp[1]\n";
        print "pattern=$comp[2]\n";

        if (defined($comp[3])) { print "context=$comp[3]\n"; }

	++$i;

      }


      # ------------------------------------------------------------
      # CALENDAR rule
      # ------------------------------------------------------------

      elsif ($type eq "CALENDAR") {

        if (scalar(@comp) < 4  ||  scalar(@comp) > 5) { 

          log_msg("Wrong number of parameters specified at line $.");
          next; 

        }

        $comp[3] = convert_actionlist($comp[3]);

        print "type=Calendar\n";
        print "time=$comp[1]\n";

        if (defined($comp[4])) { print "context=$comp[4]\n"; }

        print "desc=$comp[2]\n";
        print "action=$comp[3]\n";

	++$i;

      }

      # ------------------------------------------------------------
      # unknown rule
      # ------------------------------------------------------------
      
      else { log_msg("Unknown rule type '$type' specified at line $."); }

      print "\n";

    }

    close CONFFILE;

    log_msg("$i rules converted");

  } else {

    log_msg("Can't open configuration file $conffile, exiting");

  }

}



convert_config();
