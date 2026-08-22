package Paubox_Forms_SDK;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
                          getForm
                          submitForm
                          listForms
                          getFormById
                          createForm
                          updateForm
                          archiveForm
                          unarchiveForm
                          copyForm
                          getFormStats
                          listFormSubmissions
                          getSubmissionsCsv
                          getSubmissionPdf
                  );

our $VERSION = '2.0.1'; # x-release-please-version

use Paubox_Email_SDK::ApiHelper;

use JSON;
use Config::General;
use TryCatch;
use URI::Escape;

my $formsBaseURL = 'https://api.paubox.com/forms';

#
# Default Constructor (no credentials required for the public endpoints)
# Optional named param: 'apiKey' => a scoped API key with the "forms" scope,
# used by the authenticated form-management methods. When no 'apiKey' param
# is given, FORMS_API_KEY is loaded from ./config.cfg when present.
#
sub new {
    my ($class, %params) = @_;
    my $this = {};

    if ( defined($params{'apiKey'}) && $params{'apiKey'} ne "" ) {
        $this -> {'apiKey'} = $params{'apiKey'};
    }
    else {
        # A missing or broken config file must never break the
        # public-only constructor, so this lookup is wrapped in eval.
        eval {
            if ( -e 'config.cfg' ) {
                my $conf = Config::General -> new(
                    -ConfigFile => 'config.cfg',
                    -InterPolateVars => 1
                );
                my %config = $conf -> getall;
                if ( defined($config{'FORMS_API_KEY'}) && $config{'FORMS_API_KEY'} ne "" ) {
                    $this -> {'apiKey'} = $config{'FORMS_API_KEY'};
                }
            }
        };
    }

    bless $this, $class;
    return $this;
}

#
# Private methods
#

sub _getAuthHeader {
    my ($this) = @_;
    if ( !ref($this) || !defined($this -> {'apiKey'}) || $this -> {'apiKey'} eq "" ) {
        die "apiKey is required for this method. Pass 'apiKey' to Paubox_Forms_SDK->new() or set FORMS_API_KEY in config.cfg. Scoped API keys are generated in the Paubox admin dashboard and must include the 'forms' scope.";
    }
    return "Bearer " . $this -> {'apiKey'};
}

