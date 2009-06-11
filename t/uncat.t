use TestML -run;

__DATA__
%TestML: 1.0

error.Throw().bogus().Catch() == error;
Throw('My error message').Catch() == error;

empty == Str("");

=== Throw/Catch
--- error: My error message

=== Empty Point
--- empty

