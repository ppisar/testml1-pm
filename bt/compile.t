# BEGIN { $Pegex::Parser::Debug = 1 }
use Test::More tests => 10;
use strict;

use Test::Differences;
# use Test::Differences; *is = \&eq_or_diff;

use TestML::Compiler;
use YAML::XS;
use XXX;

test('t/testml/arguments.tml');
test('t/testml/assertions.tml');
test('t/testml/basic.tml');
test('t/testml/dataless.tml');
test('t/testml/exceptions.tml');
test('t/testml/external.tml');
#     test('t/testml/function.tml');
test('t/testml/label.tml');
test('t/testml/markers.tml');
test('t/testml/standard.tml');
test('t/testml/truth.tml');
#     test('t/testml/types.tml');

sub test {
    my $file = shift;
    (my $filename = $file) =~ s!.*/!!;
    my $ast1 = TestML::Compiler->new->compile($file);
    my $yaml1 = Dump($ast1);

    my $ast2 = YAML::XS::LoadFile("bt/ast/$filename");
    my $yaml2 = Dump($ast2);

    eq_or_diff $yaml1, $yaml2, $filename;
}
