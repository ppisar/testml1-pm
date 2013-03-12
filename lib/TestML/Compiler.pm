package TestML::Compiler;

use TestML::Base;
use TestML::Grammar;
use TestML::AST;
use Pegex::Parser;

# XXX This code is too complicated. It preprocesses the TestML code, splits it
# into 2 sections and calls a separate Pegex parse on each. This could all be
# handled in Pegex, but probably not worth it just yet.

# Take a TestML document and compile it into a TestML::Function object.
sub compile {
    my ($self, $input) = @_;

    my $result = $self->preprocess($input, 'top');

    my ($code, $data) = @$result{qw(code data)};

    my $parser = Pegex::Parser->new(
        grammar => TestML::Grammar->new,
        receiver => TestML::AST->new,
    );

    $parser->parse($code, 'code_section')
        or die "Parse TestML code section failed";

    $parser = $self->fixup_grammar($parser, $result);

    if (length $data) {
        $parser->parse($data, 'data_section')
            or die "Parse TestML data section failed";
    }

    if ($result->{DumpAST}) {
        XXX($parser->receiver->function);
    }

    my $function = $parser->receiver->function;
    $function->outer(TestML::Function->new());

    return $function;
}

sub preprocess {
    my ($self, $text, $top) = @_;

    my @parts = split /^((?:\%\w+.*|\#.*|\ *)\n)/m, $text;

    $text = '';

    my $result = {
        TestML => '',
        DataMarker => '',
        BlockMarker => '===',
        PointMarker => '---',
    };

    my $order_error = 0;
    for my $part (@parts) {
        next unless length($part);
        if ($part =~ /^(\#.*|\ *)\n/) {
            $text .= "\n";
            next;
        }
        if ($part =~ /^%(\w+)\s*(.*?)\s*\n/) {
            my ($directive, $value) = ($1, $2);
            $text .= "\n";
            if ($directive eq 'TestML') {
                die "Invalid TestML directive"
                    unless $value =~ /^\d+\.\d+\.\d+$/;
                die "More than one TestML directive found"
                    if $result->{TestML};
                $result->{TestML} = TestML::Str->new(value => $value);
                next;
            }
            $order_error = 1 unless $result->{TestML};
            if ($directive eq 'Include') {
                my $runtime = $TestML::Runtime::singleton
                    or die "Can't process Include. No runtime available";
                my $sub_result =
                    $self->preprocess($runtime->read_testml_file($value));
                $text .= $sub_result->{text};
                $result->{DataMarker} = $sub_result->{DataMarker};
                $result->{BlockMarker} = $sub_result->{BlockMarker};
                $result->{PointMarker} = $sub_result->{PointMarker};
                die "Can't define %TestML in an Included file"
                    if $sub_result->{TestML};
            }
            elsif ($directive =~ /^(DataMarker|BlockMarker|PointMarker)$/) {
                $result->{$directive} = $value;
            }
            elsif ($directive =~ /^(DebugPegex|DumpAST)$/) {
                $value = 1 unless length($value);
                $result->{$directive} = $value;
            }
            else {
                die "Unknown TestML directive '$directive'";
            }
        }
        else {
            $order_error = 1 if $text and not $result->{TestML};
            $text .= $part;
        }
    }

    if ($top) {
        die "No TestML directive found"
            unless $result->{TestML};
        die "%TestML directive must be the first (non-comment) statement"
            if $order_error;

        my $DataMarker = $result->{DataMarker} ||= $result->{BlockMarker};
        my ($code, $data);
        if ((my $split = index($text, "\n$DataMarker")) >= 0) {
            $result->{code} = substr($text, 0, $split + 1);
            $result->{data} = substr($text, $split + 1);
        }
        else {
            $result->{code} = $text;
            $result->{data} = '';
        }

        $result->{code} =~ s/^\\(\\*[\%\#])/$1/gm;
        $result->{data} =~ s/^\\(\\*[\%\#])/$1/gm;
    }
    else {
        $result->{text} = $text;
    }

    return $result;
}

# TODO This can be moved to the AST some day.
sub fixup_grammar {
    my ($self, $parser, $hash) = @_;

    my $namespace = $parser->receiver->function->namespace;
    $namespace->{TestML} = $hash->{TestML};

    my $tree = $parser->grammar->tree;

    my $point_lines = $tree->{point_lines}{'.rgx'};

    my $block_marker = $hash->{BlockMarker};
    if ($block_marker) {
        $block_marker =~ s/([\$\%\^\*\+\?\|])/\\$1/g;
        $tree->{block_marker}{'.rgx'} = qr/\G$block_marker/;
        $point_lines =~ s/===/$block_marker/;
    }

    my $point_marker = $hash->{PointMarker};
    if ($point_marker) {
        $point_marker =~ s/([\$\%\^\*\+\?\|])/\\$1/g;
        $tree->{point_marker}{'.rgx'} = qr/\G$point_marker/;
        $point_lines =~ s/\\-\\-\\-/$point_marker/;
    }

    $tree->{point_lines}{'.rgx'} = qr/$point_lines/;

    Pegex::Parser->new(
        grammar => $parser->grammar,
        receiver => $parser->receiver,
    );

}

1;
