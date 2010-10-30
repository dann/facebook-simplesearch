use inc::Module::Install;
name 'SimpleMemo';
all_from 'lib/SimpleMemo.pm';

requires(

);
test_requires(
  'Test::More'                   => 0,
);
use_test_base;
auto_include;
WriteAll;
