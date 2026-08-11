use strict;
use warnings;
use lib "t/lib";

# Paubox_Email_SDK::Test loads Paubox_Email_SDK itself, so a compile failure
# in the SDK still fails this test file. Test::Class declares the plan; the
# whole class is skipped when config.cfg is absent (see SKIP_CLASS).
use Paubox_Email_SDK::Test;

Paubox_Email_SDK::Test->runtests;
