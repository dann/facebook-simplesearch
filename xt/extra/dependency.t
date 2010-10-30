use Test::Dependencies
    exclude => [qw/Test::Dependencies Test::Base Test::Perl::Critic SimpleMemo/],
    style   => 'light';
ok_dependencies();
