use strict;
use lib -e 't' ? 't' : 'test';
use TestML;
use TestMLBridge;

TestML->new(
    testml => 'testml/types.tml',
    bridge => 'TestMLBridge',
)->run;
