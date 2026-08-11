use strict;
use warnings;
use lib "t/lib";

# Paubox_Forms_SDK::Test loads Paubox_Forms_SDK itself, so a compile failure
# in the SDK still fails this test file. Test::Class declares the plan.
use Paubox_Forms_SDK::Test;

Paubox_Forms_SDK::Test->runtests;
