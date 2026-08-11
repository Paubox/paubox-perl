# Paubox Perl SDK — API Reference

## Email API

**Module:** `Paubox_Email_SDK`  
**Base URL:** `https://api.paubox.net/v1/{apiUsername}`  
**Authentication:** `Token token=<apiKey>` — credentials read from `config.cfg`

---

### `Paubox_Email_SDK->new()`

Loads `apiKey` and `apiUsername` from `config.cfg` in the current working directory.

```
API_KEY = YOUR_API_KEY
API_USERNAME = YOUR_ENDPOINT_NAME
```

Dies with an error message if either credential is missing.

---

### `$service->sendMessage($messageObj)`

Sends a HIPAA-compliant email message.

**Endpoint:** `POST /messages`

**Parameter:** A `Paubox_Email_SDK::Message` object.

| Message Field           | Type     | Required | Description                                        |
|-------------------------|----------|----------|----------------------------------------------------|
| `from`                  | String   | Yes      | Sender email address                               |
| `to`                    | ArrayRef | Yes      | Array of recipient email addresses                 |
| `subject`               | String   | Yes      | Email subject line                                 |
| `text_content`          | String   | No       | Plain-text body                                    |
| `html_content`          | String   | No       | HTML body (base64-encoded before transmission)     |
| `replyTo`               | String   | No       | Reply-to address                                   |
| `cc`                    | ArrayRef | No       | CC recipients                                      |
| `bcc`                   | ArrayRef | No       | BCC recipients                                     |
| `allowNonTLS`           | Boolean  | No       | `1` to allow delivery without TLS (default: `0`)  |
| `forceSecureNotification` | String | No      | `"true"` or `"false"` to override org default     |
| `attachments`           | ArrayRef | No       | Array of attachment hashrefs (see below)           |

**Attachment hashref fields:**

| Field         | Type   | Description                              |
|---------------|--------|------------------------------------------|
| `fileName`    | String | Filename shown to recipient              |
| `contentType` | String | MIME type (e.g. `"application/pdf"`)     |
| `content`     | String | Base64-encoded file content              |

**Returns:** JSON string. On success, contains `data` and `sourceTrackingId`. On
failure, contains `errors`.

**Example:**

```perl
my $msg = new Paubox_Email_SDK::Message(
    'from'         => 'sender@domain.com',
    'to'           => ['recipient@example.com'],
    'subject'      => 'Hello',
    'text_content' => 'Hello World!',
    'html_content' => '<html><body><h1>Hello World!</h1></body></html>',
);

my $service  = Paubox_Email_SDK->new();
my $response = $service->sendMessage($msg);
```

---

### `$service->getEmailDisposition($sourceTrackingId)`

Retrieves delivery and open status for a previously sent message.

**Endpoint:** `GET /message_receipt?sourceTrackingId={id}`

**Parameter:** `$sourceTrackingId` — String returned by `sendMessage`.

**Returns:** JSON string. On success, contains `data.message.message_deliveries`
with per-recipient status. Unopened messages have `openedStatus` set to
`"unopened"`. On failure, contains `errors`.

**Example:**

```perl
my $service  = Paubox_Email_SDK->new();
my $response = $service->getEmailDisposition("1aed91d1-f7ce-4c3d-8df2-85ecd225a7fc");
```

---

## Forms API

**Module:** `Paubox_Forms_SDK`  
**Base URL:** `https://apx.paubox.com/forms`  
**Authentication:** None for the public endpoints (`getForm`, `submitForm`). All
form-management endpoints require a scoped API key with the `forms` scope, sent
as `Authorization: Bearer <apiKey>`. Scoped API keys are generated in the Paubox
admin dashboard.

---

### `Paubox_Forms_SDK->new([%params])`

Creates a new Forms client.

```perl
my $forms   = Paubox_Forms_SDK->new();                             # public endpoints only
my $service = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_KEY'); # + authenticated endpoints
```

No credentials or configuration file are required for the public endpoints.

When no `apiKey` parameter is given, the constructor attempts to load
`FORMS_API_KEY` from `config.cfg` in the current working directory:

```
FORMS_API_KEY = YOUR_SCOPED_API_KEY
```

A missing or unreadable `config.cfg` is ignored, so the no-argument constructor
keeps working for public endpoints. Calling any authenticated method without a
key dies with:

```
apiKey is required for this method. Pass 'apiKey' to Paubox_Forms_SDK->new() or set FORMS_API_KEY in config.cfg. Scoped API keys are generated in the Paubox admin dashboard and must include the 'forms' scope.
```

