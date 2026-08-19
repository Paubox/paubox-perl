# Mirrors PREREQ_PM in Makefile.PL so `cpanm --installdeps .` installs
# everything the modules actually load. Minimums, not exact pins: Test::More
# ships with perl, so '==' made this file uninstallable.
requires 'JSON', '>= 4.02';
requires 'Config::General', '>= 2.63';
requires 'REST::Client', '>= 273';
requires 'TryCatch', '>= 1.003002';
requires 'String::Util', '>= 1.26';
requires 'MIME::Base64', '>= 3.15';
requires 'URI', '>= 1.60';

test_requires 'Test::Class', '>= 0.50';
test_requires 'Test::More', '>= 1.302162';
test_requires 'Text::CSV', '>= 1.99';
