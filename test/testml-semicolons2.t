# DO NOT EDIT
#
# This file was generated by TestML::Setup (0.50)
#
#   > perl -MTestML::Setup -e setup test/testml.yaml
use strict;
use lib -e 't' ? 't' : 'test';
use TestML;
use TestMLBridge;
use File::Spec;

TestML->new(
    testml => File::Spec->catfile(qw{testml semicolons2.tml}),
    bridge => 'TestMLBridge',
)->run;