# Sanitizes a caller-supplied path segment before interpolation into a URL.
# Rejects undef / empty / bare `.` / bare `..` and any value containing a
# path, query, fragment, or CR/LF character — a hostile $formId like
# "<uuid>/archive?x=" would otherwise turn a read into a mutation on the
# same host with the caller's bearer token attached. When `require_uuid`
# is true, additionally enforces UUID v4-ish shape so that the documented
# "UUID" contract is honoured by the SDK itself. Returns the value
# percent-encoded via URI::Escape so any residual reserved character is
# safe inside a single path segment.
sub _pathSegment {
    my ($value, %opts) = @_;
    my $name = defined($opts{'name'}) ? $opts{'name'} : 'path segment';
    if ( !defined($value) || $value eq "" ) {
        die $name . " is required.";
    }
    if ( $value eq "." || $value eq ".." ) {
        die "invalid " . $name . ": '" . $value . "' is not allowed.";
    }
    if ( $value =~ m{[/?#\r\n]} ) {
        die "invalid " . $name . ": must not contain '/', '?', '#' or newline characters.";
    }
    if ( $opts{'require_uuid'} && $value !~ /\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/ ) {
        die "invalid " . $name . ": '" . $value . "' does not match the documented UUID format.";
    }
    return uri_escape($value);
}

# Boolean query params the backend only accepts as the literal strings
# "true"/"false", so any truthy/falsy Perl value (1/0, JSON::true/JSON::false)
# is normalized before it is put on the query string.
my %booleanQueryKeys = map { $_ => 1 } qw(archived active);

sub _buildQueryString {
    my ($params, @allowedKeys) = @_;
    return "" if ( !defined($params) || ref($params) ne 'HASH' );

    my @pairs;
    foreach my $key (@allowedKeys) {
        if ( defined($params -> {$key}) ) {
            my $value = $booleanQueryKeys{$key}
                ? ( $params -> {$key} ? "true" : "false" )
                : uri_escape($params -> {$key});
            push @pairs, $key . "=" . $value;
        }
    }
    return @pairs ? "?" . join("&", @pairs) : "";
}

#
# Coerces known boolean keys of a payload hash to JSON::true/JSON::false so
# they serialize as JSON booleans (the backend rejects 1/0 for bool fields).
# Any truthy/falsy Perl value is accepted from the caller.
#
sub _coerceBooleanKeys {
    my ($payload, @booleanKeys) = @_;
    foreach my $key (@booleanKeys) {
        if ( exists $payload -> {$key} && defined $payload -> {$key} ) {
            $payload -> {$key} = $payload -> {$key} ? JSON::true : JSON::false;
        }
    }
    return;
}

#
# Dies with the raw response when the HTTP status is not 2xx, when the body
# is not parseable JSON, when the body carries an error payload
# ("errors"/"message"), or when the expected success key is absent.
#
sub _assertSuccessKey {
    my ($apiHelper, $apiResponseJSON, $successKey) = @_;

    my $responseCode = $apiHelper -> responseCode();
    if ( !defined($responseCode) || $responseCode !~ /^2\d\d$/ ) {
        die ( defined($apiResponseJSON) && $apiResponseJSON ne ""
            ? $apiResponseJSON
            : "Request failed with HTTP status " . ( defined($responseCode) ? $responseCode : "unknown" ) . "." );
    }

    my $apiResponsePERL = eval { from_json($apiResponseJSON) };
    if ( $@ || ref($apiResponsePERL) ne 'HASH' ) {
        # Non-JSON body (e.g. an HTML proxy error page): die with the raw
        # response instead of a "malformed JSON string" parser message.
        die ( defined($apiResponseJSON) && $apiResponseJSON ne ""
            ? $apiResponseJSON
            : "Unexpected empty response from the Paubox Forms API." );
    }

    if (
        defined $apiResponsePERL -> {'errors'}
        || defined $apiResponsePERL -> {'message'}
        || !defined $apiResponsePERL -> {$successKey}
    ) {
        die $apiResponseJSON;
    }
    return;
}

#
# Public methods
#

#
# Get Form
# Retrieves a form's metadata, HTML, JSON schema, and CSS by UUID.
#
sub getForm {
    my ($class, $formId) = @_;
    my $apiResponseJSON = "";
    try {
        my $safeFormId = _pathSegment($formId, name => "formId");

        my $apiUrl = "/public/form_data/" . $safeFormId;
        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByGet($formsBaseURL, $apiUrl, "");

        my $apiResponsePERL = from_json($apiResponseJSON);

        if (
            !defined $apiResponsePERL->{'id'}
            && !defined $apiResponsePERL->{'errors'}
        ) {
            die $apiResponseJSON;
        }

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# Submit Form
# Submits form responses with optional file attachments.
# $formData  - hashref of field key/value pairs matching the form schema
# $attachments - optional arrayref of hashrefs with 'name' and 'content' (base64)
#
sub submitForm {
    my ($class, $formId, $formData, $attachments) = @_;
    my $apiResponseJSON = "";
    try {
        my $safeFormId = _pathSegment($formId, name => "formId");

        if ( !defined($formData) || ref($formData) ne 'HASH' || !%{$formData} ) {
            die "formData is required and must be a non-empty hash reference.";
        }

        my $apiUrl = "/api/forms/" . $safeFormId . "/submissions";

        my %payload = ( 'form_data' => $formData );
        if ( defined($attachments) && ref($attachments) eq 'ARRAY' && @{$attachments} ) {
            $payload{'attachments'} = $attachments;
        }

        my $reqBody = encode_json(\%payload);
        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByPost($formsBaseURL, $apiUrl, "", $reqBody);

        # 201 Created returns an empty body; treat that as success
        if ( defined($apiResponseJSON) && $apiResponseJSON ne "" ) {
            my $apiResponsePERL = from_json($apiResponseJSON);
            if ( defined $apiResponsePERL->{'errors'} ) {
                die $apiResponseJSON;
            }
        }

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# List Forms (authenticated)
# \%params: customer_id, form_id, search, order ("asc"|"desc"),
# order_by ("title"|"updated_at"|"submission_count"), archived, active,
# page, items (max 100). customer_id is required when authenticating with a
# scoped API key (pass your own customer id, or a related customer's id) —
# the server responds 403 Forbidden without it. archived/active accept any
# truthy/falsy Perl value.
#
sub listForms {
    my ($this, $params) = @_;
    my $apiResponseJSON = "";
    try {
        my $authHeader = _getAuthHeader($this);

        my $apiUrl = "/api/forms" . _buildQueryString(
            $params,
            qw(customer_id form_id search order order_by archived active page items)
        );
        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByGet($formsBaseURL, $apiUrl, $authHeader);

        _assertSuccessKey($apiHelper, $apiResponseJSON, 'results');

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# Get Form By Id (authenticated)
# Retrieves the full form record by UUID.
#
sub getFormById {
    my ($this, $formId) = @_;
    my $apiResponseJSON = "";
    try {
        my $authHeader = _getAuthHeader($this);
        my $safeFormId = _pathSegment($formId, name => "formId", require_uuid => 1);

        my $apiUrl = "/api/forms/" . $safeFormId;
        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByGet($formsBaseURL, $apiUrl, $authHeader);

        _assertSuccessKey($apiHelper, $apiResponseJSON, 'data');

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# Create Form (authenticated)
# \%attrs must include title, form_json (JSON object) and customer_id.
# version defaults to 1 when absent. Optional keys: description, form_html,
# form_css, recipient, signable, signature_confirmation_label,
# subscription_list_id, type, active, submission_count.
#
sub createForm {
    my ($this, $attrs) = @_;
    my $apiResponseJSON = "";
    try {
        my $authHeader = _getAuthHeader($this);

        if ( !defined($attrs) || ref($attrs) ne 'HASH' || !%{$attrs} ) {
            die "attrs is required and must be a non-empty hash reference.";
        }
        if ( !defined($attrs -> {'title'}) || $attrs -> {'title'} eq "" ) {
            die "title is required.";
        }
        if ( !defined($attrs -> {'form_json'}) ) {
            die "form_json is required.";
        }
        if ( !defined($attrs -> {'customer_id'}) ) {
            die "customer_id is required.";
        }

        my %payload = %{$attrs};
        $payload{'version'} = 1 unless defined $payload{'version'};
        _coerceBooleanKeys(\%payload, qw(signable active));

        my $apiUrl = "/api/forms";
        my $reqBody = encode_json(\%payload);
        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByPost($formsBaseURL, $apiUrl, $authHeader, $reqBody);

        _assertSuccessKey($apiHelper, $apiResponseJSON, 'id');

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# Update Form (authenticated)
# PATCH-style update: omitted keys are left unchanged. \%updates may include
# title, description, form_json, vanity_url, recipient, active,
# subscription_list_id.
#
sub updateForm {
    my ($this, $formId, $updates) = @_;
    my $apiResponseJSON = "";
    try {
        my $authHeader = _getAuthHeader($this);
        my $safeFormId = _pathSegment($formId, name => "formId", require_uuid => 1);

        if ( !defined($updates) || ref($updates) ne 'HASH' || !%{$updates} ) {
            die "updates is required and must be a non-empty hash reference.";
        }

        # Copy the caller's hashref so boolean coercion never mutates it.
        my %payload = %{$updates};
        _coerceBooleanKeys(\%payload, qw(active));

        my $apiUrl = "/api/forms/" . $safeFormId;
        my $reqBody = encode_json(\%payload);
        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByPut($formsBaseURL, $apiUrl, $authHeader, $reqBody);

        _assertSuccessKey($apiHelper, $apiResponseJSON, 'detail');

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# Archive Form (authenticated)
#
sub archiveForm {
    my ($this, $formId) = @_;
    my $apiResponseJSON = "";
    try {
        my $authHeader = _getAuthHeader($this);
        my $safeFormId = _pathSegment($formId, name => "formId", require_uuid => 1);

        my $apiUrl = "/api/forms/" . $safeFormId . "/archive";
        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByPost($formsBaseURL, $apiUrl, $authHeader, "");

        _assertSuccessKey($apiHelper, $apiResponseJSON, 'detail');

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# Unarchive Form (authenticated)
#
sub unarchiveForm {
    my ($this, $formId) = @_;
    my $apiResponseJSON = "";
    try {
        my $authHeader = _getAuthHeader($this);
        my $safeFormId = _pathSegment($formId, name => "formId", require_uuid => 1);

        my $apiUrl = "/api/forms/" . $safeFormId . "/unarchive";
        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByPost($formsBaseURL, $apiUrl, $authHeader, "");

        _assertSuccessKey($apiHelper, $apiResponseJSON, 'detail');

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# Copy Form (authenticated)
# Duplicates an existing form under a new title. Returns the new form record.
#
sub copyForm {
    my ($this, $formId, $newTitle) = @_;
    my $apiResponseJSON = "";
    try {
        my $authHeader = _getAuthHeader($this);

        if ( !defined($formId) || $formId eq "" ) {
            die "formId is required.";
        }
        if ( !defined($newTitle) || $newTitle eq "" ) {
            die "newTitle is required.";
        }

        my $apiUrl = "/api/forms/copy";
        my $reqBody = encode_json({ 'form_id' => $formId, 'title' => $newTitle });
        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByPost($formsBaseURL, $apiUrl, $authHeader, $reqBody);

        _assertSuccessKey($apiHelper, $apiResponseJSON, 'id');

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# Get Form Stats (authenticated)
# Optional \%params: customer_id.
#
sub getFormStats {
    my ($this, $params) = @_;
    my $apiResponseJSON = "";
    try {
        my $authHeader = _getAuthHeader($this);

        my $apiUrl = "/api/forms/stats" . _buildQueryString($params, qw(customer_id));
        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByGet($formsBaseURL, $apiUrl, $authHeader);

        _assertSuccessKey($apiHelper, $apiResponseJSON, 'active_form_count');

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# List Form Submissions (authenticated)
# Optional \%params: page, items (max 100), order ("asc"|"desc"),
# order_by ("submitter_email"), submission_id.
#
sub listFormSubmissions {
    my ($this, $formId, $params) = @_;
    my $apiResponseJSON = "";
    try {
        my $authHeader = _getAuthHeader($this);
        my $safeFormId = _pathSegment($formId, name => "formId", require_uuid => 1);

        my $apiUrl = "/api/forms/" . $safeFormId . "/submissions" . _buildQueryString(
            $params,
            qw(page items order order_by submission_id)
        );
        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByGet($formsBaseURL, $apiUrl, $authHeader);

        _assertSuccessKey($apiHelper, $apiResponseJSON, 'data');

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# Get Submissions CSV (authenticated)
# Exports all submissions of a form as raw CSV text, or a single submission
# when $submissionId is given.
#
sub getSubmissionsCsv {
    my ($this, $formId, $submissionId) = @_;
    my $apiResponse = "";
    try {
        my $authHeader = _getAuthHeader($this);
        my $safeFormId = _pathSegment($formId, name => "formId", require_uuid => 1);

        my $apiUrl = "/api/forms/" . $safeFormId . "/submissions/submission-csv";
        if ( defined($submissionId) && $submissionId ne "" ) {
            $apiUrl .= "/" . _pathSegment($submissionId, name => "submissionId", require_uuid => 1);
        }

        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponse = $apiHelper->callToAPIByGet($formsBaseURL, $apiUrl, $authHeader);

        my $responseCode = $apiHelper->responseCode();
        if ( !defined($responseCode) || $responseCode !~ /^2\d\d$/ ) {
            die ( defined($apiResponse) && $apiResponse ne ""
                ? $apiResponse
                : "Request failed with HTTP status " . ( defined($responseCode) ? $responseCode : "unknown" ) . "." );
        }

    } catch($err) {
        die $err;
    };

    return $apiResponse;
}

#
# Get Submission PDF (authenticated)
# Exports a single submission as raw PDF bytes.
#
sub getSubmissionPdf {
    my ($this, $formId, $submissionId) = @_;
    my $apiResponse = "";
    try {
        my $authHeader = _getAuthHeader($this);
        my $safeFormId = _pathSegment($formId, name => "formId", require_uuid => 1);
        my $safeSubmissionId = _pathSegment($submissionId, name => "submissionId", require_uuid => 1);

        my $apiUrl = "/api/forms/" . $safeFormId . "/submissions/" . $safeSubmissionId . "/submission-pdf";
        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponse = $apiHelper->callToAPIByGet($formsBaseURL, $apiUrl, $authHeader);

        my $responseCode = $apiHelper->responseCode();
        if ( !defined($responseCode) || $responseCode !~ /^2\d\d$/ ) {
            die ( defined($apiResponse) && $apiResponse ne ""
                ? $apiResponse
                : "Request failed with HTTP status " . ( defined($responseCode) ? $responseCode : "unknown" ) . "." );
        }

    } catch($err) {
        die $err;
    };

    return $apiResponse;
}

1;
__END__

=encoding utf8

=head1 NAME

Paubox_Forms_SDK - Perl wrapper for the Paubox Forms API (https://www.paubox.com/products/paubox-forms).

=head1 SYNOPSIS

    use strict;
    use warnings;
    use Paubox_Forms_SDK;

    # Public endpoints — no credentials required
    my $forms = Paubox_Forms_SDK->new();

    # Retrieve a form definition
    my $form = $forms->getForm("your-form-uuid");
    print $form;

    # Submit a form response
    my $response = $forms->submitForm(
        "your-form-uuid",
        { first_name => "Jane", last_name => "Doe", email => "jane\@example.com" }
    );

    # Authenticated form management — requires a scoped API key with the
    # "forms" scope (generated in the Paubox admin dashboard). The key may
    # also be set as FORMS_API_KEY in ./config.cfg.
    my $service = Paubox_Forms_SDK->new('apiKey' => 'your-scoped-api-key');

    # customer_id is required when authenticating with a scoped API key
    my $formList = $service->listForms({
        'customer_id' => 123,
        'search' => 'intake',
        'items' => 10
    });

    my $created = $service->createForm({
        'title' => 'Patient Intake',
        'form_json' => { 'fields' => [] },
        'customer_id' => 123
    });

    my $updated = $service->updateForm("your-form-uuid", { 'title' => 'New Title' });

    my $csv = $service->getSubmissionsCsv("your-form-uuid");
    my $pdf = $service->getSubmissionPdf("your-form-uuid", "submission-id");

=head1 DESCRIPTION

This is the official Perl wrapper for the Paubox Forms API. The C<getForm> and
C<submitForm> endpoints are public — no API key or credentials are required.

All other methods are authenticated form-management endpoints. They require a
scoped API key, sent as C<Authorization: Bearer E<lt>apiKeyE<gt>>. Scoped API
keys are generated in the Paubox admin dashboard and must include the C<forms>
scope. Pass the key to the constructor as C<'apiKey' =E<gt> '...'>, or set
C<FORMS_API_KEY> in C<./config.cfg>.

Unless noted otherwise, methods return the raw JSON response string on success
and die with the raw response on error.

=head1 CONSTRUCTOR

=head2 new

    my $forms = Paubox_Forms_SDK->new();                          # public endpoints only
    my $service = Paubox_Forms_SDK->new('apiKey' => '...');       # + authenticated endpoints

When no C<apiKey> parameter is given, the constructor attempts to load
C<FORMS_API_KEY> from C<./config.cfg>; a missing or unreadable config file is
ignored so the public-only constructor keeps working.

=head1 METHODS

=head2 getForm

    my $form = $forms->getForm($formId);

Public. Retrieves a form's metadata, HTML, JSON schema, and CSS by UUID.

=head2 submitForm

    my $response = $forms->submitForm($formId, \%formData, \@attachments);

Public. Submits form responses. C<\%formData> is a hashref of field key/value
pairs matching the form schema. C<\@attachments> is an optional arrayref of
hashrefs with C<name> and C<content> (base64-encoded) keys.

=head2 listForms

    my $response = $service->listForms(\%params);

Authenticated. Lists forms. C<\%params> keys: C<customer_id>,
C<form_id>, C<search>, C<order> ("asc"|"desc", default "desc"), C<order_by>
("title"|"updated_at"|"submission_count", default "created_at"), C<archived>,
C<active>, C<page> (default 1), C<items> (default 50, max 100). The response
contains C<results> and C<page_info>.

C<customer_id> is required when authenticating with a scoped API key: pass
your own customer id (or a related customer's id). Without it the server
responds C<403 Forbidden>. The C<archived> and C<active> filters accept any
truthy/falsy Perl value and are sent as C<true>/C<false>.

=head2 getFormById

    my $response = $service->getFormById($formId);

Authenticated. Retrieves the full form record by UUID. The response contains
the form under C<data>.

=head2 createForm

    my $response = $service->createForm({
        'title' => 'Patient Intake',       # required
        'form_json' => { ... },            # required (JSON object)
        'customer_id' => 123,              # required
        'version' => 1,                    # defaults to 1 when absent
        # optional: description, form_html, form_css, recipient (comma-separated
        # emails string), signable, signature_confirmation_label,
        # subscription_list_id, type, active, submission_count
    });

Authenticated. Creates a form. The response contains the new form's C<id>.
Boolean keys (C<signable>, C<active>) accept any truthy/falsy Perl value and
are sent as JSON C<true>/C<false>.

=head2 updateForm

    my $response = $service->updateForm($formId, \%updates);

Authenticated. PATCH-style update — omitted keys are left unchanged.
C<\%updates> must be a non-empty hashref and may include C<title>,
C<description>, C<form_json>, C<vanity_url>, C<recipient>, C<active>,
C<subscription_list_id>. The boolean C<active> key accepts any truthy/falsy
Perl value and is sent as JSON C<true>/C<false>.

=head2 archiveForm

    my $response = $service->archiveForm($formId);

Authenticated. Archives a form.

=head2 unarchiveForm

    my $response = $service->unarchiveForm($formId);

Authenticated. Unarchives a form.

=head2 copyForm

    my $response = $service->copyForm($formId, $newTitle);

Authenticated. Duplicates an existing form under a new title. The response is
the full new form record.

=head2 getFormStats

    my $response = $service->getFormStats(\%params);

Authenticated. Returns C<active_form_count>, C<total_submission_count> and
C<submissions_last_7_days>. Optional C<\%params> key: C<customer_id>.

=head2 listFormSubmissions

    my $response = $service->listFormSubmissions($formId, \%params);

Authenticated. Lists a form's submissions. Optional C<\%params> keys: C<page>,
C<items> (max 100), C<order> ("asc"|"desc"), C<order_by> ("submitter_email",
default "created_at"), C<submission_id>. The response contains C<data>,
C<total>, C<page> and C<items>.

=head2 getSubmissionsCsv

    my $csv = $service->getSubmissionsCsv($formId);
    my $csv = $service->getSubmissionsCsv($formId, $submissionId);

Authenticated. Exports all of a form's submissions — or a single submission
when C<$submissionId> is given — as raw CSV text (not JSON). Dies with the
response body on a non-2xx HTTP status.

=head2 getSubmissionPdf

    my $pdf = $service->getSubmissionPdf($formId, $submissionId);

Authenticated. Exports a single submission as raw PDF bytes (not JSON). Dies
with the response body on a non-2xx HTTP status.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 by Paubox Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut
