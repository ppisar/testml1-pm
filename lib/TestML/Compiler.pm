package TestML::Compiler;
use TestML::Base -base;

sub compile {
    my $self = shift;
    my $text = shift;
    my $function = TestML::Parser->parse($text)
        or die "TestML document failed to parse";
    return $function;
}

sub compile_data {
    my $self = shift;
    my $text = shift;
    my $blocks = TestML::Parser->parse_data($text)
        or die "TestML data document failed to parse";
    return $blocks;
}

sub preprocess {
}

package TestML::Parser;
use TestML::Base -base;
use TestML::Parser::Grammar;
use TestML::Document;

our $parser;

sub parse {
    $parser = TestML::Parser::Grammar->new(
        receiver => TestML::Parser::Receiver->new,
        debug => 0,
    );
    $parser->parse($_[1], 'document')
        or die "Parse TestML failed";
    return $parser->receiver->document;
}

sub parse_data {
    $parser->receiver(TestML::Parser::Receiver->new);
    $parser->parse($_[1], 'data_section')
        or die "Parse TestML data failed";
    return $parser->receiver->document->data->blocks;
}

#-----------------------------------------------------------------------------
package TestML::Parser::Receiver;
use TestML::Base -base;

use TestML::Document;

has 'document', -init => 'TestML::Document->new()';

has 'statement';
has 'expression_stack' => [];
has 'current_block';
has 'point_name';
has 'transform_name';
has 'string';
has 'transform_arguments' => [];

my %ESCAPES = (
    '\\' => '\\',
    "'" => "'",
    'n' => "\n",
    't' => "\t",
    '0' => "\0",
);

sub got_single_quoted_string {
    my $self = shift;
    my $string = shift;
    $string =~ s/\\([\\\'])/$ESCAPES{$1}/g;
    $self->string($string);
}

sub got_double_quoted_string {
    my $self = shift;
    my $string = shift;
    $string =~ s/\\([\\\"nt])/$ESCAPES{$1}/g;
    $self->string($string);
}

sub got_unquoted_string {
    my $self = shift;
    $self->string(shift);
}

sub got_meta_section {
    my $self = shift;

    my $grammar = $parser->grammar;

    my $block_marker = $self->document->meta->data->{BlockMarker};
    $block_marker =~ s/([\$\%\^\*\+\?\|])/\\$1/g;
    $grammar->{block_marker}{'+re'} = qr/\G$block_marker/;

    my $point_marker = $self->document->meta->data->{PointMarker};
    $point_marker =~ s/([\$\%\^\*\+\?\|])/\\$1/g;
    $grammar->{point_marker}{'+re'} = qr/\G$point_marker/;

    my $point_lines = $grammar->{point_lines}{'+re'};
    $point_lines =~ s/===/$block_marker/;
    $point_lines =~ s/---/$point_marker/;
    $grammar->{point_lines}{'+re'} = qr/$point_lines/;
}

sub got_meta_testml_statement {
    my $self = shift;
    $self->document->meta->data->{TestML} = shift;
}

sub got_meta_statement {
    my $self = shift;
    my $meta_keyword = shift;
    my $meta_value = shift;
    if (ref($self->document->meta->data->{$meta_keyword}) eq 'ARRAY') {
        push @{$self->document->meta->data->{$meta_keyword}}, $meta_value;
    }
    else {
        $self->document->meta->data->{$meta_keyword} = $meta_value;
    }
}

sub try_assignment_statement {
    my $self = shift;
    my $statement = TestML::Statement->new(
    );
    $self->statement($statement);
    my $expression = $self->statement->expression;
    $expression->transforms->[0] = TestML::Transform->new(
        name => 'Set',
    );
    $statement->expression($expression);
    push @{$self->expression_stack}, TestML::Expression->new;
}

sub got_assignment_statement {
    my $self = shift;
    push @{$self->document->test->statements}, $self->statement;
    $self->statement->expression->transforms->[0]->args->[1] =
        pop @{$self->expression_stack};
}

sub not_assignment_statement {
    my $self = shift;
    pop @{$self->expression_stack};
}

sub got_variable_name {
    my $self = shift;
    my $variable_name = shift;
    $self->statement->expression->transforms->[0]->args->[0] = $variable_name;
}

sub try_test_statement {
    my $self = shift;
    $self->statement(TestML::Statement->new());
    push @{$self->expression_stack}, $self->statement->expression;
}

sub got_test_statement {
    my $self = shift;
    push @{$self->document->test->statements}, $self->statement;
    pop @{$self->expression_stack};
}

sub not_test_statement {
    my $self = shift;
    pop @{$self->expression_stack};
}

sub got_point_call {
    my $self = shift;
    my $point_name = shift;
    $point_name =~ s/^\*// or die;
    my $transform = TestML::Transform->new(
        name => 'Point',
        args => [$point_name],
    );
    push @{$self->expression_stack->[-1]->transforms}, $transform;
    push @{$self->statement->points}, $point_name;
}

sub got_transform_call {
    my $self = shift;
    pop @{$self->expression_stack};
    my $transform_name = $self->transform_name;
    my $transform = TestML::Transform->new(
        name => $transform_name,
        args => $self->transform_arguments,
    );
    push @{$self->expression_stack->[-1]->transforms}, $transform;
}

sub got_transform_name {
    my $self = shift;
    $self->transform_name(shift);
    push @{$self->expression_stack}, TestML::Expression->new;
    $self->transform_arguments([]);
}

sub got_transform_argument {
    my $self = shift;
    push @{$self->transform_arguments}, pop @{$self->expression_stack};
    push @{$self->expression_stack}, TestML::Expression->new;
}

sub got_string_call {
    my $self = shift;
    my $string = $self->string;
    my $transform = TestML::String->new(
        value => $string,
    );
    push @{$self->expression_stack->[-1]->transforms}, $transform;
}

sub got_number_call {
    my $self = shift;
    my $number = shift;
    my $transform = TestML::Number->new(
        value => $number,
    );
    push @{$self->expression_stack->[-1]->transforms}, $transform;
}

sub try_assertion_call {
    my $self = shift;
    $self->statement->assertion(TestML::Assertion->new);
    push @{$self->expression_stack}, $self->statement->assertion->expression;
}

sub got_assertion_call {
    my $self = shift;
    pop @{$self->expression_stack};
}

sub not_assertion_call {
    my $self = shift;
    $self->statement->assertion(undef);
    pop @{$self->expression_stack};
}

sub got_assertion_eq {
    my $self = shift;
    $self->statement->assertion->name('EQ');
}

sub got_assertion_ok {
    my $self = shift;
    $self->statement->assertion->name('OK');
}

sub got_assertion_has {
    my $self = shift;
    $self->statement->assertion->name('HAS');
}

sub got_block_label {
    my $self = shift;
    my $block = TestML::Block->new(label => shift);
    $self->current_block($block);
}

sub got_point_name {
    my $self = shift;
    $self->point_name(shift);
}

sub got_point_phrase {
    my $self = shift;
    my $point_phrase = shift;
    $self->current_block->points->{$self->point_name} = $point_phrase;
}

sub got_point_lines {
    my $self = shift;
    my $point_lines = shift;
    $self->current_block->points->{$self->point_name} = $point_lines;
}

sub got_data_block {
    my $self = shift;
    push @{$self->document->data->blocks}, $self->current_block;
}

1;