---

### `$forms->getForm($formId)`

Retrieves a form's metadata, HTML, JSON schema, and CSS by UUID.

**Endpoint:** `GET /public/form_data/{formId}`

**Parameter:** `$formId` — UUID string of the form to retrieve.

**Returns:** JSON string containing form definition fields:

| Field       | Type   | Description                              |
|-------------|--------|------------------------------------------|
| `id`        | String | Form UUID                                |
| `title`     | String | Form title                               |
| `form_html` | String | Rendered HTML of the form                |
| `form_json` | Object | JSON schema of form fields               |
| `form_css`  | String | CSS styles for the form                  |

Dies if `formId` is empty or the response contains neither `id` nor `errors`.

**Example:**

```perl
my $forms    = Paubox_Forms_SDK->new();
my $response = $forms->getForm("your-form-uuid");
```

---

### `$forms->submitForm($formId, \%formData [, \@attachments])`

Submits a respondent's answers for a form, with optional file attachments.

**Endpoint:** `POST /api/forms/{formId}/submissions`

**Parameters:**

| Parameter      | Type     | Required | Description                                        |
|----------------|----------|----------|----------------------------------------------------|
| `$formId`      | String   | Yes      | UUID of the target form                            |
| `\%formData`   | HashRef  | Yes      | Key-value pairs matching the form's field schema   |
| `\@attachments`| ArrayRef | No       | Array of attachment hashrefs (see below)           |

**Attachment hashref fields:**

| Field     | Type   | Description                    |
|-----------|--------|--------------------------------|
| `name`    | String | Filename                       |
| `content` | String | Base64-encoded file content    |

Maximum total request size: **250 MB**.

**Returns:** Empty string on success (HTTP 201). Dies on error.

**Example:**

```perl
my $forms    = Paubox_Forms_SDK->new();
my $response = $forms->submitForm(
    "your-form-uuid",
    { first_name => "Jane", last_name => "Doe", email => "jane\@example.com" }
);
```

**With attachment:**

```perl
use MIME::Base64;

open(my $fh, '<:raw', 'consent.pdf') or die $!;
local $/;
my $encoded = encode_base64(<$fh>);
close($fh);

my $response = $forms->submitForm(
    "your-form-uuid",
    { first_name => "Jane" },
    [ { name => "consent.pdf", content => $encoded } ]
);
```

---

### `$service->listForms([\%params])`

Lists forms. Authenticated.

**Endpoint:** `GET /api/forms`

**Parameter:** `\%params` — optional hashref of query parameters. Only keys the
caller provides are sent; values are URI-escaped.

| Key           | Type    | Required | Description                                                              |
|---------------|---------|----------|--------------------------------------------------------------------------|
| `customer_id` | Integer | Yes*     | Your own customer id, or a related customer's id                         |
| `form_id`     | String  | No       | Filter by form UUID                                                      |
| `search`      | String  | No       | Search term                                                              |
| `order`       | String  | No       | `"asc"` or `"desc"` (default: `"desc"`)                                  |
| `order_by`    | String  | No       | `"title"`, `"updated_at"`, or `"submission_count"` (default: `created_at`) |
| `archived`    | Boolean | No       | Filter by archived state (any truthy/falsy Perl value; sent as `true`/`false`) |
| `active`      | Boolean | No       | Filter by active state (any truthy/falsy Perl value; sent as `true`/`false`)   |
| `page`        | Integer | No       | Page number (default: `1`)                                               |
| `items`       | Integer | No       | Items per page (default: `50`, max: `100`)                               |

\* `customer_id` is effectively required when authenticating with a scoped API
key: the server responds `403 Forbidden` unless it is your own customer id or
a related customer's id.

**Returns:** JSON string:

| Field       | Type   | Description                                    |
|-------------|--------|------------------------------------------------|
| `results`   | Array  | Array of form records                          |
| `page_info` | Object | Pagination info: `count`, `pages`, `page`, `items` |

Dies with the raw response if it contains `errors` or `message`, or if
`results` is absent.

**Example:**

```perl
use strict;
use warnings;
use Paubox_Forms_SDK;

my $service  = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_KEY');
my $response = $service->listForms({
    'customer_id' => 123,   # required with a scoped API key
    'search'      => 'intake',
    'items'       => 10,
});
print $response;
```

---

### `$service->getFormById($formId)`

Retrieves the full form record by UUID. Authenticated (unlike the public
`getForm`, this returns the complete record).

**Endpoint:** `GET /api/forms/{formId}`

**Parameter:** `$formId` — UUID string of the form. Dies with `formId is required.` if empty.

**Returns:** JSON string:

| Field  | Type   | Description          |
|--------|--------|----------------------|
| `data` | Object | The full form record |

Dies with the raw response if it contains `errors` or `message`, or if `data`
is absent.

**Example:**

```perl
my $service  = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_KEY');
my $response = $service->getFormById("your-form-uuid");
```

---

### `$service->createForm(\%attrs)`

Creates a new form. Authenticated.

**Endpoint:** `POST /api/forms`

**Parameter:** `\%attrs` — non-empty hashref of form attributes:

| Key                            | Type    | Required | Description                                       |
|--------------------------------|---------|----------|---------------------------------------------------|
| `title`                        | String  | Yes      | Form title                                        |
| `form_json`                    | Object  | Yes      | JSON schema of form fields                        |
| `customer_id`                  | Integer | Yes      | Owning customer id                                |
| `version`                      | Integer | No       | Defaults to `1` when absent                       |
| `description`                  | String  | No       | Form description                                  |
| `form_html`                    | String  | No       | Rendered HTML of the form                         |
| `form_css`                     | String  | No       | CSS styles for the form                           |
| `recipient`                    | String  | No       | Comma-separated recipient email addresses         |
| `signable`                     | Boolean | No       | Whether the form is signable (any truthy/falsy Perl value) |
| `signature_confirmation_label` | String  | No       | Signature confirmation label                      |
| `subscription_list_id`         | String  | No       | Subscription list id                              |
| `type`                         | String  | No       | Form type                                         |
| `active`                       | Boolean | No       | Active state (any truthy/falsy Perl value)        |
| `submission_count`             | Integer | No       | Initial submission count                          |

Dies with `title is required.` / `form_json is required.` /
`customer_id is required.` when a required key is missing.

**Returns:** JSON string:

| Field | Type   | Description             |
|-------|--------|-------------------------|
| `id`  | String | UUID of the new form    |

**Example:**

```perl
my $service  = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_KEY');
my $response = $service->createForm({
    'title'       => 'Patient Intake',
    'form_json'   => { 'fields' => [] },
    'customer_id' => 123,
});
```

---

### `$service->updateForm($formId, \%updates)`

Updates a form. PATCH-style: omitted keys are left unchanged. Authenticated.

**Endpoint:** `PUT /api/forms/{formId}`

**Parameters:**

| Parameter   | Type    | Required | Description                          |
|-------------|---------|----------|--------------------------------------|
| `$formId`   | String  | Yes      | UUID of the form to update           |
| `\%updates` | HashRef | Yes      | Non-empty hashref of fields to change |

Allowed `\%updates` keys: `title`, `description`, `form_json`, `vanity_url`,
`recipient`, `active` (boolean; any truthy/falsy Perl value),
`subscription_list_id`. Dies with
`updates is required and must be a non-empty hash reference.` for an empty or
missing hashref.

**Returns:** JSON string:

| Field     | Type   | Description                   |
|-----------|--------|-------------------------------|
| `detail`  | String | `"Form updated successfully"` |
| `form_id` | String | UUID of the updated form      |

**Example:**

```perl
my $service  = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_KEY');
my $response = $service->updateForm("your-form-uuid", { 'title' => 'New Title' });
```

---

### `$service->archiveForm($formId)`

Archives a form. Authenticated.

**Endpoint:** `POST /api/forms/{formId}/archive` (no request body)

**Parameter:** `$formId` — UUID string of the form. Dies with `formId is required.` if empty.

**Returns:** JSON string:

| Field    | Type   | Description         |
|----------|--------|---------------------|
| `detail` | String | `"Form archived."`  |

**Example:**

```perl
my $service  = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_KEY');
my $response = $service->archiveForm("your-form-uuid");
```

---

### `$service->unarchiveForm($formId)`

Unarchives a form. Authenticated.

**Endpoint:** `POST /api/forms/{formId}/unarchive` (no request body)

**Parameter:** `$formId` — UUID string of the form. Dies with `formId is required.` if empty.

**Returns:** JSON string:

| Field    | Type   | Description           |
|----------|--------|-----------------------|
| `detail` | String | `"Form unarchived."`  |

**Example:**

```perl
my $service  = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_KEY');
my $response = $service->unarchiveForm("your-form-uuid");
```

---

### `$service->copyForm($formId, $newTitle)`

Duplicates an existing form under a new title. Authenticated.

**Endpoint:** `POST /api/forms/copy`

**Parameters:**

| Parameter   | Type   | Required | Description                    |
|-------------|--------|----------|--------------------------------|
| `$formId`   | String | Yes      | UUID of the source form        |
| `$newTitle` | String | Yes      | Title for the copied form      |

Dies with `formId is required.` / `newTitle is required.` when missing.

**Returns:** JSON string — the full new form record, including:

| Field   | Type   | Description               |
|---------|--------|---------------------------|
| `id`    | String | UUID of the new form      |
| `title` | String | Title of the new form     |
| ...     |        | All other form fields     |

**Example:**

```perl
my $service  = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_KEY');
my $response = $service->copyForm("your-form-uuid", "Patient Intake (Copy)");
```

---

### `$service->getFormStats([\%params])`

Returns aggregate form statistics. Authenticated.

**Endpoint:** `GET /api/forms/stats`

**Parameter:** `\%params` — optional hashref:

| Key           | Type    | Required | Description        |
|---------------|---------|----------|--------------------|
| `customer_id` | Integer | No       | Filter by customer |

**Returns:** JSON string:

| Field                     | Type    | Description                       |
|---------------------------|---------|-----------------------------------|
| `active_form_count`       | Integer | Number of active forms            |
| `total_submission_count`  | Integer | Total submissions across forms    |
| `submissions_last_7_days` | Integer | Submissions in the last 7 days    |

**Example:**

```perl
my $service  = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_KEY');
my $response = $service->getFormStats();
```

---

### `$service->listFormSubmissions($formId [, \%params])`

Lists a form's submissions. Authenticated.

**Endpoint:** `GET /api/forms/{formId}/submissions`

**Parameters:**

| Parameter  | Type    | Required | Description                          |
|------------|---------|----------|--------------------------------------|
| `$formId`  | String  | Yes      | UUID of the form                     |
| `\%params` | HashRef | No       | Optional query parameters (below)    |

| Key             | Type    | Required | Description                                       |
|-----------------|---------|----------|---------------------------------------------------|
| `page`          | Integer | No       | Page number                                       |
| `items`         | Integer | No       | Items per page (max: `100`)                       |
| `order`         | String  | No       | `"asc"` or `"desc"`                               |
| `order_by`      | String  | No       | `"submitter_email"` (default: `created_at`)       |
| `submission_id` | String  | No       | Filter to a single submission                     |

**Returns:** JSON string:

| Field   | Type    | Description             |
|---------|---------|-------------------------|
| `data`  | Array   | Array of submissions    |
| `total` | Integer | Total submission count  |
| `page`  | Integer | Current page            |
| `items` | Integer | Items per page          |

**Example:**

```perl
my $service  = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_KEY');
my $response = $service->listFormSubmissions("your-form-uuid", { 'page' => 1, 'items' => 25 });
```

---

### `$service->getSubmissionsCsv($formId [, $submissionId])`

Exports all of a form's submissions — or a single submission when
`$submissionId` is given — as CSV. Authenticated.

**Endpoints:**
`GET /api/forms/{formId}/submissions/submission-csv` (all submissions)
`GET /api/forms/{formId}/submissions/submission-csv/{submissionId}` (one submission)

**Parameters:**

| Parameter       | Type   | Required | Description                          |
|-----------------|--------|----------|--------------------------------------|
| `$formId`       | String | Yes      | UUID of the form                     |
| `$submissionId` | String | No       | Export only this submission          |

**Returns:** Raw CSV text (not JSON). Dies with the response body on a non-2xx
HTTP status.

**Example:**

```perl
my $service = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_KEY');
my $csv     = $service->getSubmissionsCsv("your-form-uuid");

open(my $fh, '>', 'submissions.csv') or die $!;
print $fh $csv;
close($fh);
```

---

### `$service->getSubmissionPdf($formId, $submissionId)`

Exports a single submission as PDF. Authenticated.

**Endpoint:** `GET /api/forms/{formId}/submissions/{submissionId}/submission-pdf`

**Parameters:**

| Parameter       | Type   | Required | Description               |
|-----------------|--------|----------|---------------------------|
| `$formId`       | String | Yes      | UUID of the form          |
| `$submissionId` | String | Yes      | UUID of the submission    |

**Returns:** Raw PDF bytes (binary, not JSON). Dies with the response body on a
non-2xx HTTP status.

**Example:**

```perl
my $service = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_KEY');
my $pdf     = $service->getSubmissionPdf("your-form-uuid", "submission-id");

open(my $fh, '>:raw', 'submission.pdf') or die $!;
print $fh $pdf;
close($fh);
```
